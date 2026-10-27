\set ON_ERROR_STOP on
-- Runs after tests/league-challenges-arena-admin-schema.sql in the same disposable database.
\ir ../supabase/production-prep/rollback_20261028090000_league_challenges_arena_admin.sql
DO $t$ BEGIN
 IF to_regprocedure('public.league_v21_arena_cancel(uuid)') IS NOT NULL
    OR to_regprocedure('public.league_v21_admin_publish_global_challenge(uuid)') IS NOT NULL THEN RAISE EXCEPTION 'new RPCs left behind'; END IF;
 IF position('is_listed' in pg_get_functiondef('league_v21_private.arena_create_core(text,integer,uuid[])'::regprocedure))>0 THEN
  RAISE EXCEPTION 'arena_create_core not restored'; END IF;
 IF (SELECT count(*) FROM public.league_arena_duels_v21 WHERE status='cancelled')=0 OR (SELECT count(*) FROM public.boxer_notifications)=0 THEN
  RAISE EXCEPTION 'rollback must keep rows'; END IF;
END $t$;
\ir ../supabase/migrations/20261028090000_league_challenges_arena_admin.sql
SELECT 'PASS: rollback removes the new RPCs, restores arena_create_core, keeps rows; re-apply works' AS result;
