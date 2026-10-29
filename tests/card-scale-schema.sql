\set ON_ERROR_STOP on
-- Disposable-database test for 20261029210000_card_scale_92.sql (Etappe 15): öffentliche Kartenwerte nach der besten Karte (= 92),
-- eigene/Trainer-Sicht mit echten Werten plus 'public', Vorschau-Skala, Rücknahme wörtlich. Fixture: Selbsteinschätzung (Etappe 10).
\ir self-rating-schema.sql
CREATE TEMP TABLE ref15 AS SELECT
 md5(pg_get_functiondef('public.get_performance_card(text)'::regprocedure)||pg_get_functiondef('league_private.rating_full(uuid)'::regprocedure)
  ||pg_get_functiondef('public.staff_list_performance()'::regprocedure)) AS fns,
 (SELECT count(*)||'/'||md5(coalesce(string_agg(scores::text||scale,'|' ORDER BY id),'')) FROM public.boxer_ratings) AS rat;
GRANT SELECT ON ref15 TO PUBLIC;
\ir ../supabase/production-prep/preflight_20261029210000_card_scale_92.sql
\ir ../supabase/migrations/20261029210000_card_scale_92.sql
\ir ../supabase/migrations/20261029210000_card_scale_92.sql
\ir ../supabase/production-prep/postflight_20261029210000_card_scale_92.sql

DO $t$ DECLARE r jsonb; m jsonb; raw jsonb; rawB jsonb; best integer; v integer;
 owner uuid := '10000000-0000-0000-0000-00000000000a'; coach uuid := '10000000-0000-0000-0000-00000000000c';
 anna uuid := '10000000-0000-0000-0000-000000000001'; ben uuid := '10000000-0000-0000-0000-000000000002';
 annaP uuid := '00000000-0000-0000-0000-000000000001'; benP uuid := '00000000-0000-0000-0000-000000000002'; coachP uuid := '00000000-0000-0000-0000-00000000000c';
 altP uuid := '00000000-0000-0000-0000-000000000003';
BEGIN
 PERFORM set_config('role','postgres',true);
 IF (SELECT rat FROM ref15)<>(SELECT count(*)||'/'||md5(coalesce(string_agg(scores::text||scale,'|' ORDER BY id),'')) FROM public.boxer_ratings) THEN RAISE EXCEPTION 'ratings changed by migration'; END IF;
 -- Reine Umrechnung: × 92 / beste, gerundet, höchstens 99; ohne beste Karte unverändert
 r := league_private.rating_public('{"overall":65,"categories":{"OFF":65,"BEI":71,"KON":57}}',65);
 IF (r->>'overall')::int<>92 OR (r->'categories'->>'BEI')::int<>99 OR (r->'categories'->>'KON')::int<>81 OR (r->'categories'->>'OFF')::int<>92 OR (r->>'target')::int<>92 THEN RAISE EXCEPTION 'scale %', r; END IF;
 r := league_private.rating_public('{"overall":45,"categories":{"OFF":43}}',65);
 IF (r->>'overall')::int<>64 OR (r->'categories'->>'OFF')::int<>61 THEN RAISE EXCEPTION 'scale lower %', r; END IF;
 r := league_private.rating_public('{"overall":80,"categories":{"OFF":95}}',65);
 IF (r->>'overall')::int<>99 OR (r->'categories'->>'OFF')::int<>99 THEN RAISE EXCEPTION 'cap %', r; END IF;
 r := league_private.rating_public('{"overall":96,"categories":{"OFF":96}}',96);
 IF (r->>'overall')::int<>92 OR (r->'categories'->>'OFF')::int<>92 THEN RAISE EXCEPTION 'scale down %', r; END IF;
 r := league_private.rating_public('{"overall":40,"categories":{"OFF":40}}',NULL);
 IF (r->>'overall')::int<>40 OR (r->'categories'->>'OFF')::int<>40 THEN RAISE EXCEPTION 'no best %', r; END IF;

 -- Bewertungen: Anna 13, Ben 9, Marco (Trainer) 11; Alt (archiviert) 20 zählt nicht
 PERFORM pg_temp.act(owner);
 PERFORM public.staff_rate_boxer(annaP,pg_temp.scores(13),'E15',20);
 PERFORM public.staff_rate_boxer(benP,pg_temp.scores(8),'E15 vorher',20);
 PERFORM public.staff_rate_boxer(benP,pg_temp.scores(9),'E15',20);
 PERFORM public.staff_rate_boxer(coachP,pg_temp.scores(11),'E15',20);
 PERFORM set_config('role','postgres',true);
 INSERT INTO public.boxer_ratings(boxer_id,scores,scale,rated_by) SELECT altP,pg_temp.scores(20),20,'00000000-0000-0000-0000-00000000000a'
  WHERE EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='boxer_ratings' AND column_name='rated_by');
 raw := league_private.rating_summary(pg_temp.scores(13),20); rawB := league_private.rating_summary(pg_temp.scores(9),20)
   || jsonb_build_object('prev_overall',league_private.rating_summary(pg_temp.scores(8),20)->'overall');
 best := league_private.rating_card_best(NULL);
 IF best<>(raw->>'overall')::int THEN RAISE EXCEPTION 'best % vs %', best, raw->>'overall'; END IF;

 -- Öffentlich: Anna (beste) = 92, Ben skaliert; Kategorien skaliert; delta auf öffentlicher Skala
 PERFORM pg_temp.act(ben);
 r := public.get_performance_card('Anna');
 IF (r->'rating'->>'overall')::int<>92 OR NOT (r->'rating'->>'scaled')::boolean OR (r->'rating'->>'target')::int<>92 THEN RAISE EXCEPTION 'anna public %', r->'rating'; END IF;
 IF (r->'rating'->'categories'->>'OFF')::int<>LEAST(99,round((raw->'categories'->>'OFF')::numeric*92/best)) THEN RAISE EXCEPTION 'anna cats'; END IF;
 r := public.get_performance_card('Ben');
 v := round((rawB->>'overall')::numeric*92/best);
 IF (r->'rating'->>'overall')::int<>v THEN RAISE EXCEPTION 'ben own public % expected %', r->'rating'->>'overall', v; END IF;
 IF (r->'rating'->>'delta')::int<>v-round((rawB->>'prev_overall')::numeric*92/best) THEN RAISE EXCEPTION 'delta %', r->'rating'->>'delta'; END IF;
 IF r->'rating' ? 'public' THEN RAISE EXCEPTION 'public card leaks raw block'; END IF;
 -- Eigene Sicht: echte Werte, dazu public
 m := public.get_my_performance();
 IF (m->'rating'->'current'->'summary'->>'overall')::int<>(rawB->>'overall')::int OR (m->'rating'->'current'->'summary'->'public'->>'overall')::int<>v
    OR (m->'rating'->'previous'->'summary'->'public'->>'best')::int<>best THEN RAISE EXCEPTION 'own view %', m->'rating'->'current'->'summary'; END IF;
 -- Vorschau-Skala: nur für sich selbst
 r := public.get_rating_card_scale();
 IF (r->>'best')::int<>best OR (r->>'best_others')::int<>best OR (r->>'target')::int<>92 THEN RAISE EXCEPTION 'scale ben %', r; END IF;
 BEGIN PERFORM public.get_rating_card_scale(annaP); RAISE EXCEPTION 'boxer scale other'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM set_config('role','postgres',true);
 v := (league_private.rating_summary(pg_temp.scores(11),20)->>'overall')::int;
 PERFORM pg_temp.act(coach);
 r := public.get_rating_card_scale(annaP);
 IF (r->>'best_others')::int<>v THEN RAISE EXCEPTION 'best_others %', r; END IF;
 -- Trainer-Liste: echt und öffentlich
 r := (SELECT x FROM jsonb_array_elements(public.staff_list_performance()) x WHERE x->>'display_name'='Ben');
 IF (r->>'overall')::int<>(rawB->>'overall')::int OR (r->>'public_overall')::int<>round((rawB->>'overall')::numeric*92/best) THEN RAISE EXCEPTION 'staff list %', r; END IF;
 -- Ein anderer wird besser: Ben 17 → Ben 92, Anna rutscht nach
 PERFORM pg_temp.act(owner);
 PERFORM public.staff_rate_boxer(benP,pg_temp.scores(17),'E15 neu',20);
 PERFORM set_config('role','postgres',true);
 v := round((raw->>'overall')::numeric*92/(league_private.rating_summary(pg_temp.scores(17),20)->>'overall')::numeric);
 PERFORM pg_temp.act(anna);
 IF (public.get_performance_card('Anna')->'rating'->>'overall')::int<>v OR (public.get_performance_card('Ben')->'rating'->>'overall')::int<>92
    OR (public.get_my_performance()->'rating'->'current'->'summary'->>'overall')::int<>(raw->>'overall')::int THEN RAISE EXCEPTION 'rescale after new best'; END IF;
 PERFORM pg_temp.act(NULL);
 BEGIN PERFORM public.get_rating_card_scale(); RAISE EXCEPTION 'anon scale'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 RAISE NOTICE 'PASS: Etappe 15 – beste Karte öffentlich 92, alle Werte im gleichen Verhältnis (gerundet, höchstens 99, Archivierte zählen nicht), Delta auf öffentlicher Skala, eigene Sicht echt plus public, Trainer-Liste echt plus public, Vorschau-Skala (Boxer nur für sich), Skala wandert mit der besten Karte';
END $t$;

-- Rücknahme wörtlich, danach erneut einspielbar
\ir ../supabase/production-prep/rollback_20261029210000_card_scale_92.sql
DO $r$ BEGIN
 IF md5(pg_get_functiondef('public.get_performance_card(text)'::regprocedure)||pg_get_functiondef('league_private.rating_full(uuid)'::regprocedure)
  ||pg_get_functiondef('public.staff_list_performance()'::regprocedure))<>(SELECT fns FROM ref15) THEN RAISE EXCEPTION 'functions not restored'; END IF;
 IF to_regprocedure('league_private.rating_public(jsonb,integer)') IS NOT NULL OR to_regprocedure('public.get_rating_card_scale(uuid)') IS NOT NULL THEN RAISE EXCEPTION 'rollback incomplete'; END IF;
 RAISE NOTICE 'PASS: Rücknahme stellt 20261029090000 wörtlich wieder her';
END $r$;
\ir ../supabase/migrations/20261029210000_card_scale_92.sql
DO $r$ BEGIN
 IF to_regprocedure('league_private.rating_public(jsonb,integer)') IS NULL THEN RAISE EXCEPTION 're-apply'; END IF;
 RAISE NOTICE 'PASS: erneut einspielbar';
END $r$;
