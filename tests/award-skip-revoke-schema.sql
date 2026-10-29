\set ON_ERROR_STOP on
-- Disposable-database test for 20261029200000_award_skip_revoke.sql (Etappe 14): «Diesmal nicht vergeben» (Trainer/Admin,
-- abgeschlossene Zeiträume, schliesst Vergeben aus, aufheben durch wer es gewählt hat oder Admin), Übersicht mit kürzlich
-- vergebenen Auszeichnungen zum Zurückziehen, Rücknahme wörtlich. Fixture: Karten-Designs bis Etappe 13.
\ir award-designs-limited-schema.sql
CREATE TEMP TABLE ref14 AS SELECT
 md5(pg_get_functiondef('public.staff_card_award_overview()'::regprocedure)||pg_get_functiondef('public.staff_confirm_card_award(text,date,uuid,text)'::regprocedure)) AS fns,
 (SELECT count(*)||'/'||coalesce(sum(exp),0)||'/'||coalesce(sum(points),0) FROM public.point_transactions) AS pt,
 (SELECT count(*)||'/'||coalesce(sum(amount),0) FROM public.kg_ledger) AS led,
 (SELECT string_agg(id::text||coalesce(revoked_at::text,'-'),',' ORDER BY id) FROM public.card_awards) AS aw;
GRANT SELECT ON ref14 TO PUBLIC;
\ir ../supabase/production-prep/preflight_20261029200000_award_skip_revoke.sql
\ir ../supabase/migrations/20261029200000_award_skip_revoke.sql
\ir ../supabase/migrations/20261029200000_award_skip_revoke.sql
\ir ../supabase/production-prep/postflight_20261029200000_award_skip_revoke.sql

DO $t$ DECLARE r jsonb; o jsonb; today date := (now() AT TIME ZONE 'Europe/Zurich')::date; cw date; lw date; lm date; sid bigint; aid bigint;
 owner text := '10000000-0000-0000-0000-00000000000a'; coach text := '10000000-0000-0000-0000-00000000000c';
 anna text := '10000000-0000-0000-0000-000000000001';
 annaP uuid := '00000000-0000-0000-0000-000000000001'; benP uuid := '00000000-0000-0000-0000-000000000002';
BEGIN
 PERFORM set_config('role','postgres',true);
 cw := today - (extract(isodow FROM today)::integer-1); lw := cw-7; lm := (date_trunc('month',today)-interval '1 month')::date;
 IF (SELECT aw FROM ref14) IS DISTINCT FROM (SELECT string_agg(id::text||coalesce(revoked_at::text,'-'),',' ORDER BY id) FROM public.card_awards) THEN RAISE EXCEPTION 'awards changed by migration'; END IF;

 -- Boxer darf nicht
 PERFORM pg_temp.act(anna);
 BEGIN PERFORM public.staff_skip_card_award('cotw',lw-21); RAISE EXCEPTION 'boxer skips'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.staff_card_award_overview(); RAISE EXCEPTION 'boxer overview'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;

 -- Trainer: nur abgeschlossene, ausgerichtete, nicht zu alte Zeiträume ohne Auszeichnung
 PERFORM pg_temp.act(coach);
 BEGIN PERFORM public.staff_skip_card_award('cotw',cw); RAISE EXCEPTION 'running'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.staff_skip_card_award('cotw',lw+1); RAISE EXCEPTION 'not monday'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.staff_skip_card_award('cotw',lw-77); RAISE EXCEPTION 'too old'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.staff_skip_card_award('xx',lw); RAISE EXCEPTION 'kind'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.staff_skip_card_award('cotw',lw-21,repeat('x',301)); RAISE EXCEPTION 'note'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.staff_skip_card_award('cotw',lw); RAISE EXCEPTION 'skip with award'; EXCEPTION WHEN unique_violation THEN NULL; END;
 r := public.staff_skip_card_award('cotw',lw-21,'  Ferienwoche  ');
 sid := (r->>'id')::bigint;
 IF r->>'note'<>'Ferienwoche' OR r->>'skipped_by'<>'Marco' OR NOT (r->>'can_undo')::boolean OR (r->>'period_end')::date<>lw-15 THEN RAISE EXCEPTION 'skip json %', r; END IF;
 BEGIN PERFORM public.staff_skip_card_award('cotw',lw-21); RAISE EXCEPTION 'twice'; EXCEPTION WHEN unique_violation THEN NULL; END;
 BEGIN PERFORM public.staff_confirm_card_award('cotw',lw-21,annaP); RAISE EXCEPTION 'confirm while skipped'; EXCEPTION WHEN unique_violation THEN NULL; END;

 -- Admin nimmt Annas Card of the Month zurück und wählt für den Monat «nicht vergeben»; der Trainer darf das nicht aufheben
 PERFORM pg_temp.act(owner);
 PERFORM public.staff_revoke_card_award((SELECT (x->>'id')::bigint FROM jsonb_array_elements(public.staff_card_award_overview()->'recent') x WHERE x->>'kind'='cotm' AND (x->>'period_start')::date=lm),'Doppelt gezählt');
 r := public.staff_skip_card_award('cotm',lm);
 PERFORM pg_temp.act(coach);
 BEGIN PERFORM public.staff_unskip_card_award((r->>'id')::bigint); RAISE EXCEPTION 'coach undoes admin skip'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 o := public.staff_card_award_overview();
 r := (SELECT k->'periods'->0 FROM jsonb_array_elements(o->'kinds') k WHERE k->>'kind'='cotm');
 IF r->'skip' IS NULL OR r->'skip'='null'::jsonb OR (r->'skip'->>'can_undo')::boolean OR r->'award'<>'null'::jsonb THEN RAISE EXCEPTION 'overview skip %', r; END IF;
 IF (SELECT count(*) FROM jsonb_array_elements(o->'skips'))<>2 THEN RAISE EXCEPTION 'skips list %', o->'skips'; END IF;
 IF (SELECT k->'periods'->1->'skip' FROM jsonb_array_elements(o->'kinds') k WHERE k->>'kind'='cotw')<>'null'::jsonb THEN RAISE EXCEPTION 'running skip'; END IF;
 -- Kürzlich vergeben: auch ältere Auszeichnungen, zurückziehen nur wer vergeben hat (sonst Admin)
 IF (SELECT count(*) FROM jsonb_array_elements(o->'recent') x WHERE x->>'kind'='cotw' AND (x->>'period_start')::date<lw)<1 THEN RAISE EXCEPTION 'older awards listed %', o->'recent'; END IF;
 IF EXISTS (SELECT 1 FROM jsonb_array_elements(o->'recent') x WHERE (x->>'revoked')::boolean) THEN RAISE EXCEPTION 'revoked listed'; END IF;
 IF NOT (SELECT bool_and((x->>'can_revoke')::boolean) FROM jsonb_array_elements(o->'recent') x WHERE x->>'awarded_by'='Marco')
    OR (SELECT bool_or((x->>'can_revoke')::boolean) FROM jsonb_array_elements(o->'recent') x WHERE x->>'awarded_by'<>'Marco') THEN RAISE EXCEPTION 'can_revoke %', o->'recent'; END IF;
 -- Ältere Card of the Week (vor zwei Wochen) zurückziehen → Symbol und Design weg
 aid := (SELECT (x->>'id')::bigint FROM jsonb_array_elements(o->'recent') x WHERE x->>'kind'='cotw' AND x->>'display_name'='Anna' AND (x->>'can_revoke')::boolean LIMIT 1);
 IF aid IS NULL THEN RAISE EXCEPTION 'anna older cotw missing'; END IF;
 PERFORM public.staff_revoke_card_award(aid,'Falsch eingetragen');
 PERFORM set_config('role','postgres',true);
 IF EXISTS (SELECT 1 FROM jsonb_array_elements(league_private.card_look(annaP)->'awards') a WHERE a->>'kind'='cotw') THEN RAISE EXCEPTION 'symbol after revoke'; END IF;

 -- Aufheben: wer es gewählt hat; danach kann vergeben werden. Verlauf bleibt.
 PERFORM pg_temp.act(coach);
 r := public.staff_unskip_card_award(sid);
 BEGIN PERFORM public.staff_unskip_card_award(sid); RAISE EXCEPTION 'undo twice'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 r := public.staff_confirm_card_award('cotw',lw-21,annaP);
 BEGIN PERFORM public.staff_skip_card_award('cotw',lw-21); RAISE EXCEPTION 'skip after confirm'; EXCEPTION WHEN unique_violation THEN NULL; END;
 PERFORM set_config('role','postgres',true);
 IF (SELECT count(*) FROM public.card_award_skips)<>2 OR (SELECT count(*) FROM public.card_award_skips WHERE undone_at IS NOT NULL AND undone_by='00000000-0000-0000-0000-00000000000c')<>1 THEN RAISE EXCEPTION 'skip history'; END IF;
 IF (SELECT pt FROM ref14)<>(SELECT count(*)||'/'||coalesce(sum(exp),0)||'/'||coalesce(sum(points),0) FROM public.point_transactions)
    OR (SELECT led FROM ref14)<>(SELECT count(*)||'/'||coalesce(sum(amount),0) FROM public.kg_ledger) THEN RAISE EXCEPTION 'points or coins changed'; END IF;
 RAISE NOTICE 'PASS: Etappe 14 – «nicht vergeben» nur Trainer/Admin für abgeschlossene Zeiträume ohne Auszeichnung, sperrt Vergeben, Aufheben nur wer es gewählt hat oder Admin (Verlauf bleibt), Übersicht zeigt «nicht vergeben» und alle kürzlich vergebenen Auszeichnungen, ältere zurückziehen nimmt Design und Symbol, Punkte und Coins unverändert';
END $t$;

-- Rücknahme: verweigert, solange «nicht vergeben» benutzt wurde; sonst wörtlich zurück, erneut einspielbar
\set ON_ERROR_STOP off
\ir ../supabase/production-prep/rollback_20261029200000_award_skip_revoke.sql
\set ON_ERROR_STOP on
DO $r$ BEGIN
 IF to_regclass('public.card_award_skips') IS NULL THEN RAISE EXCEPTION 'rollback ran despite skips'; END IF;
 RAISE NOTICE 'PASS: Rücknahme verweigert, wenn «nicht vergeben» benutzt wurde';
END $r$;
DELETE FROM public.card_award_skips;
\ir ../supabase/production-prep/rollback_20261029200000_award_skip_revoke.sql
DO $r$ BEGIN
 IF md5(pg_get_functiondef('public.staff_card_award_overview()'::regprocedure)||pg_get_functiondef('public.staff_confirm_card_award(text,date,uuid,text)'::regprocedure))<>(SELECT fns FROM ref14) THEN RAISE EXCEPTION 'functions not restored'; END IF;
 IF to_regclass('public.card_award_skips') IS NOT NULL OR to_regprocedure('public.staff_skip_card_award(text,date,text)') IS NOT NULL THEN RAISE EXCEPTION 'rollback incomplete'; END IF;
 RAISE NOTICE 'PASS: Rücknahme stellt Übersicht (7d) und Vergeben (Etappe 13) wörtlich wieder her';
END $r$;
\ir ../supabase/migrations/20261029200000_award_skip_revoke.sql
DO $r$ BEGIN
 IF to_regclass('public.card_award_skips') IS NULL THEN RAISE EXCEPTION 're-apply'; END IF;
 RAISE NOTICE 'PASS: erneut einspielbar';
END $r$;
