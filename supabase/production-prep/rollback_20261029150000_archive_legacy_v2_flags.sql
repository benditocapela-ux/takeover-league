-- Rücknahme von 20261029150000_archive_legacy_v2_flags.sql: holt die 9 alten Tabellen und 16 alten Funktionen unverändert
-- (mit Regeln, Indizes, Rechten) aus legacy_v2_archive zurück nach public und legt die 7 alten Schalter wieder an (AUS).
-- Abbruch ohne Änderung, wenn in public inzwischen etwas mit gleichem Namen existiert.
BEGIN;
DO $$
DECLARE t text; f text;
 tabs text[] := ARRAY['league_seasons','league_challenges','league_challenge_participants','league_season_results','league_hall_of_fame',
   'boxer_duels','boxer_coach_goals','boxer_palmares','boxer_public_profile_details'];
 fns text[] := ARRAY['boxer_join_league_challenge(uuid)','boxer_respond_duel_invite(uuid,boolean)',
   'coach_add_boxer_palmares(uuid,text,text,text,text,date,text)','coach_add_hall_of_fame_entry(uuid,text,text,text,uuid,date)',
   'coach_award_season_hall_of_fame(uuid)','coach_create_boxer_duel(uuid,uuid,text,text,text,date,date,numeric)',
   'coach_create_league_challenge(text,text,date,date,text,numeric)','coach_create_league_season(text,date,date,text)',
   'coach_finalize_boxer_duel(uuid)','coach_finalize_league_season(uuid)','coach_set_boxer_duel_status(uuid,text)',
   'coach_set_goal_status(uuid,text)','coach_set_league_challenge_status(uuid,text)','coach_set_league_season_status(uuid,text)',
   'get_boxer_duel_score(uuid)','get_league_challenge_progress(uuid,uuid)'];
BEGIN
 IF to_regnamespace('legacy_v2_archive') IS NULL THEN RAISE EXCEPTION 'Rücknahme abgebrochen: kein Archiv vorhanden'; END IF;
 FOREACH t IN ARRAY tabs LOOP
  IF to_regclass('legacy_v2_archive.'||t) IS NOT NULL AND to_regclass('public.'||t) IS NOT NULL THEN
   RAISE EXCEPTION 'Rücknahme abgebrochen: public.% existiert schon', t;
  END IF;
 END LOOP;
 FOREACH f IN ARRAY fns LOOP
  IF to_regprocedure('legacy_v2_archive.'||f) IS NOT NULL AND to_regprocedure('public.'||f) IS NOT NULL THEN
   RAISE EXCEPTION 'Rücknahme abgebrochen: public.% existiert schon', f;
  END IF;
 END LOOP;
 FOREACH t IN ARRAY tabs LOOP
  IF to_regclass('legacy_v2_archive.'||t) IS NOT NULL THEN EXECUTE format('ALTER TABLE legacy_v2_archive.%I SET SCHEMA public', t); END IF;
 END LOOP;
 FOREACH f IN ARRAY fns LOOP
  IF to_regprocedure('legacy_v2_archive.'||f) IS NOT NULL THEN EXECUTE 'ALTER FUNCTION legacy_v2_archive.'||f||' SET SCHEMA public'; END IF;
 END LOOP;
END $$;
INSERT INTO public.league_feature_flags(feature_key,display_name,is_enabled) VALUES
 ('boxer_duels','Boxer-Duelle',false),('coach_goals','Coach-Ziele',false),('hall_of_fame','Hall of Fame',false),
 ('league_challenges','Liga-Challenges',false),('palmares','Palmarès',false),('public_boxer_profiles','Öffentliche Boxerprofile',false),
 ('seasons','Saisons',false)
ON CONFLICT (feature_key) DO NOTHING;
DROP SCHEMA legacy_v2_archive;  -- RESTRICT: nur wenn das Archiv jetzt leer ist
NOTIFY pgrst, 'reload schema';
COMMIT;
