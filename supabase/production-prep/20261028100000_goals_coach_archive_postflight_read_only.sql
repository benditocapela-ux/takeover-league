-- READ ONLY postflight for 20261028100000_goals_coach_archive.sql.
SELECT current_database() AS database_name, current_user AS database_role;
SELECT position('''coach''' in pg_get_functiondef('league_v21_private.goal_upsert_core(uuid,uuid,text,text,numeric,date)'::regprocedure))>0 AS coach_assigns,
       position('Assigned manual goals are confirmed by the coach' in pg_get_functiondef('league_v21_private.goal_progress_core(uuid,numeric,text)'::regprocedure))>0 AS no_self_confirm,
       position('''coach'',''admin''' in pg_get_functiondef('league_v21_private.goal_after_training_review()'::regprocedure))>0 AS coach_review_reconciles,
       to_regprocedure('public.league_v21_archive_goal(uuid)') IS NOT NULL AS archive_rpc;
SELECT polname, pg_get_expr(polqual,polrelid) FROM pg_policy WHERE polrelid='public.league_boxer_goals_v21'::regclass;
-- Must equal the preflight numbers:
SELECT status, count(*) FROM public.league_boxer_goals_v21 GROUP BY 1 ORDER BY 1;
SELECT (SELECT count(*) FROM public.league_goal_exp_ledger_v21) AS goal_exp_rows,
       (SELECT coalesce(sum(exp),0) FROM public.point_transactions) AS exp_sum,
       (SELECT count(*) FROM public.boxer_notifications) AS notifications;
