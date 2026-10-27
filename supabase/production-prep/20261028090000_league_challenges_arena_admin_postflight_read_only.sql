-- READ ONLY postflight for 20261028090000_league_challenges_arena_admin.sql.
SELECT current_database() AS database_name, current_user AS database_role;
SELECT p.oid::regprocedure AS fn, array_to_string(p.proacl,' ') AS acl FROM pg_proc p
WHERE p.oid IN (to_regprocedure('public.league_v21_admin_update_global_draft(uuid,text,text,text,numeric,timestamptz,timestamptz)'),
                to_regprocedure('public.league_v21_admin_publish_global_challenge(uuid)'),
                to_regprocedure('public.league_v21_admin_delete_global_draft(uuid)'),
                to_regprocedure('public.league_v21_arena_cancel(uuid)'));
SELECT position('p.is_listed' in pg_get_functiondef('league_v21_private.arena_create_core(text,integer,uuid[])'::regprocedure))>0 AS arena_public_only;
-- Must equal the preflight numbers:
SELECT status, count(*) FROM public.league_global_challenges_v21 GROUP BY 1 ORDER BY 1;
SELECT status, count(*) FROM public.league_arena_duels_v21 GROUP BY 1 ORDER BY 1;
SELECT (SELECT count(*) FROM public.point_transactions) AS point_transactions,
       (SELECT coalesce(sum(exp),0) FROM public.point_transactions) AS exp_sum,
       (SELECT count(*) FROM public.boxer_notifications) AS notifications;
