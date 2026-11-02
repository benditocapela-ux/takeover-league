-- READ ONLY after migration. Both rows MUST remain disabled and reward/type mapping NULL.
SELECT metric,enabled,reward_rule,jogging_training_type_id FROM league_v21_private.duel_metric_config ORDER BY metric;
SELECT n.nspname,p.proname,p.prosecdef,p.proconfig,
 has_function_privilege('anon',p.oid,'EXECUTE') AS anon_execute,
 has_function_privilege('authenticated',p.oid,'EXECUTE') AS authenticated_execute
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE (n.nspname='public' AND p.proname LIKE 'duel_v3_%')
 OR (n.nspname='league_v21_private' AND p.proname IN ('duel_metric_snapshot','duel_metric_reconcile_core','duel_v3_visible','duel_v3_item','training_receipt_guard'))
ORDER BY n.nspname,p.proname;
SELECT has_table_privilege('authenticated','league_v21_private.duel_metric_config','SELECT') AS client_config_read,
 has_table_privilege('authenticated','league_v21_private.duel_metric_config','UPDATE') AS client_config_write;
SELECT feature_key,is_enabled FROM public.league_feature_flags WHERE feature_key IN ('duels','notifications') ORDER BY feature_key;
SELECT scoring_metric,count(*) FROM public.league_duels GROUP BY scoring_metric ORDER BY scoring_metric;
-- Receipt guard must be enabled, SECURITY INVOKER, empty search_path, and not directly executable by clients.
SELECT column_name,data_type,is_nullable,column_default FROM information_schema.columns
 WHERE table_schema='public' AND table_name='training_submissions' AND column_name='server_received_at';
SELECT tgname,tgenabled,pg_get_triggerdef(oid) AS definition FROM pg_trigger
 WHERE tgrelid='public.training_submissions'::regclass AND tgname='zz_league_training_receipt_guard';
-- Aggregate only; no submissions or participant data exposed. Existing rows intentionally remain NULL.
SELECT count(*) FILTER (WHERE server_received_at IS NULL) AS historical_unverified_receipts,
 count(*) FILTER (WHERE server_received_at IS NOT NULL) AS trusted_receipts
 FROM public.training_submissions;
