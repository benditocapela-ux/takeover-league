-- READ ONLY. Save results alongside a separately authorized deployment record.
SELECT current_database(),current_setting('server_version') AS postgres_version,
 current_setting('TimeZone') AS server_timezone,statement_timestamp() AS checked_at;
SELECT feature_key,is_enabled FROM public.league_feature_flags
 WHERE feature_key IN ('duels','notifications') ORDER BY feature_key;
SELECT n.nspname,p.proname,pg_get_function_identity_arguments(p.oid) AS arguments,
 p.provolatile,p.prosecdef,p.proconfig,md5(pg_get_functiondef(p.oid)) AS definition_hash,
 has_function_privilege('anon',p.oid,'EXECUTE') AS anon_execute,
 has_function_privilege('authenticated',p.oid,'EXECUTE') AS authenticated_execute
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE (n.nspname,p.proname) IN (
 ('league_duel_private','duel_v2_live_scores_core'),
 ('league_v21_private','duel_reconcile_ranked_core'),
 ('public','duel_v2_live_scores'),('public','duel_v2_reconcile'))
ORDER BY n.nspname,p.proname;
SELECT table_name,column_name,data_type FROM information_schema.columns
WHERE table_schema='public' AND ((table_name='profiles' AND column_name='archived_at')
 OR (table_name='league_duels' AND column_name IN ('accepted_at','ends_at','challenger_score','opponent_score')))
ORDER BY table_name,column_name;
-- Aggregate only: no boxer names, raw training details or ledger identities are exposed.
SELECT d.status,count(*) AS duels FROM public.league_duels d GROUP BY d.status ORDER BY d.status;
SELECT count(*) AS approved_submissions_with_invalid_points_ledger FROM (
 SELECT s.id FROM public.training_submissions s
 LEFT JOIN public.point_transactions t ON t.submission_id=s.id AND t.boxer_id=s.boxer_id
  AND t.category IN ('training','legacy_import')
 WHERE s.status='approved' AND EXISTS(
  SELECT 1 FROM public.league_duels d WHERE d.status IN ('active','awaiting_reviews')
   AND s.boxer_id IN (d.challenger_id,d.opponent_id) AND s.created_at<=least(statement_timestamp(),d.ends_at)
   AND s.training_date BETWEEN (d.accepted_at AT TIME ZONE 'Europe/Zurich')::date
    AND least((d.ends_at AT TIME ZONE 'Europe/Zurich')::date,(statement_timestamp() AT TIME ZONE 'Europe/Zurich')::date))
 GROUP BY s.id HAVING count(t.id)<>1
) issues;
