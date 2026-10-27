\set ON_ERROR_STOP on
-- Disposable-database test for 20261028180000_coach_ratings_style_test.sql (+ rollback, re-apply).
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

DO $t$ DECLARE r jsonb; n integer;
 owner uuid := '10000000-0000-0000-0000-00000000000a'; coach uuid := '10000000-0000-0000-0000-00000000000c';
 anna uuid := '10000000-0000-0000-0000-000000000001'; ben uuid := '10000000-0000-0000-0000-000000000002';
 annaP uuid := '00000000-0000-0000-0000-000000000001'; benP uuid := '00000000-0000-0000-0000-000000000002';
 coachP uuid := '00000000-0000-0000-0000-00000000000c'; altP uuid := '00000000-0000-0000-0000-000000000003';
BEGIN
 -- Rechte
 IF has_function_privilege('anon','public.get_my_performance()','EXECUTE') OR has_function_privilege('anon','public.staff_rate_boxer(uuid,jsonb,text)','EXECUTE')
  OR has_function_privilege('anon','public.get_performance_card(text)','EXECUTE') THEN RAISE EXCEPTION 'anon may execute'; END IF;
 IF has_table_privilege('authenticated','public.boxer_ratings','SELECT') OR has_table_privilege('authenticated','public.style_tests','INSERT') THEN RAISE EXCEPTION 'table grant'; END IF;
 IF has_function_privilege('authenticated','league_private.rating_summary(jsonb)','EXECUTE') THEN RAISE EXCEPTION 'helper callable'; END IF;
 IF NOT has_function_privilege('authenticated','league_private.existing_helper()','EXECUTE') THEN RAISE EXCEPTION 'existing helper grant removed'; END IF;
 IF (SELECT count(*) FROM public.league_feature_flags WHERE feature_key IN ('coach_ratings','style_test') AND NOT is_enabled)<>2 THEN RAISE EXCEPTION 'flags'; END IF;

 -- Boxer darf nicht bewerten / Übersicht / freigeben
 PERFORM pg_temp.act(anna);
 BEGIN PERFORM public.staff_rate_boxer(benP,pg_temp.scores(7)); RAISE EXCEPTION 'boxer rated'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.staff_list_performance(); RAISE EXCEPTION 'boxer listed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.staff_unlock_style_test(benP); RAISE EXCEPTION 'boxer unlocked'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.staff_get_rating(benP); RAISE EXCEPTION 'boxer read staff'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;

 -- Trainer bewertet
 PERFORM pg_temp.act(coach);
 BEGIN PERFORM public.staff_rate_boxer(coachP,pg_temp.scores(7)); RAISE EXCEPTION 'self rated'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.staff_rate_boxer(altP,pg_temp.scores(7)); RAISE EXCEPTION 'archived rated'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.staff_rate_boxer(annaP,pg_temp.scores(7,'{"jab":11}')); RAISE EXCEPTION '11 accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.staff_rate_boxer(annaP,pg_temp.scores(7,'{"jab":0}')); RAISE EXCEPTION '0 accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.staff_rate_boxer(annaP,pg_temp.scores(7,'{"jab":7.5}')); RAISE EXCEPTION 'decimal accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.staff_rate_boxer(annaP,pg_temp.scores(7,'{"extra":5}')); RAISE EXCEPTION 'extra key accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.staff_rate_boxer(annaP,pg_temp.scores(7)-'jab'); RAISE EXCEPTION 'missing key accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.staff_rate_boxer(annaP,pg_temp.scores(7,'{"jab":"7"}')); RAISE EXCEPTION 'string accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.staff_rate_boxer(annaP,pg_temp.scores(7),repeat('x',601)); RAISE EXCEPTION 'long note'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 r := public.staff_rate_boxer(annaP,pg_temp.scores(7),'  Erste Bewertung  ');
 IF (r->>'overall')::int<>70 OR r->>'previous_overall' IS NOT NULL THEN RAISE EXCEPTION 'first rating %', r; END IF;
 r := public.staff_rate_boxer(annaP,pg_temp.scores(7),'Erste Bewertung');
 IF (r->>'duplicate')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'duplicate not detected %', r; END IF;
 PERFORM set_config('role','postgres',true);
 UPDATE public.boxer_ratings SET created_at=now()-interval '20 days';
 PERFORM pg_temp.act(owner);
 r := public.staff_rate_boxer(annaP,pg_temp.scores(7,'{"jab":10,"slip":3}'),'Jab top, Slip üben');
 -- OFF (10+35)/6=7.5→75, DEF (3+35)/6=6.33→63, Rest 70 → (75*25+63*25+70*20+70*30)/100 = 69.5 → 70
 IF (r->>'overall')::int<>70 OR (r->>'previous_overall')::int<>70 THEN RAISE EXCEPTION 'second rating %', r; END IF;
 PERFORM set_config('role','postgres',true);
 IF (SELECT count(*) FROM public.boxer_ratings)<>2 THEN RAISE EXCEPTION 'rating count'; END IF;
 IF (SELECT note FROM public.boxer_ratings ORDER BY id LIMIT 1)<>'Erste Bewertung' THEN RAISE EXCEPTION 'note trim'; END IF;
 r := league_private.rating_summary(pg_temp.scores(7,'{"jab":10,"slip":3}'));
 IF (r->'categories'->>'OFF')::int<>75 OR (r->'categories'->>'DEF')::int<>63 OR r->'top'->0->>'k'<>'jab' OR r->'low'->0->>'k'<>'slip'
    OR r->'top'->1->>'k'<>'cross' OR r->'low'->1->>'k'<>'cross' THEN RAISE EXCEPTION 'summary %', r; END IF;
 IF (league_private.rating_summary(pg_temp.scores(10))->>'overall')::int<>99 THEN RAISE EXCEPTION 'cap 99'; END IF;

 -- Boxer sieht eigene Bewertung erst mit Flag
 PERFORM pg_temp.act(anna);
 r := public.get_my_performance();
 IF (r->>'ratings_enabled')::boolean OR r->'rating'<>'null'::jsonb THEN RAISE EXCEPTION 'rating visible with flag off %', r; END IF;
 PERFORM set_config('role','postgres',true);
 UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='coach_ratings';
 PERFORM pg_temp.act(anna);
 r := public.get_my_performance();
 IF (r->'rating'->'current'->'scores'->>'jab')::int<>10 OR r->'rating'->'current'->>'note'<>'Jab top, Slip üben'
    OR (r->'rating'->'previous'->'scores'->>'jab')::int<>7 OR r->'rating'->'current'->>'rated_by'<>'Owner' THEN RAISE EXCEPTION 'own rating %', r; END IF;

 -- Andere sehen nur die Karte (keine Noten, kein Kommentar)
 PERFORM pg_temp.act(ben);
 r := public.get_performance_card('  anna ');
 IF r->'rating' IS NULL OR r->'rating' ? 'scores' OR r->'rating' ? 'note' OR (r->'rating'->>'overall')::int<>70 OR (r->'rating'->>'delta')::int<>0
    THEN RAISE EXCEPTION 'card %', r; END IF;
 IF r::text LIKE '%Slip üben%' THEN RAISE EXCEPTION 'note leaked'; END IF;
 PERFORM pg_temp.act(anna);
 IF public.get_performance_card('Ben') IS NOT NULL THEN RAISE EXCEPTION 'unlisted profile visible to boxer'; END IF;
 IF public.get_performance_card('Alt') IS NOT NULL OR public.get_performance_card('Niemand') IS NOT NULL THEN RAISE EXCEPTION 'archived/missing visible'; END IF;
 PERFORM pg_temp.act(coach);
 IF public.get_performance_card('Ben') IS NULL THEN RAISE EXCEPTION 'coach cannot see unlisted'; END IF;
 PERFORM pg_temp.act(NULL);
 BEGIN PERFORM public.get_performance_card('Anna'); RAISE EXCEPTION 'anon card'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;

 -- Boxstil-Test
 PERFORM pg_temp.act(anna);
 BEGIN PERFORM public.submit_style_test(ARRAY[0,0,0,0,0,0,0,0]::smallint[]); RAISE EXCEPTION 'test with flag off'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM set_config('role','postgres',true);
 UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='style_test';
 PERFORM pg_temp.act(anna);
 BEGIN PERFORM public.submit_style_test(ARRAY[0,0,0,0,0,0,0]::smallint[]); RAISE EXCEPTION '7 answers'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.submit_style_test(ARRAY[0,0,0,0,0,0,0,3]::smallint[]); RAISE EXCEPTION 'answer 3'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 r := public.submit_style_test(ARRAY[0,0,0,0,0,0,0,0]::smallint[]);
 IF (r->'scores'->>'p')::int<>80 OR (r->'scores'->>'v')::int<>45 OR (SELECT count(*) FROM jsonb_object_keys(r->'scores'))<>6 THEN RAISE EXCEPTION 'scores %', r; END IF;
 BEGIN PERFORM public.submit_style_test(ARRAY[1,1,1,1,1,1,1,1]::smallint[]); RAISE EXCEPTION 'second test same month'; EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL; END;
 r := public.get_my_performance();
 IF (r->'style'->'state'->>'locked')::boolean IS NOT TRUE OR (r->'style'->'state'->>'can_take')::boolean THEN RAISE EXCEPTION 'state %', r; END IF;
 PERFORM pg_temp.act(owner);
 BEGIN PERFORM public.submit_style_test(ARRAY[0,0,0,0,0,0,0,0]::smallint[]); RAISE EXCEPTION 'admin took test'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM pg_temp.act(coach);
 IF public.staff_unlock_style_test(benP)->>'status'<>'not_locked' THEN RAISE EXCEPTION 'unlock not locked'; END IF;
 IF public.staff_unlock_style_test(annaP)->>'status'<>'unlocked' THEN RAISE EXCEPTION 'unlock'; END IF;
 IF public.staff_unlock_style_test(annaP)->>'status'<>'already_unlocked' THEN RAISE EXCEPTION 'unlock twice'; END IF;
 r := public.staff_list_performance();
 IF jsonb_array_length(r)<>3 OR (SELECT (x->>'overall')::int FROM jsonb_array_elements(r) x WHERE x->>'display_name'='Anna')<>70
    OR (SELECT (x->'style'->>'unlocked')::boolean FROM jsonb_array_elements(r) x WHERE x->>'display_name'='Anna') IS NOT TRUE
    OR (SELECT (x->>'is_self')::boolean FROM jsonb_array_elements(r) x WHERE x->>'display_name'='Marco') IS NOT TRUE THEN RAISE EXCEPTION 'list %', r; END IF;
 PERFORM pg_temp.act(anna);
 r := public.submit_style_test(ARRAY[2,2,2,2,2,2,2,2]::smallint[]);
 IF (r->>'used_unlock')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'unlock not used %', r; END IF;
 BEGIN PERFORM public.submit_style_test(ARRAY[1,1,1,1,1,1,1,1]::smallint[]); RAISE EXCEPTION 'third test'; EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL; END;
 r := public.get_my_performance();
 IF (r->'style'->'current'->'scores'->>'o')::int<=(r->'style'->'previous'->'scores'->>'o')::int THEN RAISE EXCEPTION 'style pair %', r; END IF;
 -- Monatswechsel: alter Test gibt wieder frei
 PERFORM set_config('role','postgres',true);
 UPDATE public.style_tests SET created_at=created_at-interval '40 days';
 PERFORM pg_temp.act(anna);
 IF (public.get_my_performance()->'style'->'state'->>'can_take')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'new month not free'; END IF;
 -- Boxstil auf der Karte für andere
 PERFORM pg_temp.act(ben);
 IF public.get_performance_card('Anna')->'style'->'scores' IS NULL THEN RAISE EXCEPTION 'style on card'; END IF;
 PERFORM set_config('role','postgres',true);
 IF (SELECT count(*) FROM public.style_test_unlocks WHERE used_at IS NOT NULL)<>1 THEN RAISE EXCEPTION 'unlock usage count'; END IF;
END $t$;

SELECT set_config('role','postgres',false);
\ir ../supabase/production-prep/rollback_20261028180000_coach_ratings_style_test.sql
DO $t$ BEGIN
 IF to_regprocedure('public.staff_rate_boxer(uuid,jsonb,text)') IS NOT NULL OR to_regprocedure('league_private.rating_summary(jsonb)') IS NOT NULL THEN RAISE EXCEPTION 'rollback left functions'; END IF;
 IF (SELECT count(*) FROM public.boxer_ratings)<>2 OR (SELECT count(*) FROM public.style_tests)<>2 THEN RAISE EXCEPTION 'rollback lost data'; END IF;
 IF to_regprocedure('league_private.existing_helper()') IS NULL THEN RAISE EXCEPTION 'rollback removed existing helper'; END IF;
END $t$;
\ir ../supabase/migrations/20261028180000_coach_ratings_style_test.sql
\ir ../supabase/production-prep/postflight_20261028180000_coach_ratings_style_test.sql
SELECT 'PASS: Bewertung nur durch Trainer/Admin, Noten 1-10 geprüft, Karte ohne Noten für andere, Flags, Boxstil 1x pro Monat mit Freigabe, Rollback behält Daten' AS result;
