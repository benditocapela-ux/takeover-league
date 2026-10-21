-- Rollback for 20261021230000_club_profile_archive.sql.
-- First revert the frontend. Rollback removes only the archive marker column; it does not delete profiles.
BEGIN;
DROP FUNCTION IF EXISTS public.admin_restore_profile(uuid);
DROP FUNCTION IF EXISTS public.admin_archive_profile(uuid);
DROP FUNCTION IF EXISTS public.admin_list_profile_archive_state();
ALTER TABLE public.profile_admin_audit DROP CONSTRAINT IF EXISTS profile_admin_audit_action_check;
ALTER TABLE public.profile_admin_audit
  ADD CONSTRAINT profile_admin_audit_action_check
  CHECK (action IN ('role','active','listed','email'));
DO $rollback_guard$
BEGIN
 IF EXISTS(SELECT 1 FROM public.profiles WHERE archived_at IS NOT NULL) THEN
  RAISE EXCEPTION 'Rollback refused: restore all archived profiles before removing archived_at';
 END IF;
END
$rollback_guard$;
ALTER TABLE public.profiles DROP COLUMN IF EXISTS archived_at;
NOTIFY pgrst, 'reload schema';
COMMIT;
