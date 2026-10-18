-- Takeover League 2.0 / Achievement migration prerequisites. READ ONLY.
-- Verify transaction category and uniqueness, flags and trigger before writing.
SELECT feature_key,is_enabled FROM public.league_feature_flags
WHERE feature_key='achievements';
SELECT con.conrelid::regclass::text AS table_name,con.conname,pg_get_constraintdef(con.oid) AS definition
FROM pg_constraint con
WHERE con.conrelid IN ('public.achievement_definitions'::regclass,
 'public.boxer_achievements'::regclass,'public.point_transactions'::regclass)
ORDER BY table_name,con.conname;
SELECT c.relname AS table_name,t.tgname AS trigger_name,
 pg_get_triggerdef(t.oid) AS trigger_definition
FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid
JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND NOT t.tgisinternal
 AND c.relname IN ('training_submissions','boxer_achievements','point_transactions')
ORDER BY table_name,trigger_name;
SELECT category,COUNT(*) AS transactions FROM public.point_transactions
GROUP BY category ORDER BY category;
SELECT COUNT(*) AS active_boxers FROM public.profiles
WHERE role='boxer' AND is_active=true;
