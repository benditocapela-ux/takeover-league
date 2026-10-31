-- Training 2.0 (31.10.2026, Owner-Auftrag): Trainingsort, beantragte Kategorie und eine zentrale, serverseitige Wertung.
--
-- Ursache der bisherigen 30-Punkte-Wertung:
--  * Selbst eingetragene Trainings verlieren beim Einfügen jede Stufe (league_private.training_insert_guard setzt club_tier auf NULL –
--    richtig, Boxer dürfen keine Stufe setzen).
--  * Die Trainerbestätigung public.review_training bucht danach nur training_types.points (nach der Aktivierung vom 28.10. für
--    Reguläres Boxtraining 30) und setzt nie eine Stufe. Nur Gym-Check-in und das nachträgliche Einstufen setzten club_tier.
--  => Ein reguläres Vereinstraining, das der Boxer selbst meldet, wurde nie als Pflicht- oder Ergänzungstraining gewertet.
--
-- Lösung (additiv, ohne bestehende Trainings, Punkte, EXP oder Coins zu ändern):
--  * Boxer melden Trainingsort (Verein / individuell) und – im Verein – eine Einheit: Pflicht (aus dem Vereinsstundenplan, fester
--    Wochentag) oder Ergänzung (wochentagsunabhängig). Das ist nur ein ANTRAG (requested_*). club_tier bleibt für Boxer gesperrt.
--  * Neue Trainer-RPC public.staff_review_training: bestätigt bzw. lehnt ab, übernimmt auf Wunsch die beantragte Kategorie als Vorschlag,
--    erlaubt Korrekturen (Art, Datum, Dauer, Kategorie) mit Begründung, erkennt Duplikate (Gym-Check-in + Selbstmeldung) und ist
--    idempotent (doppelt tippen bucht nichts doppelt). Punkte/EXP laufen über die bestehende Buchung (review_training) und
--    league_private.apply_training_value; Coins und Kampfpfad folgen wie bisher automatisch aus club_tier.
--  * public.staff_correct_training: nachträgliche Korrektur bestätigter Trainings (Begründung Pflicht, Audit, Saisonschutz).
--  * Eine Bewertungsregel league_private.training_reward(type, tier) für Buchung UND Vorschau.
--  * Lese-RPCs für das neue Trainer-Dashboard (Pagination serverseitig) und einen Admin-Prüfbericht (Dry-Run, ändert nichts).
--  * Schalter training_v2 startet AUS. Ohne Schalter verhält sich alles wie bisher (Anträge werden ignoriert, Stufen gesperrt).
--  * Stundenplan Mo/Mi/Sa «Reguläres Boxtraining» und Einschalten nur mit
--    supabase/production-prep/activate_20261031090000_training_v2.sql (ausdrückliche Freigabe nötig).
BEGIN;
DO $$ BEGIN
 IF to_regclass('public.club_tiers') IS NULL OR to_regclass('public.club_schedule') IS NULL
    OR to_regprocedure('league_private.apply_training_value(uuid,uuid,text,jsonb)') IS NULL
    OR to_regprocedure('public.review_training(uuid,text)') IS NULL
    OR to_regprocedure('public.admin_edit_training(uuid,uuid,bigint,date,text,text)') IS NULL
    OR NOT EXISTS (SELECT 1 FROM public.league_feature_flags WHERE feature_key='club_checkin_only') THEN
  RAISE EXCEPTION 'Voraussetzung fehlt: zuerst 20261028230000_club_schedule_tiers und 20261029230000_club_types_selfservice anwenden';
 END IF;
END $$;

INSERT INTO public.league_feature_flags(feature_key,display_name,is_enabled)
VALUES ('training_v2','Training 2.0: Trainingsort, Pflicht-/Ergänzungstraining, Trainer-Einstufung',false)
ON CONFLICT (feature_key) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Ergänzungstrainings im Verein (an jedem Tag möglich). Pflichttrainings kommen aus dem Stundenplan (club_schedule, tier='pflicht').
CREATE TABLE IF NOT EXISTS public.club_extra_trainings(
 key text PRIMARY KEY CHECK (key ~ '^[a-z0-9_]{2,40}$'),
 label text NOT NULL CHECK (char_length(btrim(label)) BETWEEN 3 AND 60),
 training_type_id bigint NOT NULL REFERENCES public.training_types(id),
 is_active boolean NOT NULL DEFAULT true,
 sort_order smallint NOT NULL DEFAULT 0
);
INSERT INTO public.club_extra_trainings(key,label,training_type_id,sort_order)
SELECT v.key, v.label, t.id, v.ord
FROM (VALUES ('sandsack','Sandsacktraining im Verein','Sandsack / Rundenarbeit',1),
             ('athletik','Athletiktraining im Verein','Krafttraining',2),
             ('technik','Techniktraining im Verein','Techniktraining',3)) v(key,label,type_name,ord)
JOIN public.training_types t ON t.name=v.type_name
ON CONFLICT (key) DO NOTHING;
ALTER TABLE public.club_extra_trainings ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.club_extra_trainings FROM PUBLIC, anon, authenticated;

-- Antrag des Boxers und Begründung des Trainers (getrennt von der autoritativen Stufe club_tier).
ALTER TABLE public.training_submissions ADD COLUMN IF NOT EXISTS training_location text;
ALTER TABLE public.training_submissions ADD COLUMN IF NOT EXISTS requested_tier text;
ALTER TABLE public.training_submissions ADD COLUMN IF NOT EXISTS requested_slot_id integer REFERENCES public.club_schedule(id);
ALTER TABLE public.training_submissions ADD COLUMN IF NOT EXISTS requested_extra_key text REFERENCES public.club_extra_trainings(key);
ALTER TABLE public.training_submissions ADD COLUMN IF NOT EXISTS tier_note text;
ALTER TABLE public.training_submissions DROP CONSTRAINT IF EXISTS training_submissions_v2_request_check;
ALTER TABLE public.training_submissions ADD CONSTRAINT training_submissions_v2_request_check CHECK (
 (training_location IS NULL OR training_location IN ('club','individual'))
 AND (requested_tier IS NULL OR requested_tier IN ('pflicht','ergaenzung'))
 AND (requested_tier IS NULL OR training_location='club')
 AND (requested_slot_id IS NULL OR requested_tier='pflicht')
 AND (requested_extra_key IS NULL OR requested_tier='ergaenzung')
 AND (tier_note IS NULL OR char_length(tier_note) BETWEEN 3 AND 500));
CREATE INDEX IF NOT EXISTS training_submissions_v2_status_date_idx ON public.training_submissions(status, training_date DESC, created_at DESC);
CREATE INDEX IF NOT EXISTS training_submissions_v2_boxer_date_idx ON public.training_submissions(boxer_id, training_date);

-- ---------------------------------------------------------------------------
-- Zentrale Bewertungsregel (Punkte = EXP, Coins, Kampfpfad). Gleiche Formeln wie training_value, kg_training_coins und kg_pass_points:
--  Punkte/EXP = max(Stufen-EXP, Punkte der Trainingsart); Coins = max(Stufen-Coins, Grundbetrag); Kampfpfad = Stufe, sonst kp_training.
CREATE OR REPLACE FUNCTION league_private.training_reward(p_type bigint, p_tier text)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT pg_catalog.jsonb_build_object('tier',ct.tier,'tier_label',ct.label,
  'points',GREATEST(coalesce(ct.exp,0),t.points),'exp',GREATEST(coalesce(ct.exp,0),t.points),
  'coins',GREATEST(coalesce(ct.coins,0),coalesce((SELECT k.coins_per_training FROM public.kg_settings k WHERE k.id=1),0)),
  'pass_points',coalesce(ct.pass_points,(SELECT ps.kp_training FROM public.kg_pass_settings ps WHERE ps.id=1),0))
 FROM public.training_types t LEFT JOIN public.club_tiers ct ON ct.tier=p_tier
 WHERE t.id=p_type
$fn$;

-- Bestehende Buchungsregel nutzt jetzt dieselbe Funktion (Ergebnis identisch zur bisherigen Formel).
CREATE OR REPLACE FUNCTION league_private.training_value(p_sub uuid)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT CASE WHEN s.status<>'approved' THEN 0 ELSE (league_private.training_reward(s.training_type_id, s.club_tier)->>'points')::integer END
 FROM public.training_submissions s WHERE s.id=p_sub
$fn$;

-- Ist der Tag ein Pflichttag laut Stundenplan?
CREATE OR REPLACE FUNCTION league_private.pflicht_slot_on(p_date date)
RETURNS public.club_schedule LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT x.* FROM public.club_schedule x WHERE x.is_active AND x.tier='pflicht' AND x.dow=extract(isodow FROM p_date)::integer
 ORDER BY x.sort_order, x.id LIMIT 1
$fn$;

-- Vorschlag des Servers für die Einstufung (aus dem Antrag, geprüft gegen Stundenplan und Ergänzungsliste).
CREATE OR REPLACE FUNCTION league_private.suggested_tier(s public.training_submissions)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT CASE
  WHEN s.training_location IS DISTINCT FROM 'club' THEN NULL
  WHEN s.requested_tier='pflicht' AND EXISTS (SELECT 1 FROM public.club_schedule x WHERE x.is_active AND x.tier='pflicht'
       AND x.dow=extract(isodow FROM s.training_date)::integer AND (s.requested_slot_id IS NULL OR x.id=s.requested_slot_id)) THEN 'pflicht'
  WHEN s.requested_tier='ergaenzung' AND EXISTS (SELECT 1 FROM public.club_extra_trainings e WHERE e.is_active
       AND (s.requested_extra_key IS NULL OR e.key=s.requested_extra_key)) THEN 'ergaenzung'
  ELSE NULL END
$fn$;

-- Hinweise für den Trainer (verhindern unbemerkte Doppelbuchungen).
CREATE OR REPLACE FUNCTION league_private.training_conflicts(s public.training_submissions)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT coalesce(pg_catalog.jsonb_agg(c.v ORDER BY c.v),'[]'::jsonb) FROM (
  -- Gym-Check-in am selben Tag: nur relevant, wenn diese Meldung eine Vereinseinheit ist (Ort Verein, Vereinsart oder gleiche Art)
  SELECT 'gym_same_day' AS v WHERE EXISTS (SELECT 1 FROM public.gym_attendance a JOIN public.gym_sessions g ON g.id=a.session_id
    WHERE a.profile_id=s.boxer_id AND g.session_date=s.training_date AND g.status<>'cancelled' AND a.submission_id IS DISTINCT FROM s.id
      AND (s.training_location='club' OR g.training_type_id=s.training_type_id
           OR EXISTS (SELECT 1 FROM public.training_types tt WHERE tt.id=s.training_type_id AND tt.club_only)))
  UNION ALL
  SELECT 'same_type_same_day' WHERE EXISTS (SELECT 1 FROM public.training_submissions o WHERE o.boxer_id=s.boxer_id AND o.id<>s.id
    AND o.training_date=s.training_date AND o.training_type_id=s.training_type_id AND o.status IN ('pending','approved'))
  UNION ALL
  SELECT 'pflicht_already' WHERE s.requested_tier='pflicht' AND EXISTS (SELECT 1 FROM public.training_submissions o WHERE o.boxer_id=s.boxer_id
    AND o.id<>s.id AND o.training_date=s.training_date AND o.status='approved' AND o.club_tier='pflicht')
  UNION ALL
  SELECT 'pflicht_wrong_day' WHERE s.requested_tier='pflicht' AND league_private.suggested_tier(s) IS NULL
  UNION ALL
  SELECT 'future_date' WHERE s.training_date>league_private.zurich_today()
 ) c
$fn$;

CREATE OR REPLACE FUNCTION league_private.training_closed_season(p_date date)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT EXISTS (SELECT 1 FROM public.league_seasons_v21 z WHERE z.status='closed' AND p_date BETWEEN z.starts_on AND z.ends_on)
$fn$;

-- Bezeichnung der beantragten Einheit
CREATE OR REPLACE FUNCTION league_private.requested_label(s public.training_submissions)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT CASE
  WHEN s.requested_slot_id IS NOT NULL THEN (SELECT (ARRAY['Montag','Dienstag','Mittwoch','Donnerstag','Freitag','Samstag','Sonntag'])[x.dow]||' – '||x.label
    FROM public.club_schedule x WHERE x.id=s.requested_slot_id)
  WHEN s.requested_extra_key IS NOT NULL THEN (SELECT e.label FROM public.club_extra_trainings e WHERE e.key=s.requested_extra_key)
  WHEN s.training_location='individual' THEN 'Individuelles Training'
  ELSE NULL END
$fn$;

-- Kategorie für Filter: bestätigt = autoritative Stufe, sonst Vorschlag aus dem Antrag.
CREATE OR REPLACE FUNCTION league_private.training_category(s public.training_submissions)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT coalesce(CASE WHEN s.status='approved' THEN s.club_tier ELSE league_private.suggested_tier(s) END,'individual')
$fn$;

-- Ein Eintrag für Listen und Antworten (nur Felder, die Trainer bereits sehen dürfen).
CREATE OR REPLACE FUNCTION league_private.training_card(s public.training_submissions, p_me uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE sug text := league_private.suggested_tier(s); eff text; tx public.point_transactions;
BEGIN
 SELECT * INTO tx FROM public.point_transactions x WHERE x.submission_id=s.id;
 eff := CASE WHEN s.status='approved' THEN s.club_tier ELSE sug END;
 RETURN pg_catalog.jsonb_build_object('id',s.id,'boxer_id',s.boxer_id,
  'boxer_name',(SELECT p.display_name FROM public.profiles p WHERE p.id=s.boxer_id),
  'training_type_id',s.training_type_id,'training_type_name',(SELECT t.name FROM public.training_types t WHERE t.id=s.training_type_id),
  'training_date',s.training_date,'duration_minutes',s.duration_minutes,'jogging_km',s.jogging_km,'technique_minutes',s.technique_minutes,
  'notes',s.notes,'status',s.status,'created_at',s.created_at,'reviewed_at',s.reviewed_at,'reviewed_by',s.reviewed_by,
  'reviewed_by_name',(SELECT p.display_name FROM public.profiles p WHERE p.id=s.reviewed_by),
  'recorded_by_name',(SELECT p.display_name FROM public.profiles p WHERE p.id=s.recorded_by),
  'training_location',s.training_location,'requested_tier',s.requested_tier,'requested_label',league_private.requested_label(s),
  'requested_slot_id',s.requested_slot_id,'requested_extra_key',s.requested_extra_key,
  'club_tier',s.club_tier,'suggested_tier',sug,'category',coalesce(eff,'individual'),'tier_note',s.tier_note,
  'reward',league_private.training_reward(s.training_type_id, eff),
  'points',tx.points,'exp',tx.exp,
  'gym',EXISTS (SELECT 1 FROM public.gym_attendance a WHERE a.submission_id=s.id),
  'corrected',EXISTS (SELECT 1 FROM public.training_audit a WHERE a.submission_id=s.id),
  'conflicts',CASE WHEN s.status='pending' THEN league_private.training_conflicts(s) ELSE '[]'::jsonb END,
  'own',s.boxer_id=p_me,'editable',NOT league_private.training_closed_season(s.training_date));
END;
$fn$;

-- ---------------------------------------------------------------------------
-- Einreichen (Boxer): Stufe bleibt gesperrt. Mit training_v2 wird der Antrag geprüft und die Trainingsart aus der Einheit übernommen.
CREATE OR REPLACE FUNCTION league_private.training_insert_guard()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE uid uuid := auth.uid(); me public.profiles; tname text; sl public.club_schedule; ex public.club_extra_trainings;
BEGIN
 IF uid IS NULL THEN RETURN NEW; END IF;
 SELECT * INTO me FROM public.profiles p WHERE p.auth_user_id=uid LIMIT 1;
 -- Trainer/Admin tragen für andere ein (z. B. staff_record_training); eigene Trainings gelten wie bei Boxern als Antrag.
 IF me.id IS NOT NULL AND me.role IN ('admin','coach') AND me.is_active AND NEW.boxer_id IS DISTINCT FROM me.id THEN RETURN NEW; END IF;
 NEW.club_tier := NULL;
 NEW.recorded_by := NULL;
 NEW.tier_note := NULL;
 IF NOT league_private.flag_on('training_v2') THEN
  NEW.training_location := NULL; NEW.requested_tier := NULL; NEW.requested_slot_id := NULL; NEW.requested_extra_key := NULL;
 ELSE
  NEW.training_location := coalesce(NEW.training_location,'individual');
  IF NEW.training_location NOT IN ('club','individual') THEN RAISE EXCEPTION 'Bitte den Trainingsort wählen' USING ERRCODE='22023'; END IF;
  IF NEW.training_location='individual' THEN
   NEW.requested_tier := NULL; NEW.requested_slot_id := NULL; NEW.requested_extra_key := NULL;
  ELSIF NEW.requested_slot_id IS NOT NULL THEN
   SELECT * INTO sl FROM public.club_schedule x WHERE x.id=NEW.requested_slot_id AND x.is_active AND x.tier='pflicht';
   IF NOT FOUND THEN RAISE EXCEPTION 'Diese Pflichteinheit gibt es im Stundenplan nicht' USING ERRCODE='22023'; END IF;
   IF extract(isodow FROM NEW.training_date)::integer<>sl.dow THEN
    RAISE EXCEPTION 'Das Datum passt nicht: «%» findet am % statt', sl.label,
     (ARRAY['Montag','Dienstag','Mittwoch','Donnerstag','Freitag','Samstag','Sonntag'])[sl.dow] USING ERRCODE='22023';
   END IF;
   NEW.requested_tier := 'pflicht'; NEW.requested_extra_key := NULL; NEW.training_type_id := sl.training_type_id;
  ELSIF NEW.requested_extra_key IS NOT NULL THEN
   SELECT * INTO ex FROM public.club_extra_trainings x WHERE x.key=NEW.requested_extra_key AND x.is_active;
   IF NOT FOUND THEN RAISE EXCEPTION 'Dieses Ergänzungstraining gibt es nicht' USING ERRCODE='22023'; END IF;
   NEW.requested_tier := 'ergaenzung'; NEW.requested_slot_id := NULL; NEW.training_type_id := ex.training_type_id;
  ELSE
   RAISE EXCEPTION 'Bitte die Vereinseinheit wählen (Pflicht- oder Ergänzungstraining)' USING ERRCODE='22023';
  END IF;
  IF NEW.training_date>league_private.zurich_today() THEN RAISE EXCEPTION 'Das Trainingsdatum darf nicht in der Zukunft liegen' USING ERRCODE='22023'; END IF;
 END IF;
 SELECT t.name INTO tname FROM public.training_types t WHERE t.id=NEW.training_type_id AND t.club_only;
 IF tname IS NOT NULL AND league_private.flag_on('gym_training') AND league_private.flag_on('club_checkin_only') THEN
  RAISE EXCEPTION '«%» ist ein Vereinstraining und wird im Gym per Check-in erfasst. Selbst eintragen kannst du Heimtraining.', tname
   USING ERRCODE='42501';
 END IF;
 RETURN NEW;
END;
$fn$;

-- Boxer dürfen Antrag und Stufe nach dem Einreichen nicht ändern (es gibt keine Update-Policy; zusätzlicher Schutz für Direktaufrufe).
CREATE OR REPLACE FUNCTION league_private.training_request_update_guard()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE uid uuid := auth.uid(); me public.profiles;
BEGIN
 IF uid IS NULL THEN RETURN NEW; END IF;
 SELECT * INTO me FROM public.profiles p WHERE p.auth_user_id=uid LIMIT 1;
 IF me.id IS NOT NULL AND me.role IN ('admin','coach') AND me.is_active THEN RETURN NEW; END IF;
 IF NEW.club_tier IS DISTINCT FROM OLD.club_tier OR NEW.requested_tier IS DISTINCT FROM OLD.requested_tier
    OR NEW.requested_slot_id IS DISTINCT FROM OLD.requested_slot_id OR NEW.requested_extra_key IS DISTINCT FROM OLD.requested_extra_key
    OR NEW.training_location IS DISTINCT FROM OLD.training_location OR NEW.tier_note IS DISTINCT FROM OLD.tier_note THEN
  RAISE EXCEPTION 'Einstufung kann nur ein Trainer ändern' USING ERRCODE='42501';
 END IF;
 RETURN NEW;
END;
$fn$;
DROP TRIGGER IF EXISTS league_training_request_update_guard ON public.training_submissions;
CREATE TRIGGER league_training_request_update_guard BEFORE UPDATE ON public.training_submissions
 FOR EACH ROW EXECUTE FUNCTION league_private.training_request_update_guard();

-- ---------------------------------------------------------------------------
-- Prüfen einer gewünschten Stufe (gemeinsam für Bestätigung und Korrektur).
CREATE OR REPLACE FUNCTION league_private.check_tier_choice(s public.training_submissions, p_tier text, p_reason text, p_me uuid)
RETURNS void LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
BEGIN
 IF p_tier IS NULL THEN RETURN; END IF;
 IF p_tier IS NOT DISTINCT FROM s.club_tier AND s.boxer_id<>p_me THEN RETURN; END IF; -- unveränderte Stufe (z. B. Gym-Check-in) bleibt
 IF NOT league_private.flag_on('training_v2') THEN
  RAISE EXCEPTION 'Pflicht- und Ergänzungstraining gelten, sobald «Training 2.0» freigeschaltet ist' USING ERRCODE='42501';
 END IF;
 IF NOT EXISTS (SELECT 1 FROM public.club_tiers c WHERE c.tier=p_tier) THEN RAISE EXCEPTION 'Unbekannte Kategorie' USING ERRCODE='22023'; END IF;
 IF s.boxer_id=p_me THEN RAISE EXCEPTION 'Eigene Trainings stuft ein anderer Trainer oder der Admin ein' USING ERRCODE='42501'; END IF;
 IF p_tier='pflicht' AND (league_private.pflicht_slot_on(s.training_date)).id IS NULL AND pg_catalog.char_length(coalesce(p_reason,''))<3 THEN
  RAISE EXCEPTION 'An diesem Tag steht kein Pflichttraining im Stundenplan. Für ein verschobenes Vereinstraining bitte eine Begründung angeben'
   USING ERRCODE='22023';
 END IF;
END;
$fn$;

-- Trainer: offenes Training bestätigen oder ablehnen.
--  p_tier: 'auto' (Standard) = Vorschlag aus Antrag und Stundenplan · 'none' = individuell · 'pflicht' · 'ergaenzung'.
--  Korrekturen (Art, Datum, Dauer) werden vor der Bestätigung übernommen und protokolliert.
--  Abweichung vom Vorschlag, verschobenes Pflichttraining und bewusst zugelassene Duplikate brauchen eine Begründung.
--  Wiederholter Aufruf mit gleicher Entscheidung bucht nichts zusätzlich (already=true).
CREATE OR REPLACE FUNCTION public.staff_review_training(p_submission_id uuid, p_decision text, p_tier text DEFAULT 'auto',
 p_training_type_id bigint DEFAULT NULL, p_training_date date DEFAULT NULL, p_duration_minutes integer DEFAULT NULL,
 p_reason text DEFAULT NULL, p_allow_duplicate boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.require_staff(); s public.training_submissions; s0 jsonb; t public.training_types;
 reason text := NULLIF(pg_catalog.btrim(coalesce(p_reason,'')),''); want text; sug text; conflicts jsonb; corrected boolean := false; v2 boolean := league_private.flag_on('training_v2');
BEGIN
 IF p_decision IS NULL OR p_decision NOT IN ('approved','rejected') THEN RAISE EXCEPTION 'Ungültige Entscheidung' USING ERRCODE='22023'; END IF;
 IF reason IS NOT NULL AND pg_catalog.char_length(reason) NOT BETWEEN 3 AND 500 THEN RAISE EXCEPTION 'Begründung mit 3 bis 500 Zeichen' USING ERRCODE='22023'; END IF;
 SELECT * INTO s FROM public.training_submissions x WHERE x.id=p_submission_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Training nicht gefunden' USING ERRCODE='22023'; END IF;
 -- Gleichzeitige Buchungen desselben Boxers am selben Tag (Selbstmeldung und Gym-Check-in) nacheinander prüfen
 PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('training_day:'||s.boxer_id::text||':'||s.training_date::text));
 IF p_training_date IS NOT NULL AND p_training_date<>s.training_date THEN
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('training_day:'||s.boxer_id::text||':'||p_training_date::text));
 END IF;
 IF s.status<>'pending' THEN
  IF s.status=p_decision THEN
   RETURN league_private.training_card(s, me.id) || pg_catalog.jsonb_build_object('already',true);
  END IF;
  RAISE EXCEPTION 'Dieses Training wurde bereits bearbeitet' USING ERRCODE='55000';
 END IF;

 IF p_decision='rejected' THEN
  PERFORM public.review_training(s.id,'rejected');
  IF reason IS NOT NULL THEN UPDATE public.training_submissions x SET tier_note=reason WHERE x.id=s.id; END IF;
  SELECT * INTO s FROM public.training_submissions x WHERE x.id=p_submission_id;
  RETURN league_private.training_card(s, me.id) || pg_catalog.jsonb_build_object('already',false);
 END IF;

 IF s.boxer_id=me.id AND me.role<>'admin' THEN
  RAISE EXCEPTION 'Eigene Trainings bestätigt ein anderer Trainer oder der Admin' USING ERRCODE='42501';
 END IF;
 IF league_private.training_closed_season(s.training_date) THEN
  RAISE EXCEPTION 'Dieses Training gehört zu einer abgeschlossenen Saison' USING ERRCODE='22023';
 END IF;
 -- Korrekturen vor der Bestätigung
 s0 := pg_catalog.to_jsonb(s);
 IF p_training_type_id IS NOT NULL AND p_training_type_id<>s.training_type_id THEN
  SELECT * INTO t FROM public.training_types x WHERE x.id=p_training_type_id AND x.is_active;
  IF NOT FOUND THEN RAISE EXCEPTION 'Trainingsart ungültig oder inaktiv' USING ERRCODE='22023'; END IF;
  corrected := true;
 END IF;
 IF p_training_date IS NOT NULL AND p_training_date<>s.training_date THEN
  IF p_training_date>league_private.zurich_today() THEN RAISE EXCEPTION 'Das Trainingsdatum darf nicht in der Zukunft liegen' USING ERRCODE='22023'; END IF;
  corrected := true;
 END IF;
 IF p_duration_minutes IS NOT NULL AND p_duration_minutes IS DISTINCT FROM s.duration_minutes THEN
  IF p_duration_minutes NOT BETWEEN 1 AND 1440 THEN RAISE EXCEPTION 'Bitte die Dauer in Minuten angeben (1–1440)' USING ERRCODE='22023'; END IF;
  corrected := true;
 END IF;
 IF corrected THEN
  UPDATE public.training_submissions x SET training_type_id=coalesce(p_training_type_id,x.training_type_id),
   training_date=coalesce(p_training_date,x.training_date), duration_minutes=coalesce(p_duration_minutes,x.duration_minutes),
   technique_minutes=CASE
     WHEN (SELECT tt.name FROM public.training_types tt WHERE tt.id=coalesce(p_training_type_id,x.training_type_id))='Techniktraining'
      THEN coalesce(p_duration_minutes,x.duration_minutes)
     WHEN coalesce(p_training_type_id,x.training_type_id)<>x.training_type_id THEN NULL
     ELSE x.technique_minutes END
  WHERE x.id=s.id RETURNING * INTO s;
  INSERT INTO public.training_audit(submission_id,changed_by,old_submission,new_submission,old_transaction,new_transaction)
  VALUES (s.id,me.id,s0,pg_catalog.to_jsonb(s),NULL,NULL);
 END IF;
 IF league_private.training_closed_season(s.training_date) THEN
  RAISE EXCEPTION 'Dieses Training gehört zu einer abgeschlossenen Saison' USING ERRCODE='22023';
 END IF;

 -- Kategorie bestimmen
 sug := CASE WHEN v2 AND s.boxer_id<>me.id THEN league_private.suggested_tier(s) END;
 want := CASE WHEN p_tier IS NULL OR p_tier='auto' THEN sug WHEN p_tier IN ('none','') THEN NULL ELSE p_tier END;
 IF want IS DISTINCT FROM sug AND reason IS NULL THEN
  RAISE EXCEPTION 'Die Kategorie weicht vom Antrag ab: bitte kurz begründen' USING ERRCODE='22023';
 END IF;
 PERFORM league_private.check_tier_choice(s, want, reason, me.id);

 -- Duplikate (z. B. Gym-Check-in und Selbstmeldung derselben Einheit)
 conflicts := league_private.training_conflicts(s) - 'future_date' - 'pflicht_wrong_day';
 IF s.training_date>league_private.zurich_today() THEN RAISE EXCEPTION 'Das Trainingsdatum liegt in der Zukunft' USING ERRCODE='22023'; END IF;
 IF pg_catalog.jsonb_array_length(conflicts)>0 AND NOT coalesce(p_allow_duplicate,false) THEN
  RAISE EXCEPTION 'Mögliches Duplikat: Für diesen Boxer gibt es am selben Tag schon eine Einheit (Gym-Check-in oder gleiche Trainingsart). Bitte prüfen und bewusst bestätigen'
   USING ERRCODE='23505', DETAIL=conflicts::text;
 END IF;
 IF pg_catalog.jsonb_array_length(conflicts)>0 AND reason IS NULL THEN
  RAISE EXCEPTION 'Bitte begründen, warum es keine doppelte Einheit ist' USING ERRCODE='22023';
 END IF;

 -- Buchung: bestehende Bestätigung (eine Punktebuchung, Boni, Mitteilungen), danach Stufe und Wert
 PERFORM public.review_training(s.id,'approved');
 -- Stufe immer autoritativ setzen (eine vorbelegte Stufe bleibt nie unbemerkt stehen)
 UPDATE public.training_submissions x SET club_tier=want, tier_note=coalesce(reason,x.tier_note) WHERE x.id=s.id;
 IF want IS NOT NULL OR reason IS NOT NULL OR s.club_tier IS NOT NULL THEN
  PERFORM league_private.apply_training_value(s.id, me.id,
   CASE WHEN want IS NULL THEN 'Bestätigtes Training' ELSE 'Bestätigtes Training ('||league_private.tier_label(want)||')' END,
   CASE WHEN reason IS NOT NULL OR want IS DISTINCT FROM sug THEN s0 END);
 END IF;
 SELECT * INTO s FROM public.training_submissions x WHERE x.id=p_submission_id;
 RETURN league_private.training_card(s, me.id) || pg_catalog.jsonb_build_object('already',false,'corrected',corrected);
END;
$fn$;

-- Trainer: bestätigtes Training nachträglich korrigieren (Art, Datum, Dauer, Kategorie). Begründung Pflicht; Punkte/EXP, Coins
-- und Kampfpfad folgen automatisch; jede Änderung steht in training_audit. Nicht in abgeschlossenen Saisons.
CREATE OR REPLACE FUNCTION public.staff_correct_training(p_submission_id uuid, p_training_type_id bigint, p_training_date date,
 p_duration_minutes integer, p_tier text, p_reason text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.require_staff(); s public.training_submissions; s0 jsonb; want text;
 reason text := NULLIF(pg_catalog.btrim(coalesce(p_reason,'')),''); before_pts integer; tname text;
BEGIN
 IF reason IS NULL OR pg_catalog.char_length(reason) NOT BETWEEN 3 AND 500 THEN RAISE EXCEPTION 'Bitte die Korrektur begründen (3 bis 500 Zeichen)' USING ERRCODE='22023'; END IF;
 SELECT * INTO s FROM public.training_submissions x WHERE x.id=p_submission_id FOR UPDATE;
 IF NOT FOUND OR s.status<>'approved' THEN RAISE EXCEPTION 'Nur bestätigte Trainings können hier korrigiert werden' USING ERRCODE='22023'; END IF;
 IF league_private.training_closed_season(s.training_date) OR league_private.training_closed_season(coalesce(p_training_date,s.training_date)) THEN
  RAISE EXCEPTION 'Dieses Training gehört zu einer abgeschlossenen Saison' USING ERRCODE='22023';
 END IF;
 IF coalesce(p_training_date,s.training_date)>league_private.zurich_today() THEN RAISE EXCEPTION 'Das Trainingsdatum darf nicht in der Zukunft liegen' USING ERRCODE='22023'; END IF;
 IF p_duration_minutes IS NOT NULL AND p_duration_minutes NOT BETWEEN 1 AND 1440 THEN RAISE EXCEPTION 'Bitte die Dauer in Minuten angeben (1–1440)' USING ERRCODE='22023'; END IF;
 IF s.boxer_id=me.id AND me.role<>'admin' THEN RAISE EXCEPTION 'Eigene Trainings korrigiert ein anderer Trainer oder der Admin' USING ERRCODE='42501'; END IF;
 want := CASE WHEN p_tier IS NULL OR p_tier='keep' THEN s.club_tier WHEN p_tier IN ('none','') THEN NULL ELSE p_tier END;
 before_pts := (SELECT x.points FROM public.point_transactions x WHERE x.submission_id=s.id);
 s0 := pg_catalog.to_jsonb(s);
 IF coalesce(p_training_type_id,s.training_type_id)<>s.training_type_id OR coalesce(p_training_date,s.training_date)<>s.training_date THEN
  PERFORM public.admin_edit_training(s.id, s.boxer_id, coalesce(p_training_type_id,s.training_type_id), coalesce(p_training_date,s.training_date), s.notes, 'approved');
 END IF;
 SELECT * INTO s FROM public.training_submissions x WHERE x.id=p_submission_id FOR UPDATE;
 PERFORM league_private.check_tier_choice(s, want, reason, me.id);
 SELECT t.name INTO tname FROM public.training_types t WHERE t.id=s.training_type_id;
 UPDATE public.training_submissions x SET club_tier=want, tier_note=reason,
  duration_minutes=coalesce(p_duration_minutes,x.duration_minutes),
  technique_minutes=CASE WHEN tname='Techniktraining' THEN coalesce(p_duration_minutes,x.duration_minutes)
   WHEN (s0->>'training_type_id')::bigint<>x.training_type_id THEN NULL ELSE x.technique_minutes END
 WHERE x.id=s.id;
 PERFORM league_private.apply_training_value(s.id, me.id,
  CASE WHEN want IS NULL THEN 'Training (korrigiert)' ELSE 'Training ('||league_private.tier_label(want)||', korrigiert)' END, s0);
 -- Abschluss-Eintrag: vollständiger Vorher/Nachher-Stand der Korrektur (Kategorie, Dauer, Begründung)
 INSERT INTO public.training_audit(submission_id,changed_by,old_submission,new_submission,old_transaction,new_transaction)
 SELECT s.id, me.id, s0, pg_catalog.to_jsonb(x), pg_catalog.to_jsonb(tx), pg_catalog.to_jsonb(tx)
 FROM public.training_submissions x LEFT JOIN public.point_transactions tx ON tx.submission_id=x.id WHERE x.id=s.id;
 IF me.role='coach' THEN PERFORM league_private.coach_training_bonus_refresh(s.boxer_id); ELSE PERFORM public.recalculate_boxer_bonuses(s.boxer_id); END IF;
 SELECT * INTO s FROM public.training_submissions x WHERE x.id=p_submission_id;
 RETURN league_private.training_card(s, me.id) || pg_catalog.jsonb_build_object('points_before',before_pts);
END;
$fn$;

-- ---------------------------------------------------------------------------
-- Lesen
-- Konfiguration für das Formular (Boxer) und das Dashboard (Trainer). Mit Schalter aus sehen nur Trainer eine Vorschau.
CREATE OR REPLACE FUNCTION public.get_training_v2_config()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); staff boolean; on_ boolean := league_private.flag_on('training_v2');
BEGIN
 IF me.id IS NULL THEN RAISE EXCEPTION 'Bitte anmelden' USING ERRCODE='42501'; END IF;
 staff := me.role IN ('admin','coach');
 IF NOT on_ AND NOT staff THEN RETURN pg_catalog.jsonb_build_object('enabled',false); END IF;
 RETURN pg_catalog.jsonb_build_object('enabled',on_,'preview',NOT on_,'today',league_private.zurich_today(),
  'tiers',(SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('tier',c.tier,'label',c.label,'exp',c.exp,'coins',c.coins,'pass_points',c.pass_points) ORDER BY c.exp DESC) FROM public.club_tiers c),
  'pflicht',coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('slot_id',x.id,'dow',x.dow,
     'day_name',(ARRAY['Montag','Dienstag','Mittwoch','Donnerstag','Freitag','Samstag','Sonntag'])[x.dow],'label',x.label,
     'training_type_id',x.training_type_id,'training_type',(SELECT t.name FROM public.training_types t WHERE t.id=x.training_type_id),
     'duration_minutes',x.duration_minutes,'reward',league_private.training_reward(x.training_type_id,'pflicht')) ORDER BY x.dow, x.sort_order, x.id)
    FROM public.club_schedule x WHERE x.is_active AND x.tier='pflicht'),'[]'::jsonb),
  'extras',coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('key',e.key,'label',e.label,'training_type_id',e.training_type_id,
     'training_type',(SELECT t.name FROM public.training_types t WHERE t.id=e.training_type_id),
     'reward',league_private.training_reward(e.training_type_id,'ergaenzung')) ORDER BY e.sort_order, e.key)
    FROM public.club_extra_trainings e WHERE e.is_active),'[]'::jsonb),
  'types',coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id',t.id,'name',t.name,'category',t.category,'club_only',t.club_only,
     'reward',league_private.training_reward(t.id,NULL)) ORDER BY t.sort_order, t.id)
    FROM public.training_types t WHERE t.is_active),'[]'::jsonb));
END;
$fn$;

-- Vorschau einer Wertung (nur Anzeige, bucht nichts).
CREATE OR REPLACE FUNCTION public.training_reward_preview(p_training_type_id bigint, p_tier text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); r jsonb;
BEGIN
 IF me.id IS NULL THEN RAISE EXCEPTION 'Bitte anmelden' USING ERRCODE='42501'; END IF;
 IF p_tier IS NOT NULL AND p_tier NOT IN ('pflicht','ergaenzung') THEN RAISE EXCEPTION 'Unbekannte Kategorie' USING ERRCODE='22023'; END IF;
 r := league_private.training_reward(p_training_type_id, p_tier);
 IF r IS NULL THEN RAISE EXCEPTION 'Trainingsart nicht gefunden' USING ERRCODE='22023'; END IF;
 RETURN r;
END;
$fn$;

-- Trainingsliste fürs Dashboard (serverseitige Suche, Filter und Pagination; höchstens 50 pro Seite).
CREATE OR REPLACE FUNCTION public.staff_list_trainings(p_status text DEFAULT 'pending', p_category text DEFAULT NULL, p_search text DEFAULT NULL,
 p_boxer_id uuid DEFAULT NULL, p_from date DEFAULT NULL, p_to date DEFAULT NULL, p_limit integer DEFAULT 10, p_offset integer DEFAULT 0,
 p_training_type_id bigint DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.require_staff(); lim integer := LEAST(GREATEST(coalesce(p_limit,10),1),50); off integer := coalesce(p_offset,0);
 q text := NULLIF(pg_catalog.btrim(coalesce(p_search,'')),''); total integer; items jsonb;
BEGIN
 IF p_status IS NOT NULL AND p_status NOT IN ('pending','approved','rejected') THEN RAISE EXCEPTION 'Ungültiger Trainingsstatus' USING ERRCODE='22023'; END IF;
 IF p_category IS NOT NULL AND p_category NOT IN ('pflicht','ergaenzung','individual') THEN RAISE EXCEPTION 'Ungültige Kategorie' USING ERRCODE='22023'; END IF;
 IF off<0 OR off>100000 THEN RAISE EXCEPTION 'Ungültiger Offset' USING ERRCODE='22023'; END IF;
 IF pg_catalog.char_length(coalesce(q,''))>120 THEN RAISE EXCEPTION 'Die Suche darf höchstens 120 Zeichen enthalten' USING ERRCODE='22023'; END IF;
 IF p_from IS NOT NULL AND p_to IS NOT NULL AND p_from>p_to THEN RAISE EXCEPTION 'Das Startdatum darf nicht nach dem Enddatum liegen' USING ERRCODE='22023'; END IF;
 SELECT count(*)::integer INTO total
 FROM public.training_submissions s JOIN public.profiles p ON p.id=s.boxer_id JOIN public.training_types t ON t.id=s.training_type_id
 WHERE (p_status IS NULL OR s.status=p_status) AND (p_boxer_id IS NULL OR s.boxer_id=p_boxer_id)
   AND (p_from IS NULL OR s.training_date>=p_from) AND (p_to IS NULL OR s.training_date<=p_to)
   AND (p_category IS NULL OR league_private.training_category(s)=p_category)
   AND (p_training_type_id IS NULL OR s.training_type_id=p_training_type_id)
   AND (q IS NULL OR pg_catalog.strpos(pg_catalog.lower(coalesce(p.display_name,'')||' '||coalesce(t.name,'')||' '||coalesce(s.notes,'')||' '||s.training_date::text),pg_catalog.lower(q))>0);
 SELECT coalesce(pg_catalog.jsonb_agg(league_private.training_card(z.r, me.id) ORDER BY z.d DESC, z.c DESC, z.i DESC),'[]'::jsonb) INTO items
 FROM (SELECT s AS r, s.training_date AS d, s.created_at AS c, s.id AS i
       FROM public.training_submissions s JOIN public.profiles p ON p.id=s.boxer_id JOIN public.training_types t ON t.id=s.training_type_id
       WHERE (p_status IS NULL OR s.status=p_status) AND (p_boxer_id IS NULL OR s.boxer_id=p_boxer_id)
         AND (p_from IS NULL OR s.training_date>=p_from) AND (p_to IS NULL OR s.training_date<=p_to)
         AND (p_category IS NULL OR league_private.training_category(s)=p_category)
   AND (p_training_type_id IS NULL OR s.training_type_id=p_training_type_id)
         AND (q IS NULL OR pg_catalog.strpos(pg_catalog.lower(coalesce(p.display_name,'')||' '||coalesce(t.name,'')||' '||coalesce(s.notes,'')||' '||s.training_date::text),pg_catalog.lower(q))>0)
       ORDER BY s.training_date DESC, s.created_at DESC, s.id DESC LIMIT lim OFFSET off) z;
 RETURN pg_catalog.jsonb_build_object('items',items,'total_count',coalesce(total,0),'limit',lim,'offset',off);
END;
$fn$;

-- Kennzahlen für die Startseite.
CREATE OR REPLACE FUNCTION public.staff_training_summary()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.require_staff(); today date := league_private.zurich_today();
BEGIN
 RETURN pg_catalog.jsonb_build_object('today',today,'enabled',league_private.flag_on('training_v2'),
  'pending',(SELECT count(*) FROM public.training_submissions s WHERE s.status='pending'),
  'pending_conflicts',(SELECT count(*) FROM public.training_submissions s WHERE s.status='pending' AND pg_catalog.jsonb_array_length(league_private.training_conflicts(s))>0),
  'pending_by_category',(SELECT pg_catalog.jsonb_build_object('pflicht',count(*) FILTER (WHERE c='pflicht'),'ergaenzung',count(*) FILTER (WHERE c='ergaenzung'),
      'individual',count(*) FILTER (WHERE c IS NULL))
    FROM (SELECT league_private.suggested_tier(s) c FROM public.training_submissions s WHERE s.status='pending') z),
  'today_trainings',(SELECT count(*) FROM public.training_submissions s WHERE s.training_date=today AND s.status IN ('pending','approved')),
  'confirmed_today',(SELECT count(*) FROM public.training_submissions s WHERE s.status='approved' AND (s.reviewed_at AT TIME ZONE 'Europe/Zurich')::date=today),
  'active_boxers',(SELECT count(*) FROM public.profiles p WHERE p.is_active AND p.archived_at IS NULL AND p.role IN ('boxer','coach')),
  'open_gym_sessions',(SELECT count(*) FROM public.gym_sessions g WHERE g.status='open' AND g.session_date=today),
  'recent_confirmed',coalesce((SELECT pg_catalog.jsonb_agg(league_private.training_card(x, me.id) ORDER BY x.reviewed_at DESC)
    FROM (SELECT s.* FROM public.training_submissions s WHERE s.status='approved' AND s.reviewed_at IS NOT NULL ORDER BY s.reviewed_at DESC, s.id DESC LIMIT 5) x),'[]'::jsonb));
END;
$fn$;

-- Admin-Prüfbericht (Dry-Run, ändert nichts): bestätigte Vereinstrainings ohne Stufe in offenen Saisons mit Vorschlag und Differenz.
-- Vorschlag nur bei Antrag (Training 2.0) ODER Vereinsart bzw. Art der Einheit am Pflichttag / Ergänzungsart – nie allein nach Wochentag.
-- Nachbuchen nur einzeln über staff_correct_training (mit Begründung, Audit) nach ausdrücklicher Freigabe.
CREATE OR REPLACE FUNCTION public.admin_training_tier_review(p_limit integer DEFAULT 20, p_offset integer DEFAULT 0)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); lim integer := LEAST(GREATEST(coalesce(p_limit,20),1),100);
BEGIN
 IF me.id IS NULL OR me.role<>'admin' THEN RAISE EXCEPTION 'Nur der Admin sieht den Prüfbericht' USING ERRCODE='42501'; END IF;
 RETURN (WITH c AS (
   SELECT s.*, tx.points AS cur,
    CASE WHEN league_private.suggested_tier(s) IS NOT NULL THEN league_private.suggested_tier(s)
         WHEN (league_private.pflicht_slot_on(s.training_date)).id IS NOT NULL
              AND (t.club_only OR (league_private.pflicht_slot_on(s.training_date)).training_type_id=t.id) THEN 'pflicht'
         WHEN EXISTS (SELECT 1 FROM public.club_extra_trainings e WHERE e.is_active AND e.training_type_id=t.id) AND t.club_only THEN 'ergaenzung'
    END AS proposal,
    CASE WHEN league_private.suggested_tier(s) IS NOT NULL THEN 'Antrag des Boxers'
         WHEN (league_private.pflicht_slot_on(s.training_date)).id IS NOT NULL
              AND (t.club_only OR (league_private.pflicht_slot_on(s.training_date)).training_type_id=t.id) THEN 'Vereinsart am Pflichttag (bitte mit Trainer prüfen)'
         ELSE 'Vereins-Ergänzungsart (bitte mit Trainer prüfen)' END AS basis
   FROM public.training_submissions s JOIN public.training_types t ON t.id=s.training_type_id
   JOIN public.point_transactions tx ON tx.submission_id=s.id
   WHERE s.status='approved' AND s.club_tier IS NULL AND NOT league_private.training_closed_season(s.training_date)
     AND NOT EXISTS (SELECT 1 FROM public.gym_attendance a WHERE a.submission_id=s.id))
  SELECT pg_catalog.jsonb_build_object('dry_run',true,'total_count',(SELECT count(*) FROM c WHERE c.proposal IS NOT NULL),
   'total_delta',(SELECT coalesce(sum((league_private.training_reward(c.training_type_id,c.proposal)->>'points')::integer-c.cur),0) FROM c WHERE c.proposal IS NOT NULL),
   'items',coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id',z.id,'boxer_name',(SELECT p.display_name FROM public.profiles p WHERE p.id=z.boxer_id),
      'training_date',z.training_date,'training_type',(SELECT t.name FROM public.training_types t WHERE t.id=z.training_type_id),
      'current_points',z.cur,'proposed_tier',z.proposal,'proposed_points',(league_private.training_reward(z.training_type_id,z.proposal)->>'points')::integer,
      'delta',(league_private.training_reward(z.training_type_id,z.proposal)->>'points')::integer-z.cur,'basis',z.basis) ORDER BY z.training_date DESC, z.id)
    FROM (SELECT * FROM c WHERE c.proposal IS NOT NULL ORDER BY c.training_date DESC, c.id LIMIT lim OFFSET GREATEST(coalesce(p_offset,0),0)) z),'[]'::jsonb)));
END;
$fn$;

REVOKE ALL ON FUNCTION league_private.training_reward(bigint,text), league_private.pflicht_slot_on(date),
 league_private.suggested_tier(public.training_submissions), league_private.training_conflicts(public.training_submissions),
 league_private.training_closed_season(date), league_private.requested_label(public.training_submissions),
 league_private.training_category(public.training_submissions),
 league_private.training_card(public.training_submissions,uuid), league_private.training_insert_guard(),
 league_private.training_request_update_guard(), league_private.check_tier_choice(public.training_submissions,text,text,uuid),
 league_private.training_value(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.staff_review_training(uuid,text,text,bigint,date,integer,text,boolean),
 public.staff_correct_training(uuid,bigint,date,integer,text,text), public.get_training_v2_config(),
 public.training_reward_preview(bigint,text), public.staff_list_trainings(text,text,text,uuid,date,date,integer,integer,bigint),
 public.staff_training_summary(), public.admin_training_tier_review(integer,integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.staff_review_training(uuid,text,text,bigint,date,integer,text,boolean),
 public.staff_correct_training(uuid,bigint,date,integer,text,text), public.get_training_v2_config(),
 public.training_reward_preview(bigint,text), public.staff_list_trainings(text,text,text,uuid,date,date,integer,integer,bigint),
 public.staff_training_summary(), public.admin_training_tier_review(integer,integer) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
