\set ON_ERROR_STOP on
-- Disposable-database test for 20261029180000_card_designs_more_personal.sql (Etappe 12): 12 neue Designs, eigenes Design
-- (Admin schaltet frei, Boxer gestaltet, Server prüft), Rücknahme. Fixture: komplette Karten-Design-Prüfung (Etappen 1 bis 7d).
\ir card-designs-schema.sql
CREATE TEMP TABLE ref12 AS SELECT (SELECT count(*) FROM public.card_design_purchases) AS pur, (SELECT count(*) FROM public.card_awards) AS aw,
 (SELECT string_agg(profile_id::text||design_key,',' ORDER BY profile_id) FROM public.card_design_equipped) AS eq,
 (SELECT count(*)||'/'||coalesce(sum(amount),0) FROM public.kg_ledger) AS led,
 md5(pg_get_functiondef('league_private.card_look(uuid)'::regprocedure)||pg_get_functiondef('league_private.card_design_available(uuid,public.card_designs)'::regprocedure)) AS fns;
GRANT SELECT ON ref12 TO PUBLIC;
\ir ../supabase/production-prep/preflight_20261029180000_card_designs_more_personal.sql
\ir ../supabase/migrations/20261029180000_card_designs_more_personal.sql
\ir ../supabase/migrations/20261029180000_card_designs_more_personal.sql
\ir ../supabase/production-prep/postflight_20261029180000_card_designs_more_personal.sql

DO $t$ DECLARE r jsonb; ok jsonb;
 owner text := '10000000-0000-0000-0000-00000000000a'; coach text := '10000000-0000-0000-0000-00000000000c';
 anna text := '10000000-0000-0000-0000-000000000001'; ben text := '10000000-0000-0000-0000-000000000002';
 annaP uuid := '00000000-0000-0000-0000-000000000001'; benP uuid := '00000000-0000-0000-0000-000000000002';
BEGIN
 PERFORM set_config('role','postgres',true);
 IF (SELECT count(*) FROM public.card_designs)<>26 OR (SELECT count(*) FROM public.card_designs WHERE unlock='shop')<>13 OR (SELECT count(*) FROM public.card_designs WHERE unlock='rank')<>8 THEN RAISE EXCEPTION 'catalog'; END IF;
 IF (SELECT pur FROM ref12)<>(SELECT count(*) FROM public.card_design_purchases) OR (SELECT aw FROM ref12)<>(SELECT count(*) FROM public.card_awards)
    OR (SELECT eq FROM ref12) IS DISTINCT FROM (SELECT string_agg(profile_id::text||design_key,',' ORDER BY profile_id) FROM public.card_design_equipped)
    OR (SELECT led FROM ref12)<>(SELECT count(*)||'/'||coalesce(sum(amount),0) FROM public.kg_ledger) THEN RAISE EXCEPTION 'existing data changed'; END IF;
 BEGIN INSERT INTO public.card_designs(key,name,unlock) VALUES ('xx','Falsch','geheim'); RAISE EXCEPTION 'unlock check'; EXCEPTION WHEN check_violation THEN NULL; END;
 UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key IN ('card_designs','kampfgeist_shop');

 -- Neue Designs im Katalog des Boxers; Rang-Design Stahl ab E für Ben (hoher Rang) frei, eigenes Design gesperrt
 PERFORM pg_temp.act(ben);
 r := public.get_my_card_designs();
 IF (SELECT count(*) FROM jsonb_array_elements(r->'designs'))<>26 THEN RAISE EXCEPTION 'list %', jsonb_array_length(r->'designs'); END IF;
 IF NOT (SELECT (d->>'available')::boolean FROM jsonb_array_elements(r->'designs') d WHERE d->>'key'='stahl') THEN RAISE EXCEPTION 'stahl for ben'; END IF;
 IF (SELECT (d->>'available')::boolean FROM jsonb_array_elements(r->'designs') d WHERE d->>'key'='eigen') THEN RAISE EXCEPTION 'eigen open'; END IF;
 BEGIN PERFORM public.equip_card_design('eigen'); RAISE EXCEPTION 'equip eigen without grant'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 IF (public.get_my_personal_design()->>'granted')::boolean THEN RAISE EXCEPTION 'granted?'; END IF;
 BEGIN PERFORM public.save_my_personal_design('X',jsonb_build_object('a','#000000')); RAISE EXCEPTION 'save without grant'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 -- Neues Shop-Design kaufen (Coins über kg_ledger)
 PERFORM set_config('role','postgres',true);
 INSERT INTO public.kg_ledger(profile_id,amount,reason,ref,note) VALUES (benP,600,'admin','test-600','Test');
 PERFORM pg_temp.act(ben);
 r := public.buy_card_design('comic');
 IF (r->>'price')::int<>450 THEN RAISE EXCEPTION 'buy comic %', r; END IF;
 IF public.equip_card_design('comic')->>'key'<>'comic' THEN RAISE EXCEPTION 'equip comic'; END IF;

 -- Nur der Admin schaltet frei; Trainer und Boxer nicht
 BEGIN PERFORM public.admin_set_personal_design(benP,true); RAISE EXCEPTION 'boxer grants'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM pg_temp.act(coach);
 BEGIN PERFORM public.admin_list_personal_designs(); RAISE EXCEPTION 'coach lists'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM pg_temp.act(owner);
 r := public.admin_set_personal_design(benP,true);
 IF NOT (r->>'active')::boolean THEN RAISE EXCEPTION 'grant'; END IF;
 IF NOT (SELECT (x->>'active')::boolean FROM jsonb_array_elements(public.admin_list_personal_designs()) x WHERE x->>'display_name'='Ben') THEN RAISE EXCEPTION 'list active'; END IF;
 PERFORM set_config('role','postgres',true);
 IF NOT EXISTS (SELECT 1 FROM public.boxer_notifications WHERE recipient_id=benP AND title='Dein eigenes Karten-Design ist freigeschaltet' AND target_path='/karten.html') THEN RAISE EXCEPTION 'notify'; END IF;

 -- Ben gestaltet: strenge Prüfung
 PERFORM pg_temp.act(ben);
 r := public.get_my_personal_design();
 IF NOT (r->>'granted')::boolean OR jsonb_array_length(r->'patterns')<>20 OR (r->>'equipped')::boolean THEN RAISE EXCEPTION 'own %', r; END IF;
 ok := '{"a":"#FF0055","b":"#101010","ink":"#ffffff","edge":"#00ffcc","pattern":"flames","badge":"BEN","glow":true}';
 BEGIN PERFORM public.save_my_personal_design('X',ok); RAISE EXCEPTION 'short name'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.save_my_personal_design('<b>Ben</b>',ok); RAISE EXCEPTION 'html name'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.save_my_personal_design('Bens Karte',ok||'{"a":"red"}'); RAISE EXCEPTION 'color'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.save_my_personal_design('Bens Karte',ok||'{"ink":"#fff;background:url(x)"}'); RAISE EXCEPTION 'css injection'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.save_my_personal_design('Bens Karte',ok||'{"pattern":"x\"><script>"}'); RAISE EXCEPTION 'pattern'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.save_my_personal_design('Bens Karte',ok||'{"badge":"<i>"}'); RAISE EXCEPTION 'badge'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.save_my_personal_design('Bens Karte',ok||'{"badge":"BENJAMIN"}'); RAISE EXCEPTION 'badge long'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.save_my_personal_design('Bens Karte',ok||'{"glow":"yes"}'); RAISE EXCEPTION 'glow'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.save_my_personal_design('Bens Karte',ok||'{"tier":true}'); RAISE EXCEPTION 'unknown field'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.save_my_personal_design('Bens Karte',ok - 'edge'); RAISE EXCEPTION 'missing color'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.save_my_personal_design('Bens Karte',ok - 'pattern'); RAISE EXCEPTION 'missing pattern'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.save_my_personal_design('Bens Karte',ok||'{"pattern":null}'); RAISE EXCEPTION 'null pattern'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.save_my_personal_design('Bens Karte','[]'::jsonb); RAISE EXCEPTION 'array'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.save_my_personal_design(NULL,ok); RAISE EXCEPTION 'null name'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 r := public.save_my_personal_design('  Bens Karte  ',ok);
 IF r->>'name'<>'Bens Karte' OR r->'design'<>'{"a":"#ff0055","b":"#101010","ink":"#ffffff","edge":"#00ffcc","pattern":"flames","badge":"BEN","glow":true}'::jsonb THEN RAISE EXCEPTION 'saved %', r; END IF;
 r := public.save_my_personal_design('Bens Karte',ok||'{"badge":"","glow":false}');
 IF r->'design' ? 'badge' OR r->'design' ? 'glow' THEN RAISE EXCEPTION 'empty badge/glow %', r; END IF;
 PERFORM public.save_my_personal_design('Bens Karte',ok);
 -- Noch Comic ausgewählt; dann eigenes Design auswählen → andere sehen es
 IF public.equip_card_design('eigen')->>'name'<>'Bens Karte' THEN RAISE EXCEPTION 'equip eigen'; END IF;
 PERFORM pg_temp.act(anna);
 r := public.get_card_looks(ARRAY['Ben']);
 IF r->'Ben'->>'key'<>'eigen' OR r->'Ben'->>'name'<>'Bens Karte' OR r->'Ben'->'design'->>'pattern'<>'flames' OR r->'Ben'->'design'->>'badge'<>'BEN' THEN RAISE EXCEPTION 'others see %', r; END IF;
 -- Anna hat kein eigenes Design
 BEGIN PERFORM public.save_my_personal_design('Annas',ok); RAISE EXCEPTION 'anna saves'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;

 -- Entziehen: Gestaltung bleibt gespeichert, Karte fällt auf Klassisch zurück; erneut freischalten bringt sie zurück
 PERFORM pg_temp.act(owner);
 PERFORM public.admin_set_personal_design(benP,false);
 PERFORM pg_temp.act(anna);
 IF public.get_card_looks(ARRAY['Ben'])->'Ben'->>'key'<>'classic' THEN RAISE EXCEPTION 'revoked look'; END IF;
 PERFORM pg_temp.act(ben);
 IF (public.get_my_personal_design()->>'granted')::boolean THEN RAISE EXCEPTION 'revoked granted'; END IF;
 BEGIN PERFORM public.save_my_personal_design('Bens Karte',ok); RAISE EXCEPTION 'save revoked'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM pg_temp.act(owner);
 PERFORM public.admin_set_personal_design(benP,true);
 PERFORM pg_temp.act(anna);
 IF public.get_card_looks(ARRAY['Ben'])->'Ben'->>'name'<>'Bens Karte' THEN RAISE EXCEPTION 'regrant keeps design'; END IF;
 RAISE NOTICE 'PASS: Etappe 12 – 26 Designs, neues Shop-Design kaufbar, eigenes Design nur vom Admin freigeschaltet, Boxer gestaltet mit strenger Prüfung (Farbcodes, Muster, Abzeichen, Name), andere sehen es, Entziehen behält die Gestaltung, bestehende Daten unverändert';
END $t$;

-- Rücknahme: verweigert bei Käufen/eigenen Designs; sonst wörtlich zurück
\set ON_ERROR_STOP off
\ir ../supabase/production-prep/rollback_20261029180000_card_designs_more_personal.sql
\set ON_ERROR_STOP on
DO $r$ BEGIN
 IF to_regclass('public.card_personal_designs') IS NULL THEN RAISE EXCEPTION 'rollback ran despite data'; END IF;
 RAISE NOTICE 'PASS: Rücknahme verweigert bei Käufen und eigenen Designs';
END $r$;
DELETE FROM public.card_personal_designs;
UPDATE public.card_design_equipped SET design_key='classic' WHERE design_key IN ('comic','eigen');
DELETE FROM public.card_design_purchases WHERE design_key='comic';
\ir ../supabase/production-prep/rollback_20261029180000_card_designs_more_personal.sql
DO $r$ BEGIN
 IF md5(pg_get_functiondef('league_private.card_look(uuid)'::regprocedure)||pg_get_functiondef('league_private.card_design_available(uuid,public.card_designs)'::regprocedure))<>(SELECT fns FROM ref12) THEN RAISE EXCEPTION 'functions not restored'; END IF;
 IF (SELECT count(*) FROM public.card_designs)<>13 OR to_regprocedure('public.save_my_personal_design(text,jsonb)') IS NOT NULL THEN RAISE EXCEPTION 'rollback incomplete'; END IF;
 RAISE NOTICE 'PASS: Rücknahme stellt Etappe 7d wörtlich wieder her';
END $r$;
\ir ../supabase/migrations/20261029180000_card_designs_more_personal.sql
DO $r$ BEGIN
 IF (SELECT count(*) FROM public.card_designs)<>26 THEN RAISE EXCEPTION 're-apply'; END IF;
 RAISE NOTICE 'PASS: erneut einspielbar';
END $r$;
