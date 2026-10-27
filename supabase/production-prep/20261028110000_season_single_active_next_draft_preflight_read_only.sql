-- READ ONLY preflight for 20261028110000_season_single_active_next_draft.sql (production iqarjivcrddcixrvqbfb).
SELECT current_database() AS database_name, current_user AS database_role;
-- Must be the 20261027120000 version (md5 7873619f3152021221dc319f279e6f2b):
SELECT md5(pg_get_functiondef('league_v21_private.season_transition_core(uuid,text)'::regprocedure)) AS season_transition_md5;
SELECT title, starts_on, ends_on, status FROM public.league_seasons_v21 ORDER BY starts_on;
SELECT count(*) FILTER (WHERE status='active') AS active_seasons FROM public.league_seasons_v21;
SELECT (SELECT count(*) FROM public.league_season_results_v21) AS season_results, (SELECT count(*) FROM public.league_hall_of_fame_v21) AS hall_of_fame;
