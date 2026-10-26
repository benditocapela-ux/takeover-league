-- READ ONLY postflight for 20261027090000_profile_archive_hides_and_locks.sql.
SELECT column_name FROM information_schema.columns
WHERE table_schema='public' AND table_name='profiles' AND column_name IN ('archived_prev_active','archived_prev_listed')
ORDER BY 1;  -- expect 2 rows
SELECT tgname, pg_get_triggerdef(oid) FROM pg_trigger
WHERE tgrelid='public.profiles'::regclass AND tgname='profiles_archive_guard';  -- expect 1 row
SELECT p.proname,
       pg_get_functiondef(p.oid) LIKE '%archived_prev_active%' OR p.proname LIKE 'admin_set_profile_%' AS updated_body,
       pg_get_functiondef(p.oid) LIKE '%zuerst wiederherstellen%' AS locks_while_archived,
       has_function_privilege('anon',p.oid,'execute') AS anon_exec,
       has_function_privilege('authenticated',p.oid,'execute') AS auth_exec
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.proname IN ('admin_archive_profile','admin_restore_profile','admin_set_profile_active','admin_set_profile_listed','profiles_archive_guard')
ORDER BY 1;  -- anon_exec false everywhere; auth_exec false only for profiles_archive_guard
-- Invariant: no archived profile is active or listed.
SELECT count(*) AS archived_but_visible_or_active
FROM public.profiles WHERE archived_at IS NOT NULL AND (is_active OR is_listed);  -- expect 0
-- Nothing else changed in size:
SELECT (SELECT count(*) FROM public.profiles) AS profiles,
       (SELECT count(*) FROM public.training_submissions) AS trainings,
       (SELECT count(*) FROM public.point_transactions) AS point_transactions;
