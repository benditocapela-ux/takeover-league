\set ON_ERROR_STOP on
-- Disposable-database test for 20261028120000_revoke_unused_legacy_rpcs.sql (+ rollback).
CREATE ROLE anon;
CREATE ROLE authenticated;
DO $mk$
DECLARE sig text;
BEGIN
 FOREACH sig IN ARRAY ARRAY['boxer_join_league_challenge(uuid)','boxer_respond_duel_invite(uuid,boolean)',
  'coach_add_boxer_palmares(uuid,text,text,text,text,date,text)','coach_add_hall_of_fame_entry(uuid,text,text,text,uuid,date)',
  'coach_award_season_hall_of_fame(uuid)','coach_create_boxer_duel(uuid,uuid,text,text,text,date,date,numeric)',
  'coach_create_league_challenge(text,text,date,date,text,numeric)','coach_create_league_season(text,date,date,text)',
  'coach_finalize_boxer_duel(uuid)','coach_finalize_league_season(uuid)','coach_set_boxer_duel_status(uuid,text)',
  'coach_set_goal_status(uuid,text)','coach_set_league_challenge_status(uuid,text)','coach_set_league_season_status(uuid,text)',
  'get_boxer_duel_score(uuid)'] LOOP
  EXECUTE format('CREATE FUNCTION public.%s RETURNS void LANGUAGE sql SECURITY DEFINER AS $f$ select $f$', sig);
  EXECUTE format('GRANT EXECUTE ON FUNCTION public.%s TO authenticated', sig);
 END LOOP;
END $mk$;
-- One function intentionally missing (get_league_challenge_progress) like in the test project.
CREATE FUNCTION public.review_training(uuid,text) RETURNS void LANGUAGE sql SECURITY DEFINER AS $f$ select $f$;
GRANT EXECUTE ON FUNCTION public.review_training(uuid,text) TO authenticated;

\ir ../supabase/migrations/20261028120000_revoke_unused_legacy_rpcs.sql
DO $t$ BEGIN
 IF EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname<>'review_training'
   AND (has_function_privilege('authenticated',p.oid,'execute') OR has_function_privilege('anon',p.oid,'execute'))) THEN RAISE EXCEPTION 'legacy RPC still executable'; END IF;
 IF NOT has_function_privilege('authenticated','public.review_training(uuid,text)','execute') THEN RAISE EXCEPTION 'active RPC touched'; END IF;
END $t$;
\ir ../supabase/migrations/20261028120000_revoke_unused_legacy_rpcs.sql
\ir ../supabase/production-prep/rollback_20261028120000_revoke_unused_legacy_rpcs.sql
DO $t$ BEGIN
 IF NOT has_function_privilege('authenticated','public.coach_create_league_season(text,date,date,text)','execute') THEN RAISE EXCEPTION 'rollback failed'; END IF;
END $t$;
SELECT 'PASS: 16 unused legacy RPCs revoked (missing ones skipped), active RPCs untouched, idempotent, rollback restores grants' AS result;
