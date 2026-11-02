-- READ ONLY. No raw training notes or profiles returned. Preflight: columns/indexes; postflight: grants/search_path.
SELECT table_name,column_name,data_type FROM information_schema.columns
 WHERE table_schema='public' AND table_name IN ('profiles','training_submissions','training_types')
 ORDER BY table_name,ordinal_position;
SELECT indexname,indexdef FROM pg_indexes WHERE schemaname='public' AND tablename='training_submissions';
SELECT n.nspname,p.proname,p.prosecdef,p.proconfig,
 has_function_privilege('anon',p.oid,'EXECUTE') anon_execute,
 has_function_privilege('authenticated',p.oid,'EXECUTE') authenticated_execute
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='league_studio_private' OR p.proname IN ('get_my_studio_training_history','get_my_studio_training_summary')
 ORDER BY n.nspname,p.proname;
