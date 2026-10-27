-- Angriffsfläche reduzieren: ungenutzte Takeover-League-2.0-RPCs nicht mehr für angemeldete Nutzer ausführbar.
-- Alle 16 Funktionen sind vom Frontend nicht mehr referenziert (2.1 ersetzt sie), hinter ausgeschalteten
-- Feature-Flags gesperrt und werden von keiner RLS-Policy und keiner aktiven Funktion verwendet
-- (Ausnahme: get_boxer_duel_score wird nur von der ebenfalls ungenutzten coach_finalize_boxer_duel aufgerufen).
-- Die Funktionen bleiben bestehen (kein DROP); der Owner (postgres/service_role) kann sie weiter nutzen.
-- Idempotent und robust gegen fehlende Funktionen (z. B. im Testprojekt).
-- Produktion nur über den regulären Migrationsweg und eine separate ausdrückliche FREIGABE.
BEGIN;
DO $revoke$
DECLARE fn text;
BEGIN
 FOREACH fn IN ARRAY ARRAY[
  'public.boxer_join_league_challenge(uuid)',
  'public.boxer_respond_duel_invite(uuid,boolean)',
  'public.coach_add_boxer_palmares(uuid,text,text,text,text,date,text)',
  'public.coach_add_hall_of_fame_entry(uuid,text,text,text,uuid,date)',
  'public.coach_award_season_hall_of_fame(uuid)',
  'public.coach_create_boxer_duel(uuid,uuid,text,text,text,date,date,numeric)',
  'public.coach_create_league_challenge(text,text,date,date,text,numeric)',
  'public.coach_create_league_season(text,date,date,text)',
  'public.coach_finalize_boxer_duel(uuid)',
  'public.coach_finalize_league_season(uuid)',
  'public.coach_set_boxer_duel_status(uuid,text)',
  'public.coach_set_goal_status(uuid,text)',
  'public.coach_set_league_challenge_status(uuid,text)',
  'public.coach_set_league_season_status(uuid,text)',
  'public.get_boxer_duel_score(uuid)',
  'public.get_league_challenge_progress(uuid,uuid)'
 ] LOOP
  IF to_regprocedure(fn) IS NOT NULL THEN
   EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon, authenticated', fn);
  END IF;
 END LOOP;
END
$revoke$;
NOTIFY pgrst, 'reload schema';
COMMIT;
