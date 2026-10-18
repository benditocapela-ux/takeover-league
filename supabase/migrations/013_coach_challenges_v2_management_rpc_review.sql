-- Coach Challenges V2: coach-controlled draft publication and cancellation.
-- REVIEW ONLY. No live execution, goal evaluation, activation or payouts.
BEGIN;
CREATE OR REPLACE FUNCTION public.coach_challenge_v2_manage(
 p_challenge_id uuid,p_action text)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $fn$
DECLARE v_actor public.profiles%ROWTYPE;
 v_challenge public.league_coach_challenges%ROWTYPE;
BEGIN
 SELECT * INTO v_actor FROM public.profiles
 WHERE auth_user_id=(SELECT auth.uid()) AND is_active=true;
 IF NOT FOUND OR v_actor.role NOT IN ('admin','coach') THEN
  RAISE EXCEPTION 'Only a coach may manage challenges';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.league_feature_flags
               WHERE feature_key='coach_challenges' AND is_enabled=true) THEN
  RAISE EXCEPTION 'Coach challenges are not enabled';
 END IF;
 IF p_action IS NULL OR p_action NOT IN ('open','cancel') THEN
  RAISE EXCEPTION 'Unsupported challenge action';
 END IF;
 SELECT * INTO v_challenge FROM public.league_coach_challenges
 WHERE id=p_challenge_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Challenge not found'; END IF;
 IF v_actor.role<>'admin' AND v_challenge.created_by<>v_actor.id THEN
  RAISE EXCEPTION 'Only the creating coach may manage this challenge';
 END IF;
 IF p_action='open' THEN
  IF v_challenge.status<>'draft' THEN
   RAISE EXCEPTION 'Only draft challenges can be opened';
  END IF;
  UPDATE public.league_coach_challenges
  SET status='open',updated_at=pg_catalog.clock_timestamp()
  WHERE id=v_challenge.id;
  RETURN 'open';
 END IF;
 -- No cancellation after activation: future settlement logic must determine
 -- whether any earned EXP requires adjustment or reversal.
 IF v_challenge.status NOT IN ('draft','open') THEN
  RAISE EXCEPTION 'Only draft or open challenges can be cancelled';
 END IF;
 UPDATE public.league_coach_challenges
 SET status='cancelled',updated_at=pg_catalog.clock_timestamp()
 WHERE id=v_challenge.id;
 RETURN 'cancelled';
END $fn$;
REVOKE ALL ON FUNCTION public.coach_challenge_v2_manage(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.coach_challenge_v2_manage(uuid,text) TO authenticated;
COMMIT;
