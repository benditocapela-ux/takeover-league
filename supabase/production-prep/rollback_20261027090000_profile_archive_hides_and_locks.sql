-- Rollback for 20261027090000_profile_archive_hides_and_locks.sql.
-- Restores the 21.10.2026 archive semantics (marker only). Refuses while profiles are archived,
-- because the previous active/listed flags are only kept in the columns this rollback removes.
BEGIN;
DO $rollback_guard$
BEGIN
 IF EXISTS(SELECT 1 FROM public.profiles WHERE archived_at IS NOT NULL) THEN
  RAISE EXCEPTION 'Rollback refused: restore all archived profiles first (Clubverwaltung -> Wiederherstellen)';
 END IF;
END
$rollback_guard$;
DROP TRIGGER IF EXISTS profiles_archive_guard ON public.profiles;
DROP FUNCTION IF EXISTS public.profiles_archive_guard();

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

CREATE OR REPLACE FUNCTION public.admin_set_profile_active(p_profile_id uuid, p_active boolean)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
DECLARE actor uuid; target public.profiles%ROWTYPE;
BEGIN
 SELECT p.id INTO actor FROM public.profiles p
 WHERE p.auth_user_id=(SELECT auth.uid()) AND p.role='admin' AND p.is_active;
 IF actor IS NULL THEN RAISE EXCEPTION 'Nur der aktive Admin darf Profile aktivieren' USING ERRCODE='42501'; END IF;
 IF p_active IS NULL THEN RAISE EXCEPTION 'Aktivitätswert fehlt' USING ERRCODE='22023'; END IF;
 PERFORM pg_catalog.pg_advisory_xact_lock(94712019);
 SELECT * INTO target FROM public.profiles WHERE id=p_profile_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Profil nicht gefunden' USING ERRCODE='P0002'; END IF;
 IF target.role='admin' AND p_active=false AND
  (SELECT count(*) FROM public.profiles WHERE role='admin' AND is_active)=1 THEN
  RAISE EXCEPTION 'Der letzte aktive Admin kann nicht deaktiviert werden' USING ERRCODE='42501';
 END IF;
 IF target.is_active=p_active THEN RETURN; END IF;
 UPDATE public.profiles SET is_active=p_active WHERE id=target.id;
 INSERT INTO public.profile_admin_audit(profile_id,changed_by,action,old_value,new_value)
 VALUES(target.id,actor,'active',jsonb_build_object('is_active',target.is_active),jsonb_build_object('is_active',p_active));
END;
$fn$;

CREATE OR REPLACE FUNCTION public.admin_set_profile_listed(p_profile_id uuid, p_listed boolean)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
DECLARE actor uuid; target public.profiles%ROWTYPE;
BEGIN
 SELECT p.id INTO actor FROM public.profiles p
 WHERE p.auth_user_id=(SELECT auth.uid()) AND p.role='admin' AND p.is_active;
 IF actor IS NULL THEN RAISE EXCEPTION 'Nur der aktive Admin darf öffentliche Profile freigeben' USING ERRCODE='42501'; END IF;
 IF p_listed IS NULL THEN RAISE EXCEPTION 'Sichtbarkeitswert fehlt' USING ERRCODE='22023'; END IF;
 SELECT * INTO target FROM public.profiles WHERE id=p_profile_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Profil nicht gefunden' USING ERRCODE='P0002'; END IF;
 IF target.is_listed=p_listed THEN RETURN; END IF;
 UPDATE public.profiles SET is_listed=p_listed WHERE id=target.id;
 INSERT INTO public.profile_admin_audit(profile_id,changed_by,action,old_value,new_value)
 VALUES(target.id,actor,'listed',jsonb_build_object('is_listed',target.is_listed),jsonb_build_object('is_listed',p_listed));
END;
$fn$;

REVOKE ALL ON FUNCTION public.admin_archive_profile(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.admin_restore_profile(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.admin_set_profile_active(uuid,boolean) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.admin_set_profile_listed(uuid,boolean) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_archive_profile(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_restore_profile(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_profile_active(uuid,boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_profile_listed(uuid,boolean) TO authenticated;
ALTER TABLE public.profiles DROP COLUMN IF EXISTS archived_prev_listed, DROP COLUMN IF EXISTS archived_prev_active;
NOTIFY pgrst, 'reload schema';
COMMIT;
