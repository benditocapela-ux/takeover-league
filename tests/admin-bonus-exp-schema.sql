\set ON_ERROR_STOP on
-- Disposable-database test for 20261029240000_admin_bonus_exp.sql (Etappe 18): Bonus-EXP vom Admin, wahlweise mit Monatspunkten,
-- Mitteilung an den Boxer, Rücknahme als Gegenbuchung (nur einmal), Liste. Fixture: Karten-Designs (Etappe 7d) mit Profilen/Mitteilungen.
\ir card-designs-schema.sql
-- Produktionsregeln für neue Buchungen und Mitteilungen (NOT VALID: Fixture-Altdaten bleiben unberührt)
ALTER TABLE public.point_transactions ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now(); -- wie Produktion
ALTER TABLE public.point_transactions ADD CONSTRAINT point_transactions_category_check CHECK (category = ANY (ARRAY['training','trainer_bonus','adjustment','legacy_import','automatic_bonus','achievement_exp','duel_exp','challenge_exp'])) NOT VALID;
ALTER TABLE public.boxer_notifications ADD CONSTRAINT bn_type_check CHECK (notification_type = ANY (ARRAY['training_approved','training_rejected','coach_feedback','coach_goal','league_challenge','boxer_duel','achievement','season','general','level_up'])) NOT VALID;
CREATE TEMP TABLE ref18 AS SELECT (SELECT count(*)||'/'||coalesce(sum(exp),0)||'/'||coalesce(sum(points),0) FROM public.point_transactions) AS pt;
GRANT SELECT ON ref18 TO PUBLIC;
\ir ../supabase/production-prep/preflight_20261029240000_admin_bonus_exp.sql
\ir ../supabase/migrations/20261029240000_admin_bonus_exp.sql
\ir ../supabase/migrations/20261029240000_admin_bonus_exp.sql
\ir ../supabase/production-prep/postflight_20261029240000_admin_bonus_exp.sql

DO $t$ DECLARE r jsonb; l jsonb; b1 uuid; b2 uuid; e0 bigint; p0 bigint; today date := (now() AT TIME ZONE 'Europe/Zurich')::date;
 owner text := '10000000-0000-0000-0000-00000000000a'; coach text := '10000000-0000-0000-0000-00000000000c'; anna text := '10000000-0000-0000-0000-000000000001';
 ownerP uuid := '00000000-0000-0000-0000-00000000000a'; annaP uuid := '00000000-0000-0000-0000-000000000001'; benP uuid := '00000000-0000-0000-0000-000000000002';
 altP uuid := '00000000-0000-0000-0000-000000000004';
BEGIN
 PERFORM set_config('role','postgres',true);
 IF (SELECT pt FROM ref18)<>(SELECT count(*)||'/'||coalesce(sum(exp),0)||'/'||coalesce(sum(points),0) FROM public.point_transactions) THEN RAISE EXCEPTION 'migration changed data'; END IF;
 SELECT coalesce(sum(exp),0),coalesce(sum(points),0) INTO e0,p0 FROM public.point_transactions WHERE boxer_id=annaP;
 -- Nur der Admin
 PERFORM pg_temp.act(coach);
 BEGIN PERFORM public.admin_give_bonus(annaP,25,false,'Feedbackvideo'); RAISE EXCEPTION 'coach gives'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.admin_list_bonuses(); RAISE EXCEPTION 'coach lists'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM pg_temp.act(anna);
 BEGIN PERFORM public.admin_give_bonus(annaP,25,false,'Selbst'); RAISE EXCEPTION 'boxer gives'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM pg_temp.act(owner);
 BEGIN PERFORM public.admin_give_bonus(ownerP,25,false,'Ich selbst'); RAISE EXCEPTION 'self'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.admin_give_bonus(altP,25,false,'Archiviert'); RAISE EXCEPTION 'archived'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.admin_give_bonus(annaP,0,false,'Null'); RAISE EXCEPTION 'zero'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.admin_give_bonus(annaP,501,false,'Zu viel'); RAISE EXCEPTION 'too much'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.admin_give_bonus(annaP,-10,false,'Negativ'); RAISE EXCEPTION 'negative'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.admin_give_bonus(annaP,25,false,'ab'); RAISE EXCEPTION 'short reason'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.admin_give_bonus(annaP,25,false,'<b>x</b>'); RAISE EXCEPTION 'html reason'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.admin_give_bonus(annaP,25,NULL,'Feedbackvideo'); RAISE EXCEPTION 'null points'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 -- Nur EXP
 r := public.admin_give_bonus(annaP,25,false,'  Feedbackvideo geschickt  ');b1 := (r->>'id')::uuid;
 IF (r->>'exp')::int<>25 OR (r->>'points')::int<>0 OR r->>'reason'<>'Feedbackvideo geschickt' THEN RAISE EXCEPTION 'give %', r; END IF;
 -- EXP und Punkte
 r := public.admin_give_bonus(annaP,40,true,'Speziell aufgefallen');b2 := (r->>'id')::uuid;
 IF (r->>'points')::int<>40 THEN RAISE EXCEPTION 'with points %', r; END IF;
 PERFORM set_config('role','postgres',true);
 IF (SELECT coalesce(sum(exp),0) FROM public.point_transactions WHERE boxer_id=annaP)<>e0+65 OR (SELECT coalesce(sum(points),0) FROM public.point_transactions WHERE boxer_id=annaP)<>p0+40 THEN RAISE EXCEPTION 'sums'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.point_transactions WHERE id=b1 AND category='trainer_bonus' AND description='Bonus: Feedbackvideo geschickt' AND effective_date=today AND created_by=ownerP) THEN RAISE EXCEPTION 'tx row'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.boxer_notifications WHERE recipient_id=annaP AND title='Bonus: +25 EXP' AND message='Feedbackvideo geschickt' AND target_path='/boxer.html')
    OR NOT EXISTS (SELECT 1 FROM public.boxer_notifications WHERE recipient_id=annaP AND title='Bonus: +40 EXP' AND message LIKE 'Speziell aufgefallen · auch +40 Punkte%') THEN RAISE EXCEPTION 'notifications'; END IF;
 -- Liste und Rücknahme (Gegenbuchung, nur einmal, nur Boni)
 PERFORM pg_temp.act(owner);
 l := public.admin_list_bonuses();
 r := (SELECT x FROM jsonb_array_elements(l) x WHERE (x->>'id')::uuid=b2);
 IF r->>'reason'<>'Speziell aufgefallen' OR r->>'display_name'<>'Anna' OR (r->>'revoked')::boolean OR r->>'by'<>'Owner' OR jsonb_array_length(l)<2 THEN RAISE EXCEPTION 'list %', r; END IF;
 BEGIN PERFORM public.admin_revoke_bonus(b2,'x'); RAISE EXCEPTION 'short revoke'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 r := public.admin_revoke_bonus(b2,'Falscher Boxer');
 IF (r->>'exp')::int<>-40 OR (r->>'points')::int<>-40 THEN RAISE EXCEPTION 'revoke %', r; END IF;
 BEGIN PERFORM public.admin_revoke_bonus(b2,'Nochmal'); RAISE EXCEPTION 'twice'; EXCEPTION WHEN unique_violation THEN NULL; END;
 BEGIN PERFORM public.admin_revoke_bonus((r->>'revoke_id')::uuid,'Gegenbuchung'); RAISE EXCEPTION 'revoke adjustment'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 l := public.admin_list_bonuses();
 IF NOT (SELECT (x->>'revoked')::boolean AND x->>'revoke_reason'='Falscher Boxer' FROM jsonb_array_elements(l) x WHERE (x->>'id')::uuid=b2)
    OR (SELECT (x->>'revoked')::boolean FROM jsonb_array_elements(l) x WHERE (x->>'id')::uuid=b1) THEN RAISE EXCEPTION 'list revoked %', l; END IF;
 PERFORM set_config('role','postgres',true);
 IF (SELECT coalesce(sum(exp),0) FROM public.point_transactions WHERE boxer_id=annaP)<>e0+25 OR (SELECT coalesce(sum(points),0) FROM public.point_transactions WHERE boxer_id=annaP)<>p0 THEN RAISE EXCEPTION 'sums after revoke'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.point_transactions WHERE id=b2) THEN RAISE EXCEPTION 'bonus row must stay'; END IF;
 IF has_table_privilege('authenticated','public.bonus_revocations','SELECT') THEN RAISE EXCEPTION 'rights'; END IF;
 RAISE NOTICE 'PASS: Etappe 18 – nur Admin, nicht sich selbst/Archivierte, 1–500 EXP, Grund geprüft, nur EXP oder EXP+Punkte, Buchung trainer_bonus mit Datum und Admin, Mitteilung, Liste, Rücknahme als Gegenbuchung nur einmal, Bonus bleibt erhalten';
END $t$;

-- Rücknahme: verweigert, solange Boni zurückgenommen wurden; sonst entfernt sie nur die Funktionen (Boni bleiben)
\set ON_ERROR_STOP off
\ir ../supabase/production-prep/rollback_20261029240000_admin_bonus_exp.sql
\set ON_ERROR_STOP on
DO $r$ BEGIN
 IF to_regclass('public.bonus_revocations') IS NULL THEN RAISE EXCEPTION 'rollback ran despite revocations'; END IF;
 RAISE NOTICE 'PASS: Rücknahme verweigert, solange zurückgenommene Boni existieren';
END $r$;
DELETE FROM public.bonus_revocations;
\ir ../supabase/production-prep/rollback_20261029240000_admin_bonus_exp.sql
DO $r$ BEGIN
 IF to_regprocedure('public.admin_give_bonus(uuid,integer,boolean,text)') IS NOT NULL OR to_regclass('public.bonus_revocations') IS NOT NULL THEN RAISE EXCEPTION 'rollback incomplete'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.point_transactions WHERE category='trainer_bonus') THEN RAISE EXCEPTION 'bonuses must stay'; END IF;
 RAISE NOTICE 'PASS: Rücknahme entfernt die Funktionen, Boni bleiben';
END $r$;
\ir ../supabase/migrations/20261029240000_admin_bonus_exp.sql
DO $r$ BEGIN
 IF to_regprocedure('public.admin_give_bonus(uuid,integer,boolean,text)') IS NULL THEN RAISE EXCEPTION 're-apply'; END IF;
 RAISE NOTICE 'PASS: erneut einspielbar';
END $r$;
