-- Coach Challenges V2: voluntary withdrawal before activation.
-- REVIEW ONLY. No live execution, evaluation or payout.
BEGIN;
CREATE OR REPLACE FUNCTION public.coach_challenge_v2_withdraw(p_challenge_id uuid)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $fn$
DECLARE v_actor public.profiles%ROWTYPE;
 v_challenge public.league_coach_challenges%ROWTYPE;
BEGIN
 SELECT * INTO v_actor FROM public.profiles
 WHERE auth_user_id=(SELECT auth.uid()) AND is_active=true;
 IF NOT FOUND OR v_actor.role<>'boxer' THEN
  RAISE EXCEPTION 'Only an active boxer may withdraw';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.league_feature_flags
               WHERE feature_key='coach_challenges' AND is_enabled=true) THEN
  RAISE EXCEPTION 'Coach challenges are not enabled';
 END IF;
 SELECT * INTO v_challenge FROM public.league_coach_challenges
 WHERE id=p_challenge_id FOR UPDATE;
 IF NOT FOUND OR v_challenge.status<>'open' THEN
  RAISE EXCEPTION 'Only open challenges permit withdrawal';
 END IF;
 UPDATE public.league_coach_challenge_entries
 SET status='withdrawn'
 WHERE challenge_id=v_challenge.id AND boxer_id=v_actor.id AND status='joined';
 IF NOT FOUND THEN RAISE EXCEPTION 'No active enrollment to withdraw'; END IF;
 RETURN 'withdrawn';
END $fn$;
REVOKE ALL ON FUNCTION public.coach_challenge_v2_withdraw(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.coach_challenge_v2_withdraw(uuid) TO authenticated;
COMMIT;
