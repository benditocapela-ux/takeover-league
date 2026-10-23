-- READ ONLY preflight. Run against the intended database before a separately approved migration.
SELECT current_database() AS database_name, current_user AS database_role;
SELECT
  to_regclass('public.league_coach_challenges') AS challenges_table,
  to_regclass('public.league_coach_challenge_entries') AS entries_table,
  to_regclass('public.league_coach_challenge_reviews') AS reviews_table,
  to_regclass('public.league_coach_challenge_exp_ledger') AS exp_ledger_table,
  to_regclass('public.league_coach_challenge_targets') AS targets_table,
  to_regclass('public.point_transactions') AS points_ledger_table;
SELECT feature_key,is_enabled
FROM public.league_feature_flags
WHERE feature_key='coach_challenges';
SELECT to_regprocedure('public.coach_challenge_v2_delete_draft(uuid)') AS delete_draft_rpc;
SELECT status,count(*) AS challenge_count
FROM public.league_coach_challenges
GROUP BY status
ORDER BY status;
