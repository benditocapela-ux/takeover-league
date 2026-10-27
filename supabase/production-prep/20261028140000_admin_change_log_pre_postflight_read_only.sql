-- READ ONLY pre-/postflight for 20261028140000_admin_change_log.sql.
SELECT to_regclass('public.league_admin_audit_v21') AS change_log_table;
SELECT tgname, tgrelid::regclass FROM pg_trigger WHERE tgname LIKE 'league_v21_audit_%' ORDER BY 1;
SELECT has_table_privilege('anon','public.league_admin_audit_v21','SELECT') AS anon_can_read,
       has_table_privilege('authenticated','public.league_admin_audit_v21','INSERT') AS clients_can_write;
