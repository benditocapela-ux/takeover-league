-- READ ONLY preflight for the reversible Clubverwaltung archive.
SELECT current_database() AS database_name, current_user AS database_role;
SELECT to_regclass('public.profiles') AS profiles_table,
       to_regclass('public.profile_admin_audit') AS admin_audit_table;
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema='public' AND table_name='profiles'
  AND column_name IN ('id','role','is_active','archived_at')
ORDER BY column_name;
SELECT to_regprocedure('public.admin_archive_profile(uuid)') AS archive_rpc,
       to_regprocedure('public.admin_restore_profile(uuid)') AS restore_rpc,
       to_regprocedure('public.admin_list_profile_archive_state()') AS state_rpc;
SELECT action, count(*) FROM public.profile_admin_audit
WHERE action IN ('archive','restore') GROUP BY action ORDER BY action;
