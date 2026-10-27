-- READ ONLY preflight for 20261028090000_league_challenges_arena_admin.sql (production iqarjivcrddcixrvqbfb).
SELECT current_database() AS database_name, current_user AS database_role;
-- Must match the 27.10.2026 review (md5 of the replaced function):
SELECT md5(pg_get_functiondef('league_v21_private.arena_create_core(text,integer,uuid[])'::regprocedure)) AS arena_create_md5,
       '4cc7df18' AS expected_prefix;
SELECT to_regprocedure('league_v21_private.notifications_enabled()') IS NOT NULL AS gamification_migration_present,
       to_regprocedure('public.league_v21_arena_cancel(uuid)') IS NULL AS cancel_not_yet_present;
SELECT status, count(*) FROM public.league_global_challenges_v21 GROUP BY 1 ORDER BY 1;
SELECT status, count(*) FROM public.league_arena_duels_v21 GROUP BY 1 ORDER BY 1;
SELECT (SELECT count(*) FROM public.point_transactions) AS point_transactions,
       (SELECT coalesce(sum(exp),0) FROM public.point_transactions) AS exp_sum,
       (SELECT count(*) FROM public.boxer_notifications) AS notifications;
