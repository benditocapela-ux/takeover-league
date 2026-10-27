-- Rollback für 20261028160000_admin_set_profile_display_name.sql – behält alle Daten.
-- Entfernt die RPC. Bereits geänderte Namen und die Protokolleinträge bleiben erhalten; deshalb bleibt
-- 'display_name' als erlaubte Protokoll-Aktion bestehen (sonst wären vorhandene Einträge ungültig).
BEGIN;
DROP FUNCTION IF EXISTS public.admin_set_profile_display_name(uuid,text);
NOTIFY pgrst, 'reload schema';
COMMIT;
