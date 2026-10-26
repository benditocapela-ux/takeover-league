-- READ ONLY preflight for 20261027090000_profile_archive_hides_and_locks.sql.
-- Expected: production project iqarjivcrddcixrvqbfb, archive migration 20261021230000 present.
SELECT current_database() AS database_name, current_user AS database_role;
SELECT column_name, data_type FROM information_schema.columns
WHERE table_schema='public' AND table_name='profiles'
  AND column_name IN ('is_active','is_listed','archived_at','archived_prev_active','archived_prev_listed')
ORDER BY column_name;
SELECT to_regprocedure('public.admin_archive_profile(uuid)') AS archive_rpc,
       to_regprocedure('public.admin_restore_profile(uuid)') AS restore_rpc,
       to_regprocedure('public.admin_set_profile_active(uuid,boolean)') AS active_rpc,
       to_regprocedure('public.admin_set_profile_listed(uuid,boolean)') AS listed_rpc;
-- Profiles the migration will backfill (archived under the old semantics):
SELECT count(*) FILTER (WHERE archived_at IS NOT NULL) AS archived_profiles,
       count(*) FILTER (WHERE archived_at IS NOT NULL AND (is_active OR is_listed)) AS archived_but_visible_or_active,
       count(*) FILTER (WHERE is_active AND is_listed) AS public_profiles,
       count(*) AS profiles_total
FROM public.profiles;
SELECT tgname FROM pg_trigger WHERE tgrelid='public.profiles'::regclass AND NOT tgisinternal ORDER BY 1;
