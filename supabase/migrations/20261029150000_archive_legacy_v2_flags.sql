BEGIN;
-- Aufräumen (28.10.2026, Owner-Auftrag): die 7 alten V2-Schalter boxer_duels, coach_goals, hall_of_fame, league_challenges,
-- palmares, public_boxer_profiles und seasons verschwinden. Sie schalteten nur noch Altstrukturen frei, die keine Seite nutzt;
-- Duelle, Coach-Ziele, Saisons, Hall of Fame und Liga-Challenges laufen über die neuen Strukturen (duels, coach_challenges, Liga 2.1).
-- * Die 9 alten, leeren Tabellen und die 16 alten Funktionen wandern unverändert (mit Regeln, Indizes, Rechten) in das
--   gesperrte Schema legacy_v2_archive. Niemand ausser dem Datenbank-Owner kommt dort hin. Nichts wird gelöscht.
-- * Die 7 Schalter-Zeilen werden entfernt.
-- * Abbruch ohne Änderung, wenn ein alter Schalter an ist, eine alte Tabelle Zeilen hat oder fremde Objekte daran hängen.
-- Rücknahme: supabase/production-prep/rollback_20261029150000_archive_legacy_v2_flags.sql (holt alles zurück).

DO $$
DECLARE t text; n bigint; legacy oid[];
BEGIN
 IF EXISTS (SELECT 1 FROM public.league_feature_flags WHERE is_enabled AND feature_key IN
   ('boxer_duels','coach_goals','hall_of_fame','league_challenges','palmares','public_boxer_profiles','seasons')) THEN
  RAISE EXCEPTION 'Abbruch: ein alter Schalter ist eingeschaltet – bitte zuerst prüfen';
 END IF;
 FOREACH t IN ARRAY ARRAY['boxer_duels','boxer_coach_goals','league_hall_of_fame','league_challenges','league_challenge_participants',
   'boxer_palmares','boxer_public_profile_details','league_seasons','league_season_results'] LOOP
  IF to_regclass('public.'||t) IS NOT NULL THEN
   EXECUTE format('SELECT count(*) FROM public.%I', t) INTO n;
   IF n>0 THEN RAISE EXCEPTION 'Abbruch: public.% enthält % Zeilen – nichts verschoben', t, n; END IF;
   legacy := legacy || ('public.'||t)::regclass::oid;
  END IF;
 END LOOP;
 IF EXISTS (SELECT 1 FROM pg_constraint c WHERE c.contype='f' AND c.confrelid=ANY(legacy) AND NOT c.conrelid=ANY(legacy)) THEN
  RAISE EXCEPTION 'Abbruch: eine andere Tabelle verweist auf eine alte Tabelle';
 END IF;
 IF EXISTS (SELECT 1 FROM pg_depend d JOIN pg_rewrite r ON r.oid=d.objid WHERE d.classid='pg_rewrite'::regclass
   AND d.refobjid=ANY(legacy) AND NOT r.ev_class=ANY(legacy)) THEN
  RAISE EXCEPTION 'Abbruch: eine Ansicht hängt an einer alten Tabelle';
 END IF;
END $$;

CREATE SCHEMA IF NOT EXISTS legacy_v2_archive;
REVOKE ALL ON SCHEMA legacy_v2_archive FROM PUBLIC, anon, authenticated, service_role;
COMMENT ON SCHEMA legacy_v2_archive IS 'Gesperrtes Archiv der alten V2-Strukturen (seit 20261029150000). Nicht für die App. Rücknahme siehe production-prep.';

DO $$
DECLARE t text; f text;
BEGIN
 FOREACH t IN ARRAY ARRAY['league_challenge_participants','league_challenges','league_season_results','league_hall_of_fame','league_seasons',
   'boxer_duels','boxer_coach_goals','boxer_palmares','boxer_public_profile_details'] LOOP
  IF to_regclass('public.'||t) IS NOT NULL THEN
   EXECUTE format('ALTER TABLE public.%I SET SCHEMA legacy_v2_archive', t);
  END IF;
 END LOOP;
 FOREACH f IN ARRAY ARRAY[
   'boxer_join_league_challenge(uuid)','boxer_respond_duel_invite(uuid,boolean)',
   'coach_add_boxer_palmares(uuid,text,text,text,text,date,text)','coach_add_hall_of_fame_entry(uuid,text,text,text,uuid,date)',
   'coach_award_season_hall_of_fame(uuid)','coach_create_boxer_duel(uuid,uuid,text,text,text,date,date,numeric)',
   'coach_create_league_challenge(text,text,date,date,text,numeric)','coach_create_league_season(text,date,date,text)',
   'coach_finalize_boxer_duel(uuid)','coach_finalize_league_season(uuid)','coach_set_boxer_duel_status(uuid,text)',
   'coach_set_goal_status(uuid,text)','coach_set_league_challenge_status(uuid,text)','coach_set_league_season_status(uuid,text)',
   'get_boxer_duel_score(uuid)','get_league_challenge_progress(uuid,uuid)'] LOOP
  IF to_regprocedure('public.'||f) IS NOT NULL THEN
   EXECUTE 'ALTER FUNCTION public.'||f||' SET SCHEMA legacy_v2_archive';
  END IF;
 END LOOP;
END $$;

DELETE FROM public.league_feature_flags WHERE NOT is_enabled AND feature_key IN
 ('boxer_duels','coach_goals','hall_of_fame','league_challenges','palmares','public_boxer_profiles','seasons');

NOTIFY pgrst, 'reload schema';
COMMIT;
