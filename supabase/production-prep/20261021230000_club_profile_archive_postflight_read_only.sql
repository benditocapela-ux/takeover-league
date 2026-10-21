-- READ ONLY postflight for the reversible Clubverwaltung archive.
SELECT current_database() AS database_name, current_user AS database_role;
SELECT count(*) FILTER (WHERE archived_at IS NOT NULL) AS archived_profiles,
       count(*) FILTER (WHERE archived_at IS NULL) AS non_archived_profiles,
       count(*) FILTER (WHERE role='admin' AND archived_at IS NOT NULL) AS archived_admin_profiles
FROM public.profiles;
SELECT to_regprocedure('public.admin_archive_profile(uuid)') AS archive_rpc,
       to_regprocedure('public.admin_restore_profile(uuid)') AS restore_rpc,
       to_regprocedure('public.admin_list_profile_archive_state()') AS state_rpc;
SELECT action, count(*) FROM public.profile_admin_audit
WHERE action IN ('archive','restore') GROUP BY action ORDER BY action;
