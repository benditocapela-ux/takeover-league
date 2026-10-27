-- Etappe 1 (27.10.2026, Owner-Auftrag): Coach-Bewertung als Spielerkarte und Boxstil-Test.
--  * public.boxer_ratings: Bewertungen der Trainer, append-only (jede Bewertung ist ein neuer Eintrag,
--    dadurch sieht der Boxer, was seit der letzten Bewertung rauf/runter ging und seit wann).
--    25 Einzelnoten von 1 bis 10 in sechs Bereichen (Offense, Defense, Beinarbeit, Kondition, Taktik, Mentalität).
--  * public.style_tests / public.style_test_unlocks: Boxstil-Test (8 Fragen) einmal pro Kalendermonat
--    (Europe/Zurich). Trainer und Admins können ihn früher wieder freigeben. Die Auswertung rechnet der Server.
--  * Zugriff nur über RPCs (Tabellen ohne direkte Rechte, RLS aktiv):
--    - Boxer sehen ihre eigene Bewertung vollständig (Noten, Kommentar, Verlauf).
--    - Andere angemeldete Liga-Mitglieder sehen nur die Karte (Gesamt, Bereiche, je 3 Stärken/Schwächen)
--      und den Boxstil – nur bei sichtbaren Profilen (is_listed). Gäste sehen nichts davon.
--    - Nur aktive Trainer/Admins bewerten und geben frei; niemand bewertet sich selbst.
--  * Neue Feature-Flags coach_ratings und style_test, beide AUS. Admins können vorab testen,
--    Trainer können schon bewerten; Boxer sehen die Bereiche erst nach dem Einschalten.
-- Bestehende Daten (Punkte, EXP, Trainings, Profile) bleiben unverändert.
-- Produktion nur über den regulären Migrationsweg und eine separate ausdrückliche FREIGABE.
BEGIN;

CREATE SCHEMA IF NOT EXISTS league_private;

INSERT INTO public.league_feature_flags(feature_key,display_name,is_enabled)
VALUES ('coach_ratings','Coach-Bewertung (Spielerkarte)',false),
       ('style_test','Boxstil-Test',false)
ON CONFLICT(feature_key) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.boxer_ratings(
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 boxer_id uuid NOT NULL REFERENCES public.profiles(id),
 rated_by uuid NOT NULL REFERENCES public.profiles(id),
 scores jsonb NOT NULL CHECK (jsonb_typeof(scores)='object'),
 note text CHECK (note IS NULL OR char_length(note) BETWEEN 1 AND 600),
 created_at timestamptz NOT NULL DEFAULT now(),
 CHECK (boxer_id<>rated_by)
);
CREATE INDEX IF NOT EXISTS boxer_ratings_boxer_idx ON public.boxer_ratings(boxer_id, created_at DESC, id DESC);

CREATE TABLE IF NOT EXISTS public.style_tests(
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 boxer_id uuid NOT NULL REFERENCES public.profiles(id),
 answers smallint[] NOT NULL CHECK (cardinality(answers)=8 AND 0<=ALL(answers) AND 2>=ALL(answers)),
 scores jsonb NOT NULL CHECK (jsonb_typeof(scores)='object'),
 version text NOT NULL DEFAULT 'v1',
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS style_tests_boxer_idx ON public.style_tests(boxer_id, created_at DESC, id DESC);

CREATE TABLE IF NOT EXISTS public.style_test_unlocks(
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 boxer_id uuid NOT NULL REFERENCES public.profiles(id),
 unlocked_by uuid NOT NULL REFERENCES public.profiles(id),
 created_at timestamptz NOT NULL DEFAULT now(),
 used_at timestamptz,
 used_test_id bigint REFERENCES public.style_tests(id)
);
CREATE UNIQUE INDEX IF NOT EXISTS style_test_unlocks_one_open ON public.style_test_unlocks(boxer_id) WHERE used_at IS NULL;

ALTER TABLE public.boxer_ratings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.style_tests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.style_test_unlocks ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.boxer_ratings, public.style_tests, public.style_test_unlocks FROM PUBLIC, anon, authenticated;

-- ---------- Hilfsfunktionen (privat) ----------
CREATE OR REPLACE FUNCTION league_private.flag_on(p_key text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT EXISTS (SELECT 1 FROM public.league_feature_flags f WHERE f.feature_key=p_key AND f.is_enabled IS TRUE)
$fn$;

CREATE OR REPLACE FUNCTION league_private.rating_categories()
RETURNS TABLE(cat text, weight integer, keys text[]) LANGUAGE sql IMMUTABLE SET search_path='' AS $fn$
 VALUES ('OFF',25,ARRAY['jab','cross','hook','upper','body','combo']),
        ('DEF',25,ARRAY['guard','block','slip','roll','parry','counter']),
        ('BEI',20,ARRAY['stance','steps','angles','ring']),
        ('KON',10,ARRAY['endur','pace','recov']),
        ('TAK',10,ARRAY['timing','dist','plan']),
        ('MEN',10,ARRAY['focus','heart','coach'])
$fn$;

CREATE OR REPLACE FUNCTION league_private.rating_scores_valid(p jsonb)
RETURNS boolean LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $fn$
DECLARE k text; expected text[]; v jsonb;
BEGIN
 IF p IS NULL OR pg_catalog.jsonb_typeof(p)<>'object' THEN RETURN false; END IF;
 SELECT pg_catalog.array_agg(x ORDER BY x) INTO expected FROM league_private.rating_categories() c, LATERAL pg_catalog.unnest(c.keys) x;
 IF (SELECT pg_catalog.array_agg(x ORDER BY x) FROM pg_catalog.jsonb_object_keys(p) x) IS DISTINCT FROM expected THEN RETURN false; END IF;
 FOREACH k IN ARRAY expected LOOP
  v := p->k;
  IF pg_catalog.jsonb_typeof(v)<>'number' OR (v#>>'{}')::numeric NOT IN (1,2,3,4,5,6,7,8,9,10) THEN RETURN false; END IF;
 END LOOP;
 RETURN true;
END;
$fn$;

-- Karte: Bereiche = Durchschnitt × 10 (max. 99), Gesamt = gewichteter Schnitt der Bereiche (max. 99),
-- dazu die drei besten und drei schwächsten Einzelnoten (bei Gleichstand gilt die feste Reihenfolge).
CREATE OR REPLACE FUNCTION league_private.rating_summary(p jsonb)
RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path='' AS $fn$
 WITH c AS (
  SELECT c.cat, c.weight, LEAST(99, round(pg_catalog.avg((p->>k)::numeric)*10))::integer AS v
  FROM league_private.rating_categories() c, LATERAL pg_catalog.unnest(c.keys) k GROUP BY c.cat, c.weight
 ), s AS (
  SELECT k, (p->>k)::integer AS v, c.co*100+k.ko AS ord
  FROM league_private.rating_categories() WITH ORDINALITY c(cat,weight,keys,co), LATERAL pg_catalog.unnest(c.keys) WITH ORDINALITY k(k,ko)
 )
 SELECT pg_catalog.jsonb_build_object(
  'categories',(SELECT pg_catalog.jsonb_object_agg(cat,v) FROM c),
  'overall',(SELECT LEAST(99, round(pg_catalog.sum(v*weight)/100.0))::integer FROM c),
  'top',(SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('k',k,'v',v) ORDER BY v DESC, ord) FROM (SELECT * FROM s ORDER BY v DESC, ord LIMIT 3) t),
  'low',(SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('k',k,'v',v) ORDER BY v, ord) FROM (SELECT * FROM s ORDER BY v, ord LIMIT 3) t))
$fn$;

-- Boxstil: Gewichte je Frage und Antwort (A/B/C) für die Achsen
-- o Distanz, v Schlagzahl, c Konter, p Druck, s Präzision, a Angriff. Ergebnis je Achse 0–100.
CREATE OR REPLACE FUNCTION league_private.style_weights()
RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path='' AS $fn$
 SELECT '[[{"v":2,"a":1},{"c":1,"o":1},{"s":2}],
          [{"p":2,"a":1},{"v":1,"o":1},{"o":2,"c":1}],
          [{"a":2,"p":1},{"v":1,"c":1},{"c":2,"s":1}],
          [{"p":2,"v":1},{"o":2},{"c":2,"s":1}],
          [{"p":2,"v":1},{"a":1,"c":1},{"o":2,"s":1}],
          [{"p":1,"v":1,"a":1},{"o":1,"c":1},{"c":2,"s":1}],
          [{"s":2,"c":1},{"a":1,"p":1},{"v":2,"p":1}],
          [{"o":2,"c":1},{"v":2,"p":1},{"s":2,"a":1}]]'::jsonb
$fn$;

CREATE OR REPLACE FUNCTION league_private.style_scores(p smallint[])
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $fn$
DECLARE w jsonb := league_private.style_weights(); ax text; total integer; mx integer; i integer; res jsonb := '{}'::jsonb;
BEGIN
 IF p IS NULL OR pg_catalog.cardinality(p)<>8 OR NOT (0<=ALL(p) AND 2>=ALL(p)) THEN
  RAISE EXCEPTION 'Bitte alle 8 Fragen beantworten' USING ERRCODE='22023';
 END IF;
 FOREACH ax IN ARRAY ARRAY['o','v','c','p','s','a'] LOOP
  total := 0; mx := 0;
  FOR i IN 0..7 LOOP
   total := total + coalesce((w->i->p[i+1]->>ax)::integer,0);
   mx := mx + GREATEST(coalesce((w->i->0->>ax)::integer,0),coalesce((w->i->1->>ax)::integer,0),coalesce((w->i->2->>ax)::integer,0));
  END LOOP;
  res := res || pg_catalog.jsonb_build_object(ax, round(total*100.0/mx)::integer);
 END LOOP;
 RETURN res;
END;
$fn$;

CREATE OR REPLACE FUNCTION league_private.month_start(p timestamptz)
RETURNS date LANGUAGE sql STABLE SET search_path='' AS $fn$
 SELECT pg_catalog.date_trunc('month',(p AT TIME ZONE 'Europe/Zurich'))::date
$fn$;

-- Gesperrt, wenn diesen Monat schon ein Test existiert und keine offene Freigabe vorliegt.
CREATE OR REPLACE FUNCTION league_private.style_state(p_boxer uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 WITH last AS (SELECT t.created_at FROM public.style_tests t WHERE t.boxer_id=p_boxer ORDER BY t.created_at DESC, t.id DESC LIMIT 1),
 st AS (SELECT
   EXISTS (SELECT 1 FROM last WHERE league_private.month_start(last.created_at)=league_private.month_start(now())) AS done_this_month,
   EXISTS (SELECT 1 FROM public.style_test_unlocks u WHERE u.boxer_id=p_boxer AND u.used_at IS NULL) AS unlocked,
   (SELECT created_at FROM last) AS last_at)
 SELECT pg_catalog.jsonb_build_object('last_at',last_at,'unlocked',unlocked,
  'locked',done_this_month AND NOT unlocked,'can_take',NOT done_this_month OR unlocked,
  'next_allowed_on',(league_private.month_start(now()) + interval '1 month')::date) FROM st
$fn$;

CREATE OR REPLACE FUNCTION league_private.active_viewer()
RETURNS public.profiles LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT p.* FROM public.profiles p WHERE p.auth_user_id=(SELECT auth.uid()) AND p.is_active AND p.archived_at IS NULL LIMIT 1
$fn$;

CREATE OR REPLACE FUNCTION league_private.rating_row(p_boxer uuid, p_offset integer)
RETURNS public.boxer_ratings LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT r.* FROM public.boxer_ratings r WHERE r.boxer_id=p_boxer ORDER BY r.created_at DESC, r.id DESC OFFSET p_offset LIMIT 1
$fn$;

CREATE OR REPLACE FUNCTION league_private.rating_full(p_boxer uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE cur public.boxer_ratings; prev public.boxer_ratings;
BEGIN
 cur := league_private.rating_row(p_boxer,0);
 IF cur.id IS NULL THEN RETURN NULL; END IF;
 prev := league_private.rating_row(p_boxer,1);
 RETURN pg_catalog.jsonb_build_object(
  'current',pg_catalog.jsonb_build_object('scores',cur.scores,'summary',league_private.rating_summary(cur.scores),
     'created_at',cur.created_at,'note',cur.note,
     'rated_by',(SELECT p.display_name FROM public.profiles p WHERE p.id=cur.rated_by)),
  'previous',CASE WHEN prev.id IS NULL THEN NULL ELSE pg_catalog.jsonb_build_object('scores',prev.scores,
     'summary',league_private.rating_summary(prev.scores),'created_at',prev.created_at) END);
END;
$fn$;

CREATE OR REPLACE FUNCTION league_private.style_pair(p_boxer uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT pg_catalog.jsonb_build_object(
  'current',(SELECT pg_catalog.jsonb_build_object('scores',t.scores,'created_at',t.created_at) FROM public.style_tests t
             WHERE t.boxer_id=p_boxer ORDER BY t.created_at DESC, t.id DESC LIMIT 1),
  'previous',(SELECT pg_catalog.jsonb_build_object('scores',t.scores,'created_at',t.created_at) FROM public.style_tests t
             WHERE t.boxer_id=p_boxer ORDER BY t.created_at DESC, t.id DESC OFFSET 1 LIMIT 1))
$fn$;

-- Nur die neuen Hilfsfunktionen sperren (bestehende Funktionen in league_private bleiben unverändert).
REVOKE ALL ON FUNCTION league_private.flag_on(text), league_private.rating_categories(), league_private.rating_scores_valid(jsonb),
 league_private.rating_summary(jsonb), league_private.style_weights(), league_private.style_scores(smallint[]),
 league_private.month_start(timestamptz), league_private.style_state(uuid), league_private.active_viewer(),
 league_private.rating_row(uuid,integer), league_private.rating_full(uuid), league_private.style_pair(uuid) FROM PUBLIC, anon, authenticated;

-- ---------- RPCs ----------
-- Eigene Bewertung und eigener Boxstil (vollständig).
CREATE OR REPLACE FUNCTION public.get_my_performance()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles; r_on boolean; s_on boolean;
BEGIN
 me := league_private.active_viewer();
 IF me.id IS NULL THEN RAISE EXCEPTION 'Bitte anmelden' USING ERRCODE='42501'; END IF;
 r_on := league_private.flag_on('coach_ratings') OR me.role='admin';
 s_on := league_private.flag_on('style_test') OR me.role='admin';
 RETURN pg_catalog.jsonb_build_object(
  'profile',pg_catalog.jsonb_build_object('id',me.id,'display_name',me.display_name,'role',me.role),
  'ratings_enabled',r_on,'style_enabled',s_on,
  'rating',CASE WHEN r_on THEN league_private.rating_full(me.id) END,
  'style',CASE WHEN s_on THEN league_private.style_pair(me.id) || pg_catalog.jsonb_build_object('state',league_private.style_state(me.id)) END);
END;
$fn$;

-- Karte für das Profil eines anderen Boxers (nur angemeldete Liga-Mitglieder, nur sichtbare Profile).
CREATE OR REPLACE FUNCTION public.get_performance_card(p_display_name text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles; t public.profiles; n integer; staff boolean; r_on boolean; s_on boolean;
 cur public.boxer_ratings; prev public.boxer_ratings; sm jsonb;
BEGIN
 me := league_private.active_viewer();
 IF me.id IS NULL THEN RETURN NULL; END IF;
 SELECT count(*) INTO n FROM public.profiles p
 WHERE pg_catalog.lower(p.display_name)=pg_catalog.lower(pg_catalog.btrim(coalesce(p_display_name,'')))
   AND p.is_active AND p.archived_at IS NULL AND p.role IN ('boxer','coach');
 IF n<>1 THEN RETURN NULL; END IF;
 SELECT * INTO t FROM public.profiles p
 WHERE pg_catalog.lower(p.display_name)=pg_catalog.lower(pg_catalog.btrim(p_display_name))
   AND p.is_active AND p.archived_at IS NULL AND p.role IN ('boxer','coach');
 staff := me.role IN ('admin','coach');
 IF t.id<>me.id AND NOT staff AND t.is_listed IS NOT TRUE THEN RETURN NULL; END IF;
 r_on := league_private.flag_on('coach_ratings') OR staff;
 s_on := league_private.flag_on('style_test') OR staff;
 IF r_on THEN
  cur := league_private.rating_row(t.id,0); prev := league_private.rating_row(t.id,1);
  IF cur.id IS NOT NULL THEN
   sm := league_private.rating_summary(cur.scores);
   sm := sm || pg_catalog.jsonb_build_object('rated_at',cur.created_at,
     'delta',CASE WHEN prev.id IS NULL THEN NULL ELSE (sm->>'overall')::integer-(league_private.rating_summary(prev.scores)->>'overall')::integer END);
  END IF;
 END IF;
 RETURN pg_catalog.jsonb_build_object('display_name',t.display_name,
  'rating',sm,
  'style',CASE WHEN s_on THEN (SELECT pg_catalog.jsonb_build_object('scores',x.scores,'created_at',x.created_at) FROM public.style_tests x
            WHERE x.boxer_id=t.id ORDER BY x.created_at DESC, x.id DESC LIMIT 1) END);
END;
$fn$;

-- Übersicht für Trainer/Admins: alle aktiven Boxer mit Karte und Teststatus.
CREATE OR REPLACE FUNCTION public.staff_list_performance()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles;
BEGIN
 me := league_private.active_viewer();
 IF me.id IS NULL OR me.role NOT IN ('admin','coach') THEN RAISE EXCEPTION 'Nur für Trainer und Admins' USING ERRCODE='42501'; END IF;
 RETURN coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
   'id',p.id,'display_name',p.display_name,'role',p.role,
   'overall',(SELECT (league_private.rating_summary(r.scores)->>'overall')::integer FROM public.boxer_ratings r WHERE r.boxer_id=p.id ORDER BY r.created_at DESC, r.id DESC LIMIT 1),
   'rated_at',(SELECT r.created_at FROM public.boxer_ratings r WHERE r.boxer_id=p.id ORDER BY r.created_at DESC, r.id DESC LIMIT 1),
   'style',league_private.style_state(p.id),
   'style_scores',(SELECT t.scores FROM public.style_tests t WHERE t.boxer_id=p.id ORDER BY t.created_at DESC, t.id DESC LIMIT 1),
   'is_self',p.id=me.id) ORDER BY pg_catalog.lower(p.display_name))
  FROM public.profiles p WHERE p.is_active AND p.archived_at IS NULL AND p.role IN ('boxer','coach')),'[]'::jsonb);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.staff_get_rating(p_boxer_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles;
BEGIN
 me := league_private.active_viewer();
 IF me.id IS NULL OR me.role NOT IN ('admin','coach') THEN RAISE EXCEPTION 'Nur für Trainer und Admins' USING ERRCODE='42501'; END IF;
 RETURN league_private.rating_full(p_boxer_id);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.staff_rate_boxer(p_boxer_id uuid, p_scores jsonb, p_note text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles; t public.profiles; last public.boxer_ratings; note text; new_id bigint; before integer;
BEGIN
 me := league_private.active_viewer();
 IF me.id IS NULL OR me.role NOT IN ('admin','coach') THEN RAISE EXCEPTION 'Nur aktive Trainer und Admins dürfen bewerten' USING ERRCODE='42501'; END IF;
 SELECT * INTO t FROM public.profiles p WHERE p.id=p_boxer_id FOR UPDATE;
 IF NOT FOUND OR t.role NOT IN ('boxer','coach') OR NOT t.is_active OR t.archived_at IS NOT NULL THEN
  RAISE EXCEPTION 'Bitte einen aktiven Boxer wählen' USING ERRCODE='22023';
 END IF;
 IF t.id=me.id THEN RAISE EXCEPTION 'Die eigene Bewertung macht ein anderer Trainer' USING ERRCODE='42501'; END IF;
 IF NOT league_private.rating_scores_valid(p_scores) THEN
  RAISE EXCEPTION 'Bitte alle 25 Noten von 1 bis 10 vergeben' USING ERRCODE='22023';
 END IF;
 note := NULLIF(pg_catalog.btrim(coalesce(p_note,'')),'');
 IF note IS NOT NULL AND pg_catalog.char_length(note)>600 THEN RAISE EXCEPTION 'Der Kommentar darf höchstens 600 Zeichen haben' USING ERRCODE='22023'; END IF;
 last := league_private.rating_row(t.id,0);
 -- Doppelklick: identische Bewertung desselben Trainers innerhalb von 2 Minuten wird nicht doppelt gespeichert.
 IF last.id IS NOT NULL AND last.rated_by=me.id AND last.scores=p_scores AND last.note IS NOT DISTINCT FROM note
    AND last.created_at > now() - interval '2 minutes' THEN
  RETURN pg_catalog.jsonb_build_object('id',last.id,'duplicate',true,'overall',(league_private.rating_summary(last.scores)->>'overall')::integer);
 END IF;
 before := CASE WHEN last.id IS NULL THEN NULL ELSE (league_private.rating_summary(last.scores)->>'overall')::integer END;
 INSERT INTO public.boxer_ratings(boxer_id,rated_by,scores,note) VALUES (t.id,me.id,p_scores,note) RETURNING id INTO new_id;
 RETURN pg_catalog.jsonb_build_object('id',new_id,'boxer',t.display_name,'previous_overall',before,
  'overall',(league_private.rating_summary(p_scores)->>'overall')::integer);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.submit_style_test(p_answers smallint[])
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles; st jsonb; sc jsonb; new_id bigint; unlock_id bigint;
BEGIN
 me := league_private.active_viewer();
 IF me.id IS NULL OR me.role NOT IN ('boxer','coach') THEN RAISE EXCEPTION 'Den Boxstil-Test machen Boxer mit ihrem eigenen Konto' USING ERRCODE='42501'; END IF;
 IF NOT league_private.flag_on('style_test') THEN RAISE EXCEPTION 'Der Boxstil-Test ist noch nicht freigeschaltet' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM public.profiles p WHERE p.id=me.id FOR UPDATE;
 sc := league_private.style_scores(p_answers);
 st := league_private.style_state(me.id);
 IF NOT (st->>'can_take')::boolean THEN
  RAISE EXCEPTION 'Du hast den Test diesen Monat schon gemacht. Nächster Test ab %.',
   pg_catalog.to_char((st->>'next_allowed_on')::date,'DD.MM.YYYY') USING ERRCODE='55000';
 END IF;
 INSERT INTO public.style_tests(boxer_id,answers,scores) VALUES (me.id,p_answers,sc) RETURNING id INTO new_id;
 -- Eine offene Freigabe wird mit dem nächsten Test verbraucht (sie gilt nicht über den Monatswechsel hinaus doppelt).
 IF (st->>'unlocked')::boolean THEN
  UPDATE public.style_test_unlocks u SET used_at=now(), used_test_id=new_id
  WHERE u.boxer_id=me.id AND u.used_at IS NULL RETURNING u.id INTO unlock_id;
 END IF;
 RETURN pg_catalog.jsonb_build_object('id',new_id,'scores',sc,'used_unlock',unlock_id IS NOT NULL,
  'next_allowed_on',(league_private.month_start(now()) + interval '1 month')::date);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.staff_unlock_style_test(p_boxer_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles; t public.profiles; st jsonb; new_id bigint;
BEGIN
 me := league_private.active_viewer();
 IF me.id IS NULL OR me.role NOT IN ('admin','coach') THEN RAISE EXCEPTION 'Nur aktive Trainer und Admins dürfen freigeben' USING ERRCODE='42501'; END IF;
 SELECT * INTO t FROM public.profiles p WHERE p.id=p_boxer_id FOR UPDATE;
 IF NOT FOUND OR t.role NOT IN ('boxer','coach') OR NOT t.is_active OR t.archived_at IS NOT NULL THEN
  RAISE EXCEPTION 'Bitte einen aktiven Boxer wählen' USING ERRCODE='22023';
 END IF;
 st := league_private.style_state(t.id);
 IF (st->>'unlocked')::boolean THEN RETURN pg_catalog.jsonb_build_object('status','already_unlocked'); END IF;
 IF NOT (st->>'locked')::boolean THEN RETURN pg_catalog.jsonb_build_object('status','not_locked'); END IF;
 INSERT INTO public.style_test_unlocks(boxer_id,unlocked_by) VALUES (t.id,me.id) RETURNING id INTO new_id;
 RETURN pg_catalog.jsonb_build_object('status','unlocked','id',new_id,'boxer',t.display_name);
END;
$fn$;

REVOKE ALL ON FUNCTION public.get_my_performance(), public.get_performance_card(text), public.staff_list_performance(),
 public.staff_get_rating(uuid), public.staff_rate_boxer(uuid,jsonb,text), public.submit_style_test(smallint[]),
 public.staff_unlock_style_test(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_performance(), public.get_performance_card(text), public.staff_list_performance(),
 public.staff_get_rating(uuid), public.staff_rate_boxer(uuid,jsonb,text), public.submit_style_test(smallint[]),
 public.staff_unlock_style_test(uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
