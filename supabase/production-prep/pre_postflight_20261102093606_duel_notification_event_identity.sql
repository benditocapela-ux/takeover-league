-- READ ONLY. Before: event_key/index absent. After: text column and partial unique index present.
SELECT feature_key,is_enabled FROM public.league_feature_flags
 WHERE feature_key IN ('duels','notifications') ORDER BY feature_key;
SELECT column_name,data_type,is_nullable FROM information_schema.columns
 WHERE table_schema='public' AND table_name='boxer_notifications' AND column_name='event_key';
SELECT indexname,indexdef FROM pg_indexes WHERE schemaname='public'
 AND tablename='boxer_notifications' AND indexname='boxer_notifications_recipient_event_key_uidx';
SELECT grantee,privilege_type FROM information_schema.role_table_grants
 WHERE table_schema='public' AND table_name='boxer_notifications' AND grantee IN ('anon','authenticated');
SELECT p.prosecdef,p.proconfig,has_function_privilege('anon',p.oid,'EXECUTE') AS anon_execute,
 has_function_privilege('authenticated',p.oid,'EXECUTE') AS authenticated_execute,
 md5(pg_get_functiondef(p.oid)) AS definition_hash
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='league_v21_private' AND p.proname='notify_duel_events';
-- No rows, titles, recipients, read acknowledgements or payouts are changed by this script.
