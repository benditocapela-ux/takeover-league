-- Etappe 7b (28.10.2026, Owner-Auftrag): Feedback-Portal.
-- * Angemeldete Mitglieder melden Fehler, falsche Anzeigen oder Ideen, auf Wunsch mit bis zu 3 Screenshots.
--   Seite und Gerät werden mitgeschickt. Nur der Admin sieht die Meldungen und Bilder, setzt den Status und antwortet;
--   die Antwort kommt als Benachrichtigung (Typ «general») zurück.
-- * Screenshots liegen im privaten Speicher «feedback-shots» unter <auth.uid>/<datei>; höchstens 5 MB, nur PNG/JPEG/WebP.
--   Hochladen nur in den eigenen Ordner, lesen nur eigene Bilder und der Admin, keine Änderungen oder Löschungen durch Mitglieder.
-- * Höchstens 10 Meldungen pro Person und Tag. Neues Feature-Flag app_feedback (AUS); der Admin kann vorab testen.
-- Bestehende Daten bleiben unverändert.
BEGIN;

DO $$ BEGIN
 IF to_regprocedure('league_private.active_viewer()') IS NULL OR to_regprocedure('league_private.flag_on(text)') IS NULL
    OR to_regclass('public.boxer_notifications') IS NULL
    OR to_regclass('storage.buckets') IS NULL OR to_regclass('storage.objects') IS NULL THEN
  RAISE EXCEPTION 'Voraussetzung fehlt: league_private.active_viewer/flag_on, boxer_notifications, Storage';
 END IF;
END $$;

INSERT INTO public.league_feature_flags(feature_key,display_name,is_enabled)
VALUES ('app_feedback','Feedback-Portal',false) ON CONFLICT(feature_key) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.app_feedback(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 profile_id uuid NOT NULL REFERENCES public.profiles(id),
 kind text NOT NULL CHECK (kind IN ('bug','display','idea','other')),
 title text NOT NULL CHECK (char_length(btrim(title)) BETWEEN 3 AND 120),
 message text NOT NULL CHECK (char_length(btrim(message)) BETWEEN 1 AND 4000),
 page text CHECK (page IS NULL OR char_length(page)<=200),
 device text CHECK (device IS NULL OR char_length(device)<=300),
 attachments text[] NOT NULL DEFAULT '{}' CHECK (cardinality(attachments)<=3),
 status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','done','rejected')),
 admin_reply text CHECK (admin_reply IS NULL OR char_length(admin_reply) BETWEEN 1 AND 2000),
 replied_at timestamptz,
 replied_by uuid REFERENCES public.profiles(id),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz
);
CREATE INDEX IF NOT EXISTS app_feedback_profile_idx ON public.app_feedback(profile_id, created_at DESC);
CREATE INDEX IF NOT EXISTS app_feedback_status_idx ON public.app_feedback(status, created_at DESC);
ALTER TABLE public.app_feedback ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.app_feedback FROM PUBLIC, anon, authenticated;

-- Privater Speicher für Screenshots
INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
VALUES ('feedback-shots','feedback-shots',false,5242880,ARRAY['image/png','image/jpeg','image/webp'])
ON CONFLICT (id) DO UPDATE SET public=false, file_size_limit=5242880, allowed_mime_types=ARRAY['image/png','image/jpeg','image/webp'];

DROP POLICY IF EXISTS feedback_shots_insert_own ON storage.objects;
CREATE POLICY feedback_shots_insert_own ON storage.objects FOR INSERT TO authenticated WITH CHECK (
 bucket_id='feedback-shots' AND (storage.foldername(name))[1]=(SELECT auth.uid())::text
 AND EXISTS (SELECT 1 FROM public.profiles p WHERE p.auth_user_id=(SELECT auth.uid()) AND p.is_active AND p.archived_at IS NULL));
DROP POLICY IF EXISTS feedback_shots_select_own_or_admin ON storage.objects;
CREATE POLICY feedback_shots_select_own_or_admin ON storage.objects FOR SELECT TO authenticated USING (
 bucket_id='feedback-shots' AND ((storage.foldername(name))[1]=(SELECT auth.uid())::text
  OR EXISTS (SELECT 1 FROM public.profiles p WHERE p.auth_user_id=(SELECT auth.uid()) AND p.role='admin' AND p.is_active)));

CREATE OR REPLACE FUNCTION league_private.app_feedback_json(f public.app_feedback, p_admin boolean)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT pg_catalog.jsonb_build_object('id',f.id,'kind',f.kind,'title',f.title,'message',f.message,'page',f.page,
  'attachments',pg_catalog.to_jsonb(f.attachments),'status',f.status,'reply',f.admin_reply,'replied_at',f.replied_at,
  'created_at',f.created_at,'updated_at',f.updated_at)
 || CASE WHEN p_admin THEN pg_catalog.jsonb_build_object('device',f.device,
     'author',(SELECT p.display_name FROM public.profiles p WHERE p.id=f.profile_id),
     'author_role',(SELECT p.role FROM public.profiles p WHERE p.id=f.profile_id)) ELSE '{}'::jsonb END
$fn$;
REVOKE ALL ON FUNCTION league_private.app_feedback_json(public.app_feedback,boolean) FROM PUBLIC, anon, authenticated;

-- Melden: Bilder müssen schon im eigenen Ordner liegen (Upload vorher über den Storage).
CREATE OR REPLACE FUNCTION public.submit_app_feedback(p_kind text, p_title text, p_message text, p_page text DEFAULT NULL,
 p_device text DEFAULT NULL, p_attachments text[] DEFAULT '{}')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); f public.app_feedback; a text; atts text[] := '{}';
BEGIN
 IF me.id IS NULL THEN RAISE EXCEPTION 'Bitte anmelden' USING ERRCODE='42501'; END IF;
 IF NOT league_private.flag_on('app_feedback') AND me.role<>'admin' THEN RAISE EXCEPTION 'Das Feedback-Portal ist noch nicht freigeschaltet' USING ERRCODE='42501'; END IF;
 IF coalesce(p_kind,'') NOT IN ('bug','display','idea','other') THEN RAISE EXCEPTION 'Bitte eine Art wählen' USING ERRCODE='22023'; END IF;
 IF char_length(btrim(coalesce(p_title,''))) NOT BETWEEN 3 AND 120 THEN RAISE EXCEPTION 'Titel mit 3 bis 120 Zeichen' USING ERRCODE='22023'; END IF;
 IF char_length(btrim(coalesce(p_message,''))) NOT BETWEEN 1 AND 4000 THEN RAISE EXCEPTION 'Bitte beschreiben, was passiert ist (höchstens 4000 Zeichen)' USING ERRCODE='22023'; END IF;
 IF coalesce(cardinality(p_attachments),0)>3 THEN RAISE EXCEPTION 'Höchstens 3 Bilder' USING ERRCODE='22023'; END IF;
 IF (SELECT count(*) FROM public.app_feedback x WHERE x.profile_id=me.id AND x.created_at > now() - interval '1 day')>=10 THEN
  RAISE EXCEPTION 'Heute hast du schon 10 Meldungen geschickt. Danke! Morgen geht es weiter.' USING ERRCODE='54000';
 END IF;
 FOREACH a IN ARRAY coalesce(p_attachments,'{}'::text[]) LOOP
  IF a !~ ('^'||me.auth_user_id::text||'/[A-Za-z0-9_-]{8,80}\.(png|jpe?g|webp)$') THEN RAISE EXCEPTION 'Ungültiges Bild' USING ERRCODE='22023'; END IF;
  IF NOT EXISTS (SELECT 1 FROM storage.objects o WHERE o.bucket_id='feedback-shots' AND o.name=a) THEN RAISE EXCEPTION 'Bild nicht gefunden – bitte erneut hochladen' USING ERRCODE='22023'; END IF;
  IF a = ANY(atts) THEN CONTINUE; END IF;
  IF EXISTS (SELECT 1 FROM public.app_feedback x WHERE a = ANY(x.attachments)) THEN RAISE EXCEPTION 'Bild wurde schon verwendet' USING ERRCODE='22023'; END IF;
  atts := atts || a;
 END LOOP;
 INSERT INTO public.app_feedback(profile_id,kind,title,message,page,device,attachments)
 VALUES (me.id,p_kind,btrim(p_title),btrim(p_message),NULLIF(left(btrim(coalesce(p_page,'')),200),''),NULLIF(left(btrim(coalesce(p_device,'')),300),''),atts)
 RETURNING * INTO f;
 RETURN league_private.app_feedback_json(f,false);
END;
$fn$;

-- Eigene Meldungen mit Status und Antwort.
CREATE OR REPLACE FUNCTION public.my_app_feedback()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer();
BEGIN
 IF me.id IS NULL THEN RAISE EXCEPTION 'Bitte anmelden' USING ERRCODE='42501'; END IF;
 RETURN pg_catalog.jsonb_build_object('enabled',league_private.flag_on('app_feedback') OR me.role='admin','is_admin',me.role='admin',
  'items',coalesce((SELECT pg_catalog.jsonb_agg(league_private.app_feedback_json(x,false) ORDER BY x.created_at DESC)
   FROM (SELECT f.* FROM public.app_feedback f WHERE f.profile_id=me.id ORDER BY f.created_at DESC LIMIT 50) x),'[]'::jsonb));
END;
$fn$;

-- Admin: Eingang (optional nach Status) und Zähler.
CREATE OR REPLACE FUNCTION public.admin_list_app_feedback(p_status text DEFAULT NULL, p_limit integer DEFAULT 50)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer();
BEGIN
 IF me.id IS NULL OR me.role<>'admin' THEN RAISE EXCEPTION 'Nur für den Admin' USING ERRCODE='42501'; END IF;
 RETURN pg_catalog.jsonb_build_object(
  'counts',(SELECT pg_catalog.jsonb_object_agg(s, (SELECT count(*) FROM public.app_feedback f WHERE f.status=s))
            FROM pg_catalog.unnest(ARRAY['open','in_progress','done','rejected']) s),
  'items',coalesce((SELECT pg_catalog.jsonb_agg(league_private.app_feedback_json(x,true) ORDER BY x.created_at DESC)
   FROM (SELECT f.* FROM public.app_feedback f WHERE p_status IS NULL OR f.status=p_status
         ORDER BY f.created_at DESC LIMIT LEAST(GREATEST(coalesce(p_limit,50),1),200)) x),'[]'::jsonb));
END;
$fn$;

-- Admin: Status setzen und/oder antworten. Eine neue oder geänderte Antwort geht als Benachrichtigung an den Absender.
CREATE OR REPLACE FUNCTION public.admin_update_app_feedback(p_id uuid, p_status text DEFAULT NULL, p_reply text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); f public.app_feedback; r text; new_reply boolean; new_status boolean;
 labels jsonb := '{"open":"offen","in_progress":"in Arbeit","done":"erledigt","rejected":"abgelehnt"}';
BEGIN
 IF me.id IS NULL OR me.role<>'admin' THEN RAISE EXCEPTION 'Nur für den Admin' USING ERRCODE='42501'; END IF;
 SELECT * INTO f FROM public.app_feedback x WHERE x.id=p_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Meldung nicht gefunden' USING ERRCODE='22023'; END IF;
 IF p_status IS NOT NULL AND p_status NOT IN ('open','in_progress','done','rejected') THEN RAISE EXCEPTION 'Unbekannter Status' USING ERRCODE='22023'; END IF;
 r := NULLIF(btrim(coalesce(p_reply,'')),'');
 IF r IS NOT NULL AND char_length(r)>2000 THEN RAISE EXCEPTION 'Antwort höchstens 2000 Zeichen' USING ERRCODE='22023'; END IF;
 IF p_status IS NULL AND r IS NULL THEN RAISE EXCEPTION 'Nichts zu ändern' USING ERRCODE='22023'; END IF;
 new_reply := r IS NOT NULL AND r IS DISTINCT FROM f.admin_reply;
 new_status := p_status IS NOT NULL AND p_status<>f.status;
 UPDATE public.app_feedback x SET status=coalesce(p_status,x.status), admin_reply=coalesce(r,x.admin_reply),
  replied_at=CASE WHEN new_reply THEN now() ELSE x.replied_at END, replied_by=CASE WHEN new_reply THEN me.id ELSE x.replied_by END,
  updated_at=now()
 WHERE x.id=f.id RETURNING * INTO f;
 IF (new_reply OR new_status) AND f.profile_id<>me.id THEN
  INSERT INTO public.boxer_notifications(recipient_id,notification_type,title,message,target_path)
  VALUES (f.profile_id,'general',left('Feedback «'||f.title||'»: '||(labels->>f.status),160),
   left(CASE WHEN new_reply THEN 'Antwort: '||r ELSE 'Der Status deiner Meldung hat sich geändert.' END,2000),'/feedback.html');
 END IF;
 RETURN league_private.app_feedback_json(f,true);
END;
$fn$;

REVOKE ALL ON FUNCTION public.submit_app_feedback(text,text,text,text,text,text[]), public.my_app_feedback(),
 public.admin_list_app_feedback(text,integer), public.admin_update_app_feedback(uuid,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_app_feedback(text,text,text,text,text,text[]), public.my_app_feedback(),
 public.admin_list_app_feedback(text,integer), public.admin_update_app_feedback(uuid,text,text) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
