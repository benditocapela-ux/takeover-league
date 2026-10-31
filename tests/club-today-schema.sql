\set ON_ERROR_STOP on
-- Disposable-database test for 20261031100000_scheduled_club_training_quick_request.sql (einheitlicher Vereins-Check-in, PR #84).
-- Baut auf tests/training-v2-schema.sql auf. Prüft jeden Rückgabestatus gegen das tatsächliche Datenbankergebnis und das
-- Zusammenspiel mit gym_check_in, staff_confirm_gym_session und staff_review_training. Keine echten Konten, keine Produktion.
\ir training-v2-schema.sql

-- Test-Boxer ohne Fixture-Trainings am heutigen Tag
INSERT INTO public.profiles(id,auth_user_id,display_name,role,is_active)
SELECT ('00000000-0000-0000-0000-0000000000'||n)::uuid, ('20000000-0000-0000-0000-0000000000'||n)::uuid, 'Quick '||n, 'boxer', true
FROM unnest(ARRAY['51','52','53','54','55','56','57']) n;

\ir ../supabase/migrations/20261031100000_scheduled_club_training_quick_request.sql
\ir ../supabase/migrations/20261031100000_scheduled_club_training_quick_request.sql
CREATE TEMP TABLE ref_confirm AS SELECT md5(pg_get_functiondef('public.staff_confirm_gym_session(bigint)'::regprocedure)) AS fp;
GRANT SELECT ON ref_confirm TO PUBLIC;
\ir ../supabase/migrations/20261031110000_gym_confirm_day_lock.sql
\ir ../supabase/migrations/20261031110000_gym_confirm_day_lock.sql

CREATE FUNCTION pg_temp.q(p_auth text, p_slot integer DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql AS $fn$
DECLARE r jsonb; BEGIN PERFORM pg_temp.act(p_auth); r := public.submit_scheduled_club_training_today(p_slot); PERFORM set_config('role','postgres',true); RETURN r; END $fn$;
CREATE FUNCTION pg_temp.subs(p uuid) RETURNS integer LANGUAGE sql AS $fn$ SELECT count(*)::integer FROM public.training_submissions x WHERE x.boxer_id=p AND x.training_date=league_private.zurich_today() $fn$;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA pg_temp TO PUBLIC;

-- Schalter aus → disabled, nichts geschrieben; Trainer und Gäste haben keinen Zugriff
DO $t$ DECLARE r jsonb; BEGIN
 PERFORM set_config('role','postgres',true);
 r := pg_temp.q('20000000-0000-0000-0000-000000000051');
 IF r->>'status'<>'disabled' OR pg_temp.subs('00000000-0000-0000-0000-000000000051')<>0 THEN RAISE EXCEPTION 'disabled %', r; END IF;
 BEGIN PERFORM pg_temp.q('10000000-0000-0000-0000-00000000000c'); RAISE EXCEPTION 'coach allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM set_config('role','postgres',true);
 BEGIN PERFORM pg_temp.act(NULL); PERFORM public.submit_scheduled_club_training_today(NULL); RAISE EXCEPTION 'anon allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM set_config('role','postgres',true);
 RAISE NOTICE 'PASS Q0: Schalter aus = disabled ohne Schreibzugriff; Trainer und Gäste abgewiesen';
END $t$;

\ir ../supabase/production-prep/activate_20261031090000_training_v2.sql
-- Heute muss eine Pflichteinheit im Stundenplan stehen (der Test läuft an jedem Wochentag)
INSERT INTO public.club_schedule(dow,training_type_id,tier,label,duration_minutes,sort_order)
SELECT extract(isodow FROM league_private.zurich_today())::integer, t.id, 'pflicht', 'Reguläres Boxtraining', 90, 0
FROM public.training_types t WHERE t.name='Reguläres Boxtraining'
 AND NOT EXISTS (SELECT 1 FROM public.club_schedule x WHERE x.is_active AND x.tier='pflicht' AND x.dow=extract(isodow FROM league_private.zurich_today())::integer);

DO $t$ DECLARE r jsonb; r2 jsonb; sid uuid; slot integer; slot2 integer; other integer; reg bigint; today date := league_private.zurich_today();
 coach text := '10000000-0000-0000-0000-00000000000c';
 a1 text := '20000000-0000-0000-0000-000000000051'; p1 uuid := '00000000-0000-0000-0000-000000000051';
 a2 text := '20000000-0000-0000-0000-000000000052'; p2 uuid := '00000000-0000-0000-0000-000000000052';
BEGIN
 PERFORM set_config('role','postgres',true);
 SELECT id INTO reg FROM public.training_types WHERE name='Reguläres Boxtraining';
 SELECT id INTO slot FROM public.club_schedule WHERE is_active AND tier='pflicht' AND dow=extract(isodow FROM today)::integer ORDER BY sort_order,id LIMIT 1;
 SELECT id INTO other FROM public.club_schedule WHERE is_active AND tier='pflicht' AND dow<>extract(isodow FROM today)::integer ORDER BY id LIMIT 1;
 -- submitted: nur ein Antrag (offen, ohne Stufe, ohne Buchung), Art und Einheit vom Server
 r := pg_temp.q(a1);
 SELECT id INTO sid FROM public.training_submissions WHERE boxer_id=p1 AND training_date=today;
 IF r->>'status'<>'submitted' OR (r->>'submission_id')::uuid<>sid THEN RAISE EXCEPTION 'submitted %', r; END IF;
 IF (SELECT status||':'||training_type_id||':'||requested_slot_id||':'||requested_tier||':'||coalesce(club_tier,'-')||':'||training_location FROM public.training_submissions WHERE id=sid)
    <>'pending:'||reg||':'||slot||':pflicht:-:club' OR pg_temp.ntx(sid)<>0 THEN RAISE EXCEPTION 'submitted row'; END IF;
 -- doppelt tippen → already_pending, kein zweiter Eintrag
 r := pg_temp.q(a1);
 IF r->>'status'<>'already_pending' OR (r->>'submission_id')::uuid<>sid OR pg_temp.subs(p1)<>1 THEN RAISE EXCEPTION 'already_pending %', r; END IF;
 -- fremde Einheit (anderer Wochentag) kann nicht gewählt werden
 IF other IS NOT NULL THEN BEGIN PERFORM pg_temp.q(a2, other); RAISE EXCEPTION 'foreign slot accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END; END IF;
 PERFORM set_config('role','postgres',true);
 IF pg_temp.subs(p2)<>0 THEN RAISE EXCEPTION 'foreign slot wrote'; END IF;
 -- Trainer bestätigt → Pflicht 60, danach already_approved
 PERFORM pg_temp.act(coach); r2 := public.staff_review_training(sid,'approved'); PERFORM set_config('role','postgres',true);
 IF pg_temp.pts(sid)<>60 OR pg_temp.coins(sid)<>15 THEN RAISE EXCEPTION 'approval value %', pg_temp.pts(sid); END IF;
 r := pg_temp.q(a1);
 IF r->>'status'<>'already_approved' OR pg_temp.subs(p1)<>1 OR pg_temp.ntx(sid)<>1 THEN RAISE EXCEPTION 'already_approved %', r; END IF;
 -- no_slot
 UPDATE public.club_schedule SET is_active=false WHERE id=slot;
 r := pg_temp.q(a2);
 IF r->>'status'<>'no_slot' OR pg_temp.subs(p2)<>0 THEN RAISE EXCEPTION 'no_slot %', r; END IF;
 UPDATE public.club_schedule SET is_active=true WHERE id=slot;
 -- choose_slot bei zwei Pflichteinheiten heute; mit Auswahl → Antrag für genau diese Einheit
 INSERT INTO public.club_schedule(dow,training_type_id,tier,label,duration_minutes,sort_order)
 VALUES (extract(isodow FROM today)::integer,reg,'pflicht','Abendtraining',60,9) RETURNING id INTO slot2;
 r := pg_temp.q(a2);
 IF r->>'status'<>'choose_slot' OR pg_temp.subs(p2)<>0 THEN RAISE EXCEPTION 'choose_slot %', r; END IF;
 r := pg_temp.q(a2, slot2);
 IF r->>'status'<>'submitted' OR (SELECT requested_slot_id FROM public.training_submissions WHERE id=(r->>'submission_id')::uuid)<>slot2 THEN RAISE EXCEPTION 'chosen slot %', r; END IF;
 UPDATE public.club_schedule SET is_active=false WHERE id=slot2;
 RAISE NOTICE 'PASS Q1: submitted (nur Antrag, keine Buchung), already_pending, already_approved (60 nach Trainerbestätigung), no_slot, choose_slot, keine fremde Einheit';
END $t$;

-- Gym: checked_in, already_checked_in, Bestätigung, choose_gym_session, abgebrochene Einheit, gym_not_open, Duplikatschutz
DO $t$ DECLARE r jsonb; g1 bigint; g2 bigint; g3 bigint; slot integer; sid uuid; c jsonb; reg bigint; today date := league_private.zurich_today();
 coach text := '10000000-0000-0000-0000-00000000000c';
 a3 text := '20000000-0000-0000-0000-000000000053'; p3 uuid := '00000000-0000-0000-0000-000000000053';
 a4 text := '20000000-0000-0000-0000-000000000054'; p4 uuid := '00000000-0000-0000-0000-000000000054';
 a5 text := '20000000-0000-0000-0000-000000000055'; p5 uuid := '00000000-0000-0000-0000-000000000055';
 a6 text := '20000000-0000-0000-0000-000000000056'; p6 uuid := '00000000-0000-0000-0000-000000000056';
BEGIN
 PERFORM set_config('role','postgres',true);
 SELECT id INTO reg FROM public.training_types WHERE name='Reguläres Boxtraining';
 SELECT id INTO slot FROM public.club_schedule WHERE is_active AND tier='pflicht' AND dow=extract(isodow FROM today)::integer ORDER BY sort_order,id LIMIT 1;
 UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='gym_training';
 -- Fixture hat heute schon eine bestätigte Einheit für diesen Slot; staff_open_club_session gäbe diese zurück, darum direkt öffnen
 PERFORM pg_temp.act(coach); g1 := (public.staff_open_gym_session(reg,90,'Pflicht heute',NULL)->>'id')::bigint; PERFORM set_config('role','postgres',true);
 r := pg_temp.q(a3);
 IF r->>'status'<>'checked_in' OR (r->>'session_id')::bigint<>g1 OR NOT EXISTS (SELECT 1 FROM public.gym_attendance WHERE session_id=g1 AND profile_id=p3 AND source='self')
    OR pg_temp.subs(p3)<>0 THEN RAISE EXCEPTION 'checked_in %', r; END IF;
 r := pg_temp.q(a3);
 IF r->>'status'<>'already_checked_in' OR (SELECT count(*) FROM public.gym_attendance WHERE profile_id=p3)<>1 THEN RAISE EXCEPTION 'already_checked_in %', r; END IF;
 -- auch ein Check-in über gym_check_in zählt
 PERFORM pg_temp.act(a4); PERFORM public.gym_check_in(g1); PERFORM set_config('role','postgres',true);
 r := pg_temp.q(a4);
 IF r->>'status'<>'already_checked_in' OR pg_temp.subs(p4)<>0 THEN RAISE EXCEPTION 'gym_check_in then quick %', r; END IF;
 -- Trainer bestätigt die Einheit → je eine Pflicht-Buchung, danach already_approved
 PERFORM pg_temp.act(coach); c := public.staff_confirm_gym_session(g1); PERFORM set_config('role','postgres',true);
 IF (c->>'confirmed')::integer<>2 THEN RAISE EXCEPTION 'confirm %', c; END IF;
 SELECT submission_id INTO sid FROM public.gym_attendance WHERE session_id=g1 AND profile_id=p3;
 IF pg_temp.pts(sid)<>60 OR pg_temp.subs(p3)<>1 THEN RAISE EXCEPTION 'gym value %', pg_temp.pts(sid); END IF;
 r := pg_temp.q(a3);
 IF r->>'status'<>'already_approved' OR pg_temp.subs(p3)<>1 THEN RAISE EXCEPTION 'after confirm %', r; END IF;
 -- zwei offene passende Einheiten → choose_gym_session ohne Schreibzugriff
 PERFORM pg_temp.act(coach);
 g2 := (public.staff_open_gym_session(reg,90,'Zweite Einheit',NULL)->>'id')::bigint;
 g3 := (public.staff_open_gym_session(reg,90,'Dritte Einheit',NULL)->>'id')::bigint;
 PERFORM set_config('role','postgres',true);
 r := pg_temp.q(a5);
 IF r->>'status'<>'choose_gym_session' OR EXISTS (SELECT 1 FROM public.gym_attendance WHERE profile_id=p5) OR pg_temp.subs(p5)<>0 THEN RAISE EXCEPTION 'choose_gym_session %', r; END IF;
 -- abgebrochene Einheiten zählen nicht: ohne offene Einheit und mit «nur betreuter Check-in» → gym_not_open
 PERFORM pg_temp.act(coach); PERFORM public.staff_cancel_gym_session(g2); PERFORM public.staff_cancel_gym_session(g3); PERFORM set_config('role','postgres',true);
 UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='club_checkin_only';
 r := pg_temp.q(a5);
 IF r->>'status'<>'gym_not_open' OR pg_temp.subs(p5)<>0 OR EXISTS (SELECT 1 FROM public.gym_attendance WHERE profile_id=p5) THEN RAISE EXCEPTION 'gym_not_open %', r; END IF;
 -- Selbstmeldung erlaubt → Antrag; Trainer öffnet danach eine Einheit, markiert den Boxer und bestätigt:
 -- die Gym-Bestätigung überspringt ihn (schon eingereicht), die Freigabe des Antrags verlangt eine bewusste Prüfung → keine Doppelbuchung
 UPDATE public.league_feature_flags SET is_enabled=false WHERE feature_key='club_checkin_only';
 r := pg_temp.q(a6);
 IF r->>'status'<>'submitted' THEN RAISE EXCEPTION 'submitted with gym on %', r; END IF;
 sid := (r->>'submission_id')::uuid;
 PERFORM pg_temp.act(coach);
 g2 := (public.staff_open_gym_session(reg,60,'Spätes Training',NULL)->>'id')::bigint;
 PERFORM public.staff_set_gym_attendance(g2,p6,true);
 c := public.staff_confirm_gym_session(g2);
 IF (c->>'confirmed')::integer<>0 OR c->'skipped'->0->>'reason' NOT LIKE '%schon eingereicht%' THEN RAISE EXCEPTION 'gym confirm must skip %', c; END IF;
 BEGIN PERFORM public.staff_review_training(sid,'approved'); RAISE EXCEPTION 'duplicate approved silently';
 EXCEPTION WHEN unique_violation THEN NULL; END;
 r := public.staff_review_training(sid,'approved','auto',NULL,NULL,NULL,'Gym-Einheit wurde übersprungen, nur dieser Antrag zählt',true);
 PERFORM set_config('role','postgres',true);
 IF pg_temp.subs(p6)<>1 OR pg_temp.pts(sid)<>60 OR (SELECT count(*) FROM public.point_transactions x JOIN public.training_submissions s ON s.id=x.submission_id WHERE s.boxer_id=p6)<>1 THEN
  RAISE EXCEPTION 'p6 bookings';
 END IF;
 UPDATE public.league_feature_flags SET is_enabled=false WHERE feature_key='gym_training';
 RAISE NOTICE 'PASS Q2: checked_in, already_checked_in (auch nach gym_check_in), Gym-Bestätigung bucht einmal, already_approved, choose_gym_session, abgebrochene Einheiten ignoriert, gym_not_open, Antrag + Gym-Einheit ohne Doppelbuchung';
END $t$;

-- Pflicht-Antrag mit anderer Trainingsart als die Gym-Einheit wird bei der Gym-Bestätigung ebenfalls übersprungen
DO $t$ DECLARE r jsonb; c jsonb; g bigint; sid uuid; tech bigint; today date := league_private.zurich_today();
 coach text := '10000000-0000-0000-0000-00000000000c'; a7 text := '20000000-0000-0000-0000-000000000057'; p7 uuid := '00000000-0000-0000-0000-000000000057';
BEGIN
 PERFORM set_config('role','postgres',true);
 SELECT id INTO tech FROM public.training_types WHERE name='Techniktraining';
 r := pg_temp.q(a7); sid := (r->>'submission_id')::uuid;
 IF r->>'status'<>'submitted' THEN RAISE EXCEPTION 'q7 %', r; END IF;
 UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='gym_training';
 PERFORM pg_temp.act(coach);
 g := (public.staff_open_gym_session(tech,60,'Technik-Pflicht',NULL)->>'id')::bigint;
 PERFORM set_config('role','postgres',true); UPDATE public.gym_sessions SET club_tier='pflicht' WHERE id=g; PERFORM pg_temp.act(coach);
 PERFORM public.staff_set_gym_attendance(g,p7,true);
 c := public.staff_confirm_gym_session(g);
 PERFORM set_config('role','postgres',true);
 UPDATE public.league_feature_flags SET is_enabled=false WHERE feature_key='gym_training';
 IF (c->>'confirmed')::integer<>0 OR pg_temp.subs(p7)<>1 THEN RAISE EXCEPTION 'pflicht request of other type must block gym booking %', c; END IF;
 RAISE NOTICE 'PASS Q3: Gym-Bestätigung erkennt offenen Pflicht-Antrag auch bei anderer Trainingsart (keine zweite Pflicht-Buchung)';
END $t$;

\ir ../supabase/production-prep/rollback_20261031110000_gym_confirm_day_lock.sql
DO $r$ BEGIN
 IF md5(pg_get_functiondef('public.staff_confirm_gym_session(bigint)'::regprocedure))<>(SELECT fp FROM ref_confirm) THEN RAISE EXCEPTION 'confirm not restored'; END IF;
 RAISE NOTICE 'PASS: Rücknahme Tages-Lock stellt staff_confirm_gym_session wörtlich wieder her';
END $r$;
\ir ../supabase/migrations/20261031110000_gym_confirm_day_lock.sql
\ir ../supabase/production-prep/rollback_20261031100000_scheduled_club_training_quick_request.sql
DO $r$ BEGIN
 IF to_regprocedure('public.submit_scheduled_club_training_today(integer)') IS NOT NULL THEN RAISE EXCEPTION 'quick rpc left'; END IF;
 RAISE NOTICE 'PASS: Rücknahme Ein-Klick-Antrag entfernt nur die RPC';
END $r$;
\ir ../supabase/migrations/20261031100000_scheduled_club_training_quick_request.sql
DO $r$ BEGIN RAISE NOTICE 'PASS: erneut einspielbar'; END $r$;
