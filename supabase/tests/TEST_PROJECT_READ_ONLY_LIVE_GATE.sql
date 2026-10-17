-- Safe, read-only live test against isolated Supabase test project.
-- Run with the SQL editor/service role. Never enable feature flags here.
BEGIN READ ONLY;
DO $test$
BEGIN
 IF EXISTS (SELECT 1 FROM public.league_feature_flags WHERE feature_key IN ('achievements','duels','coach_challenges') AND is_enabled)
 THEN RAISE EXCEPTION 'Unexpected enabled feature flag'; END IF;
 IF (SELECT count(*) FROM public.achievement_definitions) <> 32 THEN RAISE EXCEPTION 'Achievement definition count mismatch'; END IF;
 IF (SELECT count(*) FROM public.achievement_v2_rules) <> 32 THEN RAISE EXCEPTION 'Achievement rule count mismatch'; END IF;
 IF has_function_privilege('anon','public.coach_challenge_v2_settle_manual(uuid)','EXECUTE')
 THEN RAISE EXCEPTION 'Anonymous settlement access'; END IF;
 IF has_function_privilege('anon','public.coach_challenge_v2_save_goal_reward(uuid,text,text,integer,numeric,text)','EXECUTE')
 THEN RAISE EXCEPTION 'Anonymous goal editing access'; END IF;
END $test$;
ROLLBACK;
