-- Etappe 6b (28.10.2026, Owner-Auftrag): Coach-Feedback mit Ablaufdatum, Archiv und Zurückziehen.
-- * Jedes Feedback hat «sichtbar bis» (Vorgabe: Versanddatum + 7 Tage, wählbar bis 90 Tage). Bis dahin sieht der Boxer es oben als
--   aktives Feedback, danach unter «Archivierte Feedbacks».
-- * Coach (Verfasser) oder Admin kann das Datum ändern, sofort archivieren (gestern) oder das Feedback zurückziehen.
--   Zurückgezogene Feedbacks sieht der Boxer nicht mehr (auch nicht über die API); für Coaches bleiben sie mit Vermerk sichtbar.
--   Es wird nichts gelöscht; Zurückziehen lässt sich rückgängig machen.
-- * Bestehende Feedbacks erhalten «sichtbar bis» = Versanddatum + 7 Tage (Owner-Entscheid: die 2 Feedbacks vom 18.10. sind damit archiviert).
--   Titel, Text, Absender und Datum bleiben unverändert.
BEGIN;
DO $$ BEGIN
 IF to_regclass('public.boxer_coach_feedback') IS NULL OR to_regprocedure('league_private.require_staff()') IS NULL
    OR to_regprocedure('league_private.zurich_today()') IS NULL OR to_regprocedure('public.is_league_admin()') IS NULL THEN
  RAISE EXCEPTION 'Voraussetzung fehlt: boxer_coach_feedback, league_private.require_staff/zurich_today, public.is_league_admin';
 END IF;
END $$;

ALTER TABLE public.boxer_coach_feedback ADD COLUMN IF NOT EXISTS visible_until date;
ALTER TABLE public.boxer_coach_feedback ADD COLUMN IF NOT EXISTS withdrawn_at timestamptz;
ALTER TABLE public.boxer_coach_feedback ADD COLUMN IF NOT EXISTS withdrawn_by uuid REFERENCES public.profiles(id);
ALTER TABLE public.boxer_coach_feedback ADD COLUMN IF NOT EXISTS updated_at timestamptz;
ALTER TABLE public.boxer_coach_feedback ADD COLUMN IF NOT EXISTS updated_by uuid REFERENCES public.profiles(id);
UPDATE public.boxer_coach_feedback SET visible_until=(created_at AT TIME ZONE 'Europe/Zurich')::date + 7 WHERE visible_until IS NULL;
ALTER TABLE public.boxer_coach_feedback ALTER COLUMN visible_until SET DEFAULT ((now() AT TIME ZONE 'Europe/Zurich')::date + 7);
ALTER TABLE public.boxer_coach_feedback ALTER COLUMN visible_until SET NOT NULL;
CREATE INDEX IF NOT EXISTS boxer_coach_feedback_boxer_idx ON public.boxer_coach_feedback(boxer_id, created_at DESC);

-- Neues Feedback: «sichtbar bis» zwischen heute und 90 Tagen; Zurückziehen nur über die RPC.
CREATE OR REPLACE FUNCTION league_private.feedback_insert_guard()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE today date := league_private.zurich_today();
BEGIN
 NEW.withdrawn_at := NULL; NEW.withdrawn_by := NULL; NEW.updated_at := NULL; NEW.updated_by := NULL;
 NEW.visible_until := coalesce(NEW.visible_until, today + 7);
 IF NEW.visible_until < today OR NEW.visible_until > today + 90 THEN
  RAISE EXCEPTION '«Sichtbar bis» muss zwischen heute und in 90 Tagen liegen' USING ERRCODE='22023';
 END IF;
 RETURN NEW;
END;
$fn$;
DROP TRIGGER IF EXISTS league_feedback_insert_guard ON public.boxer_coach_feedback;
CREATE TRIGGER league_feedback_insert_guard BEFORE INSERT ON public.boxer_coach_feedback
 FOR EACH ROW EXECUTE FUNCTION league_private.feedback_insert_guard();
REVOKE ALL ON FUNCTION league_private.feedback_insert_guard() FROM PUBLIC, anon, authenticated;

-- Boxer sehen zurückgezogene Feedbacks nicht mehr (Admin weiterhin; Coaches über ihre eigene Policy).
DROP POLICY IF EXISTS feedback_select_enabled ON public.boxer_coach_feedback;
CREATE POLICY feedback_select_enabled ON public.boxer_coach_feedback FOR SELECT TO authenticated USING (
 (EXISTS (SELECT 1 FROM public.league_feature_flags f WHERE f.feature_key='coach_feedback' AND f.is_enabled))
 AND (public.is_league_admin() OR (boxer_coach_feedback.withdrawn_at IS NULL AND EXISTS (SELECT 1 FROM public.profiles p
   WHERE p.id=boxer_coach_feedback.boxer_id AND p.auth_user_id=(SELECT auth.uid())))));

CREATE OR REPLACE FUNCTION league_private.feedback_json(f public.boxer_coach_feedback, p_today date)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT pg_catalog.jsonb_build_object('id',f.id,'title',f.title,'message',f.message,'created_at',f.created_at,'visible_until',f.visible_until,
  'coach',(SELECT p.display_name FROM public.profiles p WHERE p.id=f.coach_id),
  'status',CASE WHEN f.withdrawn_at IS NOT NULL THEN 'withdrawn' WHEN f.visible_until>=p_today THEN 'active' ELSE 'archived' END)
$fn$;
REVOKE ALL ON FUNCTION league_private.feedback_json(public.boxer_coach_feedback,date) FROM PUBLIC, anon, authenticated;

-- Boxer: aktive Feedbacks (oben im Studio) und Archiv. Zurückgezogene erscheinen nie.
CREATE OR REPLACE FUNCTION public.get_my_feedback()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); today date := league_private.zurich_today();
BEGIN
 IF me.id IS NULL THEN RAISE EXCEPTION 'Bitte anmelden' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.league_feature_flags f WHERE f.feature_key='coach_feedback' AND f.is_enabled) THEN
  RETURN pg_catalog.jsonb_build_object('enabled',false);
 END IF;
 RETURN pg_catalog.jsonb_build_object('enabled',true,'today',today,
  'active',coalesce((SELECT pg_catalog.jsonb_agg(league_private.feedback_json(f,today) ORDER BY f.created_at DESC)
    FROM public.boxer_coach_feedback f WHERE f.boxer_id=me.id AND f.withdrawn_at IS NULL AND f.visible_until>=today),'[]'::jsonb),
  'archived',coalesce((SELECT pg_catalog.jsonb_agg(league_private.feedback_json(x,today) ORDER BY x.created_at DESC) FROM (
    SELECT f.* FROM public.boxer_coach_feedback f WHERE f.boxer_id=me.id AND f.withdrawn_at IS NULL AND f.visible_until<today
    ORDER BY f.created_at DESC LIMIT 100) x),'[]'::jsonb));
END;
$fn$;

-- Coach: letzte Feedbacks mit Status (aktiv / archiviert / zurückgezogen), optional für einen Boxer.
CREATE OR REPLACE FUNCTION public.staff_list_feedback(p_boxer_id uuid DEFAULT NULL, p_limit integer DEFAULT 20)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.require_staff(); today date := league_private.zurich_today();
BEGIN
 RETURN coalesce((SELECT pg_catalog.jsonb_agg(league_private.feedback_json(x,today) || pg_catalog.jsonb_build_object(
    'boxer_id',x.boxer_id,'boxer',(SELECT p.display_name FROM public.profiles p WHERE p.id=x.boxer_id),
    'withdrawn_at',x.withdrawn_at,'can_edit',me.role='admin' OR x.coach_id=me.id) ORDER BY x.created_at DESC)
  FROM (SELECT f.* FROM public.boxer_coach_feedback f WHERE p_boxer_id IS NULL OR f.boxer_id=p_boxer_id
        ORDER BY f.created_at DESC LIMIT LEAST(GREATEST(coalesce(p_limit,20),1),100)) x),'[]'::jsonb);
END;
$fn$;

-- Coach (Verfasser) oder Admin: «sichtbar bis» ändern (gestern = sofort archivieren), zurückziehen oder wiederherstellen.
CREATE OR REPLACE FUNCTION public.staff_update_feedback(p_feedback_id uuid, p_visible_until date DEFAULT NULL, p_withdrawn boolean DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.require_staff(); f public.boxer_coach_feedback; today date := league_private.zurich_today();
BEGIN
 IF NOT EXISTS (SELECT 1 FROM public.league_feature_flags x WHERE x.feature_key='coach_feedback' AND x.is_enabled) THEN
  RAISE EXCEPTION 'Coach-Feedback ist nicht freigeschaltet' USING ERRCODE='42501';
 END IF;
 SELECT * INTO f FROM public.boxer_coach_feedback x WHERE x.id=p_feedback_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Feedback nicht gefunden' USING ERRCODE='22023'; END IF;
 IF me.role<>'admin' AND f.coach_id<>me.id THEN RAISE EXCEPTION 'Nur der Verfasser oder der Admin ändert dieses Feedback' USING ERRCODE='42501'; END IF;
 IF p_visible_until IS NULL AND p_withdrawn IS NULL THEN RAISE EXCEPTION 'Nichts zu ändern' USING ERRCODE='22023'; END IF;
 IF p_visible_until IS NOT NULL AND (p_visible_until < today - 1 OR p_visible_until > today + 90) THEN
  RAISE EXCEPTION '«Sichtbar bis» zwischen gestern (archivieren) und in 90 Tagen' USING ERRCODE='22023';
 END IF;
 UPDATE public.boxer_coach_feedback x SET
  visible_until=coalesce(p_visible_until,x.visible_until),
  withdrawn_at=CASE WHEN p_withdrawn IS NULL THEN x.withdrawn_at WHEN p_withdrawn THEN coalesce(x.withdrawn_at,now()) ELSE NULL END,
  withdrawn_by=CASE WHEN p_withdrawn IS NULL THEN x.withdrawn_by WHEN p_withdrawn THEN coalesce(x.withdrawn_by,me.id) ELSE NULL END,
  updated_at=now(), updated_by=me.id
 WHERE x.id=f.id RETURNING * INTO f;
 RETURN league_private.feedback_json(f,today) || pg_catalog.jsonb_build_object('boxer_id',f.boxer_id);
END;
$fn$;

-- Coach oder Admin sendet Feedback. Über die Tabelle scheitert das für Coaches an der Insert-Policy: sie verlangt einen aktiven
-- Boxer in profiles, Coaches dürfen dort aber nur ihr eigenes Profil lesen (nur der Admin sieht alle). Die RPC prüft dasselbe
-- serverseitig; Datumsprüfung und Benachrichtigung laufen weiter über die Trigger der Tabelle.
CREATE OR REPLACE FUNCTION public.staff_send_feedback(p_boxer_id uuid, p_title text, p_message text, p_visible_until date DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.require_staff(); f public.boxer_coach_feedback;
BEGIN
 IF NOT EXISTS (SELECT 1 FROM public.league_feature_flags x WHERE x.feature_key='coach_feedback' AND x.is_enabled) THEN
  RAISE EXCEPTION 'Coach-Feedback ist nicht freigeschaltet' USING ERRCODE='42501';
 END IF;
 IF NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=p_boxer_id AND p.role='boxer' AND p.is_active) THEN
  RAISE EXCEPTION 'Boxer nicht gefunden oder nicht aktiv' USING ERRCODE='22023';
 END IF;
 IF char_length(btrim(coalesce(p_title,''))) NOT BETWEEN 1 AND 120 OR char_length(btrim(coalesce(p_message,''))) NOT BETWEEN 1 AND 4000 THEN
  RAISE EXCEPTION 'Titel (1–120 Zeichen) und Nachricht (1–4000 Zeichen) angeben' USING ERRCODE='22023';
 END IF;
 INSERT INTO public.boxer_coach_feedback(boxer_id,coach_id,title,message,visible_until)
 VALUES (p_boxer_id, me.id, btrim(p_title), btrim(p_message), p_visible_until) RETURNING * INTO f;
 RETURN league_private.feedback_json(f, league_private.zurich_today()) || pg_catalog.jsonb_build_object('boxer_id',f.boxer_id);
END;
$fn$;

REVOKE ALL ON FUNCTION public.get_my_feedback(), public.staff_list_feedback(uuid,integer), public.staff_update_feedback(uuid,date,boolean),
 public.staff_send_feedback(uuid,text,text,date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_feedback(), public.staff_list_feedback(uuid,integer), public.staff_update_feedback(uuid,date,boolean),
 public.staff_send_feedback(uuid,text,text,date) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
