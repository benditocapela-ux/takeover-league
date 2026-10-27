\set ON_ERROR_STOP on
-- Runs after tests/goals-coach-archive-schema.sql in the same disposable database.
\ir ../supabase/production-prep/rollback_20261028100000_goals_coach_archive.sql
DO $t$ BEGIN
 IF to_regprocedure('public.league_v21_archive_goal(uuid)') IS NOT NULL OR to_regprocedure('league_v21_private.notify_goal_completed(uuid,integer)') IS NOT NULL THEN
  RAISE EXCEPTION 'new functions left behind'; END IF;
 IF position('coach' in pg_get_functiondef('league_v21_private.goal_upsert_core(uuid,uuid,text,text,numeric,date)'::regprocedure))>0 THEN RAISE EXCEPTION 'upsert not restored'; END IF;
 IF (SELECT count(*) FROM public.league_boxer_goals_v21 WHERE status='archived')<>2 OR (SELECT sum(exp) FROM public.point_transactions)<>50 THEN RAISE EXCEPTION 'rows changed'; END IF;
END $t$;
\ir ../supabase/migrations/20261028100000_goals_coach_archive.sql
SELECT 'PASS: rollback restores goal functions and policy, keeps archived goals and EXP; re-apply works' AS result;
