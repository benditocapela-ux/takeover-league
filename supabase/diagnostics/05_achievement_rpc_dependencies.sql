-- Read-only: check functions that depend on points, EXP and achievement tables.
SELECT p.proname AS function_name, pg_get_functiondef(p.oid) AS function_definition
FROM pg_proc p
JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public'
  AND p.proname IN ('get_boxer_exp_level_rank','get_public_levels',
                   'get_public_leaderboard','admin_edit_training_details',
                   'admin_edit_training','review_training')
ORDER BY p.proname;

-- Current feature state
SELECT feature_key,is_enabled
FROM public.league_feature_flags
WHERE feature_key='achievements';

-- Relevant indexes (including non-constraint indexes)
SELECT tablename,indexname,indexdef
FROM pg_indexes
WHERE schemaname='public'
 AND tablename IN ('boxer_achievements','point_transactions','training_submissions')
ORDER BY tablename,indexname;
