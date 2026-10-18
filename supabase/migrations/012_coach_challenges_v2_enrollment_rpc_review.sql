-- Coach Challenges V2: coach-only draft creation and boxer opt-in.
-- REVIEW ONLY; no live execution. No evaluation or payouts in this migration.
BEGIN;
CREATE OR REPLACE FUNCTION public.coach_challenge_v2_create_draft(
 p_title text,p_description text,p_kind text,p_duration_days integer)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $fn$
DECLARE v_actor public.profiles%ROWTYPE; v_id uuid;
BEGIN
 SELECT * INTO v_actor FROM public.profiles
 WHERE auth_user_id=(SELECT auth.uid()) AND is_active=true;
 IF NOT FOUND OR v_actor.role NOT IN ('admin','coach') THEN
  RAISE EXCEPTION 'Only a coach may create challenges';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.league_feature_flags
               WHERE feature_key='coach_challenges' AND is_enabled=true) THEN
  RAISE EXCEPTION 'Coach challenges are not enabled';
 END IF;
 IF p_kind IS NULL OR p_kind NOT IN ('individual','competition','coach_goal')
    OR p_duration_days IS NULL OR p_duration_days NOT IN (7,14,30)
    OR p_title IS NULL OR pg_catalog.char_length(pg_catalog.btrim(p_title)) NOT BETWEEN 3 AND 120
    OR p_description IS NULL THEN
  RAISE EXCEPTION 'Invalid challenge draft parameters';
 END IF;
 INSERT INTO public.league_coach_challenges
  (created_by,title,description,challenge_kind,duration_days)
 VALUES(v_actor.id,pg_catalog.btrim(p_title),p_description,p_kind,p_duration_days)
 RETURNING id INTO v_id;
 RETURN v_id;
END $fn$;

CREATE OR REPLACE FUNCTION public.coach_challenge_v2_join(p_challenge_id uuid)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $fn$
DECLARE v_actor public.profiles%ROWTYPE; v_challenge public.league_coach_challenges%ROWTYPE;
BEGIN
 SELECT * INTO v_actor FROM public.profiles
 WHERE auth_user_id=(SELECT auth.uid()) AND is_active=true;
 IF NOT FOUND OR v_actor.role<>'boxer' THEN
  RAISE EXCEPTION 'Only an active boxer may join challenges';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.league_feature_flags
               WHERE feature_key='coach_challenges' AND is_enabled=true) THEN
  RAISE EXCEPTION 'Coach challenges are not enabled';
 END IF;
 SELECT * INTO v_challenge FROM public.league_coach_challenges
 WHERE id=p_challenge_id FOR UPDATE;
 IF NOT FOUND OR v_challenge.status<>'open' THEN
  RAISE EXCEPTION 'Challenge is not open for enrollment';
 END IF;
 INSERT INTO public.league_coach_challenge_entries(challenge_id,boxer_id)
 VALUES(v_challenge.id,v_actor.id)
 ON CONFLICT(challenge_id,boxer_id) DO UPDATE
 SET status='joined',joined_at=pg_catalog.clock_timestamp()
 WHERE public.league_coach_challenge_entries.status='withdrawn';
 IF NOT FOUND THEN RAISE EXCEPTION 'Already enrolled in challenge'; END IF;
 RETURN 'joined';
END $fn$;

REVOKE ALL ON FUNCTION public.coach_challenge_v2_create_draft(text,text,text,integer) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.coach_challenge_v2_join(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.coach_challenge_v2_create_draft(text,text,text,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.coach_challenge_v2_join(uuid) TO authenticated;
COMMIT;
