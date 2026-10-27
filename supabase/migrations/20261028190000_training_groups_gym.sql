-- Etappe 2 (27.10.2026, Owner-Auftrag): Training im Gym.
--  * Trainingsgruppen Newcomer / Fortgeschrittene / Wettkämpfer mit steigendem Wochenziel (2 / 3 / 5 Trainings).
--    Zuteilung durch Trainer/Admins, Wochenziele ändert nur der Admin.
--  * Gym-Check-in: Trainer starten eine Einheit, markieren Anwesende (Boxer können sich selbst einchecken)
--    und bestätigen alle auf einmal. Die Trainings entstehen über die bestehende public.staff_record_training
--    (Punkte, EXP, Boni, Achievements, Ziele, Mitteilung exakt wie bisher, sofort bestätigt, «vom Trainer eingetragen»).
--    Wer an dem Tag dieselbe Trainingsart schon eingereicht hat, wird nicht doppelt eingetragen.
--  * Präsenz: Trainingstage der letzten 4 Wochen, Wochenziel der Gruppe, Serie erfüllter Wochen.
--  * Wochenplan pro Gruppe und Woche (Fokus + Einheiten); Boxer sehen den veröffentlichten Plan ihrer Gruppe
--    mit Status aus ihren eigenen Trainings.
--  * Zugriff nur über RPCs; Tabellen mit RLS ohne direkte Rechte. Neues Feature-Flag gym_training (AUS):
--    Boxer sehen die Bereiche erst nach dem Einschalten, Trainer/Admins können vorbereiten.
-- Bestehende Trainings, Punkte und EXP bleiben unverändert.
-- Produktion nur über den regulären Migrationsweg und eine separate ausdrückliche FREIGABE.
BEGIN;

DO $$ BEGIN
 IF to_regprocedure('public.staff_record_training(uuid,bigint,date,integer,text,numeric,uuid)') IS NULL
    OR to_regprocedure('league_private.active_viewer()') IS NULL OR to_regprocedure('league_private.flag_on(text)') IS NULL THEN
  RAISE EXCEPTION 'Voraussetzung fehlt: zuerst 20261028170000 und 20261028180000 anwenden';
 END IF;
END $$;

INSERT INTO public.league_feature_flags(feature_key,display_name,is_enabled)
VALUES ('gym_training','Training im Gym (Gruppen, Check-in, Präsenz, Wochenplan)',false)
ON CONFLICT(feature_key) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.training_groups(
 id smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 key text NOT NULL UNIQUE CHECK (key ~ '^[a-z][a-z0-9_]{1,30}$'),
 name text NOT NULL CHECK (char_length(name) BETWEEN 2 AND 40),
 weekly_target smallint NOT NULL CHECK (weekly_target BETWEEN 1 AND 14),
 sort_order smallint NOT NULL DEFAULT 0,
 description text
);
INSERT INTO public.training_groups(key,name,weekly_target,sort_order,description) VALUES
 ('newcomer','Newcomer',2,1,'Einstieg: Grundtechnik lernen und regelmässig kommen.'),
 ('fortgeschritten','Fortgeschrittene',3,2,'Technik festigen, Kombinationen, erstes Sparring.'),
 ('wettkampf','Wettkämpfer',5,3,'Wettkampfvorbereitung mit Sparring, Kraft und Ausdauer.')
ON CONFLICT(key) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.training_group_members(
 profile_id uuid PRIMARY KEY REFERENCES public.profiles(id),
 group_id smallint NOT NULL REFERENCES public.training_groups(id),
 updated_at timestamptz NOT NULL DEFAULT now(),
 updated_by uuid REFERENCES public.profiles(id)
);

CREATE TABLE IF NOT EXISTS public.gym_sessions(
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 session_date date NOT NULL,
 training_type_id bigint NOT NULL REFERENCES public.training_types(id),
 duration_minutes integer NOT NULL CHECK (duration_minutes BETWEEN 1 AND 1440),
 note text NOT NULL CHECK (char_length(btrim(note)) BETWEEN 3 AND 500),
 group_id smallint REFERENCES public.training_groups(id),
 opened_by uuid NOT NULL REFERENCES public.profiles(id),
 status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','confirmed','cancelled')),
 created_at timestamptz NOT NULL DEFAULT now(),
 confirmed_at timestamptz,
 confirmed_by uuid REFERENCES public.profiles(id)
);
CREATE INDEX IF NOT EXISTS gym_sessions_date_idx ON public.gym_sessions(session_date DESC, id DESC);

CREATE TABLE IF NOT EXISTS public.gym_attendance(
 session_id bigint NOT NULL REFERENCES public.gym_sessions(id),
 profile_id uuid NOT NULL REFERENCES public.profiles(id),
 source text NOT NULL CHECK (source IN ('coach','self')),
 checked_in_at timestamptz NOT NULL DEFAULT now(),
 submission_id uuid,
 skipped_reason text,
 PRIMARY KEY(session_id, profile_id)
);

CREATE TABLE IF NOT EXISTS public.training_plans(
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 group_id smallint NOT NULL REFERENCES public.training_groups(id),
 week_start date NOT NULL CHECK (extract(isodow FROM week_start)=1),
 focus text CHECK (focus IS NULL OR char_length(focus) BETWEEN 1 AND 200),
 items jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(items)='array'),
 published_at timestamptz,
 updated_at timestamptz NOT NULL DEFAULT now(),
 updated_by uuid REFERENCES public.profiles(id),
 UNIQUE(group_id, week_start)
);

ALTER TABLE public.training_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.training_group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gym_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gym_attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.training_plans ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.training_groups, public.training_group_members, public.gym_sessions, public.gym_attendance, public.training_plans
 FROM PUBLIC, anon, authenticated;

-- ---------- Hilfsfunktionen ----------
CREATE OR REPLACE FUNCTION league_private.zurich_today()
RETURNS date LANGUAGE sql STABLE SET search_path='' AS $fn$ SELECT (now() AT TIME ZONE 'Europe/Zurich')::date $fn$;

CREATE OR REPLACE FUNCTION league_private.week_monday(p date)
RETURNS date LANGUAGE sql IMMUTABLE SET search_path='' AS $fn$ SELECT p - (extract(isodow FROM p)::integer - 1) $fn$;

CREATE OR REPLACE FUNCTION league_private.require_staff()
RETURNS public.profiles LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles;
BEGIN
 me := league_private.active_viewer();
 IF me.id IS NULL OR me.role NOT IN ('admin','coach') THEN RAISE EXCEPTION 'Nur für aktive Trainer und Admins' USING ERRCODE='42501'; END IF;
 RETURN me;
END;
$fn$;

CREATE OR REPLACE FUNCTION league_private.group_of(p_profile uuid)
RETURNS public.training_groups LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT g.* FROM public.training_group_members m JOIN public.training_groups g ON g.id=m.group_id WHERE m.profile_id=p_profile
$fn$;

CREATE OR REPLACE FUNCTION league_private.group_json(g public.training_groups)
RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path='' AS $fn$
 SELECT CASE WHEN g.id IS NULL THEN NULL ELSE pg_catalog.jsonb_build_object('key',g.key,'name',g.name,'weekly_target',g.weekly_target,'description',g.description) END
$fn$;

-- Bestätigte Trainings je Tag (Datum = Trainingsdatum).
CREATE OR REPLACE FUNCTION league_private.approved_count(p_profile uuid, p_from date, p_to date)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT count(*)::integer FROM public.training_submissions s
 WHERE s.boxer_id=p_profile AND s.status='approved' AND s.training_date BETWEEN p_from AND p_to
$fn$;

CREATE OR REPLACE FUNCTION league_private.presence_weeks(p_profile uuid, p_weeks integer)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 WITH g AS (SELECT coalesce((league_private.group_of(p_profile)).weekly_target,2) AS target),
 w AS (SELECT league_private.week_monday(league_private.zurich_today()) - 7*i AS ws FROM pg_catalog.generate_series(0,p_weeks-1) i)
 SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('week_start',w.ws,
   'trainings',league_private.approved_count(p_profile,w.ws,w.ws+6),'target',g.target,
   'met',league_private.approved_count(p_profile,w.ws,w.ws+6)>=g.target,'current',w.ws=league_private.week_monday(league_private.zurich_today()))
   ORDER BY w.ws DESC) FROM w, g
$fn$;

CREATE OR REPLACE FUNCTION league_private.presence_streak(p_profile uuid)
RETURNS integer LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE target integer := coalesce((league_private.group_of(p_profile)).weekly_target,2); ws date; n integer := 0;
BEGIN
 ws := league_private.week_monday(league_private.zurich_today());
 -- laufende Woche zählt mit, sobald das Ziel erreicht ist; sonst ab der letzten abgeschlossenen Woche zählen
 IF league_private.approved_count(p_profile,ws,ws+6)>=target THEN n := 1; END IF;
 ws := ws-7;
 FOR i IN 1..104 LOOP
  EXIT WHEN league_private.approved_count(p_profile,ws,ws+6)<target;
  n := n+1; ws := ws-7;
 END LOOP;
 RETURN n;
END;
$fn$;

CREATE OR REPLACE FUNCTION league_private.plan_items_valid(p jsonb)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE it jsonb;
BEGIN
 IF p IS NULL OR pg_catalog.jsonb_typeof(p)<>'array' OR pg_catalog.jsonb_array_length(p)>40 THEN RETURN false; END IF;
 FOR it IN SELECT x FROM pg_catalog.jsonb_array_elements(p) x LOOP
  IF pg_catalog.jsonb_typeof(it)<>'object' OR pg_catalog.jsonb_typeof(it->'day')<>'number' OR pg_catalog.jsonb_typeof(it->'type_id')<>'number'
     OR pg_catalog.jsonb_typeof(it->'minutes')<>'number' THEN RETURN false; END IF;
  IF (it->>'day')::numeric NOT IN (0,1,2,3,4,5,6) OR (it->>'minutes')::numeric<>trunc((it->>'minutes')::numeric)
     OR (it->>'minutes')::integer NOT BETWEEN 5 AND 600 THEN RETURN false; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.training_types t WHERE t.id=(it->>'type_id')::bigint AND t.is_active) THEN RETURN false; END IF;
 END LOOP;
 RETURN true;
END;
$fn$;

REVOKE ALL ON FUNCTION league_private.zurich_today(), league_private.week_monday(date), league_private.require_staff(),
 league_private.group_of(uuid), league_private.group_json(public.training_groups), league_private.approved_count(uuid,date,date),
 league_private.presence_weeks(uuid,integer), league_private.presence_streak(uuid), league_private.plan_items_valid(jsonb)
 FROM PUBLIC, anon, authenticated;

-- ---------- Gruppen ----------
CREATE OR REPLACE FUNCTION public.list_training_groups()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles;
BEGIN
 me := league_private.active_viewer();
 IF me.id IS NULL THEN RAISE EXCEPTION 'Bitte anmelden' USING ERRCODE='42501'; END IF;
 RETURN coalesce((SELECT pg_catalog.jsonb_agg(league_private.group_json(g) || pg_catalog.jsonb_build_object('members',
   (SELECT count(*) FROM public.training_group_members m JOIN public.profiles p ON p.id=m.profile_id
    WHERE m.group_id=g.id AND p.is_active AND p.archived_at IS NULL)) ORDER BY g.sort_order) FROM public.training_groups g),'[]'::jsonb);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.staff_list_group_members()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.require_staff();
BEGIN
 RETURN coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id',p.id,'display_name',p.display_name,'role',p.role,
   'group',(SELECT g.key FROM public.training_group_members m JOIN public.training_groups g ON g.id=m.group_id WHERE m.profile_id=p.id))
   ORDER BY pg_catalog.lower(p.display_name))
  FROM public.profiles p WHERE p.is_active AND p.archived_at IS NULL AND p.role IN ('boxer','coach')),'[]'::jsonb);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.staff_set_training_group(p_profile_id uuid, p_group_key text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.require_staff(); t public.profiles; g public.training_groups;
BEGIN
 SELECT * INTO t FROM public.profiles p WHERE p.id=p_profile_id FOR UPDATE;
 IF NOT FOUND OR t.role NOT IN ('boxer','coach') OR NOT t.is_active OR t.archived_at IS NOT NULL THEN
  RAISE EXCEPTION 'Bitte einen aktiven Boxer wählen' USING ERRCODE='22023';
 END IF;
 IF p_group_key IS NULL OR pg_catalog.btrim(p_group_key)='' THEN
  DELETE FROM public.training_group_members m WHERE m.profile_id=t.id;
  RETURN pg_catalog.jsonb_build_object('profile',t.display_name,'group',NULL);
 END IF;
 SELECT * INTO g FROM public.training_groups x WHERE x.key=p_group_key;
 IF NOT FOUND THEN RAISE EXCEPTION 'Unbekannte Trainingsgruppe' USING ERRCODE='22023'; END IF;
 INSERT INTO public.training_group_members(profile_id,group_id,updated_at,updated_by) VALUES (t.id,g.id,now(),me.id)
 ON CONFLICT(profile_id) DO UPDATE SET group_id=EXCLUDED.group_id, updated_at=now(), updated_by=me.id;
 RETURN pg_catalog.jsonb_build_object('profile',t.display_name,'group',g.key);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.admin_set_group_target(p_group_key text, p_weekly_target integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); g public.training_groups;
BEGIN
 IF me.id IS NULL OR me.role<>'admin' THEN RAISE EXCEPTION 'Nur der Admin ändert Wochenziele' USING ERRCODE='42501'; END IF;
 IF p_weekly_target IS NULL OR p_weekly_target NOT BETWEEN 1 AND 14 THEN RAISE EXCEPTION 'Wochenziel zwischen 1 und 14 Trainings' USING ERRCODE='22023'; END IF;
 UPDATE public.training_groups x SET weekly_target=p_weekly_target WHERE x.key=p_group_key RETURNING * INTO g;
 IF g.id IS NULL THEN RAISE EXCEPTION 'Unbekannte Trainingsgruppe' USING ERRCODE='22023'; END IF;
 RETURN league_private.group_json(g);
END;
$fn$;

-- ---------- Gym-Check-in ----------
CREATE OR REPLACE FUNCTION public.staff_open_gym_session(p_training_type_id bigint, p_duration_minutes integer, p_note text, p_group_key text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.require_staff(); t public.training_types; g public.training_groups; new_id bigint; note text;
BEGIN
 SELECT * INTO t FROM public.training_types x WHERE x.id=p_training_type_id AND x.is_active;
 IF NOT FOUND THEN RAISE EXCEPTION 'Bitte eine gültige Trainingsart wählen' USING ERRCODE='22023'; END IF;
 IF t.name='Joggen' THEN RAISE EXCEPTION 'Joggen bitte einzeln mit Distanz eintragen, nicht über den Gym-Check-in' USING ERRCODE='22023'; END IF;
 IF p_duration_minutes IS NULL OR p_duration_minutes NOT BETWEEN 1 AND 1440 THEN RAISE EXCEPTION 'Bitte die Dauer in Minuten angeben' USING ERRCODE='22023'; END IF;
 note := pg_catalog.btrim(coalesce(p_note,''));
 IF pg_catalog.char_length(note)<3 OR pg_catalog.char_length(note)>500 THEN RAISE EXCEPTION 'Bitte eine Bemerkung für alle angeben (mindestens 3 Zeichen)' USING ERRCODE='22023'; END IF;
 IF p_group_key IS NOT NULL AND p_group_key<>'' THEN
  SELECT * INTO g FROM public.training_groups x WHERE x.key=p_group_key;
  IF NOT FOUND THEN RAISE EXCEPTION 'Unbekannte Trainingsgruppe' USING ERRCODE='22023'; END IF;
 END IF;
 INSERT INTO public.gym_sessions(session_date,training_type_id,duration_minutes,note,group_id,opened_by)
 VALUES (league_private.zurich_today(),t.id,p_duration_minutes,note,g.id,me.id) RETURNING id INTO new_id;
 RETURN pg_catalog.jsonb_build_object('id',new_id,'session_date',league_private.zurich_today());
END;
$fn$;

CREATE OR REPLACE FUNCTION public.staff_list_gym_sessions(p_days integer DEFAULT 14)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.require_staff();
BEGIN
 RETURN coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id',s.id,'session_date',s.session_date,'status',s.status,
   'training_type',t.name,'training_type_id',s.training_type_id,'duration_minutes',s.duration_minutes,'note',s.note,
   'group',(SELECT g.key FROM public.training_groups g WHERE g.id=s.group_id),
   'opened_by',(SELECT p.display_name FROM public.profiles p WHERE p.id=s.opened_by),
   'present',(SELECT count(*) FROM public.gym_attendance a WHERE a.session_id=s.id),
   'confirmed',(SELECT count(*) FROM public.gym_attendance a WHERE a.session_id=s.id AND a.submission_id IS NOT NULL))
   ORDER BY s.session_date DESC, s.id DESC)
  FROM public.gym_sessions s JOIN public.training_types t ON t.id=s.training_type_id
  WHERE s.session_date >= league_private.zurich_today() - LEAST(GREATEST(coalesce(p_days,14),1),120)),'[]'::jsonb);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.staff_get_gym_session(p_session_id bigint)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.require_staff(); s public.gym_sessions;
BEGIN
 SELECT * INTO s FROM public.gym_sessions x WHERE x.id=p_session_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Einheit nicht gefunden' USING ERRCODE='22023'; END IF;
 RETURN pg_catalog.jsonb_build_object('id',s.id,'session_date',s.session_date,'status',s.status,'duration_minutes',s.duration_minutes,'note',s.note,
  'training_type',(SELECT t.name FROM public.training_types t WHERE t.id=s.training_type_id),
  'group',(SELECT g.key FROM public.training_groups g WHERE g.id=s.group_id),
  'people',coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id',p.id,'display_name',p.display_name,'is_self',p.id=me.id,
     'group',(SELECT g.key FROM public.training_group_members m JOIN public.training_groups g ON g.id=m.group_id WHERE m.profile_id=p.id),
     'present',a.profile_id IS NOT NULL,'source',a.source,'confirmed',a.submission_id IS NOT NULL,'skipped_reason',a.skipped_reason)
     ORDER BY pg_catalog.lower(p.display_name))
    FROM public.profiles p LEFT JOIN public.gym_attendance a ON a.session_id=s.id AND a.profile_id=p.id
    WHERE (p.is_active AND p.archived_at IS NULL AND p.role IN ('boxer','coach')) OR a.profile_id IS NOT NULL),'[]'::jsonb));
END;
$fn$;

CREATE OR REPLACE FUNCTION public.staff_set_gym_attendance(p_session_id bigint, p_profile_id uuid, p_present boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.require_staff(); s public.gym_sessions; t public.profiles;
BEGIN
 SELECT * INTO s FROM public.gym_sessions x WHERE x.id=p_session_id FOR UPDATE;
 IF NOT FOUND OR s.status<>'open' THEN RAISE EXCEPTION 'Diese Einheit ist schon abgeschlossen' USING ERRCODE='55000'; END IF;
 SELECT * INTO t FROM public.profiles p WHERE p.id=p_profile_id;
 IF NOT FOUND OR t.role NOT IN ('boxer','coach') OR NOT t.is_active OR t.archived_at IS NOT NULL THEN
  RAISE EXCEPTION 'Bitte einen aktiven Boxer wählen' USING ERRCODE='22023';
 END IF;
 IF p_present THEN
  INSERT INTO public.gym_attendance(session_id,profile_id,source) VALUES (s.id,t.id,'coach') ON CONFLICT DO NOTHING;
 ELSE
  DELETE FROM public.gym_attendance a WHERE a.session_id=s.id AND a.profile_id=t.id;
 END IF;
 RETURN pg_catalog.jsonb_build_object('present',coalesce(p_present,false),
  'count',(SELECT count(*) FROM public.gym_attendance a WHERE a.session_id=s.id));
END;
$fn$;

CREATE OR REPLACE FUNCTION public.staff_cancel_gym_session(p_session_id bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.require_staff(); s public.gym_sessions;
BEGIN
 SELECT * INTO s FROM public.gym_sessions x WHERE x.id=p_session_id FOR UPDATE;
 IF NOT FOUND OR s.status<>'open' THEN RAISE EXCEPTION 'Nur offene Einheiten können abgebrochen werden' USING ERRCODE='55000'; END IF;
 UPDATE public.gym_sessions x SET status='cancelled' WHERE x.id=s.id;
 RETURN pg_catalog.jsonb_build_object('id',s.id,'status','cancelled');
END;
$fn$;

-- Alle Anwesenden bestätigen: jedes Training über public.staff_record_training (sofort bestätigt, Punkte/EXP wie bisher).
CREATE OR REPLACE FUNCTION public.staff_confirm_gym_session(p_session_id bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.require_staff(); s public.gym_sessions; a record; r jsonb;
 n integer := 0; pts integer := 0; skipped jsonb := '[]'::jsonb; reason text;
BEGIN
 SELECT * INTO s FROM public.gym_sessions x WHERE x.id=p_session_id FOR UPDATE;
 IF NOT FOUND OR s.status<>'open' THEN RAISE EXCEPTION 'Diese Einheit ist schon abgeschlossen' USING ERRCODE='55000'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.gym_attendance x WHERE x.session_id=s.id) THEN RAISE EXCEPTION 'Noch niemand als anwesend markiert' USING ERRCODE='22023'; END IF;
 FOR a IN SELECT x.profile_id, p.display_name, p.role, p.is_active, p.archived_at FROM public.gym_attendance x JOIN public.profiles p ON p.id=x.profile_id
          WHERE x.session_id=s.id AND x.submission_id IS NULL ORDER BY pg_catalog.lower(p.display_name) LOOP
  reason := NULL;
  IF a.profile_id=me.id THEN reason := 'eigenes Training – bitte normal einreichen';
  ELSIF a.role NOT IN ('boxer','coach') OR NOT a.is_active OR a.archived_at IS NOT NULL THEN reason := 'Profil nicht aktiv';
  ELSIF EXISTS (SELECT 1 FROM public.training_submissions t WHERE t.boxer_id=a.profile_id AND t.training_date=s.session_date
                AND t.training_type_id=s.training_type_id AND t.status IN ('pending','approved')) THEN reason := 'hat dieses Training schon eingereicht';
  END IF;
  IF reason IS NOT NULL THEN
   UPDATE public.gym_attendance x SET skipped_reason=reason WHERE x.session_id=s.id AND x.profile_id=a.profile_id;
   skipped := skipped || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object('name',a.display_name,'reason',reason));
   CONTINUE;
  END IF;
  r := public.staff_record_training(a.profile_id, s.training_type_id, s.session_date, s.duration_minutes, s.note, NULL,
        pg_catalog.md5('gym:'||s.id::text||':'||a.profile_id::text)::uuid);
  UPDATE public.gym_attendance x SET submission_id=(r->>'submission_id')::uuid, skipped_reason=NULL WHERE x.session_id=s.id AND x.profile_id=a.profile_id;
  n := n+1; pts := pts+coalesce((r->>'points_awarded')::integer,0);
 END LOOP;
 UPDATE public.gym_sessions x SET status='confirmed', confirmed_at=now(), confirmed_by=me.id WHERE x.id=s.id;
 RETURN pg_catalog.jsonb_build_object('confirmed',n,'points_awarded',pts,'skipped',skipped);
END;
$fn$;

-- Boxer: offene Einheiten von heute und selbst einchecken.
CREATE OR REPLACE FUNCTION public.my_gym_sessions_today()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer();
BEGIN
 IF me.id IS NULL THEN RAISE EXCEPTION 'Bitte anmelden' USING ERRCODE='42501'; END IF;
 IF NOT league_private.flag_on('gym_training') AND me.role NOT IN ('admin','coach') THEN RETURN '[]'::jsonb; END IF;
 RETURN coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id',s.id,'training_type',t.name,'duration_minutes',s.duration_minutes,
   'note',s.note,'group',(SELECT g.name FROM public.training_groups g WHERE g.id=s.group_id),
   'checked_in',EXISTS (SELECT 1 FROM public.gym_attendance a WHERE a.session_id=s.id AND a.profile_id=me.id)) ORDER BY s.id)
  FROM public.gym_sessions s JOIN public.training_types t ON t.id=s.training_type_id
  WHERE s.status='open' AND s.session_date=league_private.zurich_today()),'[]'::jsonb);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.gym_check_in(p_session_id bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); s public.gym_sessions;
BEGIN
 IF me.id IS NULL OR me.role NOT IN ('boxer','coach') THEN RAISE EXCEPTION 'Einchecken können Boxer mit ihrem eigenen Konto' USING ERRCODE='42501'; END IF;
 IF NOT league_private.flag_on('gym_training') THEN RAISE EXCEPTION 'Der Gym-Check-in ist noch nicht freigeschaltet' USING ERRCODE='42501'; END IF;
 SELECT * INTO s FROM public.gym_sessions x WHERE x.id=p_session_id;
 IF NOT FOUND OR s.status<>'open' OR s.session_date<>league_private.zurich_today() THEN
  RAISE EXCEPTION 'Für diese Einheit kannst du dich nicht mehr einchecken' USING ERRCODE='55000';
 END IF;
 INSERT INTO public.gym_attendance(session_id,profile_id,source) VALUES (s.id,me.id,'self') ON CONFLICT DO NOTHING;
 RETURN pg_catalog.jsonb_build_object('checked_in',true,'session_id',s.id);
END;
$fn$;

-- ---------- Präsenz ----------
CREATE OR REPLACE FUNCTION public.get_my_presence()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); today date := league_private.zurich_today(); from_d date;
BEGIN
 IF me.id IS NULL THEN RAISE EXCEPTION 'Bitte anmelden' USING ERRCODE='42501'; END IF;
 IF NOT league_private.flag_on('gym_training') AND me.role<>'admin' THEN RETURN pg_catalog.jsonb_build_object('enabled',false); END IF;
 from_d := league_private.week_monday(today) - 21;
 RETURN pg_catalog.jsonb_build_object('enabled',true,'today',today,
  'group',league_private.group_json(league_private.group_of(me.id)),
  'days',(SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('date',d::date,
     'trainings',(SELECT count(*) FROM public.training_submissions s WHERE s.boxer_id=me.id AND s.status='approved' AND s.training_date=d::date),
     'pending',(SELECT count(*) FROM public.training_submissions s WHERE s.boxer_id=me.id AND s.status='pending' AND s.training_date=d::date),
     'gym',EXISTS (SELECT 1 FROM public.gym_attendance a JOIN public.gym_sessions g ON g.id=a.session_id
                   WHERE a.profile_id=me.id AND g.session_date=d::date AND g.status<>'cancelled')) ORDER BY d)
     FROM pg_catalog.generate_series(from_d::timestamp, (from_d+27)::timestamp, interval '1 day') d),
  'weeks',league_private.presence_weeks(me.id,4),
  'streak_weeks',league_private.presence_streak(me.id));
END;
$fn$;

CREATE OR REPLACE FUNCTION public.staff_presence_overview()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.require_staff();
BEGIN
 RETURN coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id',p.id,'display_name',p.display_name,
   'group',league_private.group_json(league_private.group_of(p.id)),
   'weeks',league_private.presence_weeks(p.id,4),'streak_weeks',league_private.presence_streak(p.id),
   'last_training',(SELECT max(s.training_date) FROM public.training_submissions s WHERE s.boxer_id=p.id AND s.status='approved'))
   ORDER BY pg_catalog.lower(p.display_name))
  FROM public.profiles p WHERE p.is_active AND p.archived_at IS NULL AND p.role IN ('boxer','coach')),'[]'::jsonb);
END;
$fn$;

-- ---------- Wochenplan ----------
CREATE OR REPLACE FUNCTION public.staff_get_training_plan(p_group_key text, p_week_start date)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.require_staff(); g public.training_groups; pl public.training_plans;
BEGIN
 SELECT * INTO g FROM public.training_groups x WHERE x.key=p_group_key;
 IF NOT FOUND THEN RAISE EXCEPTION 'Unbekannte Trainingsgruppe' USING ERRCODE='22023'; END IF;
 SELECT * INTO pl FROM public.training_plans x WHERE x.group_id=g.id AND x.week_start=league_private.week_monday(p_week_start);
 RETURN pg_catalog.jsonb_build_object('group',league_private.group_json(g),'week_start',league_private.week_monday(p_week_start),
  'plan',CASE WHEN pl.id IS NULL THEN NULL ELSE pg_catalog.jsonb_build_object('focus',pl.focus,'items',pl.items,'published_at',pl.published_at,
   'updated_at',pl.updated_at,'updated_by',(SELECT p.display_name FROM public.profiles p WHERE p.id=pl.updated_by)) END);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.staff_save_training_plan(p_group_key text, p_week_start date, p_focus text, p_items jsonb, p_publish boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.require_staff(); g public.training_groups; ws date; focus text;
BEGIN
 SELECT * INTO g FROM public.training_groups x WHERE x.key=p_group_key;
 IF NOT FOUND THEN RAISE EXCEPTION 'Unbekannte Trainingsgruppe' USING ERRCODE='22023'; END IF;
 IF p_week_start IS NULL THEN RAISE EXCEPTION 'Bitte eine Woche wählen' USING ERRCODE='22023'; END IF;
 ws := league_private.week_monday(p_week_start);
 IF ws < league_private.week_monday(league_private.zurich_today()) - 7 THEN RAISE EXCEPTION 'Vergangene Wochen können nicht mehr geändert werden' USING ERRCODE='22023'; END IF;
 IF NOT league_private.plan_items_valid(p_items) THEN RAISE EXCEPTION 'Bitte nur gültige Einheiten (Tag, aktive Trainingsart, 5–600 Minuten, höchstens 40)' USING ERRCODE='22023'; END IF;
 focus := NULLIF(pg_catalog.btrim(coalesce(p_focus,'')),'');
 IF focus IS NOT NULL AND pg_catalog.char_length(focus)>200 THEN RAISE EXCEPTION 'Der Fokus darf höchstens 200 Zeichen haben' USING ERRCODE='22023'; END IF;
 INSERT INTO public.training_plans(group_id,week_start,focus,items,published_at,updated_at,updated_by)
 VALUES (g.id,ws,focus,p_items,CASE WHEN p_publish THEN now() END,now(),me.id)
 ON CONFLICT(group_id,week_start) DO UPDATE SET focus=EXCLUDED.focus, items=EXCLUDED.items,
  published_at=CASE WHEN p_publish THEN now() ELSE NULL END, updated_at=now(), updated_by=me.id;
 RETURN pg_catalog.jsonb_build_object('group',g.key,'week_start',ws,'published',coalesce(p_publish,false),'items',pg_catalog.jsonb_array_length(p_items));
END;
$fn$;

CREATE OR REPLACE FUNCTION public.get_my_week_plan(p_week_start date DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.active_viewer(); g public.training_groups; pl public.training_plans; ws date; today date := league_private.zurich_today();
BEGIN
 IF me.id IS NULL THEN RAISE EXCEPTION 'Bitte anmelden' USING ERRCODE='42501'; END IF;
 IF NOT league_private.flag_on('gym_training') AND me.role<>'admin' THEN RETURN pg_catalog.jsonb_build_object('enabled',false); END IF;
 ws := league_private.week_monday(coalesce(p_week_start,today));
 g := league_private.group_of(me.id);
 IF g.id IS NOT NULL THEN
  SELECT * INTO pl FROM public.training_plans x WHERE x.group_id=g.id AND x.week_start=ws AND x.published_at IS NOT NULL;
 END IF;
 RETURN pg_catalog.jsonb_build_object('enabled',true,'today',today,'week_start',ws,'group',league_private.group_json(g),
  'trainings',league_private.approved_count(me.id,ws,ws+6),
  'plan',CASE WHEN pl.id IS NULL THEN NULL ELSE pg_catalog.jsonb_build_object('focus',pl.focus,'published_at',pl.published_at,
   'updated_by',(SELECT p.display_name FROM public.profiles p WHERE p.id=pl.updated_by),
   'items',coalesce((SELECT pg_catalog.jsonb_agg(it || pg_catalog.jsonb_build_object(
      'date',ws+(it->>'day')::integer,
      'training_type',(SELECT t.name FROM public.training_types t WHERE t.id=(it->>'type_id')::bigint),
      'status',CASE
        WHEN EXISTS (SELECT 1 FROM public.training_submissions s WHERE s.boxer_id=me.id AND s.status='approved'
                     AND s.training_type_id=(it->>'type_id')::bigint AND s.training_date=ws+(it->>'day')::integer) THEN 'done'
        WHEN EXISTS (SELECT 1 FROM public.training_submissions s WHERE s.boxer_id=me.id AND s.status='pending'
                     AND s.training_type_id=(it->>'type_id')::bigint AND s.training_date=ws+(it->>'day')::integer) THEN 'pending'
        WHEN ws+(it->>'day')::integer < today THEN 'missed'
        WHEN ws+(it->>'day')::integer = today THEN 'today'
        ELSE 'open' END) ORDER BY (it->>'day')::integer, ord)
     FROM pg_catalog.jsonb_array_elements(pl.items) WITH ORDINALITY e(it,ord)),'[]'::jsonb)) END);
END;
$fn$;

REVOKE ALL ON FUNCTION public.list_training_groups(), public.staff_list_group_members(), public.staff_set_training_group(uuid,text),
 public.admin_set_group_target(text,integer), public.staff_open_gym_session(bigint,integer,text,text), public.staff_list_gym_sessions(integer),
 public.staff_get_gym_session(bigint), public.staff_set_gym_attendance(bigint,uuid,boolean), public.staff_cancel_gym_session(bigint),
 public.staff_confirm_gym_session(bigint), public.my_gym_sessions_today(), public.gym_check_in(bigint), public.get_my_presence(),
 public.staff_presence_overview(), public.staff_get_training_plan(text,date), public.staff_save_training_plan(text,date,text,jsonb,boolean),
 public.get_my_week_plan(date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_training_groups(), public.staff_list_group_members(), public.staff_set_training_group(uuid,text),
 public.admin_set_group_target(text,integer), public.staff_open_gym_session(bigint,integer,text,text), public.staff_list_gym_sessions(integer),
 public.staff_get_gym_session(bigint), public.staff_set_gym_attendance(bigint,uuid,boolean), public.staff_cancel_gym_session(bigint),
 public.staff_confirm_gym_session(bigint), public.my_gym_sessions_today(), public.gym_check_in(bigint), public.get_my_presence(),
 public.staff_presence_overview(), public.staff_get_training_plan(text,date), public.staff_save_training_plan(text,date,text,jsonb,boolean),
 public.get_my_week_plan(date) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
