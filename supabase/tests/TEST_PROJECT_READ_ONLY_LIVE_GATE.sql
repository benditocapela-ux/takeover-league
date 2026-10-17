-- Safe, read-only live test against isolated Supabase test project.
-- Run with the SQL editor/service role. Never enable feature flags here.
BEGIN READ ONLY;
DO $test$
BEGIN
 IF EXISTS (SELECT 1 FROM public.league_feature_flags WHERE feature_key IN ('achievements','duels','coach_challenges') AND is_enabled)
 THEN RAISE EXCEPTION 'Unexpected enabled feature flag'; END IF;
 IF (SELECT count(*) FROM public.achievement_definitions) <> 32 THEN RAISE EXCEPTION 'Achievement definition count mismatch'; END IF;
 IF (SELECT count(*) FROM public.achievement_v2_rules) <> 32 THEN RAISE EXCEPTION 'Achievement rule count mismatch'; END IF;
 IF (SELECT count(*) FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname LIKE 'coach_challenge_v2_%') <> 17
 THEN RAISE EXCEPTION 'Challenge RPC inventory mismatch'; END IF;
 IF EXISTS (
   SELECT 1 FROM information_schema.role_table_grants
   WHERE table_schema='public' AND table_name LIKE 'league_coach_challenge%'
   AND grantee IN ('anon','authenticated')
   AND privilege_type IN ('SELECT','INSERT','UPDATE','DELETE')
 ) THEN RAISE EXCEPTION 'Direct challenge table API grant found'; END IF;
 IF EXISTS (
   SELECT 1 FROM pg_catalog.pg_proc p
   JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname='public' AND p.proname LIKE 'coach_challenge_v2_%'
     AND (NOT p.prosecdef OR NOT EXISTS (
       SELECT 1 FROM unnest(p.proconfig) setting WHERE setting LIKE 'search_path=%'
     ))
 ) THEN RAISE EXCEPTION 'Challenge RPC lacks protected search_path or SECURITY DEFINER'; END IF;
 IF EXISTS (
   SELECT 1 FROM pg_catalog.pg_proc p
   JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname='public' AND p.proname LIKE 'coach_challenge_v2_%'
     AND has_function_privilege('anon',p.oid,'EXECUTE')
 ) THEN RAISE EXCEPTION 'Anonymous access to challenge RPC'; END IF;
 IF has_function_privilege('anon','public.coach_challenge_v2_settle_manual(uuid)','EXECUTE')
 THEN RAISE EXCEPTION 'Anonymous settlement access'; END IF;
 IF has_function_privilege('anon','public.coach_challenge_v2_save_goal_reward(uuid,text,text,integer,numeric,text)','EXECUTE')
 THEN RAISE EXCEPTION 'Anonymous goal editing access'; END IF;
END $test$;
ROLLBACK;
