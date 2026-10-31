\set ON_ERROR_STOP on
-- Disposable-database test for 20261031090000_training_v2_classification.sql (Training 2.0) plus Aktivierung, Rücknahme, Rollback.
-- Fixture: Vereinsstundenplan/Stufen (Etappe 6a) und Selbsteintrag (Etappe 17a). Keine echten Konten, keine Produktion.
\ir club-types-selfservice-schema.sql

-- Referenz: bestehende Daten dürfen sich durch die Migration nicht ändern
CREATE TEMP TABLE ref_v2 AS SELECT
 (SELECT count(*) FROM public.training_submissions) AS subs,
 (SELECT count(*)||'/'||coalesce(sum(points),0)||'/'||coalesce(sum(exp),0) FROM public.point_transactions) AS pts,
 (SELECT count(*)||'/'||coalesce(sum(amount),0) FROM public.kg_ledger) AS coins,
 (SELECT string_agg(s.id::text||':'||coalesce(s.club_tier,'-')||':'||league_private.training_value(s.id),',' ORDER BY s.id) FROM public.training_submissions s) AS vals,
 md5(pg_get_functiondef('league_private.training_insert_guard()'::regprocedure)) AS guard,
 md5(pg_get_functiondef('league_private.training_value(uuid)'::regprocedure)) AS val_fn;
GRANT SELECT ON ref_v2 TO PUBLIC;

\ir ../supabase/production-prep/preflight_20261031090000_training_v2.sql
\ir ../supabase/migrations/20261031090000_training_v2_classification.sql
\ir ../supabase/migrations/20261031090000_training_v2_classification.sql
\ir ../supabase/production-prep/postflight_20261031090000_training_v2.sql

CREATE FUNCTION pg_temp.pts(p uuid) RETURNS integer LANGUAGE sql AS $fn$ SELECT coalesce((SELECT x.points FROM public.point_transactions x WHERE x.submission_id=p),0) $fn$;
CREATE FUNCTION pg_temp.ntx(p uuid) RETURNS integer LANGUAGE sql AS $fn$ SELECT count(*)::integer FROM public.point_transactions x WHERE x.submission_id=p $fn$;
CREATE FUNCTION pg_temp.coins(p uuid) RETURNS integer LANGUAGE plpgsql AS $fn$ DECLARE b uuid; BEGIN
 SELECT boxer_id INTO b FROM public.training_submissions WHERE id=p; PERFORM league_private.kg_sync(b);
 RETURN coalesce((SELECT sum(l.amount) FROM public.kg_ledger l WHERE l.profile_id=b AND l.reason IN ('training','training_fix') AND split_part(l.ref,':',1)=p::text),0)::integer; END $fn$;
CREATE FUNCTION pg_temp.kp(b uuid, d date) RETURNS integer LANGUAGE sql AS $fn$ SELECT (league_private.kg_pass_points(b,d)->>'points_trainings')::integer $fn$;
CREATE FUNCTION pg_temp.slot(dow integer) RETURNS integer LANGUAGE sql AS $fn$ SELECT id FROM public.club_schedule WHERE dow=$1 AND tier='pflicht' AND is_active ORDER BY sort_order,id LIMIT 1 $fn$;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA pg_temp TO PUBLIC;

-- 0. Migration ändert keine Daten; Schalter aus = bisheriges Verhalten
DO $t$ DECLARE sub uuid; r jsonb; m date := DATE '2026-09-07'; -- fester Montag ohne Fixture-Daten (offene Saison)
 anna text := '10000000-0000-0000-0000-000000000001'; coach text := '10000000-0000-0000-0000-00000000000c';
 annaP uuid := '00000000-0000-0000-0000-000000000001'; reg bigint; jog bigint; sMo integer := pg_temp.slot(1);
BEGIN
 PERFORM set_config('role','postgres',true);
 IF (SELECT subs FROM ref_v2)<>(SELECT count(*) FROM public.training_submissions)
  OR (SELECT pts FROM ref_v2)<>(SELECT count(*)||'/'||coalesce(sum(points),0)||'/'||coalesce(sum(exp),0) FROM public.point_transactions)
  OR (SELECT coins FROM ref_v2)<>(SELECT count(*)||'/'||coalesce(sum(amount),0) FROM public.kg_ledger)
  OR (SELECT vals FROM ref_v2)<>(SELECT string_agg(s.id::text||':'||coalesce(s.club_tier,'-')||':'||league_private.training_value(s.id),',' ORDER BY s.id) FROM public.training_submissions s)
 THEN RAISE EXCEPTION 'migration changed existing data or values'; END IF;
 IF (SELECT is_enabled FROM public.league_feature_flags WHERE feature_key='training_v2') IS DISTINCT FROM false THEN RAISE EXCEPTION 'flag must start off'; END IF;
 SELECT id INTO reg FROM public.training_types WHERE name='Reguläres Boxtraining'; SELECT id INTO jog FROM public.training_types WHERE name='Joggen';
 -- Antrag wird ohne Schalter ignoriert
 PERFORM pg_temp.act(anna);
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes,training_location,requested_slot_id)
 VALUES (annaP,reg,m,'Schalter aus','pending',90,'club',sMo) RETURNING id INTO sub;
 PERFORM set_config('role','postgres',true);
 IF (SELECT training_location IS NOT NULL OR requested_tier IS NOT NULL OR requested_slot_id IS NOT NULL FROM public.training_submissions WHERE id=sub) THEN RAISE EXCEPTION 'request must be ignored with flag off'; END IF;
 PERFORM pg_temp.act(coach);
 BEGIN PERFORM public.staff_review_training(sub,'approved','pflicht',NULL,NULL,NULL,'Test'); RAISE EXCEPTION 'tier allowed with flag off';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 r := public.staff_review_training(sub,'approved');
 PERFORM set_config('role','postgres',true);
 IF pg_temp.pts(sub)<>(SELECT points FROM public.training_types WHERE id=reg) OR (SELECT club_tier FROM public.training_submissions WHERE id=sub) IS NOT NULL THEN RAISE EXCEPTION 'flag off must book like before'; END IF;
 DELETE FROM public.point_transactions WHERE submission_id=sub; DELETE FROM public.training_submissions WHERE id=sub;
 RAISE NOTICE 'PASS 0: Migration ändert keine Daten, Schalter startet aus, ohne Schalter Wertung wie bisher und keine Einstufung';
END $t$;

-- Aktivierung (Stundenplan Mo/Mi/Sa Reguläres Boxtraining + Schalter)
\ir ../supabase/production-prep/activate_20261031090000_training_v2.sql

DO $t$ DECLARE r jsonb; s1 uuid; s2 uuid; s3 uuid; s4 uuid; s5 uuid; s6 uuid; s7 uuid; s8 uuid; x uuid; y uuid; z uuid; kp0 integer; kp1 integer;
 today date := league_private.zurich_today(); m date := DATE '2026-09-07'; -- fester Montag ohne Fixture-Daten (offene Saison)
 anna text := '10000000-0000-0000-0000-000000000001'; ben text := '10000000-0000-0000-0000-000000000002'; bob text := '10000000-0000-0000-0000-000000000003';
 coach text := '10000000-0000-0000-0000-00000000000c'; owner text := '10000000-0000-0000-0000-00000000000a';
 annaP uuid := '00000000-0000-0000-0000-000000000001'; benP uuid := '00000000-0000-0000-0000-000000000002'; bobP uuid := '00000000-0000-0000-0000-000000000003';
 coachP uuid := '00000000-0000-0000-0000-00000000000c';
 reg bigint; jog bigint; kraft bigint; wk bigint; tech bigint; sandsack bigint; gs bigint;
 sMo integer := pg_temp.slot(1); sMi integer := pg_temp.slot(3); sSa integer := pg_temp.slot(6);
BEGIN
 PERFORM set_config('role','postgres',true);
 SELECT id INTO reg FROM public.training_types WHERE name='Reguläres Boxtraining'; SELECT id INTO jog FROM public.training_types WHERE name='Joggen';
 SELECT id INTO kraft FROM public.training_types WHERE name='Krafttraining'; SELECT id INTO wk FROM public.training_types WHERE name='Wettkampf';
 SELECT id INTO tech FROM public.training_types WHERE name='Techniktraining'; SELECT id INTO sandsack FROM public.training_types WHERE name='Sandsack / Rundenarbeit';
 IF (SELECT string_agg(dow||':'||training_type_id,',' ORDER BY dow) FROM public.club_schedule WHERE is_active AND tier='pflicht')<>'1:'||reg||',3:'||reg||',6:'||reg THEN
  RAISE EXCEPTION 'schedule Mo/Mi/Sa must be Reguläres Boxtraining';
 END IF;
 IF NOT EXISTS (SELECT 1 FROM public.club_schedule WHERE is_active AND tier='ergaenzung') THEN RAISE EXCEPTION 'supplementary slots kept'; END IF;

 -- Konfiguration und Vorschau (gleiche Regel wie die Buchung)
 PERFORM pg_temp.act(anna);
 r := public.get_training_v2_config();
 IF NOT (r->>'enabled')::boolean OR jsonb_array_length(r->'pflicht')<>3 OR jsonb_array_length(r->'extras')<>3 THEN RAISE EXCEPTION 'config %', r; END IF;
 IF (r->'pflicht'->0->'reward'->>'exp')::integer<>60 OR (r->'pflicht'->0->'reward'->>'coins')::integer<>15 OR (r->'pflicht'->0->'reward'->>'pass_points')::integer<>15 THEN RAISE EXCEPTION 'pflicht reward %', r->'pflicht'->0; END IF;
 IF (SELECT bool_or((e->'reward'->>'exp')::integer<>40 OR (e->'reward'->>'coins')::integer<>12 OR (e->'reward'->>'pass_points')::integer<>12) FROM jsonb_array_elements(r->'extras') e) THEN RAISE EXCEPTION 'extra reward %', r->'extras'; END IF;
 r := public.training_reward_preview(jog,NULL);
 IF (r->>'points')::integer<>20 OR (r->>'coins')::integer<>10 OR (r->>'pass_points')::integer<>10 THEN RAISE EXCEPTION 'individual preview %', r; END IF;
 BEGIN PERFORM league_private.training_reward(jog,NULL); RAISE EXCEPTION 'private helper callable'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.staff_list_trainings(); RAISE EXCEPTION 'boxer can list'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.admin_training_tier_review(); RAISE EXCEPTION 'boxer sees review'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;

 -- Boxer reicht ein: Mo/Mi/Sa Pflicht, Di/Do/Fr Ergänzung, So individuell
 PERFORM set_config('role','postgres',true); kp0 := pg_temp.kp(annaP, m); PERFORM pg_temp.act(anna);
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes,training_location,requested_slot_id,club_tier,recorded_by)
 VALUES (annaP,wk,m,'Montag','pending',90,'club',sMo,'pflicht',coachP) RETURNING id INTO s1;
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes,training_location,requested_slot_id)
 VALUES (annaP,reg,m+2,'Mittwoch','pending',90,'club',sMi) RETURNING id INTO s2;
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes,training_location,requested_slot_id)
 VALUES (annaP,reg,m+5,'Samstag','pending',90,'club',sSa) RETURNING id INTO s3;
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes,training_location,requested_extra_key)
 VALUES (annaP,jog,m+1,'Sandsack','pending',60,'club','sandsack') RETURNING id INTO s4;
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes,training_location,requested_extra_key)
 VALUES (annaP,jog,m+3,'Athletik','pending',60,'club','athletik') RETURNING id INTO s5;
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes,training_location,requested_extra_key)
 VALUES (annaP,jog,m+4,'Technik','pending',60,'club','technik') RETURNING id INTO s6;
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes,training_location,requested_tier,club_tier)
 VALUES (annaP,jog,m+6,'Joggen','pending',45,'individual','pflicht','pflicht') RETURNING id INTO s7;
 -- 8. Manipulation: falscher Wochentag, Kategorie ohne Einheit, Zukunft, Stufe nachträglich ändern
 BEGIN INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes,training_location,requested_slot_id)
  VALUES (annaP,reg,m+1,'Dienstag als Montag','pending',90,'club',sMo); RAISE EXCEPTION 'wrong weekday accepted';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes,training_location,requested_tier)
  VALUES (annaP,reg,m,'Nur Kategorie','pending',90,'club','pflicht'); RAISE EXCEPTION 'tier without unit accepted';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes,training_location,requested_extra_key)
  VALUES (annaP,reg,today+1,'Zukunft','pending',90,'club','sandsack'); RAISE EXCEPTION 'future accepted';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN UPDATE public.training_submissions SET club_tier='pflicht' WHERE id=s7; RAISE EXCEPTION 'boxer updated tier';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.staff_review_training(s1,'approved'); RAISE EXCEPTION 'boxer approved';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.staff_correct_training(s1,reg,m,90,'pflicht','selbst'); RAISE EXCEPTION 'boxer corrected';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM set_config('role','postgres',true);
 IF (SELECT training_type_id<>reg OR club_tier IS NOT NULL OR recorded_by IS NOT NULL OR requested_tier<>'pflicht' FROM public.training_submissions WHERE id=s1) THEN RAISE EXCEPTION 'slot must force type, tier stays null'; END IF;
 IF (SELECT training_type_id FROM public.training_submissions WHERE id=s4)<>sandsack OR (SELECT training_type_id FROM public.training_submissions WHERE id=s6)<>tech THEN RAISE EXCEPTION 'extra must force type'; END IF;
 IF (SELECT requested_tier IS NOT NULL OR club_tier IS NOT NULL FROM public.training_submissions WHERE id=s7) THEN RAISE EXCEPTION 'individual cannot request tier'; END IF;

 -- Trainerliste: Kategorien als Vorschlag, Pagination, Kennzahlen
 PERFORM pg_temp.act(coach);
 r := public.staff_list_trainings('pending',NULL,NULL,annaP,m,m+6,10,0);
 IF (r->>'total_count')::integer<>7 THEN RAISE EXCEPTION 'list total %', r->>'total_count'; END IF;
 IF (public.staff_list_trainings('pending','pflicht',NULL,annaP,m,m+6,10,0)->>'total_count')::integer<>3
  OR (public.staff_list_trainings('pending','ergaenzung',NULL,annaP,m,m+6,10,0)->>'total_count')::integer<>3
  OR (public.staff_list_trainings('pending','individual',NULL,annaP,m,m+6,10,0)->>'total_count')::integer<>1 THEN RAISE EXCEPTION 'category filter'; END IF;
 r := public.staff_list_trainings('pending',NULL,NULL,annaP,m,m+6,2,2);
 IF jsonb_array_length(r->'items')<>2 THEN RAISE EXCEPTION 'pagination'; END IF;
 r := public.staff_list_trainings('pending',NULL,'Samstag',NULL,NULL,NULL,10,0);
 IF (r->>'total_count')::integer<>1 OR r->'items'->0->>'requested_label'<>'Samstag – Reguläres Boxtraining' OR (r->'items'->0->'reward'->>'points')::integer<>60 THEN RAISE EXCEPTION 'search/card %', r; END IF;
 IF (public.staff_training_summary()->>'pending')::integer<8 THEN RAISE EXCEPTION 'summary'; END IF;

 -- 1.–7. Bestätigen mit Vorschlag (Sammelbestätigung = gleiche RPC pro Eintrag, Wert pro Training)
 FOREACH x IN ARRAY ARRAY[s1,s2,s3,s4,s5,s6,s7] LOOP r := public.staff_review_training(x,'approved'); END LOOP;
 PERFORM set_config('role','postgres',true);
 IF pg_temp.pts(s1)<>60 OR pg_temp.pts(s2)<>60 OR pg_temp.pts(s3)<>60 THEN RAISE EXCEPTION 'pflicht 60: % % %', pg_temp.pts(s1),pg_temp.pts(s2),pg_temp.pts(s3); END IF;
 IF (SELECT exp FROM public.point_transactions WHERE submission_id=s1)<>60 THEN RAISE EXCEPTION 'exp = points'; END IF;
 IF pg_temp.pts(s4)<>40 OR pg_temp.pts(s5)<>40 OR pg_temp.pts(s6)<>40 THEN RAISE EXCEPTION 'ergaenzung 40: % % %', pg_temp.pts(s4),pg_temp.pts(s5),pg_temp.pts(s6); END IF;
 IF pg_temp.pts(s7)<>20 THEN RAISE EXCEPTION 'individual keeps type value: %', pg_temp.pts(s7); END IF;
 IF pg_temp.coins(s1)<>15 OR pg_temp.coins(s4)<>12 OR pg_temp.coins(s7)<>10 THEN RAISE EXCEPTION 'coins % % %', pg_temp.coins(s1), pg_temp.coins(s4), pg_temp.coins(s7); END IF;
 kp1 := pg_temp.kp(annaP, m);
 -- Kampfpfad im Monat des Montags: Pflicht 15, Ergänzung 12, sonst 10 (nur Einträge im selben Monat zählen)
 IF kp1-kp0<>(SELECT sum(CASE club_tier WHEN 'pflicht' THEN 15 WHEN 'ergaenzung' THEN 12 ELSE 10 END) FROM public.training_submissions
   WHERE id = ANY(ARRAY[s1,s2,s3,s4,s5,s6,s7]) AND date_trunc('month',training_date)=date_trunc('month',m)) THEN RAISE EXCEPTION 'kampfpfad % -> %', kp0, kp1; END IF;
 IF (SELECT string_agg(coalesce(club_tier,'-'),',' ORDER BY training_date) FROM public.training_submissions WHERE id = ANY(ARRAY[s1,s2,s3,s4,s5,s6,s7]))<>'pflicht,ergaenzung,pflicht,ergaenzung,ergaenzung,pflicht,-' THEN RAISE EXCEPTION 'tiers'; END IF;
 -- 19. Pflichtquote, Quests und Boni laufen weiter
 IF league_private.pflicht_days(annaP, m, m+6)<>3 OR league_private.quest_progress(annaP,'pflicht_days',m,m+6)<>3 THEN RAISE EXCEPTION 'pflicht quota'; END IF;
 RAISE NOTICE 'PASS 1–7, 16, 19: Pflicht 60/60/15/15, Ergänzung 40/40/12/12, individuell nach Trainingsart (20/10/10), Kampfpfad, Pflichtquote, Quests';

 -- 12. Doppelt bestätigen: keine zweite Buchung
 PERFORM pg_temp.act(coach);
 r := public.staff_review_training(s1,'approved');
 IF NOT (r->>'already')::boolean THEN RAISE EXCEPTION 'second approve must be idempotent'; END IF;
 BEGIN PERFORM public.staff_review_training(s1,'rejected'); RAISE EXCEPTION 'reject after approve'; EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL; END;
 PERFORM set_config('role','postgres',true);
 IF pg_temp.ntx(s1)<>1 OR pg_temp.pts(s1)<>60 OR pg_temp.coins(s1)<>15 THEN RAISE EXCEPTION 'double booking'; END IF;

 -- 8b. Manipulierte Trainingsart (Wettkampf 100) über Pflichtantrag → Reguläres Boxtraining 60, nicht 100
 IF (SELECT training_type_id FROM public.training_submissions WHERE id=s1)<>reg THEN RAISE EXCEPTION 'type manipulation'; END IF;

 -- Höhere Werte einer Trainingsart bleiben (Reguläres Boxtraining hat in der Fixture 50 Punkte, in Produktion 30): Wert = max(Stufe, Art)
 -- 9. Individuell → Pflicht (Begründung nötig) · 10. Pflicht → Ergänzung · 11. Ablehnen
 PERFORM pg_temp.act(ben);
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes,training_location)
 VALUES (benP,reg,m,'Individuell gemeldet','pending',90,'individual') RETURNING id INTO x;
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes,training_location,requested_slot_id)
 VALUES (benP,reg,m+2,'Pflicht gemeldet','pending',90,'club',sMi) RETURNING id INTO y;
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes,training_location,requested_extra_key)
 VALUES (benP,jog,m+1,'Abzulehnen','pending',60,'club','sandsack') RETURNING id INTO z;
 PERFORM pg_temp.act(coach);
 BEGIN PERFORM public.staff_review_training(x,'approved','pflicht'); RAISE EXCEPTION 'override without reason';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM set_config('role','postgres',true);
 IF (SELECT status FROM public.training_submissions WHERE id=x)<>'pending' OR pg_temp.ntx(x)<>0 THEN RAISE EXCEPTION '17: failed call must leave no booking'; END IF;
 PERFORM pg_temp.act(coach);
 r := public.staff_review_training(x,'approved','pflicht',NULL,NULL,NULL,'War im Vereinstraining');
 r := public.staff_review_training(y,'approved','ergaenzung',NULL,NULL,75,'Nur Sandsack-Teil absolviert');
 r := public.staff_review_training(z,'rejected',NULL,NULL,NULL,NULL,'Nicht anwesend');
 -- Pflicht an einem Tag ohne Pflichteinheit nur mit Begründung (verschobenes Training)
 PERFORM pg_temp.act(ben);
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes,training_location)
 VALUES (benP,reg,m+3,'Verschoben','pending',90,'individual') RETURNING id INTO s8;
 PERFORM pg_temp.act(coach);
 r := public.staff_review_training(s8,'approved','pflicht',NULL,NULL,NULL,'Training von Mittwoch auf Donnerstag verschoben');
 PERFORM set_config('role','postgres',true);
 IF pg_temp.pts(x)<>60 OR (SELECT club_tier FROM public.training_submissions WHERE id=x)<>'pflicht' THEN RAISE EXCEPTION '9 individual->pflicht'; END IF;
 IF pg_temp.pts(y)<>GREATEST(40,(SELECT points FROM public.training_types WHERE id=reg)) OR (SELECT duration_minutes FROM public.training_submissions WHERE id=y)<>75 THEN RAISE EXCEPTION '10 pflicht->ergaenzung % %', pg_temp.pts(y), (SELECT row_to_json(qq)::text FROM public.training_submissions qq WHERE qq.id=y); END IF;
 IF pg_temp.ntx(z)<>0 OR (SELECT status||':'||tier_note FROM public.training_submissions WHERE id=z)<>'rejected:Nicht anwesend' THEN RAISE EXCEPTION '11 reject'; END IF;
 IF pg_temp.pts(s8)<>60 THEN RAISE EXCEPTION 'moved pflicht'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.training_audit WHERE submission_id=x) OR NOT EXISTS (SELECT 1 FROM public.training_audit WHERE submission_id=y) THEN RAISE EXCEPTION 'audit for corrections'; END IF;
 RAISE NOTICE 'PASS 8–12, 17: Manipulation ohne Wirkung, Korrekturen mit Begründung und Audit, Ablehnung 0, doppelt = eine Buchung, Fehler ohne Buchung';

 -- 13. Gym-Check-in und Selbstmeldung derselben Einheit · 14. zwei echte Einheiten am selben Tag
 INSERT INTO public.gym_sessions(session_date,training_type_id,duration_minutes,note,opened_by,status,club_tier)
 VALUES (m+5,reg,90,'Samstagstraining',coachP,'open','pflicht') RETURNING id INTO gs;
 INSERT INTO public.gym_attendance(session_id,profile_id,source) VALUES (gs,bobP,'coach');
 PERFORM pg_temp.act(bob);
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes,training_location,requested_slot_id)
 VALUES (bobP,reg,m+5,'Auch selbst gemeldet','pending',90,'club',sSa) RETURNING id INTO x;
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes,training_location,requested_slot_id)
 VALUES (bobP,reg,m,'Montag Verein','pending',90,'club',sMo) RETURNING id INTO y;
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes,training_location)
 VALUES (bobP,jog,m,'Abends joggen','pending',30,'individual') RETURNING id INTO z;
 PERFORM pg_temp.act(coach);
 IF NOT (public.staff_list_trainings('pending',NULL,NULL,bobP,m+5,m+5,10,0)->'items'->0->'conflicts') ? 'gym_same_day' THEN RAISE EXCEPTION 'conflict flag'; END IF;
 BEGIN PERFORM public.staff_review_training(x,'approved'); RAISE EXCEPTION 'duplicate approved';
 EXCEPTION WHEN unique_violation THEN NULL; END;
 BEGIN PERFORM public.staff_review_training(x,'approved','auto',NULL,NULL,NULL,NULL,true); RAISE EXCEPTION 'duplicate without reason';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 r := public.staff_review_training(y,'approved'); r := public.staff_review_training(z,'approved');
 r := public.staff_review_training(x,'rejected',NULL,NULL,NULL,NULL,'Bereits per Gym-Check-in erfasst');
 PERFORM set_config('role','postgres',true);
 IF pg_temp.ntx(x)<>0 OR pg_temp.pts(y)<>60 OR pg_temp.pts(z)<>20 THEN RAISE EXCEPTION '13/14'; END IF;
 RAISE NOTICE 'PASS 13–14: Gym-Duplikat wird erkannt und nur bewusst (mit Begründung) zugelassen; zwei verschiedene Einheiten am selben Tag ohne Hinweis';

 -- 15. Nachträgliche Korrektur bestätigter Einheiten (Punkte, EXP, Coins, Kampfpfad folgen; Audit; Begründung Pflicht)
 PERFORM pg_temp.act(coach);
 BEGIN PERFORM public.staff_correct_training(s1,NULL,NULL,NULL,'ergaenzung',NULL); RAISE EXCEPTION 'correct without reason';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 r := public.staff_correct_training(s1,NULL,NULL,NULL,'ergaenzung','Nur Ergänzungsteil');
 r := public.staff_correct_training(s7,kraft,NULL,60,'none','War Krafttraining, nicht Joggen');
 r := public.staff_correct_training(s4,NULL,m,NULL,'pflicht','Datum korrigiert: war Montag');
 PERFORM set_config('role','postgres',true);
 IF pg_temp.pts(s1)<>GREATEST(40,(SELECT points FROM public.training_types WHERE id=reg)) OR pg_temp.coins(s1)<>12 THEN RAISE EXCEPTION 'correct pflicht->ergaenzung % %', pg_temp.pts(s1), pg_temp.coins(s1); END IF;
 IF pg_temp.pts(s7)<>30 OR (SELECT training_type_id FROM public.training_submissions WHERE id=s7)<>kraft THEN RAISE EXCEPTION 'correct type'; END IF;
 IF pg_temp.pts(s4)<>60 OR (SELECT training_date FROM public.training_submissions WHERE id=s4)<>m THEN RAISE EXCEPTION 'correct date+tier'; END IF;
 IF pg_temp.ntx(s1)<>1 OR (SELECT count(*) FROM public.training_audit WHERE submission_id=s1)<1 THEN RAISE EXCEPTION 'audit/one tx'; END IF;
 -- Eigene Trainings stuft ein anderer Trainer ein; abgeschlossene Saison geschützt
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes) VALUES (coachP,reg,m,'Eigenes','pending',90) RETURNING id INTO x;
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes) VALUES (annaP,reg,'2026-02-02','Alte Saison','pending',90) RETURNING id INTO y;
 PERFORM pg_temp.act(coach);
 BEGIN PERFORM public.staff_review_training(x,'approved','pflicht',NULL,NULL,NULL,'Ich war da'); RAISE EXCEPTION 'own tier';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.staff_review_training(y,'approved'); RAISE EXCEPTION 'closed season';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 RAISE NOTICE 'PASS 15: Korrektur bestätigter Einheiten mit Begründung, Audit und Coins; eigene Trainings und abgeschlossene Saisons geschützt';

 -- 18 (sequenziell): Coach und Admin bestätigen dasselbe Training nacheinander → eine Buchung
 PERFORM pg_temp.act(anna);
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes,training_location,requested_slot_id)
 VALUES (annaP,reg,m-7,'Vorwoche','pending',90,'club',sMo) RETURNING id INTO x;
 PERFORM pg_temp.act(coach); r := public.staff_review_training(x,'approved');
 PERFORM pg_temp.act(owner); r := public.staff_review_training(x,'approved');
 IF NOT (r->>'already')::boolean THEN RAISE EXCEPTION 'second staff'; END IF;
 PERFORM set_config('role','postgres',true);
 IF pg_temp.ntx(x)<>1 THEN RAISE EXCEPTION 'one tx'; END IF;

 -- Admin-Prüfbericht (Dry-Run): bestätigtes Vereinstraining ohne Stufe wird vorgeschlagen, ändert nichts
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes) VALUES (benP,reg,m-5,'Alt bestätigt','pending',90) RETURNING id INTO y;
 PERFORM pg_temp.act(coach); r := public.staff_review_training(y,'approved','none');
 PERFORM pg_temp.act(owner);
 r := public.admin_training_tier_review(50,0);
 PERFORM set_config('role','postgres',true);
 IF NOT (r->>'dry_run')::boolean OR NOT EXISTS (SELECT 1 FROM jsonb_array_elements(r->'items') i WHERE (i->>'id')::uuid=y AND i->>'proposed_tier'='pflicht' AND (i->>'delta')::integer=60-pg_temp.pts(y)) THEN RAISE EXCEPTION 'review report %', r; END IF;
 PERFORM set_config('role','postgres',true);
 IF (SELECT club_tier FROM public.training_submissions WHERE id=y) IS NOT NULL THEN RAISE EXCEPTION 'dry run changed data'; END IF;
 RAISE NOTICE 'PASS 18 (sequenziell), 20: zweiter Trainer bucht nicht doppelt; Prüfbericht schlägt nur vor und ändert nichts';
END $t$;


-- Befunde der unabhängigen Prüfung: eigene Trainings, Stufe bei Schalter aus, Saisonschutz vor Datumskorrektur
DO $t$ DECLARE r jsonb; x uuid; y uuid; z uuid; m date := DATE '2026-09-07';
 coach text := '10000000-0000-0000-0000-00000000000c'; owner text := '10000000-0000-0000-0000-00000000000a';
 coachP uuid := '00000000-0000-0000-0000-00000000000c'; annaP uuid := '00000000-0000-0000-0000-000000000001'; jog bigint; wk bigint;
BEGIN
 PERFORM set_config('role','postgres',true);
 SELECT id INTO jog FROM public.training_types WHERE name='Joggen'; SELECT id INTO wk FROM public.training_types WHERE name='Wettkampf';
 -- Trainer meldet eigenes Training mit vorbelegter Stufe: Stufe wird entfernt, Freigabe durch anderen Trainer bucht den Artwert
 PERFORM pg_temp.act(coach);
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes,club_tier,tier_note)
 VALUES (coachP,jog,m+4,'Eigenes Joggen','pending',40,'pflicht','selbst') RETURNING id INTO x;
 PERFORM set_config('role','postgres',true);
 IF (SELECT club_tier IS NOT NULL OR tier_note IS NOT NULL FROM public.training_submissions WHERE id=x) THEN RAISE EXCEPTION 'coach preset own tier'; END IF;
 PERFORM pg_temp.act(coach);
 BEGIN PERFORM public.staff_review_training(x,'approved'); RAISE EXCEPTION 'coach approved own'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.staff_review_training(x,'approved','none',wk,NULL,NULL,'Wettkampf'); RAISE EXCEPTION 'coach upgraded own'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM pg_temp.act(owner); r := public.staff_review_training(x,'approved');
 PERFORM set_config('role','postgres',true);
 IF pg_temp.pts(x)<>20 OR (SELECT club_tier FROM public.training_submissions WHERE id=x) IS NOT NULL OR pg_temp.coins(x)<>10 THEN RAISE EXCEPTION 'own training value'; END IF;
 PERFORM pg_temp.act(coach);
 BEGIN PERFORM public.staff_correct_training(x,wk,NULL,NULL,'keep','mehr Punkte'); RAISE EXCEPTION 'coach corrected own'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 -- Schalter aus: Dauer korrigieren behält bestehende Stufe (z. B. Gym-Check-in), Stufe neu setzen ist gesperrt
 PERFORM set_config('role','postgres',true);
 SELECT id INTO y FROM public.training_submissions WHERE boxer_id=annaP AND status='approved' AND club_tier='pflicht' AND training_date=m+2;
 UPDATE public.league_feature_flags SET is_enabled=false WHERE feature_key='training_v2';
 PERFORM pg_temp.act(coach);
 r := public.staff_correct_training(y,NULL,NULL,75,NULL,'Dauer korrigiert');
 BEGIN PERFORM public.staff_correct_training(y,NULL,NULL,NULL,'ergaenzung','Stufe'); RAISE EXCEPTION 'tier change with flag off'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM set_config('role','postgres',true);
 UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='training_v2';
 IF (SELECT club_tier||':'||duration_minutes FROM public.training_submissions WHERE id=y)<>'pflicht:75' OR pg_temp.pts(y)<>60 THEN RAISE EXCEPTION 'keep tier'; END IF;
 IF (SELECT count(*) FROM public.training_audit WHERE submission_id=y AND new_submission->>'duration_minutes'='75')<1 THEN RAISE EXCEPTION 'audit duration'; END IF;
 -- Offenes Training in abgeschlossener Saison lässt sich nicht durch Datumskorrektur freigeben
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes) VALUES (annaP,jog,'2026-02-10','Alte Saison','pending',30) RETURNING id INTO z;
 PERFORM pg_temp.act(coach);
 BEGIN PERFORM public.staff_review_training(z,'approved','auto',NULL,m+4,NULL,'verschoben'); RAISE EXCEPTION 'closed season bypass'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 RAISE NOTICE 'PASS Prüfbefunde: keine vorbelegte eigene Stufe, eigene Trainings bestätigt/korrigiert ein anderer Trainer, Stufe bleibt bei Schalter aus, Saisonschutz vor Datumskorrektur, Audit vollständig';
END $t$;

-- 20. Bestehende Werte bleiben ohne ausdrückliche Korrektur gleich
DO $t$ BEGIN
 PERFORM set_config('role','postgres',true);
 IF EXISTS (SELECT 1 FROM ref_v2 r, unnest(string_to_array(r.vals,',')) v
   WHERE (SELECT s.id::text||':'||coalesce(s.club_tier,'-')||':'||league_private.training_value(s.id) FROM public.training_submissions s WHERE s.id=split_part(v,':',1)::uuid)<>v) THEN
  RAISE EXCEPTION 'historic values changed';
 END IF;
 RAISE NOTICE 'PASS 20: historische Trainings unverändert';
END $t$;
\ir ../supabase/production-prep/training_v2_dry_run_read_only.sql

-- Rücknahme der Aktivierung und Rollback der Migration
\ir ../supabase/production-prep/deactivate_20261031090000_training_v2.sql
\ir ../supabase/production-prep/rollback_20261031090000_training_v2_classification.sql
DO $r$ BEGIN
 IF md5(pg_get_functiondef('league_private.training_insert_guard()'::regprocedure))<>(SELECT guard FROM ref_v2) THEN RAISE EXCEPTION 'guard not restored'; END IF;
 IF md5(pg_get_functiondef('league_private.training_value(uuid)'::regprocedure))<>(SELECT val_fn FROM ref_v2) THEN RAISE EXCEPTION 'training_value not restored'; END IF;
 IF to_regprocedure('public.staff_review_training(uuid,text,text,bigint,date,integer,text,boolean)') IS NOT NULL OR to_regclass('public.club_extra_trainings') IS NOT NULL
  OR EXISTS (SELECT 1 FROM public.league_feature_flags WHERE feature_key='training_v2') THEN RAISE EXCEPTION 'objects left'; END IF;
 IF (SELECT string_agg(dow||':'||label,',' ORDER BY dow) FROM public.club_schedule WHERE is_active AND tier='pflicht') LIKE '%Reguläres%' THEN RAISE EXCEPTION 'schedule not restored'; END IF;
 RAISE NOTICE 'PASS: Rücknahme stellt Sperre, Wertung und Stundenplan wörtlich wieder her';
END $r$;
\ir ../supabase/migrations/20261031090000_training_v2_classification.sql
DO $r$ BEGIN RAISE NOTICE 'PASS: erneut einspielbar'; END $r$;
