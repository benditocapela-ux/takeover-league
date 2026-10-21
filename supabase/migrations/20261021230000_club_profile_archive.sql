-- Reversible Clubverwaltung archive. No profile, training, points or EXP rows are deleted.
-- Production use requires the normal migration path and a separate explicit FREIGEBEN.
BEGIN;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS archived_at timestamptz;

CREATE OR REPLACE FUNCTION public.admin_list_profile_archive_state()
RETURNS TABLE(profile_id uuid, archived_at timestamptz)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $fn$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.auth_user_id = (SELECT auth.uid())
      AND p.role = 'admin' AND p.is_active IS TRUE
  ) THEN
    RAISE EXCEPTION 'Nur der aktive Admin darf Archivstatus sehen' USING ERRCODE='42501';
  END IF;
  RETURN QUERY SELECT p.id, p.archived_at FROM public.profiles p;
END
$fn$;

CREATE OR REPLACE FUNCTION public.admin_archive_profile(p_profile_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
DECLARE target public.profiles%ROWTYPE;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.auth_user_id = (SELECT auth.uid())
      AND p.role = 'admin' AND p.is_active IS TRUE
  ) THEN
    RAISE EXCEPTION 'Nur der aktive Admin darf Profile archivieren' USING ERRCODE='42501';
  END IF;

  SELECT * INTO target FROM public.profiles p
  WHERE p.id = p_profile_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Profil nicht gefunden' USING ERRCODE='P0002'; END IF;
  IF target.role = 'admin' THEN
    RAISE EXCEPTION 'Das Eigentümer-Adminprofil kann nicht archiviert werden' USING ERRCODE='42501';
  END IF;
  IF target.archived_at IS NOT NULL THEN
    RAISE EXCEPTION 'Profil ist bereits archiviert' USING ERRCODE='22023';
  END IF;

  UPDATE public.profiles SET archived_at = pg_catalog.now() WHERE id = target.id;
  INSERT INTO public.profile_admin_audit(profile_id, changed_by, action, old_value, new_value)
  SELECT target.id, p.id, 'archive',
    pg_catalog.jsonb_build_object('archived_at', NULL),
    pg_catalog.jsonb_build_object('archived_at', pg_catalog.now())
  FROM public.profiles p
  WHERE p.auth_user_id = (SELECT auth.uid()) AND p.role='admin' AND p.is_active IS TRUE;
END
$fn$;

CREATE OR REPLACE FUNCTION public.admin_restore_profile(p_profile_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
DECLARE target public.profiles%ROWTYPE;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.auth_user_id = (SELECT auth.uid())
      AND p.role = 'admin' AND p.is_active IS TRUE
  ) THEN
    RAISE EXCEPTION 'Nur der aktive Admin darf Profile wiederherstellen' USING ERRCODE='42501';
  END IF;

  SELECT * INTO target FROM public.profiles p
  WHERE p.id = p_profile_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Profil nicht gefunden' USING ERRCODE='P0002'; END IF;
  IF target.role = 'admin' THEN
    RAISE EXCEPTION 'Das Eigentümer-Adminprofil kann nicht archiviert sein' USING ERRCODE='42501';
  END IF;
  IF target.archived_at IS NULL THEN
    RAISE EXCEPTION 'Profil ist nicht archiviert' USING ERRCODE='22023';
  END IF;

  UPDATE public.profiles SET archived_at = NULL WHERE id = target.id;
  INSERT INTO public.profile_admin_audit(profile_id, changed_by, action, old_value, new_value)
  SELECT target.id, p.id, 'restore',
    pg_catalog.jsonb_build_object('archived_at', target.archived_at),
    pg_catalog.jsonb_build_object('archived_at', NULL)
  FROM public.profiles p
  WHERE p.auth_user_id = (SELECT auth.uid()) AND p.role='admin' AND p.is_active IS TRUE;
END
$fn$;

REVOKE ALL ON FUNCTION public.admin_list_profile_archive_state() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.admin_archive_profile(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.admin_restore_profile(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_profile_archive_state() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_archive_profile(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_restore_profile(uuid) TO authenticated;

-- Extend the existing private admin audit action constraint additively.
ALTER TABLE public.profile_admin_audit DROP CONSTRAINT IF EXISTS profile_admin_audit_action_check;
ALTER TABLE public.profile_admin_audit
  ADD CONSTRAINT profile_admin_audit_action_check
  CHECK (action IN ('role','active','listed','email','archive','restore'));

NOTIFY pgrst, 'reload schema';
COMMIT;
