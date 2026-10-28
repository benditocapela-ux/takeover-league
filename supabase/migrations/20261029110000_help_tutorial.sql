-- Etappe 7c (28.10.2026, Owner-Auftrag): Tutorial beim nächsten Login, Hilfe-Seite und FAQ mit Suche.
-- * Kurze Tour beim nächsten Login (Mein Studio), einmal pro Person und Tour-Version – gilt für alle Geräte.
--   Neues Feature-Flag tutorial (AUS); der Admin sieht die Tour vorab.
-- * FAQ: Fragen und Antworten, die der Admin pflegt (veröffentlichen/ausblenden statt löschen). Veröffentlichte Einträge
--   sind öffentlich lesbar (auch Gäste), Entwürfe nur für den Admin. Startinhalt sind 14 Entwürfe zum Korrigieren.
-- Bestehende Daten bleiben unverändert.
BEGIN;

DO $$ BEGIN
 IF to_regprocedure('league_private.active_viewer()') IS NULL OR to_regprocedure('league_private.flag_on(text)') IS NULL THEN
  RAISE EXCEPTION 'Voraussetzung fehlt: league_private.active_viewer/flag_on';
 END IF;
END $$;

INSERT INTO public.league_feature_flags(feature_key,display_name,is_enabled)
VALUES ('tutorial','Tutorial beim Login',false) ON CONFLICT(feature_key) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.profile_onboarding(
 profile_id uuid PRIMARY KEY REFERENCES public.profiles(id),
 tour_version integer NOT NULL DEFAULT 0 CHECK (tour_version BETWEEN 0 AND 1000),
 seen_at timestamptz
);
ALTER TABLE public.profile_onboarding ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.profile_onboarding FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS public.faq_entries(
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 category text NOT NULL CHECK (category IN ('start','training','punkte','kaempfe','kampfgeist','coach','konto')),
 question text NOT NULL CHECK (char_length(btrim(question)) BETWEEN 5 AND 200),
 answer text NOT NULL CHECK (char_length(btrim(answer)) BETWEEN 5 AND 2000),
 sort_order integer NOT NULL DEFAULT 100,
 is_published boolean NOT NULL DEFAULT true,
 updated_at timestamptz NOT NULL DEFAULT now(),
 updated_by uuid REFERENCES public.profiles(id)
);
ALTER TABLE public.faq_entries ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.faq_entries FROM PUBLIC, anon, authenticated;

INSERT INTO public.faq_entries(category,question,answer,sort_order)
SELECT v.c,v.q,v.a,v.o FROM (VALUES
 ('start','Wie funktioniert die Takeover League?','Du trainierst, trägst dein Training ein und dein Coach bestätigt es. Bestätigte Trainings bringen Punkte und EXP. Mit EXP steigst du im Level und Rang auf, die Punkte zählen für das Monatsranking.',10),
 ('training','Wie trage ich ein Training ein?','Öffne «Mein Studio» und tippe auf «Training einreichen». Wähle Art, Datum und Dauer und sende es ab. Sobald dein Coach es bestätigt, bekommst du die Punkte.',20),
 ('training','Warum zählt mein Training noch nicht?','Trainings zählen erst, wenn ein Coach sie bestätigt hat. Bis dahin stehen sie als «offen» in deinem Studio. Wurde ein Training abgelehnt, siehst du das in deinen Mitteilungen.',30),
 ('training','Was sind Pflicht- und Ergänzungstrainings?','Montag, Mittwoch und Samstag sind Pflichttrainings, Dienstag und Donnerstag Ergänzungstrainings. Pflichttrainings geben am meisten EXP, Ergänzungstrainings etwas weniger, Heimtraining je nach Art.',40),
 ('training','Wie funktioniert der Gym-Check-in?','Startet dein Coach das Training im Gym, kannst du dich unter «Gym-Check-in» einchecken. Nach dem Training bestätigt der Coach alle Anwesenden auf einmal.',50),
 ('punkte','Was ist der Unterschied zwischen Punkten und EXP?','Punkte zählen für das Monatsranking und starten jeden Monat neu. EXP bleiben für immer und bestimmen dein Level und deinen Rang.',60),
 ('punkte','Wie steige ich im Level und Rang auf?','Mit jeder EXP kommst du deinem nächsten Level näher. Es gibt 99 Levels und 7 Ränge von F bis S. In der Level-Roadmap siehst du, was als Nächstes kommt.',70),
 ('kaempfe','Wie funktioniert ein Duell?','Unter «Duell starten» forderst du einen anderen Boxer heraus. Nimmt er an, zählt, wer im Zeitraum mehr bestätigte Trainingspunkte sammelt.',80),
 ('kaempfe','Was sind Challenges und Quests?','Challenges sind Ziele vom Coach oder vom Verein. Wochen-Quests füllen sich automatisch mit deinen bestätigten Trainings und geben Belohnungen, die du abholen kannst.',90),
 ('kampfgeist','Was sind Kampfgeist-Coins und der Kampfpfad?','Für bestätigte Trainings und Quests bekommst du Coins. Damit kaufst du im Shop Avatare, Rahmen und mehr. Der Kampfpfad startet jeden Monat neu und schaltet Belohnungen frei.',100),
 ('coach','Wer sieht meine Bewertung und mein Feedback?','Deine Einzelnoten und das Feedback deines Coaches siehst nur du (und die Trainer). Andere Mitglieder sehen nur deine Spielerkarte, wenn dein Profil sichtbar ist.',110),
 ('coach','Wie oft kann ich den Boxstil-Test machen?','Einmal pro Monat. Möchtest du ihn früher wiederholen, kann dein Coach ihn freigeben.',120),
 ('konto','Ich habe einen Fehler gefunden. Was mache ich?','Tippe im Menü auf «Feedback & Fehler melden», beschreibe kurz, was passiert ist, und hänge am besten einen Screenshot an.',130),
 ('konto','Ich kann mich nicht anmelden. Was nun?','Prüfe E-Mail und Passwort und nutze «Passwort vergessen». Klappt es weiterhin nicht, melde dich direkt bei deinem Coach.',140)
) v(c,q,a,o)
WHERE NOT EXISTS (SELECT 1 FROM public.faq_entries);

-- Tour: Stand der Person (Flag aus: nur der Admin sieht die Tour).
CREATE OR REPLACE FUNCTION public.get_my_onboarding()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer();
BEGIN
 IF me.id IS NULL THEN RETURN pg_catalog.jsonb_build_object('enabled',false); END IF;
 RETURN pg_catalog.jsonb_build_object('enabled',league_private.flag_on('tutorial') OR me.role='admin','role',me.role,
  'tour_version',coalesce((SELECT o.tour_version FROM public.profile_onboarding o WHERE o.profile_id=me.id),0));
END;
$fn$;

CREATE OR REPLACE FUNCTION public.mark_tour_seen(p_version integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); v integer;
BEGIN
 IF me.id IS NULL THEN RAISE EXCEPTION 'Bitte anmelden' USING ERRCODE='42501'; END IF;
 IF p_version IS NULL OR p_version NOT BETWEEN 1 AND 1000 THEN RAISE EXCEPTION 'Ungültige Tour-Version' USING ERRCODE='22023'; END IF;
 INSERT INTO public.profile_onboarding(profile_id,tour_version,seen_at) VALUES (me.id,p_version,now())
 ON CONFLICT (profile_id) DO UPDATE SET tour_version=GREATEST(public.profile_onboarding.tour_version,EXCLUDED.tour_version), seen_at=now()
 RETURNING tour_version INTO v;
 RETURN pg_catalog.jsonb_build_object('tour_version',v);
END;
$fn$;

-- FAQ lesen: veröffentlichte Einträge für alle; der Admin sieht auch Entwürfe.
CREATE OR REPLACE FUNCTION public.get_faq()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); adm boolean;
BEGIN
 adm := me.id IS NOT NULL AND me.role='admin';
 RETURN pg_catalog.jsonb_build_object('can_edit',adm,
  'items',coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id',f.id,'category',f.category,'question',f.question,'answer',f.answer,
     'sort_order',f.sort_order,'is_published',f.is_published) ORDER BY f.sort_order, f.id)
   FROM public.faq_entries f WHERE f.is_published OR adm),'[]'::jsonb));
END;
$fn$;

-- FAQ pflegen (nur Admin). p_id NULL = neu.
CREATE OR REPLACE FUNCTION public.admin_save_faq(p_id bigint, p_category text, p_question text, p_answer text, p_sort_order integer DEFAULT 100, p_published boolean DEFAULT true)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); f public.faq_entries;
BEGIN
 IF me.id IS NULL OR me.role<>'admin' THEN RAISE EXCEPTION 'Nur der Admin pflegt die FAQ' USING ERRCODE='42501'; END IF;
 IF coalesce(p_category,'') NOT IN ('start','training','punkte','kaempfe','kampfgeist','coach','konto') THEN RAISE EXCEPTION 'Unbekannte Kategorie' USING ERRCODE='22023'; END IF;
 IF char_length(btrim(coalesce(p_question,''))) NOT BETWEEN 5 AND 200 THEN RAISE EXCEPTION 'Frage mit 5 bis 200 Zeichen' USING ERRCODE='22023'; END IF;
 IF char_length(btrim(coalesce(p_answer,''))) NOT BETWEEN 5 AND 2000 THEN RAISE EXCEPTION 'Antwort mit 5 bis 2000 Zeichen' USING ERRCODE='22023'; END IF;
 IF p_sort_order IS NULL OR p_sort_order NOT BETWEEN 0 AND 10000 THEN RAISE EXCEPTION 'Reihenfolge 0 bis 10000' USING ERRCODE='22023'; END IF;
 IF p_id IS NULL THEN
  INSERT INTO public.faq_entries(category,question,answer,sort_order,is_published,updated_by)
  VALUES (p_category,btrim(p_question),btrim(p_answer),p_sort_order,coalesce(p_published,true),me.id) RETURNING * INTO f;
 ELSE
  UPDATE public.faq_entries x SET category=p_category,question=btrim(p_question),answer=btrim(p_answer),sort_order=p_sort_order,
   is_published=coalesce(p_published,x.is_published),updated_at=now(),updated_by=me.id WHERE x.id=p_id RETURNING * INTO f;
  IF f.id IS NULL THEN RAISE EXCEPTION 'Eintrag nicht gefunden' USING ERRCODE='22023'; END IF;
 END IF;
 RETURN pg_catalog.jsonb_build_object('id',f.id,'category',f.category,'question',f.question,'answer',f.answer,'sort_order',f.sort_order,'is_published',f.is_published);
END;
$fn$;

REVOKE ALL ON FUNCTION public.get_my_onboarding(), public.mark_tour_seen(integer), public.get_faq(),
 public.admin_save_faq(bigint,text,text,text,integer,boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_onboarding(), public.mark_tour_seen(integer),
 public.admin_save_faq(bigint,text,text,text,integer,boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_faq() TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
