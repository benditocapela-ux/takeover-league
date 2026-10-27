-- READ ONLY postflight for 20261028110000_season_single_active_next_draft.sql.
SELECT current_database() AS database_name, current_user AS database_role;
SELECT position('Another season is already active' in pg_get_functiondef('league_v21_private.season_transition_core(uuid,text)'::regprocedure))>0 AS single_active_guard,
       position('next_draft' in pg_get_functiondef('league_v21_private.season_transition_core(uuid,text)'::regprocedure))>0 AS next_draft_prepared;
-- Must equal the preflight:
SELECT title, starts_on, ends_on, status FROM public.league_seasons_v21 ORDER BY starts_on;
SELECT (SELECT count(*) FROM public.league_season_results_v21) AS season_results, (SELECT count(*) FROM public.league_hall_of_fame_v21) AS hall_of_fame;
