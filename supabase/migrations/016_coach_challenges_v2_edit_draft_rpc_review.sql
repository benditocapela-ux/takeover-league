-- REVIEW ONLY. Coach challenge draft edits; no live execution.
BEGIN;
CREATE OR REPLACE FUNCTION public.coach_challenge_v2_edit_draft(
 p_id uuid,p_title text,p_description text,p_kind text,p_days integer)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $fn$
DECLARE actor public.profiles%ROWTYPE; challenge public.league_coach_challenges%ROWTYPE;
BEGIN
 SELECT * INTO actor FROM public.profiles
 WHERE auth_user_id=(SELECT auth.uid()) AND is_active;
 IF NOT FOUND OR actor.role NOT IN ('coach','admin') THEN
  RAISE EXCEPTION 'Coach authorization required';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.league_feature_flags
 WHERE feature_key='coach_challenges' AND is_enabled) THEN
  RAISE EXCEPTION 'Coach challenges are disabled';
 END IF;
 SELECT * INTO challenge FROM public.league_coach_challenges WHERE id=p_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Challenge not found'; END IF;
 IF actor.role<>'admin' AND challenge.created_by<>actor.id THEN
  RAISE EXCEPTION 'Not challenge owner';
 END IF;
 IF challenge.status<>'draft' THEN RAISE EXCEPTION 'Only drafts can be edited'; END IF;
 IF p_title IS NULL OR length(btrim(p_title)) NOT BETWEEN 3 AND 120
 OR p_description IS NULL OR p_kind IS NULL
 OR p_kind NOT IN ('individual','competition','coach_goal')
 OR p_days IS NULL OR p_days NOT IN (7,14,30) THEN
  RAISE EXCEPTION 'Invalid draft fields';
 END IF;
 UPDATE public.league_coach_challenges
 SET title=btrim(p_title),description=p_description,
 challenge_kind=p_kind,duration_days=p_days,updated_at=clock_timestamp()
 WHERE id=p_id;
 RETURN 'updated';
END $fn$;
REVOKE ALL ON FUNCTION public.coach_challenge_v2_edit_draft(uuid,text,text,text,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.coach_challenge_v2_edit_draft(uuid,text,text,text,integer) TO authenticated;
COMMIT;
