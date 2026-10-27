-- READ ONLY preflight for 20261028100000_goals_coach_archive.sql (production iqarjivcrddcixrvqbfb).
SELECT current_database() AS database_name, current_user AS database_role;
-- md5 prefixes must match the 27.10.2026 review:
SELECT p.proname, left(md5(pg_get_functiondef(p.oid)),8) AS md5_prefix,
 CASE p.proname WHEN 'goal_upsert_core' THEN '3ad32d7b' WHEN 'goal_progress_core' THEN '6cb7a61e' WHEN 'complete_goal_core' THEN '3455a708'
  WHEN 'complete_and_reward_goal_core' THEN '08a93bb0' WHEN 'goal_after_training_review' THEN 'e9b8d128' END AS expected
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='league_v21_private' AND p.proname IN ('goal_upsert_core','goal_progress_core','complete_goal_core','complete_and_reward_goal_core','goal_after_training_review')
ORDER BY 1;
SELECT status, count(*) FROM public.league_boxer_goals_v21 GROUP BY 1 ORDER BY 1;
SELECT (SELECT count(*) FROM public.league_goal_exp_ledger_v21) AS goal_exp_rows,
       (SELECT coalesce(sum(exp),0) FROM public.point_transactions) AS exp_sum,
       (SELECT count(*) FROM public.boxer_notifications) AS notifications;
