\set ON_ERROR_STOP on
DO $$BEGIN IF current_database() NOT LIKE 'league21_replay_%' THEN RAISE EXCEPTION 'Disposable database required'; END IF; END$$;
CREATE TEMP TABLE studio_rows_before AS SELECT md5(string_agg(to_jsonb(s)::text,'' ORDER BY id)) digest FROM public.training_submissions s;
\ir ../supabase/production-prep/rollback_20261102103929_studio_training_history_summary.sql
DO $$BEGIN
 IF to_regprocedure('public.get_my_studio_training_summary()') IS NOT NULL OR to_regnamespace('league_studio_private') IS NOT NULL
 THEN RAISE EXCEPTION 'Reader rollback incomplete'; END IF;
 IF (SELECT digest FROM studio_rows_before) IS DISTINCT FROM (SELECT md5(string_agg(to_jsonb(s)::text,'' ORDER BY id)) FROM public.training_submissions s)
 THEN RAISE EXCEPTION 'Rollback changed training data';END IF;
END$$;
\ir ../supabase/migrations/20261102103929_studio_training_history_summary.sql
DO $$BEGIN
 IF EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='league_studio_private' AND (has_function_privilege('anon',p.oid,'EXECUTE') OR p.proconfig<>ARRAY['search_path=""']))
 THEN RAISE EXCEPTION 'Private helper grants/search_path invalid';END IF;
 IF has_schema_privilege('anon','league_studio_private','USAGE') THEN RAISE EXCEPTION 'Anonymous private schema usage';END IF;
END$$;
\echo PASS Studio reader rollback/reapply preserves every training row and restrictive helper grants.
