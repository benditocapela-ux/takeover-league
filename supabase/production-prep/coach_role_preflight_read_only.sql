-- Coach roles preflight: READ ONLY; safe to run on production before future FREIGEBEN.
SELECT role,is_active,count(*) AS profiles FROM public.profiles GROUP BY role,is_active ORDER BY role,is_active;
SELECT p.proname,pg_get_function_identity_arguments(p.oid) arguments,p.prosecdef FROM pg_proc p
 JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.proname IN ('is_league_admin','recalculate_boxer_bonuses','review_training','admin_edit_training','coach_link_boxer_account','coach_list_unlinked_accounts') ORDER BY p.proname;
SELECT tablename,policyname,cmd FROM pg_policies WHERE schemaname='public' AND (qual LIKE '%is_league_admin%' OR with_check LIKE '%is_league_admin%') ORDER BY tablename,policyname;
