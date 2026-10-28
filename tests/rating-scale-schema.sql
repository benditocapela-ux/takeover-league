\set ON_ERROR_STOP on
-- Disposable-database test for 20261029090000_rating_scale_20.sql (Etappe 7a: Regler 1–20) inkl. Rollback und erneutem Anwenden.
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE ROLE anon;
CREATE ROLE authenticated;
CREATE SCHEMA auth;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $fn$ SELECT nullif(current_setting('request.jwt.claim.sub', true),'')::uuid $fn$;
GRANT USAGE ON SCHEMA auth TO authenticated, anon;
GRANT EXECUTE ON FUNCTION auth.uid() TO authenticated, anon;
CREATE SCHEMA league_private;
CREATE FUNCTION league_private.existing_helper() RETURNS integer LANGUAGE sql AS $fn$ SELECT 1 $fn$;
GRANT USAGE ON SCHEMA league_private TO authenticated;
GRANT EXECUTE ON FUNCTION league_private.existing_helper() TO authenticated;
CREATE TABLE public.profiles(id uuid PRIMARY KEY, auth_user_id uuid UNIQUE, display_name text NOT NULL, role text NOT NULL DEFAULT 'boxer',
 is_active boolean NOT NULL DEFAULT true, is_listed boolean NOT NULL DEFAULT true, archived_at timestamptz);
CREATE TABLE public.league_feature_flags(feature_key text PRIMARY KEY, display_name text, is_enabled boolean NOT NULL DEFAULT false);
GRANT SELECT ON public.profiles, public.league_feature_flags TO authenticated, anon;
INSERT INTO public.profiles(id,auth_user_id,display_name,role,is_listed,archived_at,is_active) VALUES
 ('00000000-0000-0000-0000-00000000000a','10000000-0000-0000-0000-00000000000a','Owner','admin',true,NULL,true),
 ('00000000-0000-0000-0000-00000000000c','10000000-0000-0000-0000-00000000000c','Marco','coach',true,NULL,true),
 ('00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','Anna','boxer',true,NULL,true),
 ('00000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000002','Ben','boxer',false,NULL,true),
 ('00000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000003','Alt','boxer',true,now(),true);

\ir ../supabase/migrations/20261028180000_coach_ratings_style_test.sql
CREATE FUNCTION pg_temp.act(p uuid) RETURNS void LANGUAGE plpgsql AS $fn$ BEGIN
 PERFORM set_config('role','postgres',true);
 IF p IS NULL THEN PERFORM set_config('request.jwt.claim.sub','',true); PERFORM set_config('role','anon',true);
 ELSE PERFORM set_config('request.jwt.claim.sub',p::text,true); PERFORM set_config('role','authenticated',true); END IF;
END $fn$;
CREATE FUNCTION pg_temp.scores(base integer, extra jsonb DEFAULT '{}') RETURNS jsonb LANGUAGE sql AS $fn$
 SELECT jsonb_object_agg(k,base) || extra FROM unnest(ARRAY['jab','cross','hook','upper','body','combo','guard','block','slip','roll','parry','counter',
  'stance','steps','angles','ring','endur','pace','recov','timing','dist','plan','focus','heart','coach']) k $fn$;
GRANT EXECUTE ON FUNCTION pg_temp.act(uuid), pg_temp.scores(integer,jsonb) TO authenticated, anon;
UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='coach_ratings';
-- Bestehende Bewertung auf der 10er-Skala (wie in Produktion), mit der bisherigen Funktion gespeichert
DO $s$ BEGIN
 PERFORM pg_temp.act('10000000-0000-0000-0000-00000000000a');
 PERFORM public.staff_rate_boxer('00000000-0000-0000-0000-000000000001',pg_temp.scores(7,'{"jab":10,"slip":3}'),'Alt');
 PERFORM set_config('role','postgres',true);
 UPDATE public.boxer_ratings SET created_at=now()-interval '30 days';
END $s$;
CREATE TEMP TABLE before_rating AS SELECT id, scores, note, created_at, rated_by, (league_private.rating_summary(scores)) AS summary FROM public.boxer_ratings;
\ir ../supabase/production-prep/preflight_20261029090000_rating_scale_20.sql
\ir ../supabase/migrations/20261029090000_rating_scale_20.sql
\ir ../supabase/migrations/20261029090000_rating_scale_20.sql

DO $t$ DECLARE r jsonb;
 owner uuid := '10000000-0000-0000-0000-00000000000a'; coach uuid := '10000000-0000-0000-0000-00000000000c';
 anna uuid := '10000000-0000-0000-0000-000000000001'; ben uuid := '10000000-0000-0000-0000-000000000002';
 annaP uuid := '00000000-0000-0000-0000-000000000001'; benP uuid := '00000000-0000-0000-0000-000000000002';
BEGIN
 -- Bestehende Bewertung: Daten unverändert, scale 10, gleiche Karte
 IF EXISTS (SELECT 1 FROM before_rating b JOIN public.boxer_ratings r USING (id) WHERE (b.scores,b.note,b.created_at,b.rated_by) IS DISTINCT FROM (r.scores,r.note,r.created_at,r.rated_by) OR r.scale<>10)
  THEN RAISE EXCEPTION 'existing rating changed'; END IF;
 IF EXISTS (SELECT 1 FROM before_rating b JOIN public.boxer_ratings r USING (id) WHERE (b.summary - 'top' - 'low') <> (league_private.rating_summary(r.scores,r.scale) - 'top' - 'low' - 'scale'))
  THEN RAISE EXCEPTION 'existing card changed'; END IF;
 -- Rechte
 IF to_regprocedure('public.staff_rate_boxer(uuid,jsonb,text)') IS NOT NULL THEN RAISE EXCEPTION 'old signature left'; END IF;
 IF has_function_privilege('anon','public.staff_rate_boxer(uuid,jsonb,text,integer)','EXECUTE') OR NOT has_function_privilege('authenticated','public.staff_rate_boxer(uuid,jsonb,text,integer)','EXECUTE')
  OR has_function_privilege('authenticated','league_private.rating_summary(jsonb,integer)','EXECUTE') OR has_function_privilege('authenticated','league_private.rating_scores_valid(jsonb,integer)','EXECUTE')
  THEN RAISE EXCEPTION 'rights'; END IF;

 -- Bisherige Oberfläche (ohne p_scale): weiter 1–10
 PERFORM pg_temp.act(coach);
 BEGIN PERFORM public.staff_rate_boxer(benP,pg_temp.scores(12)); RAISE EXCEPTION '12 on scale 10'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 r := public.staff_rate_boxer(p_boxer_id=>benP,p_scores=>pg_temp.scores(8),p_note=>'alte Oberfläche');
 IF (r->>'overall')::int<>80 OR (r->>'scale')::int<>10 THEN RAISE EXCEPTION 'scale 10 call %', r; END IF;

 -- Regler 1–20
 BEGIN PERFORM public.staff_rate_boxer(annaP,pg_temp.scores(12,'{"jab":21}'),NULL,20); RAISE EXCEPTION '21 accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.staff_rate_boxer(annaP,pg_temp.scores(12,'{"jab":0}'),NULL,20); RAISE EXCEPTION '0 accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.staff_rate_boxer(annaP,pg_temp.scores(12,'{"jab":12.5}'),NULL,20); RAISE EXCEPTION 'decimal accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.staff_rate_boxer(annaP,pg_temp.scores(12),NULL,15); RAISE EXCEPTION 'scale 15'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 -- Gleiche Leistung wie die alte Bewertung (alles doppelt) → gleiche Karte, Delta 0
 r := public.staff_rate_boxer(annaP,pg_temp.scores(14,'{"jab":20,"slip":6}'),'Regler',20);
 IF (r->>'overall')::int<>70 OR (r->>'previous_overall')::int<>70 OR (r->>'scale')::int<>20 THEN RAISE EXCEPTION 'scale 20 same %', r; END IF;
 PERFORM set_config('role','postgres',true);
 r := league_private.rating_summary(pg_temp.scores(14,'{"jab":20,"slip":6}'),20);
 IF (r->'categories'->>'OFF')::int<>75 OR (r->'categories'->>'DEF')::int<>63 OR (r->>'scale')::int<>20 OR (r->'top'->0->>'v')::int<>20 THEN RAISE EXCEPTION 'summary 20 %', r; END IF;
 IF (league_private.rating_summary(pg_temp.scores(20),20)->>'overall')::int<>99 OR (league_private.rating_summary(pg_temp.scores(1),20)->>'overall')::int<>5 THEN RAISE EXCEPTION 'bounds'; END IF;
 -- Feinere Abstufung: 13 von 20 = 65 (vorher nur 60 oder 70 möglich)
 IF (league_private.rating_summary(pg_temp.scores(13),20)->>'overall')::int<>65 THEN RAISE EXCEPTION 'fine grain'; END IF;
 -- Doppelklick
 PERFORM pg_temp.act(coach);
 r := public.staff_rate_boxer(annaP,pg_temp.scores(14,'{"jab":20,"slip":6}'),'Regler',20);
 IF (r->>'duplicate')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'duplicate'; END IF;

 -- Boxer: eigene Bewertung mit Skala, vorherige auf 10er-Skala
 PERFORM pg_temp.act(anna);
 r := public.get_my_performance();
 IF (r->'rating'->'current'->>'scale')::int<>20 OR (r->'rating'->'previous'->>'scale')::int<>10 OR (r->'rating'->'current'->'summary'->>'overall')::int<>70
    OR (r->'rating'->'previous'->'summary'->>'overall')::int<>70 THEN RAISE EXCEPTION 'own %', r; END IF;
 -- Andere: Karte, Delta 0, eigene Karte markiert
 PERFORM pg_temp.act(ben);
 r := public.get_performance_card('Anna');
 IF (r->'rating'->>'overall')::int<>70 OR (r->'rating'->>'delta')::int<>0 OR (r->>'is_me')::boolean OR r::text LIKE '%Regler%' THEN RAISE EXCEPTION 'card %', r; END IF;
 IF NOT (public.get_performance_card('Ben')->>'is_me')::boolean THEN RAISE EXCEPTION 'is_me'; END IF;
 PERFORM pg_temp.act(owner);
 IF (SELECT (x->>'overall')::int FROM jsonb_array_elements(public.staff_list_performance()) x WHERE x->>'display_name'='Anna')<>70 THEN RAISE EXCEPTION 'staff list'; END IF;
 PERFORM set_config('role','postgres',true);
 RAISE NOTICE 'PASS: Etappe 7a Bewertung – Regler 1–20 (feinere Abstufung), bisherige 10er-Bewertungen unverändert gespeichert und gleich gerechnet, alte Oberfläche weiter gültig, Grenzen 1–20, Doppelklick, Karte ohne Noten/Kommentar';
END $t$;

\ir ../supabase/production-prep/postflight_20261029090000_rating_scale_20.sql
-- Rollback bricht ab, solange 20er-Bewertungen existieren (Fehler hier erwartet)
\set ON_ERROR_STOP off
\ir ../supabase/production-prep/rollback_20261029090000_rating_scale_20.sql
\set ON_ERROR_STOP on
DO $r$ BEGIN
 IF to_regprocedure('public.staff_rate_boxer(uuid,jsonb,text,integer)') IS NULL THEN RAISE EXCEPTION 'rollback ran despite scale-20 ratings'; END IF;
 RAISE NOTICE 'PASS: Rollback 7a verweigert, solange Bewertungen auf der 20er-Skala existieren';
END $r$;
DELETE FROM public.boxer_ratings WHERE scale=20;
\ir ../supabase/production-prep/rollback_20261029090000_rating_scale_20.sql
DO $r$ BEGIN
 IF to_regprocedure('public.staff_rate_boxer(uuid,jsonb,text)') IS NULL OR to_regprocedure('public.staff_rate_boxer(uuid,jsonb,text,integer)') IS NOT NULL
    OR to_regprocedure('league_private.rating_summary(jsonb,integer)') IS NOT NULL THEN RAISE EXCEPTION 'rollback functions'; END IF;
 IF (SELECT count(*) FROM public.boxer_ratings)<>2 THEN RAISE EXCEPTION 'rollback data'; END IF;
 RAISE NOTICE 'PASS: Rollback 7a stellt die 10er-Funktionen her und behält die Bewertungen';
END $r$;
\ir ../supabase/migrations/20261029090000_rating_scale_20.sql
DO $a$ BEGIN IF to_regprocedure('public.staff_rate_boxer(uuid,jsonb,text,integer)') IS NULL THEN RAISE EXCEPTION 'reapply'; END IF; RAISE NOTICE 'PASS: Migration 7a nach Rollback erneut anwendbar'; END $a$;
