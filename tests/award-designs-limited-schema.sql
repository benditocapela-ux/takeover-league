\set ON_ERROR_STOP on
-- Disposable-database test for 20261029190000_award_designs_limited.sql (Etappe 13): Auszeichnungs-Designs gelten nur im
-- Folgezeitraum (Woche / Monat / Jahr nach dem gewonnenen), Symbole bleiben, Mitteilung nennt das Enddatum, Rücknahme wörtlich.
-- Fixture: komplette Karten-Design-Prüfung bis Etappe 12.
\ir card-designs-personal-schema.sql
CREATE TEMP TABLE ref13 AS SELECT
 md5(pg_get_functiondef('league_private.card_design_available(uuid,public.card_designs)'::regprocedure)
  ||pg_get_functiondef('league_private.card_award_json(public.card_awards)'::regprocedure)||pg_get_functiondef('public.get_my_card_designs()'::regprocedure)
  ||pg_get_functiondef('public.staff_confirm_card_award(text,date,uuid,text)'::regprocedure)) AS fns,
 (SELECT count(*)||'/'||coalesce(sum(exp),0)||'/'||coalesce(sum(points),0) FROM public.point_transactions) AS pt,
 (SELECT count(*)||'/'||coalesce(sum(amount),0) FROM public.kg_ledger) AS led,
 (SELECT string_agg(id::text||coalesce(revoked_at::text,'-'),',' ORDER BY id) FROM public.card_awards) AS aw,
 (SELECT string_agg(profile_id::text||design_key,',' ORDER BY profile_id) FROM public.card_design_equipped) AS eq;
GRANT SELECT ON ref13 TO PUBLIC;
\ir ../supabase/production-prep/preflight_20261029190000_award_designs_limited.sql
\ir ../supabase/migrations/20261029190000_award_designs_limited.sql
\ir ../supabase/migrations/20261029190000_award_designs_limited.sql
\ir ../supabase/production-prep/postflight_20261029190000_award_designs_limited.sql

DO $t$ DECLARE r jsonb; d jsonb; today date := (now() AT TIME ZONE 'Europe/Zurich')::date; cw date; lw date; ly date; mend date; yend date; bid bigint;
 owner text := '10000000-0000-0000-0000-00000000000a'; coach text := '10000000-0000-0000-0000-00000000000c';
 anna text := '10000000-0000-0000-0000-000000000001'; ben text := '10000000-0000-0000-0000-000000000002'; bob text := '10000000-0000-0000-0000-000000000003';
 annaP uuid := '00000000-0000-0000-0000-000000000001'; benP uuid := '00000000-0000-0000-0000-000000000002'; bobP uuid := '00000000-0000-0000-0000-000000000003';
 coachP uuid := '00000000-0000-0000-0000-00000000000c';
BEGIN
 PERFORM set_config('role','postgres',true);
 cw := today - (extract(isodow FROM today)::integer-1); lw := cw-7; ly := (date_trunc('year',today)-interval '1 year')::date;
 mend := (date_trunc('month',today)+interval '1 month -1 day')::date; yend := (date_trunc('year',today)+interval '1 year -1 day')::date;
 -- Bestehende Daten durch die Migration unverändert
 IF (SELECT pt FROM ref13)<>(SELECT count(*)||'/'||coalesce(sum(exp),0)||'/'||coalesce(sum(points),0) FROM public.point_transactions)
    OR (SELECT led FROM ref13)<>(SELECT count(*)||'/'||coalesce(sum(amount),0) FROM public.kg_ledger)
    OR (SELECT aw FROM ref13) IS DISTINCT FROM (SELECT string_agg(id::text||coalesce(revoked_at::text,'-'),',' ORDER BY id) FROM public.card_awards)
    OR (SELECT eq FROM ref13) IS DISTINCT FROM (SELECT string_agg(profile_id::text||design_key,',' ORDER BY profile_id) FROM public.card_design_equipped) THEN
  RAISE EXCEPTION 'existing data changed';
 END IF;
 -- Gültigkeitsfenster: immer der Zeitraum direkt danach (Wochen-, Monats-, Jahreswechsel)
 IF league_private.card_award_window(jsonb_populate_record(NULL::public.card_awards,'{"kind":"cotw","period_start":"2026-10-19","period_end":"2026-10-25"}'))<>daterange('2026-10-26','2026-11-02')
    OR league_private.card_award_window(jsonb_populate_record(NULL::public.card_awards,'{"kind":"cotw","period_start":"2026-12-28","period_end":"2027-01-03"}'))<>daterange('2027-01-04','2027-01-11')
    OR league_private.card_award_window(jsonb_populate_record(NULL::public.card_awards,'{"kind":"cotm","period_start":"2026-01-01","period_end":"2026-01-31"}'))<>daterange('2026-02-01','2026-03-01')
    OR league_private.card_award_window(jsonb_populate_record(NULL::public.card_awards,'{"kind":"cotm","period_start":"2025-12-01","period_end":"2025-12-31"}'))<>daterange('2026-01-01','2026-02-01')
    OR league_private.card_award_window(jsonb_populate_record(NULL::public.card_awards,'{"kind":"poty","period_start":"2025-01-01","period_end":"2025-12-31"}'))<>daterange('2026-01-01','2027-01-01') THEN
  RAISE EXCEPTION 'window';
 END IF;
 -- Ausgangslage aus der Fixture: Ben Card of the Week letzte Woche, Anna Card of the Month letzter Monat.
 -- Dazu: Anna Card of the Week vor zwei Wochen (abgelaufen), Ben Player of the Year letztes Jahr (gilt), Anna POTY vorletztes Jahr (abgelaufen).
 INSERT INTO public.card_awards(kind,period_start,period_end,profile_id,exp_in_period,awarded_by) VALUES
  ('cotw',lw-7,lw-1,annaP,0,coachP),('poty',ly,(ly+interval '1 year -1 day')::date,benP,0,coachP),
  ('poty',(ly-interval '1 year')::date,ly-1,annaP,0,coachP);
 INSERT INTO public.card_design_equipped(profile_id,design_key) VALUES (annaP,'cotw') ON CONFLICT (profile_id) DO UPDATE SET design_key='cotw';

 PERFORM pg_temp.act(anna);
 r := public.get_my_card_designs();
 SELECT x INTO d FROM jsonb_array_elements(r->'designs') x WHERE x->>'key'='cotw';
 IF (d->>'available')::boolean OR (d->>'won')::int<>1 OR d->'valid_until'<>'null'::jsonb THEN RAISE EXCEPTION 'anna cotw expired %', d; END IF;
 SELECT x INTO d FROM jsonb_array_elements(r->'designs') x WHERE x->>'key'='cotm';
 IF NOT (d->>'available')::boolean OR (d->>'valid_until')::date<>mend THEN RAISE EXCEPTION 'anna cotm valid %', d; END IF;
 SELECT x INTO d FROM jsonb_array_elements(r->'designs') x WHERE x->>'key'='poty';
 IF (d->>'available')::boolean OR (d->>'won')::int<>1 THEN RAISE EXCEPTION 'anna poty expired %', d; END IF;
 IF (SELECT count(*) FROM jsonb_array_elements(r->'designs') x WHERE x ? 'valid_until' AND x->>'unlock'<>'award' AND x->'valid_until'<>'null'::jsonb)<>0 THEN RAISE EXCEPTION 'valid_until only for awards'; END IF;
 -- Abgelaufene Auswahl → Klassisch; Symbole (Auszeichnungen) bleiben
 IF r->'look'->>'key'<>'classic' THEN RAISE EXCEPTION 'expired look %', r->'look'->>'key'; END IF;
 IF (SELECT count(*) FROM jsonb_array_elements(r->'look'->'awards') a WHERE a->>'kind' IN ('cotw','poty'))<>2 OR jsonb_array_length(r->'look'->'awards')<>3 THEN RAISE EXCEPTION 'symbols %', r->'look'->'awards'; END IF;
 BEGIN PERFORM public.equip_card_design('cotw'); RAISE EXCEPTION 'equip expired'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 IF public.equip_card_design('cotm')->>'key'<>'cotm' THEN RAISE EXCEPTION 'equip valid'; END IF;

 PERFORM pg_temp.act(ben);
 r := public.get_my_card_designs();
 SELECT x INTO d FROM jsonb_array_elements(r->'designs') x WHERE x->>'key'='cotw';
 IF NOT (d->>'available')::boolean OR (d->>'valid_until')::date<>cw+6 THEN RAISE EXCEPTION 'ben cotw %', d; END IF;
 SELECT x INTO d FROM jsonb_array_elements(r->'designs') x WHERE x->>'key'='poty';
 IF NOT (d->>'available')::boolean OR (d->>'valid_until')::date<>yend THEN RAISE EXCEPTION 'ben poty %', d; END IF;
 SELECT x INTO d FROM jsonb_array_elements(r->'designs') x WHERE x->>'key'='cotm';
 IF (d->>'available')::boolean OR (d->>'won')::int<>0 THEN RAISE EXCEPTION 'ben cotm %', d; END IF;
 IF public.get_card_looks(ARRAY['Anna'])->'Anna'->>'key'<>'cotm' THEN RAISE EXCEPTION 'others see'; END IF;
 r := public.get_card_awards();
 IF (r->'latest'->'cotw'->>'design_until')::date<>cw+6 OR (r->'latest'->'cotw'->>'design_from')::date<>cw THEN RAISE EXCEPTION 'award json %', r->'latest'->'cotw'; END IF;

 -- Vergeben: Mitteilung nennt das Enddatum; liegt das Fenster schon zurück, kein Datum.
 PERFORM set_config('role','postgres',true);
 SELECT id INTO bid FROM public.card_awards WHERE kind='cotw' AND period_start=lw AND revoked_at IS NULL;
 PERFORM pg_temp.act(owner);
 PERFORM public.staff_revoke_card_award(bid,'Test Etappe 13');
 PERFORM pg_temp.act(coach);
 r := public.staff_confirm_card_award('cotw',lw,bobP,'Stark');
 IF (r->>'design_until')::date<>cw+6 THEN RAISE EXCEPTION 'confirm json %', r; END IF;
 r := public.staff_confirm_card_award('cotw',lw-14,bobP);
 PERFORM set_config('role','postgres',true);
 IF NOT EXISTS (SELECT 1 FROM public.boxer_notifications WHERE recipient_id=bobP AND message LIKE '%Dein Spezial-Design gilt bis '||to_char(cw+6,'DD.MM.YYYY')||'.%«Stark»') THEN RAISE EXCEPTION 'message with date'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.boxer_notifications WHERE recipient_id=bobP AND message LIKE '%('||to_char(lw-14,'DD.MM.YYYY')||'%' AND message NOT LIKE '%gilt bis%') THEN RAISE EXCEPTION 'message without date'; END IF;
 PERFORM pg_temp.act(ben);
 IF (SELECT (x->>'available')::boolean FROM jsonb_array_elements(public.get_my_card_designs()->'designs') x WHERE x->>'key'='cotw') THEN RAISE EXCEPTION 'revoked still valid'; END IF;
 PERFORM pg_temp.act(bob);
 IF NOT (SELECT (x->>'available')::boolean FROM jsonb_array_elements(public.get_my_card_designs()->'designs') x WHERE x->>'key'='cotw') THEN RAISE EXCEPTION 'bob valid'; END IF;
 PERFORM set_config('role','postgres',true);
 IF (SELECT pt FROM ref13)<>(SELECT count(*)||'/'||coalesce(sum(exp),0)||'/'||coalesce(sum(points),0) FROM public.point_transactions)
    OR (SELECT led FROM ref13)<>(SELECT count(*)||'/'||coalesce(sum(amount),0) FROM public.kg_ledger) THEN RAISE EXCEPTION 'points or coins changed'; END IF;
 RAISE NOTICE 'PASS: Etappe 13 – Auszeichnungs-Designs nur im Folgezeitraum (Woche, Monat, Jahr; Jahres- und Monatswechsel), abgelaufene Auswahl fällt auf Klassisch, Symbole bleiben, gilt-bis im Katalog und in den Auszeichnungen, Mitteilung mit Enddatum, Zurücknehmen beendet sofort, Punkte und Coins unverändert';
END $t$;

-- Rücknahme: wörtlich Etappe 12 / 7d, danach erneut einspielbar
\ir ../supabase/production-prep/rollback_20261029190000_award_designs_limited.sql
DO $r$ BEGIN
 IF md5(pg_get_functiondef('league_private.card_design_available(uuid,public.card_designs)'::regprocedure)
  ||pg_get_functiondef('league_private.card_award_json(public.card_awards)'::regprocedure)||pg_get_functiondef('public.get_my_card_designs()'::regprocedure)
  ||pg_get_functiondef('public.staff_confirm_card_award(text,date,uuid,text)'::regprocedure))<>(SELECT fns FROM ref13) THEN RAISE EXCEPTION 'functions not restored'; END IF;
 IF to_regprocedure('league_private.card_award_until(uuid,text)') IS NOT NULL OR to_regprocedure('league_private.card_award_window(public.card_awards)') IS NOT NULL THEN RAISE EXCEPTION 'helpers left'; END IF;
 RAISE NOTICE 'PASS: Rücknahme stellt Etappe 12 / 7d wörtlich wieder her';
END $r$;
\ir ../supabase/migrations/20261029190000_award_designs_limited.sql
DO $r$ BEGIN
 IF to_regprocedure('league_private.card_award_until(uuid,text)') IS NULL THEN RAISE EXCEPTION 're-apply'; END IF;
 RAISE NOTICE 'PASS: erneut einspielbar';
END $r$;
