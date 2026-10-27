-- Rollback for 20261028120000_revoke_unused_legacy_rpcs.sql: restores EXECUTE for authenticated (state before).
BEGIN;
DO $grant$
DECLARE fn text;
BEGIN
 FOREACH fn IN ARRAY ARRAY[
  'public.boxer_join_league_challenge(uuid)','public.boxer_respond_duel_invite(uuid,boolean)',
  'public.coach_add_boxer_palmares(uuid,text,text,text,text,date,text)','public.coach_add_hall_of_fame_entry(uuid,text,text,text,uuid,date)',
  'public.coach_award_season_hall_of_fame(uuid)','public.coach_create_boxer_duel(uuid,uuid,text,text,text,date,date,numeric)',
  'public.coach_create_league_challenge(text,text,date,date,text,numeric)','public.coach_create_league_season(text,date,date,text)',
  'public.coach_finalize_boxer_duel(uuid)','public.coach_finalize_league_season(uuid)','public.coach_set_boxer_duel_status(uuid,text)',
  'public.coach_set_goal_status(uuid,text)','public.coach_set_league_challenge_status(uuid,text)','public.coach_set_league_season_status(uuid,text)',
  'public.get_boxer_duel_score(uuid)','public.get_league_challenge_progress(uuid,uuid)'
 ] LOOP
  IF to_regprocedure(fn) IS NOT NULL THEN EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated', fn); END IF;
 END LOOP;
END
$grant$;
NOTIFY pgrst, 'reload schema';
COMMIT;
