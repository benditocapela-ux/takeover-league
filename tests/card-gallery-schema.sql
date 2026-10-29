\set ON_ERROR_STOP on
-- Disposable-database test for 20261029220000_card_gallery.sql (Etappe 16): alle Karten auf einmal, beste zuerst, genau die
-- Werte von get_performance_card, gleiche Sichtbarkeit (sichtbare Profile, eigenes, Trainer/Admin alle; eindeutige Namen; Flags).
-- Fixture: öffentliche Kartenwerte (Etappe 15) mit Bewertungen Anna 13, Ben 17 (unsichtbar), Marco 11, Alt archiviert.
\ir card-scale-schema.sql
\ir ../supabase/production-prep/preflight_20261029220000_card_gallery.sql
\ir ../supabase/migrations/20261029220000_card_gallery.sql
\ir ../supabase/migrations/20261029220000_card_gallery.sql
\ir ../supabase/production-prep/postflight_20261029220000_card_gallery.sql

DO $t$ DECLARE g jsonb; e jsonb; c jsonb; names text;
 owner uuid := '10000000-0000-0000-0000-00000000000a'; anna uuid := '10000000-0000-0000-0000-000000000001'; ben uuid := '10000000-0000-0000-0000-000000000002';
BEGIN
 PERFORM set_config('role','postgres',true);
 IF has_function_privilege('anon','public.get_card_gallery()','EXECUTE') THEN RAISE EXCEPTION 'anon'; END IF;
 UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key IN ('coach_ratings','style_test');
 -- Anna (Boxerin, sichtbar): ohne Ben (unsichtbar), ohne Archivierte, ohne Admin; beste zuerst
 PERFORM pg_temp.act(anna);
 g := public.get_card_gallery();
 SELECT string_agg(x->>'display_name',',' ORDER BY o) INTO names FROM jsonb_array_elements(g) WITH ORDINALITY a(x,o);
 IF names<>'Anna,Marco' THEN RAISE EXCEPTION 'anna sees %', names; END IF;
 -- Gleiche Werte wie die einzelne Profilkarte, keine Einzelnoten
 FOR e IN SELECT x FROM jsonb_array_elements(g) x LOOP
  c := public.get_performance_card(e->>'display_name');
  IF e->'rating'->'overall'<>c->'rating'->'overall' OR e->'rating'->'categories'<>c->'rating'->'categories' OR (e->'rating'->'delta') IS DISTINCT FROM (c->'rating'->'delta')
     OR (e->'is_me')<>(c->'is_me') THEN RAISE EXCEPTION 'differs from card: % vs %', e, c; END IF;
  IF e->'rating' ? 'top' OR e->'rating' ? 'low' OR e ? 'scores' THEN RAISE EXCEPTION 'leaks notes'; END IF;
 END LOOP;
 IF NOT (g->0->>'is_me')::boolean THEN RAISE EXCEPTION 'is_me'; END IF;
 -- Ben (unsichtbar) sieht sich selbst, als beste Karte 92 ganz oben
 PERFORM pg_temp.act(ben);
 g := public.get_card_gallery();
 IF g->0->>'display_name'<>'Ben' OR (g->0->'rating'->>'overall')::int<>92 OR NOT (g->0->>'is_me')::boolean THEN RAISE EXCEPTION 'ben top %', g->0; END IF;
 -- Admin sieht alle (ausser Archivierte), absteigend sortiert
 PERFORM pg_temp.act(owner);
 g := public.get_card_gallery();
 SELECT string_agg(x->>'display_name',',' ORDER BY o) INTO names FROM jsonb_array_elements(g) WITH ORDINALITY a(x,o);
 IF names<>'Ben,Anna,Marco' THEN RAISE EXCEPTION 'admin sees %', names; END IF;
 IF EXISTS (SELECT 1 FROM jsonb_array_elements(g) WITH ORDINALITY a(x,o) JOIN jsonb_array_elements(g) WITH ORDINALITY b(y,p) ON p=o+1
            WHERE (x->'rating'->>'overall')::int<(y->'rating'->>'overall')::int) THEN RAISE EXCEPTION 'order'; END IF;
 -- Ohne Bewertung: am Ende, rating null
 PERFORM set_config('role','postgres',true);
 INSERT INTO public.profiles(id,auth_user_id,display_name,role,is_listed) VALUES ('00000000-0000-0000-0000-0000000000b1','10000000-0000-0000-0000-0000000000b1','Bea','boxer',true);
 PERFORM pg_temp.act(anna);
 g := public.get_card_gallery();
 IF g->-1->>'display_name'<>'Bea' OR g->-1->'rating'<>'null'::jsonb THEN RAISE EXCEPTION 'unrated last %', g->-1; END IF;
 -- Flag aus: Boxer sehen keine Werte, Trainer schon
 PERFORM set_config('role','postgres',true);
 UPDATE public.league_feature_flags SET is_enabled=false WHERE feature_key='coach_ratings';
 PERFORM pg_temp.act(anna);
 IF EXISTS (SELECT 1 FROM jsonb_array_elements(public.get_card_gallery()) x WHERE x->'rating'<>'null'::jsonb) THEN RAISE EXCEPTION 'flag off'; END IF;
 PERFORM pg_temp.act(owner);
 IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(public.get_card_gallery()) x WHERE x->'rating'<>'null'::jsonb) THEN RAISE EXCEPTION 'staff flag off'; END IF;
 -- Doppelte Namen: nicht eindeutig → nicht in der Galerie
 PERFORM set_config('role','postgres',true);
 UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='coach_ratings';
 INSERT INTO public.profiles(id,auth_user_id,display_name,role,is_listed) VALUES ('00000000-0000-0000-0000-0000000000b2','10000000-0000-0000-0000-0000000000b2','bea','boxer',true);
 PERFORM pg_temp.act(anna);
 IF EXISTS (SELECT 1 FROM jsonb_array_elements(public.get_card_gallery()) x WHERE lower(x->>'display_name')='bea') THEN RAISE EXCEPTION 'duplicate names'; END IF;
 PERFORM pg_temp.act(NULL);
 PERFORM set_config('role','postgres',true);
 RAISE NOTICE 'PASS: Etappe 16 – Kartengalerie: beste zuerst, Werte identisch mit get_performance_card, ohne Einzelnoten, Sichtbarkeit wie Profilkarte (unsichtbare nur selbst/Trainer, Archivierte nie, doppelte Namen nie), ohne Bewertung am Ende, Flag respektiert';
END $t$;

\ir ../supabase/production-prep/rollback_20261029220000_card_gallery.sql
DO $r$ BEGIN
 IF to_regprocedure('public.get_card_gallery()') IS NOT NULL THEN RAISE EXCEPTION 'rollback'; END IF;
 RAISE NOTICE 'PASS: Rücknahme entfernt die Galerie';
END $r$;
\ir ../supabase/migrations/20261029220000_card_gallery.sql
DO $r$ BEGIN
 IF to_regprocedure('public.get_card_gallery()') IS NULL THEN RAISE EXCEPTION 're-apply'; END IF;
 RAISE NOTICE 'PASS: erneut einspielbar';
END $r$;
