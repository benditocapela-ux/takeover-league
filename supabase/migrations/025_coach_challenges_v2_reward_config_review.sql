-- REVIEW ONLY. Add optional per-challenge reward configuration to draft goals.
-- No EXP payout; feature remains disabled by default.
BEGIN;
CREATE OR REPLACE FUNCTION public.coach_challenge_v2_set_reward(
 p_challenge_id uuid,p_reward_exp integer)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $fn$
DECLARE actor public.profiles%ROWTYPE; c public.league_coach_challenges%ROWTYPE;
BEGIN
 SELECT * INTO actor FROM public.profiles
 WHERE auth_user_id=(SELECT auth.uid()) AND is_active=true
 AND role IN ('coach','admin');
 IF NOT FOUND THEN RAISE EXCEPTION 'Coach authorization required'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.league_feature_flags
 WHERE feature_key='coach_challenges' AND is_enabled=true) THEN
 RAISE EXCEPTION 'Coach challenges are disabled'; END IF;
 SELECT * INTO c FROM public.league_coach_challenges
 WHERE id=p_challenge_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Challenge not found'; END IF;
 IF actor.role<>'admin' AND c.created_by<>actor.id THEN
 RAISE EXCEPTION 'Not challenge owner'; END IF;
 IF c.status<>'draft' THEN RAISE EXCEPTION 'Only drafts can be edited'; END IF;
 IF p_reward_exp IS NULL OR p_reward_exp NOT IN (25,50,100,150,200) THEN
 RAISE EXCEPTION 'Unsupported reward amount'; END IF;
 UPDATE public.league_coach_challenges
 SET goal_spec=pg_catalog.jsonb_set(
 COALESCE(goal_spec,'{}'::jsonb),'{reward_exp}',pg_catalog.to_jsonb(p_reward_exp),true),
 updated_at=pg_catalog.clock_timestamp() WHERE id=p_challenge_id;
 RETURN 'reward_saved';
END $fn$;
REVOKE ALL ON FUNCTION public.coach_challenge_v2_set_reward(uuid,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.coach_challenge_v2_set_reward(uuid,integer) TO authenticated;
COMMIT;
