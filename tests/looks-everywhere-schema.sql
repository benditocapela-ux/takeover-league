\set ON_ERROR_STOP on
-- Disposable-database test for 20261029170000_looks_everywhere.sql (Etappe 11): Rang-Rahmen/-Titel als Standard,
-- öffentliche Looks für Rangliste/Podium/Profil/Gäste, Sichtbarkeit, Rücknahme. Fixture: komplette Podium-Emote-Prüfung (Etappen 1 bis 8).
\ir podium-emote-schema.sql
CREATE TEMP TABLE before_look AS
 SELECT p.id, p.display_name, league_private.kg_look(p.id) AS look, md5(pg_get_functiondef('league_private.kg_look(uuid)'::regprocedure)) AS def
 FROM public.profiles p;
CREATE TEMP TABLE before_eq AS SELECT * FROM public.kg_equipped;
GRANT SELECT ON before_look, before_eq TO PUBLIC;
\ir ../supabase/production-prep/preflight_20261029170000_looks_everywhere.sql
\ir ../supabase/migrations/20261029170000_looks_everywhere.sql
\ir ../supabase/migrations/20261029170000_looks_everywhere.sql
\ir ../supabase/production-prep/postflight_20261029170000_looks_everywhere.sql

DO $t$ DECLARE r jsonb; l jsonb; x jsonb; bobP uuid := '00000000-0000-0000-0000-000000000003'; benP uuid := '00000000-0000-0000-0000-000000000002';
BEGIN
 PERFORM set_config('role','postgres',true);
 -- Keine Daten verändert; Rang F und explizite Auswahl: Aussehen identisch wie vorher
 IF EXISTS (SELECT * FROM public.kg_equipped EXCEPT SELECT * FROM before_eq) OR EXISTS (SELECT * FROM before_eq EXCEPT SELECT * FROM public.kg_equipped) THEN RAISE EXCEPTION 'equipment changed'; END IF;
 IF EXISTS (SELECT 1 FROM before_look b WHERE league_private.kg_look(b.id)->>'rank'='F' AND league_private.kg_look(b.id)<>b.look) THEN RAISE EXCEPTION 'rank F look changed'; END IF;
 IF has_function_privilege('authenticated','league_private.kg_look(uuid)','EXECUTE') OR NOT has_function_privilege('anon','public.get_public_boxer_looks()','EXECUTE') THEN RAISE EXCEPTION 'rights'; END IF;

 -- Bob erreicht Rang D: ohne Auswahl Rang-Emblem D und Titel Contender
 INSERT INTO public.point_transactions(boxer_id,points,exp,category,description) VALUES (bobP,0,7000,'test','Rangtest');
 l := league_private.kg_look(bobP);
 IF l->>'rank'<>'D' OR l->'rahmen'->>'key'<>'f_rang_d' OR l->'titel'->>'key'<>'t_contender' OR l->'rahmen'->'design'->>'rk'<>'D' THEN RAISE EXCEPTION 'rank default %', l; END IF;
 IF l->'avatar'->>'key'<>'a_kenji' OR l->'banner'->>'key'<>'b_dojo' OR l->'emote'->>'key'<>'m_respekt' THEN RAISE EXCEPTION 'other defaults changed %', l; END IF;
 -- Bewusst «Schlicht» und «Rookie» gewählt: bleibt so
 INSERT INTO public.kg_equipped(profile_id,rahmen,titel) VALUES (bobP,'f_none','t_rookie') ON CONFLICT (profile_id) DO UPDATE SET rahmen='f_none', titel='t_rookie';
 l := league_private.kg_look(bobP);
 IF l->'rahmen'->>'key'<>'f_none' OR l->'titel'->>'key'<>'t_rookie' THEN RAISE EXCEPTION 'explicit choice overridden %', l; END IF;
 -- Ein tieferes Rang-Emblem (E) bleibt wählbar und sichtbar
 UPDATE public.kg_equipped SET rahmen='f_rang_e', titel=NULL WHERE profile_id=bobP;
 l := league_private.kg_look(bobP);
 IF l->'rahmen'->>'key'<>'f_rang_e' OR l->'titel'->>'key'<>'t_contender' THEN RAISE EXCEPTION 'chosen E frame %', l; END IF;
 -- Nicht besessener Rahmen fällt auf den Rang-Standard zurück
 UPDATE public.kg_equipped SET rahmen='f_srang' WHERE profile_id=bobP;
 IF league_private.kg_look(bobP)->'rahmen'->>'key'<>'f_rang_d' THEN RAISE EXCEPTION 'not owned frame'; END IF;

 -- Öffentlich (ohne Anmeldung): nur sichtbare, aktive, eindeutige Boxer; Rahmen/Titel nur wenn nicht Standard
 PERFORM pg_temp.act(NULL);
 r := public.get_public_boxer_looks();
 IF (SELECT string_agg(e->>'name',',' ORDER BY e->>'name') FROM jsonb_array_elements(r) e)<>'Anna,Ben,Bob,Marco' THEN RAISE EXCEPTION 'anon names %', r; END IF;
 SELECT e INTO x FROM jsonb_array_elements(r) e WHERE e->>'name'='Bob';
 IF x->>'rank'<>'D' OR x->'rahmen'->>'key'<>'f_rang_d' OR x->'rahmen'->'design'->>'fr'<>'rank' OR x->'titel'->>'name'<>'Contender' OR x->'titel'->>'rarity'<>'rare' THEN RAISE EXCEPTION 'bob public %', x; END IF;
 IF x ? 'avatar' OR x ? 'aura' OR x ? 'level' OR r::text ~ 'balance|coins|price' THEN RAISE EXCEPTION 'too much public data %', x; END IF;
 SELECT e INTO x FROM jsonb_array_elements(r) e WHERE e->>'name'='Marco';
 IF x->'rahmen'<>'null'::jsonb OR x->'titel'<>'null'::jsonb OR x->>'rank'<>'F' THEN RAISE EXCEPTION 'rank F public %', x; END IF;
 -- Unsichtbares Profil: Gäste und andere Boxer sehen es nicht, der Boxer selbst und Trainer schon
 PERFORM set_config('role','postgres',true);
 UPDATE public.profiles SET is_listed=false WHERE id=benP;
 PERFORM pg_temp.act(NULL);
 IF public.get_public_boxer_looks()::text LIKE '%"Ben"%' THEN RAISE EXCEPTION 'hidden ben for anon'; END IF;
 PERFORM pg_temp.act('10000000-0000-0000-0000-000000000001');
 IF public.get_public_boxer_looks()::text LIKE '%"Ben"%' THEN RAISE EXCEPTION 'hidden ben for anna'; END IF;
 PERFORM pg_temp.act('10000000-0000-0000-0000-000000000002');
 IF public.get_public_boxer_looks()::text NOT LIKE '%"Ben"%' THEN RAISE EXCEPTION 'ben sees himself'; END IF;
 PERFORM pg_temp.act('10000000-0000-0000-0000-00000000000c');
 IF public.get_public_boxer_looks()::text NOT LIKE '%"Ben"%' THEN RAISE EXCEPTION 'coach sees ben'; END IF;
 -- Doppelte Namen erscheinen nicht
 PERFORM set_config('role','postgres',true);
 UPDATE public.profiles SET is_listed=true WHERE id=benP;
 INSERT INTO public.profiles(id,auth_user_id,display_name,role) VALUES ('00000000-0000-0000-0000-000000000009','10000000-0000-0000-0000-000000000009','anna','boxer');
 PERFORM pg_temp.act(NULL);
 IF public.get_public_boxer_looks()::text ~* '"anna"' THEN RAISE EXCEPTION 'duplicate name shown'; END IF;
 -- Shop aus: leer
 PERFORM set_config('role','postgres',true);
 DELETE FROM public.profiles WHERE id='00000000-0000-0000-0000-000000000009';
 UPDATE public.league_feature_flags SET is_enabled=false WHERE feature_key='kampfgeist_shop';
 PERFORM pg_temp.act(NULL);
 IF public.get_public_boxer_looks()<>'[]'::jsonb THEN RAISE EXCEPTION 'flag off'; END IF;
 PERFORM set_config('role','postgres',true);
 UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='kampfgeist_shop';
 RAISE NOTICE 'PASS: Looks überall – Rang-Rahmen und Rang-Titel ohne Auswahl, bewusste Auswahl bleibt, öffentliche Looks nur sichtbar/eindeutig und nur Design-Daten, Shop aus = leer, keine Daten verändert';
END $t$;

-- Rücknahme: kg_look exakt wie vorher, Funktion weg; danach erneut einspielbar
\ir ../supabase/production-prep/rollback_20261029170000_looks_everywhere.sql
DO $r$ BEGIN
 IF md5(pg_get_functiondef('league_private.kg_look(uuid)'::regprocedure))<>(SELECT DISTINCT def FROM before_look) THEN RAISE EXCEPTION 'kg_look not restored'; END IF;
 IF to_regprocedure('public.get_public_boxer_looks()') IS NOT NULL THEN RAISE EXCEPTION 'function left'; END IF;
 -- Bob hat «Rang S · Gold» gewählt, besitzt es aber nicht: wieder der alte Standard «Schlicht»
 IF league_private.kg_look('00000000-0000-0000-0000-000000000003')->'rahmen'->>'key'<>'f_none' THEN RAISE EXCEPTION 'old default not back'; END IF;
 RAISE NOTICE 'PASS: Rücknahme stellt kg_look identisch wieder her';
END $r$;
\ir ../supabase/migrations/20261029170000_looks_everywhere.sql
DO $r$ BEGIN
 IF to_regprocedure('public.get_public_boxer_looks()') IS NULL THEN RAISE EXCEPTION 're-apply'; END IF;
 RAISE NOTICE 'PASS: erneut einspielbar';
END $r$;
