-- Coach roles preflight: READ ONLY; safe to run on production before future FREIGEBEN.
SELECT role,is_active,count(*) AS profiles FROM public.profiles GROUP BY role,is_active ORDER BY role,is_active;
SELECT p.proname,pg_get_function_identity_arguments(p.oid) arguments,p.prosecdef FROM pg_proc p
 JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.proname IN ('is_league_admin','recalculate_boxer_bonuses','review_training','admin_edit_training','coach_link_boxer_account','coach_list_unlinked_accounts') ORDER BY p.proname;
SELECT tablename,policyname,cmd FROM pg_policies WHERE schemaname='public' AND (qual LIKE '%is_league_admin%' OR with_check LIKE '%is_league_admin%') ORDER BY tablename,policyname;
-- Baseline ACL risk: TRUNCATE ignores RLS.
SELECT c.relname,
 has_table_privilege('anon',c.oid,'TRUNCATE') AS anon_truncate,
 has_table_privilege('authenticated',c.oid,'TRUNCATE') AS authenticated_truncate
FROM pg_class c WHERE c.oid IN
 ('public.profiles'::regclass,'public.training_submissions'::regclass,
  'public.point_transactions'::regclass,'public.training_types'::regclass,
  'public.training_drafts_v2'::regclass)
ORDER BY c.relname;
