\set ON_ERROR_STOP on
-- Runs after tests/profile-archive-hides-locks-schema.sql in the same disposable database.
-- 1) Rollback must refuse while a profile is archived (profile 5 is still archived there).
DO $test$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.profiles WHERE archived_at IS NOT NULL) THEN
  RAISE EXCEPTION 'Fixture expected at least one archived profile';
 END IF;
END
$test$;
\set ON_ERROR_STOP off
\ir ../supabase/production-prep/rollback_20261027090000_profile_archive_hides_and_locks.sql
\set ON_ERROR_STOP on
ROLLBACK;
DO $test$
BEGIN
 IF to_regprocedure('public.profiles_archive_guard()') IS NULL THEN
  RAISE EXCEPTION 'Rollback ran although profiles were archived';
 END IF;
END
$test$;
-- 2) After restoring everything, rollback succeeds and returns the 21.10. semantics.
SELECT set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',false);
SELECT public.admin_restore_profile(id) FROM public.profiles WHERE archived_at IS NOT NULL;
\ir ../supabase/production-prep/rollback_20261027090000_profile_archive_hides_and_locks.sql
DO $test$
BEGIN
 IF to_regprocedure('public.profiles_archive_guard()') IS NOT NULL
    OR EXISTS(SELECT 1 FROM information_schema.columns WHERE table_name='profiles' AND column_name LIKE 'archived_prev_%')
    OR pg_get_functiondef('public.admin_archive_profile(uuid)'::regprocedure) LIKE '%archived_prev_active%'
    OR pg_get_functiondef('public.admin_set_profile_active(uuid,boolean)'::regprocedure) LIKE '%zuerst wiederherstellen%' THEN
  RAISE EXCEPTION 'Rollback left new archive semantics behind';
 END IF;
 IF has_function_privilege('anon','public.admin_archive_profile(uuid)','execute') THEN
  RAISE EXCEPTION 'Rollback widened grants';
 END IF;
END
$test$;
-- 3) Re-applying the migration after a rollback works.
\ir ../supabase/migrations/20261027090000_profile_archive_hides_and_locks.sql
SELECT 'PASS: rollback refuses while archived, restores previous semantics, migration re-applies' AS result;
