-- READ ONLY; inspect before a separately authorized migration. No configuration changes.
SELECT current_setting('server_version') AS postgres_version,current_setting('TimeZone') AS server_timezone;
SELECT conname,pg_get_constraintdef(oid) AS definition FROM pg_constraint
 WHERE conrelid='public.league_duels'::regclass AND contype='c' ORDER BY conname;
SELECT feature_key,is_enabled FROM public.league_feature_flags WHERE feature_key IN ('duels','notifications') ORDER BY feature_key;
SELECT column_name,data_type FROM information_schema.columns WHERE table_schema='public'
 AND ((table_name='profiles' AND column_name IN ('is_listed','archived_at'))
  OR (table_name='boxer_notifications' AND column_name='event_key')
  OR (table_name='training_submissions' AND column_name IN ('created_at','server_received_at')))
 ORDER BY table_name,column_name;
-- Before this migration created_at is client-writable. Historical timestamps cannot be verified retroactively.
-- The new receipt column deliberately has no historical backfill.
SELECT has_table_privilege('authenticated','public.training_submissions','INSERT') AS client_training_insert,
 has_column_privilege('authenticated','public.training_submissions','created_at','INSERT') AS client_created_at_insert;
SELECT tgname,tgenabled,pg_get_triggerdef(oid) AS definition FROM pg_trigger
 WHERE tgrelid='public.training_submissions'::regclass AND NOT tgisinternal ORDER BY tgname;
SELECT n.nspname,p.proname,md5(pg_get_functiondef(p.oid)) AS definition_hash FROM pg_proc p
 JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE (n.nspname,p.proname) IN (('public','duel_v2_invite'),('public','duel_v2_respond'),
 ('public','duel_v2_list_mine'),('public','duel_v2_reconcile_due'),('league_v21_private','sync_public_duel_history'),
 ('league_v21_private','notify_duel_events')) ORDER BY n.nspname,p.proname;
-- Training IDs are shown for review; the migration does not silently choose a jogging type or reward rule.
SELECT id,name,is_active FROM public.training_types ORDER BY id;
