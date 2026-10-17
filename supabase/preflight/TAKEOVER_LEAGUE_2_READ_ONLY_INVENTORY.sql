-- Takeover League 2.0: READ-ONLY inventory, for explicit owner review only.
-- This script does not grant permission to run it or any production migration.
-- Run in a transaction marked READ ONLY. No data modifications are included.
BEGIN TRANSACTION READ ONLY;

SELECT current_database() AS database_name, current_user AS database_user,
       current_setting('server_version') AS postgres_version;

SELECT n.nspname AS schema_name, c.relname AS table_name, c.relkind
FROM pg_catalog.pg_class c
JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND c.relkind IN ('r','p')
AND c.relname IN ('profiles','point_transactions','league_feature_flags',
 'league_coach_challenges','league_coach_challenge_entries',
 'league_coach_challenge_reviews','league_coach_challenge_exp_ledger',
 'league_duels','league_achievements')
ORDER BY c.relname;

SELECT table_name,column_name,data_type,is_nullable,column_default
FROM information_schema.columns
WHERE table_schema='public'
AND table_name IN ('profiles','point_transactions','league_feature_flags',
 'league_coach_challenges','league_coach_challenge_entries',
 'league_coach_challenge_reviews','league_coach_challenge_exp_ledger')
ORDER BY table_name,ordinal_position;

SELECT t.relname AS table_name,c.conname AS constraint_name,
 pg_catalog.pg_get_constraintdef(c.oid) AS definition
FROM pg_catalog.pg_constraint c
JOIN pg_catalog.pg_class t ON t.oid=c.conrelid
JOIN pg_catalog.pg_namespace n ON n.oid=t.relnamespace
WHERE n.nspname='public'
AND t.relname IN ('profiles','point_transactions','league_feature_flags',
 'league_coach_challenges','league_coach_challenge_entries',
 'league_coach_challenge_reviews','league_coach_challenge_exp_ledger')
ORDER BY t.relname,c.conname;

SELECT schemaname,tablename,policyname,roles,cmd,qual,with_check
FROM pg_catalog.pg_policies WHERE schemaname='public'
AND tablename IN ('profiles','point_transactions','league_feature_flags',
 'league_coach_challenges','league_coach_challenge_entries',
 'league_coach_challenge_reviews','league_coach_challenge_exp_ledger')
ORDER BY tablename,policyname;

SELECT c.relname AS table_name,c.relrowsecurity,c.relforcerowsecurity
FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND c.relname IN
 ('profiles','point_transactions','league_feature_flags',
 'league_coach_challenges','league_coach_challenge_entries',
 'league_coach_challenge_reviews','league_coach_challenge_exp_ledger')
ORDER BY c.relname;

SELECT p.proname,pg_catalog.pg_get_function_identity_arguments(p.oid) AS arguments,
 pg_catalog.pg_get_userbyid(p.proowner) AS owner,p.prosecdef AS security_definer
FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND
 (p.proname LIKE 'coach_challenge_v2_%'
 OR p.proname LIKE 'duel_v2_%'
 OR p.proname LIKE 'achievement_v2_%')
ORDER BY p.proname;

SELECT extname,extversion FROM pg_catalog.pg_extension ORDER BY extname;

-- Aggregate-only checks; point_transactions is a required existing table.\nSELECT category,count(*) AS transaction_count
FROM public.point_transactions GROUP BY category ORDER BY category;
SELECT count(*) AS existing_challenge_exp_rows
FROM public.point_transactions WHERE category='challenge_exp';

COMMIT;
