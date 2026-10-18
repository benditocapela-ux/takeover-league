-- REVIEW ONLY. Atomic draft goal and trainer-configured EXP reward.
-- No EXP transactions are issued by this function.
BEGIN;
CREATE OR REPLACE FUNCTION public.coach_challenge_v2_save_goal_reward(
 p_challenge_id uuid,p_goal_text text,p_review_mode text,
 p_reward_exp integer,p_target_value numeric DEFAULT NULL,p_metric text DEFAULT NULL)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $fn$
DECLARE actor public.profiles%ROWTYPE; c public.league_coach_challenges%ROWTYPE;
BEGIN
 SELECT * INTO actor FROM public.profiles WHERE auth_user_id=(SELECT auth.uid())
 AND is_active=true AND role IN ('coach','admin');
 IF NOT FOUND THEN RAISE EXCEPTION 'Coach authorization required'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.league_feature_flags
 WHERE feature_key='coach_challenges' AND is_enabled=true) THEN
 RAISE EXCEPTION 'Coach challenges are disabled'; END IF;
 SELECT * INTO c FROM public.league_coach_challenges WHERE id=p_challenge_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Challenge not found'; END IF;
 IF actor.role<>'admin' AND c.created_by<>actor.id THEN
 RAISE EXCEPTION 'Not challenge owner'; END IF;
 IF c.status<>'draft' THEN RAISE EXCEPTION 'Only drafts can be edited'; END IF;
 IF p_reward_exp IS NULL OR p_reward_exp NOT IN (25,50,100,150,200)
 OR p_goal_text IS NULL OR pg_catalog.char_length(pg_catalog.btrim(p_goal_text)) NOT BETWEEN 5 AND 1000
 OR p_review_mode IS DISTINCT FROM 'manual'
 OR p_target_value IS NOT NULL OR p_metric IS NOT NULL THEN
 RAISE EXCEPTION 'Invalid challenge goal or reward'; END IF;
 UPDATE public.league_coach_challenges
 SET goal_spec=pg_catalog.jsonb_build_object(
 'version',1,'goal_text',pg_catalog.btrim(p_goal_text),
 'review_mode',p_review_mode,'target_value',p_target_value,
 'metric',p_metric,'reward_exp',p_reward_exp),
 updated_at=pg_catalog.clock_timestamp() WHERE id=p_challenge_id;
 RETURN 'goal_reward_saved';
END $fn$;
REVOKE ALL ON FUNCTION public.coach_challenge_v2_save_goal_reward(uuid,text,text,integer,numeric,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.coach_challenge_v2_save_goal_reward(uuid,text,text,integer,numeric,text) TO authenticated;
COMMIT;
