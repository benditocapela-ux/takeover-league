-- READ ONLY. No preview/closure calls and no feature flag writes.
SELECT n.nspname,p.proname,pg_get_function_identity_arguments(p.oid) AS arguments,
 p.provolatile,p.prosecdef,p.proconfig,
 has_function_privilege('anon',p.oid,'EXECUTE') AS anon_execute,
 has_function_privilege('authenticated',p.oid,'EXECUTE') AS authenticated_execute
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE p.proname IN ('duel_points_snapshot','duel_points_reward','duel_close_preview_core',
 'duel_close_confirm_core','duel_v2_close_preview','duel_v2_close_confirm',
 'duel_v2_live_scores_core','duel_reconcile_ranked_core')
 AND n.nspname IN ('public','league_v21_private','league_duel_private')
ORDER BY n.nspname,p.proname;
SELECT feature_key,is_enabled FROM public.league_feature_flags
 WHERE feature_key IN ('duels','notifications') ORDER BY feature_key;
SELECT p.proname,position('duel_points_snapshot' IN pg_get_functiondef(p.oid))>0 AS shared_scorer
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE (n.nspname,p.proname) IN (
 ('league_duel_private','duel_v2_live_scores_core'),('league_v21_private','duel_reconcile_ranked_core'));
