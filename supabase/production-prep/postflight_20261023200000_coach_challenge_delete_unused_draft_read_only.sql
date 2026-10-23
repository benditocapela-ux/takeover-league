-- READ ONLY postflight. No RPC is called and no rows are changed.
SELECT
  to_regprocedure('public.coach_challenge_v2_delete_draft(uuid)') AS delete_draft_rpc,
  has_function_privilege('anon','public.coach_challenge_v2_delete_draft(uuid)','EXECUTE') AS anon_can_execute,
  has_function_privilege('authenticated','public.coach_challenge_v2_delete_draft(uuid)','EXECUTE') AS authenticated_can_execute;
SELECT feature_key,is_enabled
FROM public.league_feature_flags
WHERE feature_key='coach_challenges';
SELECT status,count(*) AS challenge_count
FROM public.league_coach_challenges
GROUP BY status
ORDER BY status;
