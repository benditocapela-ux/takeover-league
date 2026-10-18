-- REVIEW ONLY. Define explicit goals for draft coach challenges.
-- No activation, evaluation, awards or live execution.
BEGIN;
CREATE OR REPLACE FUNCTION public.coach_challenge_v2_set_goal(
 p_challenge_id uuid,p_goal_text text,p_review_mode text,p_target_value numeric DEFAULT NULL,
 p_metric text DEFAULT NULL)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $fn$
DECLARE actor public.profiles%ROWTYPE; challenge public.league_coach_challenges%ROWTYPE;
BEGIN
 SELECT * INTO actor FROM public.profiles
 WHERE auth_user_id=(SELECT auth.uid()) AND is_active=true;
 IF NOT FOUND OR actor.role NOT IN ('coach','admin') THEN
  RAISE EXCEPTION 'Coach authorization required';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.league_feature_flags
 WHERE feature_key='coach_challenges' AND is_enabled=true) THEN
  RAISE EXCEPTION 'Coach challenges are disabled';
 END IF;
 SELECT * INTO challenge FROM public.league_coach_challenges
 WHERE id=p_challenge_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Challenge not found'; END IF;
 IF actor.role<>'admin' AND challenge.created_by<>actor.id THEN
  RAISE EXCEPTION 'Not challenge owner';
 END IF;
 IF challenge.status<>'draft' THEN RAISE EXCEPTION 'Only drafts can be edited'; END IF;
 IF p_goal_text IS NULL OR pg_catalog.char_length(pg_catalog.btrim(p_goal_text)) NOT BETWEEN 5 AND 1000
 OR p_review_mode IS NULL OR p_review_mode NOT IN ('manual','automatic')
 OR (p_review_mode='manual' AND (p_target_value IS NOT NULL OR p_metric IS NOT NULL))
 OR (p_review_mode='automatic' AND
    (p_target_value IS NULL OR p_target_value<=0 OR p_target_value>1000000
     OR p_metric IS NULL OR p_metric NOT IN ('jogging_km','technique_minutes'))) THEN
  RAISE EXCEPTION 'Invalid challenge goal definition';
 END IF;
 UPDATE public.league_coach_challenges
 SET goal_spec=pg_catalog.jsonb_build_object(
  'version',1,'goal_text',pg_catalog.btrim(p_goal_text),
  'review_mode',p_review_mode,'target_value',p_target_value,
  'metric',p_metric) || CASE WHEN challenge.goal_spec ? 'reward_exp' THEN
 pg_catalog.jsonb_build_object('reward_exp',challenge.goal_spec->'reward_exp')
 ELSE '{}'::jsonb END,
  updated_at=clock_timestamp()
 WHERE id=p_challenge_id;
 RETURN 'goal_saved';
END $fn$;
REVOKE ALL ON FUNCTION public.coach_challenge_v2_set_goal(uuid,text,text,numeric,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.coach_challenge_v2_set_goal(uuid,text,text,numeric,text) TO authenticated;
COMMIT;
