-- Coach roles postflight: READ ONLY; never modifies a profile, point, flag or migration.
SELECT count(*) AS active_coach_profiles FROM public.profiles WHERE role='coach' AND is_active;
SELECT p.proname,pg_get_function_identity_arguments(p.oid) args,p.prosecdef,pg_get_function_result(p.oid) AS return_type FROM pg_proc p
 JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname IN ('is_league_coach','coach_list_boxers','is_league_admin','recalculate_boxer_bonuses');
SELECT tablename,policyname,cmd FROM pg_policies WHERE schemaname='public' AND policyname LIKE 'coach_v3_%' ORDER BY tablename,policyname;
SELECT feature_key,is_enabled FROM public.league_feature_flags WHERE feature_key IN ('seasons','league_challenges','hall_of_fame','palmares','public_boxer_profiles','boxer_duels','coach_goals') ORDER BY feature_key;
