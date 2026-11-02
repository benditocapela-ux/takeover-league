-- Read-only pre/postflight for the standalone staff points queue.
SELECT to_regprocedure('league_v21_private.duel_close_preview_core(uuid,timestamp with time zone)') IS NOT NULL AS shared_preview_exists,
 EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='archived_at') AS archived_guard_exists,
 to_regprocedure('public.duel_v2_staff_queue(text,integer,timestamp with time zone,uuid,text,uuid)') IS NOT NULL AS queue_installed;
SELECT n.nspname,p.proname,p.provolatile,p.prosecdef,p.proconfig,
 has_function_privilege('anon',p.oid,'EXECUTE') AS anon_execute,
 has_function_privilege('authenticated',p.oid,'EXECUTE') AS authenticated_execute
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE (n.nspname='public' AND p.proname='duel_v2_staff_queue') OR
 (n.nspname='league_v21_private' AND p.proname='duel_staff_queue_core');
SELECT indexname,indexdef FROM pg_indexes WHERE schemaname='public' AND indexname='league_duels_staff_cursor_idx';
