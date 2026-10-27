-- Clubverwaltung: Admin kann den Anzeigenamen eines Profils ändern (27.10.2026, Owner-Auftrag).
--  * Neue RPC public.admin_set_profile_display_name(p_profile_id, p_display_name), nur für den aktiven Admin.
--  * Name wird getrimmt, Mehrfach-Leerzeichen zusammengefasst; 2–40 Zeichen; keine Steuerzeichen.
--  * Kein neuer Doppelname (Gross-/Kleinschreibung egal). Bestehende Doppelnamen bleiben, bis sie umbenannt werden.
--  * Jede Änderung landet im bestehenden Profil-Protokoll (profile_admin_audit, Aktion 'display_name').
--  * Historische Ergebnisse (Saison-Snapshots, Hall of Fame) behalten bewusst den Namen zum damaligen Zeitpunkt.
-- Keine Punkte, EXP, Trainings oder anderen Profilfelder werden verändert.
-- Produktion nur über den regulären Migrationsweg und eine separate ausdrückliche FREIGABE.
BEGIN;

ALTER TABLE public.profile_admin_audit DROP CONSTRAINT IF EXISTS profile_admin_audit_action_check;
ALTER TABLE public.profile_admin_audit ADD CONSTRAINT profile_admin_audit_action_check
 CHECK (action = ANY (ARRAY['role','active','listed','email','archive','restore','display_name']));

CREATE OR REPLACE FUNCTION public.admin_set_profile_display_name(p_profile_id uuid, p_display_name text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
DECLARE actor uuid; target public.profiles%ROWTYPE; normalized text;
BEGIN
 SELECT p.id INTO actor FROM public.profiles p
 WHERE p.auth_user_id=(SELECT auth.uid()) AND p.role='admin' AND p.is_active;
 IF actor IS NULL THEN RAISE EXCEPTION 'Nur der aktive Admin darf Namen ändern' USING ERRCODE='42501'; END IF;
 normalized := regexp_replace(btrim(coalesce(p_display_name,'')), '\s+', ' ', 'g');
 IF char_length(normalized) NOT BETWEEN 2 AND 40 OR normalized ~ '[[:cntrl:]]' THEN
  RAISE EXCEPTION 'Der Name muss 2 bis 40 Zeichen lang sein' USING ERRCODE='22023';
 END IF;
 SELECT * INTO target FROM public.profiles WHERE id=p_profile_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Profil nicht gefunden' USING ERRCODE='P0002'; END IF;
 IF target.display_name = normalized THEN RETURN normalized; END IF;
 IF EXISTS (SELECT 1 FROM public.profiles p WHERE lower(p.display_name)=lower(normalized) AND p.id<>target.id) THEN
  RAISE EXCEPTION 'Dieser Name wird bereits von einem anderen Profil verwendet' USING ERRCODE='23505';
 END IF;
 UPDATE public.profiles SET display_name=normalized WHERE id=target.id;
 INSERT INTO public.profile_admin_audit(profile_id,changed_by,action,old_value,new_value)
 VALUES(target.id,actor,'display_name',jsonb_build_object('display_name',target.display_name),jsonb_build_object('display_name',normalized));
 RETURN normalized;
END;
$fn$;

REVOKE ALL ON FUNCTION public.admin_set_profile_display_name(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_set_profile_display_name(uuid,text) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
