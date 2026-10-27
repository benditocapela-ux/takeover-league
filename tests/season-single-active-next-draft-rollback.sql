\set ON_ERROR_STOP on
-- Runs after tests/season-single-active-next-draft-schema.sql in the same disposable database.
\ir ../supabase/production-prep/rollback_20261028110000_season_single_active_next_draft.sql
DO $t$ BEGIN
 IF position('next_draft' in pg_get_functiondef('league_v21_private.season_transition_core(uuid,text)'::regprocedure))>0 THEN RAISE EXCEPTION 'not restored'; END IF;
 IF (SELECT count(*) FROM public.league_seasons_v21)=0 OR (SELECT count(*) FROM public.league_season_results_v21)=0 THEN RAISE EXCEPTION 'rows changed'; END IF;
END $t$;
\ir ../supabase/migrations/20261028110000_season_single_active_next_draft.sql
SELECT 'PASS: rollback restores season_transition_core, keeps seasons and results; re-apply works' AS result;
