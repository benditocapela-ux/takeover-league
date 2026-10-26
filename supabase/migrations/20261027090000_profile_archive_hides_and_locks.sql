-- Archive = hide and lock (owner decision 27.10.2026).
-- An archived profile is hidden from every public list and selection and can no
-- longer act, by reusing the existing, already enforced flags:
--   is_listed=false -> excluded from leaderboard, awards, avatars, levels, award rankings
--   is_active=false -> excluded from coach lists, duel/arena/challenge selection; no submissions
-- The previous flags are remembered and restored on un-archive. Past seasons, hall of fame,
-- records and duel history stay unchanged. No profile, training, points or EXP rows are deleted.
-- Production use requires the normal migration path and a separate explicit FREIGEBEN.
BEGIN;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS archived_prev_active boolean,
  ADD COLUMN IF NOT EXISTS archived_prev_listed boolean;

-- Backstop: while archived_at is set, the profile stays inactive and unlisted no matter
-- which code path updates it (e.g. the signup trigger linking a prepared e-mail profile).
CREATE OR REPLACE FUNCTION public.profiles_archive_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $fn$
BEGIN
  IF NEW.archived_at IS NOT NULL THEN
    NEW.is_active := false;
    NEW.is_listed := false;
  END IF;
  RETURN NEW;
END
$fn$;
REVOKE ALL ON FUNCTION public.profiles_archive_guard() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS profiles_archive_guard ON public.profiles;
CREATE TRIGGER profiles_archive_guard
  BEFORE INSERT OR UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.profiles_archive_guard();

-- Profiles archived before this migration get the same semantics.
UPDATE public.profiles
SET archived_prev_active = is_active,
    archived_prev_listed = is_listed,
    is_active = false,
    is_listed = false
WHERE archived_at IS NOT NULL AND archived_prev_active IS NULL;

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

  UPDATE public.profiles
  SET archived_at = pg_catalog.now(),
      archived_prev_active = target.is_active,
      archived_prev_listed = target.is_listed,
      is_active = false,
      is_listed = false
  WHERE id = target.id;
  INSERT INTO public.profile_admin_audit(profile_id, changed_by, action, old_value, new_value)
  SELECT target.id, p.id, 'archive',
    pg_catalog.jsonb_build_object('archived_at', NULL, 'is_active', target.is_active, 'is_listed', target.is_listed),
    pg_catalog.jsonb_build_object('archived_at', pg_catalog.now(), 'is_active', false, 'is_listed', false)
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
DECLARE target public.profiles%ROWTYPE; next_active boolean; next_listed boolean;
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

  next_active := COALESCE(target.archived_prev_active, target.is_active);
  next_listed := COALESCE(target.archived_prev_listed, target.is_listed);
  UPDATE public.profiles
  SET archived_at = NULL,
      is_active = next_active,
      is_listed = next_listed,
      archived_prev_active = NULL,
      archived_prev_listed = NULL
  WHERE id = target.id;
  INSERT INTO public.profile_admin_audit(profile_id, changed_by, action, old_value, new_value)
  SELECT target.id, p.id, 'restore',
    pg_catalog.jsonb_build_object('archived_at', target.archived_at, 'is_active', target.is_active, 'is_listed', target.is_listed),
    pg_catalog.jsonb_build_object('archived_at', NULL, 'is_active', next_active, 'is_listed', next_listed)
  FROM public.profiles p
  WHERE p.auth_user_id = (SELECT auth.uid()) AND p.role='admin' AND p.is_active IS TRUE;
END
$fn$;

-- Active/listed switches are locked while a profile is archived (restore first).
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
 IF target.archived_at IS NOT NULL THEN
  RAISE EXCEPTION 'Archivierte Profile zuerst wiederherstellen' USING ERRCODE='22023';
 END IF;
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
 IF target.archived_at IS NOT NULL THEN
  RAISE EXCEPTION 'Archivierte Profile zuerst wiederherstellen' USING ERRCODE='22023';
 END IF;
 IF target.is_listed=p_listed THEN RETURN; END IF;
 UPDATE public.profiles SET is_listed=p_listed WHERE id=target.id;
 INSERT INTO public.profile_admin_audit(profile_id,changed_by,action,old_value,new_value)
 VALUES(target.id,actor,'listed',jsonb_build_object('is_listed',target.is_listed),jsonb_build_object('is_listed',p_listed));
END;
$fn$;

-- Grants unchanged from the previous definitions (authenticated only, checked inside).
REVOKE ALL ON FUNCTION public.admin_archive_profile(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.admin_restore_profile(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.admin_set_profile_active(uuid,boolean) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.admin_set_profile_listed(uuid,boolean) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_archive_profile(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_restore_profile(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_profile_active(uuid,boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_profile_listed(uuid,boolean) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
