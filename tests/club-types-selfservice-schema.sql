\set ON_ERROR_STOP on
-- Disposable-database test for 20261029230000_club_types_selfservice.sql (Etappe 17a): fürs Erste jede Trainingsart selbst eintragen.
-- Sperre für Vereinstrainings nur noch mit gym_training UND club_checkin_only; Stufe/«eingetragen von» weiter nicht selbst setzbar.
-- Fixture: Vereinsstundenplan und Stufen (Etappe 6a) mit Rücknahme und erneutem Einspielen.
\ir club-schedule-tiers-schema.sql
CREATE TEMP TABLE ref17 AS SELECT md5(pg_get_functiondef('league_private.training_insert_guard()'::regprocedure)) AS guard,
 (SELECT count(*) FROM public.training_submissions) AS subs, (SELECT count(*)||'/'||coalesce(sum(points),0) FROM public.point_transactions) AS pts;
GRANT SELECT ON ref17 TO PUBLIC;
\ir ../supabase/production-prep/preflight_20261029230000_club_types_selfservice.sql
\ir ../supabase/migrations/20261029230000_club_types_selfservice.sql
\ir ../supabase/migrations/20261029230000_club_types_selfservice.sql
\ir ../supabase/production-prep/postflight_20261029230000_club_types_selfservice.sql

DO $t$ DECLARE sub uuid; today date := (now() AT TIME ZONE 'Europe/Zurich')::date; reg bigint; kraft bigint;
 anna text := '10000000-0000-0000-0000-000000000001'; coach text := '10000000-0000-0000-0000-00000000000c';
 annaP uuid := '00000000-0000-0000-0000-000000000001'; coachP uuid := '00000000-0000-0000-0000-00000000000c';
BEGIN
 PERFORM set_config('role','postgres',true);
 IF (SELECT subs FROM ref17)<>(SELECT count(*) FROM public.training_submissions) OR (SELECT pts FROM ref17)<>(SELECT count(*)||'/'||coalesce(sum(points),0) FROM public.point_transactions)
  THEN RAISE EXCEPTION 'data changed by migration'; END IF;
 IF (SELECT is_enabled FROM public.league_feature_flags WHERE feature_key='club_checkin_only') IS DISTINCT FROM false THEN RAISE EXCEPTION 'flag must start off'; END IF;
 SELECT id INTO reg FROM public.training_types WHERE name='Reguläres Boxtraining';
 SELECT id INTO kraft FROM public.training_types WHERE name='Krafttraining';
 IF NOT (SELECT club_only FROM public.training_types WHERE id=reg) THEN RAISE EXCEPTION 'club_only marker kept'; END IF;
 UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='gym_training';
 -- Gym an, neuer Schalter aus: Boxerin trägt Vereinstraining selbst ein; Stufe und «eingetragen von» werden weiter entfernt
 PERFORM pg_temp.act(anna);
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes,club_tier,recorded_by)
 VALUES (annaP,reg,today,'Selbst gemeldet','pending',60,'pflicht',coachP) RETURNING id INTO sub;
 PERFORM set_config('role','postgres',true);
 IF (SELECT club_tier IS NOT NULL OR recorded_by IS NOT NULL FROM public.training_submissions WHERE id=sub) THEN RAISE EXCEPTION 'tier/recorded_by'; END IF;
 DELETE FROM public.training_submissions WHERE id=sub;
 -- Schalter an: Vereinstraining gesperrt, Heimtraining weiter möglich, Trainer dürfen alles
 UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='club_checkin_only';
 PERFORM pg_temp.act(anna);
 BEGIN
  INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes) VALUES (annaP,reg,today,'Gesperrt','pending',60);
  RAISE EXCEPTION 'club type allowed with switch on';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes) VALUES (annaP,kraft,today,'Kraft','pending',60) RETURNING id INTO sub;
 PERFORM set_config('role','postgres',true);DELETE FROM public.training_submissions WHERE id=sub;
 PERFORM pg_temp.act(coach);
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes) VALUES (annaP,reg,today,'Vom Coach','pending',60) RETURNING id INTO sub;
 PERFORM set_config('role','postgres',true);DELETE FROM public.training_submissions WHERE id=sub;
 -- Gym aus: auch mit Schalter an keine Sperre (wie bisher)
 UPDATE public.league_feature_flags SET is_enabled=false WHERE feature_key='gym_training';
 PERFORM pg_temp.act(anna);
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes) VALUES (annaP,reg,today,'Gym aus','pending',60) RETURNING id INTO sub;
 PERFORM set_config('role','postgres',true);DELETE FROM public.training_submissions WHERE id=sub;
 UPDATE public.league_feature_flags SET is_enabled=false WHERE feature_key='club_checkin_only';
 RAISE NOTICE 'PASS: Etappe 17a – Schalter startet aus, Vereinstrainings selbst eintragbar, Sperre nur mit gym_training und club_checkin_only, Heimtraining und Trainer nie gesperrt, Stufe nicht selbst setzbar, Daten unverändert';
END $t$;

\ir ../supabase/production-prep/rollback_20261029230000_club_types_selfservice.sql
DO $r$ BEGIN
 IF md5(pg_get_functiondef('league_private.training_insert_guard()'::regprocedure))<>(SELECT guard FROM ref17) THEN RAISE EXCEPTION 'guard not restored'; END IF;
 IF EXISTS (SELECT 1 FROM public.league_feature_flags WHERE feature_key='club_checkin_only') THEN RAISE EXCEPTION 'flag left'; END IF;
 RAISE NOTICE 'PASS: Rücknahme stellt die Sperre wörtlich wieder her';
END $r$;
\ir ../supabase/migrations/20261029230000_club_types_selfservice.sql
DO $r$ BEGIN
 IF NOT EXISTS (SELECT 1 FROM public.league_feature_flags WHERE feature_key='club_checkin_only' AND NOT is_enabled) THEN RAISE EXCEPTION 're-apply'; END IF;
 RAISE NOTICE 'PASS: erneut einspielbar';
END $r$;
