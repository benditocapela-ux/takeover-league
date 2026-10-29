\set ON_ERROR_STOP on
-- Disposable-database test for 20261030090000_kg_cards_everywhere.sql (Etappe 19): komplette Kampfgeist-Anzeige (Banner, Avatar,
-- Aura, Rahmen, Titel, Handschuhe, Rang, Level) für Ranking, Profil, Studio und Podium. Fixture: Looks überall (Etappe 11).
\ir looks-everywhere-schema.sql
CREATE TEMP TABLE ref19 AS SELECT
 (SELECT count(*)||'/'||md5(coalesce(string_agg(q::text,'|' ORDER BY q.profile_id),'')) FROM public.kg_equipped q) AS eq,
 (SELECT count(*)||'/'||coalesce(sum(exp),0)||'/'||coalesce(sum(points),0) FROM public.point_transactions) AS pt;
GRANT SELECT ON ref19 TO PUBLIC;
\ir ../supabase/production-prep/preflight_20261030090000_kg_cards_everywhere.sql
\ir ../supabase/migrations/20261030090000_kg_cards_everywhere.sql
\ir ../supabase/migrations/20261030090000_kg_cards_everywhere.sql
\ir ../supabase/production-prep/postflight_20261030090000_kg_cards_everywhere.sql

DO $t$ DECLARE r jsonb; x jsonb; lk jsonb; bobP uuid := '00000000-0000-0000-0000-000000000003'; benP uuid := '00000000-0000-0000-0000-000000000002';
BEGIN
 PERFORM set_config('role','postgres',true);
 IF (SELECT eq FROM ref19)<>(SELECT count(*)||'/'||md5(coalesce(string_agg(q::text,'|' ORDER BY q.profile_id),'')) FROM public.kg_equipped q)
    OR (SELECT pt FROM ref19)<>(SELECT count(*)||'/'||coalesce(sum(exp),0)||'/'||coalesce(sum(points),0) FROM public.point_transactions) THEN RAISE EXCEPTION 'data changed'; END IF;
 IF NOT has_function_privilege('anon','public.get_public_boxer_cards()','EXECUTE') THEN RAISE EXCEPTION 'anon rights'; END IF;
 -- Bob wählt Avatar, Aura und Banner
 INSERT INTO public.kg_inventory(profile_id,item_key,price_paid) VALUES (bobP,'b_ember',0) ON CONFLICT DO NOTHING;
 UPDATE public.kg_equipped SET avatar='a_zara', banner='b_ember' WHERE profile_id=bobP;
 lk := league_private.kg_look(bobP);
 IF lk->'avatar'->>'key'<>'a_zara' OR lk->'banner'->>'key'<>'b_ember' THEN RAISE EXCEPTION 'fixture %', lk; END IF;
 -- Gäste: gleiche Personen wie get_public_boxer_looks, komplettes Aussehen nur als Design-Daten
 PERFORM pg_temp.act(NULL);
 r := public.get_public_boxer_cards();
 IF (SELECT string_agg(e->>'name',',' ORDER BY e->>'name') FROM jsonb_array_elements(r) e)
    <>(SELECT string_agg(e->>'name',',' ORDER BY e->>'name') FROM jsonb_array_elements(public.get_public_boxer_looks()) e) THEN RAISE EXCEPTION 'names differ %', r; END IF;
 SELECT e INTO x FROM jsonb_array_elements(r) e WHERE e->>'name'='Bob';
 IF (x->>'level')::int<>(lk->>'level')::int OR x->>'rank'<>lk->>'rank' THEN RAISE EXCEPTION 'level/rank %', x; END IF;
 IF x->'avatar'->>'key'<>lk->'avatar'->>'key' OR x->'banner'->'design'<>lk->'banner'->'design' OR x->'rahmen'->>'key'<>lk->'rahmen'->>'key'
    OR x->'titel'->>'name'<>lk->'titel'->>'name' OR x->'handschuhe'->'design'<>lk->'handschuhe'->'design' OR x->'aura'->>'key'<>lk->'aura'->>'key' THEN RAISE EXCEPTION 'look differs % vs %', x, lk; END IF;
 IF NOT (x->>'own_avatar')::boolean OR x->'banner'->>'key'<>'b_ember' THEN RAISE EXCEPTION 'own_avatar bob %', x; END IF;
 IF r::text ~ '"(price|coins|balance|description|unlock|min_rank|emote|einlauf)"' THEN RAISE EXCEPTION 'too much public data'; END IF;
 -- Ohne eigene Avatar-Wahl: own_avatar false (Seiten zeigen dann das Profilbild)
 SELECT e INTO x FROM jsonb_array_elements(r) e WHERE e->>'name'='Marco';
 IF (x->>'own_avatar')::boolean OR x->'avatar'->>'key'<>'a_kenji' OR x->'banner'->>'key'<>'b_dojo' THEN RAISE EXCEPTION 'defaults %', x; END IF;
 -- Unsichtbar: nur selbst und Trainer
 PERFORM set_config('role','postgres',true);
 UPDATE public.profiles SET is_listed=false WHERE id=benP;
 PERFORM pg_temp.act(NULL);
 IF public.get_public_boxer_cards()::text LIKE '%"Ben"%' THEN RAISE EXCEPTION 'hidden ben anon'; END IF;
 PERFORM pg_temp.act('10000000-0000-0000-0000-000000000001');
 IF public.get_public_boxer_cards()::text LIKE '%"Ben"%' THEN RAISE EXCEPTION 'hidden ben anna'; END IF;
 PERFORM pg_temp.act('10000000-0000-0000-0000-000000000002');
 IF public.get_public_boxer_cards()::text NOT LIKE '%"Ben"%' THEN RAISE EXCEPTION 'ben himself'; END IF;
 PERFORM pg_temp.act('10000000-0000-0000-0000-00000000000c');
 IF public.get_public_boxer_cards()::text NOT LIKE '%"Ben"%' THEN RAISE EXCEPTION 'coach sees ben'; END IF;
 -- Shop aus: leer
 PERFORM set_config('role','postgres',true);
 UPDATE public.profiles SET is_listed=true WHERE id=benP;
 UPDATE public.league_feature_flags SET is_enabled=false WHERE feature_key='kampfgeist_shop';
 PERFORM pg_temp.act(NULL);
 IF public.get_public_boxer_cards()<>'[]'::jsonb THEN RAISE EXCEPTION 'flag off'; END IF;
 PERFORM set_config('role','postgres',true);
 UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='kampfgeist_shop';
 RAISE NOTICE 'PASS: Etappe 19 – Kartenliste wie kg_look (Banner, Avatar, Aura, Rahmen, Titel, Handschuhe, Rang, Level), own_avatar nur bei eigener Wahl, nur Design-Daten, Sichtbarkeit wie öffentliche Looks, Shop aus = leer, keine Daten verändert';
END $t$;

\ir ../supabase/production-prep/rollback_20261030090000_kg_cards_everywhere.sql
DO $r$ BEGIN
 IF to_regprocedure('public.get_public_boxer_cards()') IS NOT NULL OR to_regprocedure('public.get_public_boxer_looks()') IS NULL THEN RAISE EXCEPTION 'rollback'; END IF;
 RAISE NOTICE 'PASS: Rücknahme entfernt nur die Kartenliste';
END $r$;
\ir ../supabase/migrations/20261030090000_kg_cards_everywhere.sql
DO $r$ BEGIN
 IF to_regprocedure('public.get_public_boxer_cards()') IS NULL THEN RAISE EXCEPTION 're-apply'; END IF;
 RAISE NOTICE 'PASS: erneut einspielbar';
END $r$;
