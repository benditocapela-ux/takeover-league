-- Read-only Postflight nach 20261028190000_training_groups_gym.sql (ändert nichts).
SELECT '5 Tabellen vorhanden, RLS aktiv' AS check_name, (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='public' AND c.relrowsecurity AND c.relname IN ('training_groups','training_group_members','gym_sessions','gym_attendance','training_plans'))=5 AS ok
UNION ALL SELECT 'Keine direkten Tabellenrechte', NOT EXISTS (SELECT 1 FROM information_schema.role_table_grants WHERE table_schema='public'
  AND table_name IN ('training_groups','training_group_members','gym_sessions','gym_attendance','training_plans') AND grantee IN ('anon','authenticated','PUBLIC'))
UNION ALL SELECT '17 RPCs SECURITY DEFINER mit festem search_path', (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public' AND p.prosecdef AND p.proconfig @> ARRAY['search_path=""'] AND p.proname IN ('list_training_groups','staff_list_group_members','staff_set_training_group','admin_set_group_target','staff_open_gym_session',
   'staff_list_gym_sessions','staff_get_gym_session','staff_set_gym_attendance','staff_cancel_gym_session','staff_confirm_gym_session',
   'my_gym_sessions_today','gym_check_in','get_my_presence','staff_presence_overview','staff_get_training_plan','staff_save_training_plan','get_my_week_plan'))=17
UNION ALL SELECT 'anon darf keine RPC ausführen', NOT has_function_privilege('anon','public.staff_confirm_gym_session(bigint)','EXECUTE')
  AND NOT has_function_privilege('anon','public.get_my_presence()','EXECUTE') AND NOT has_function_privilege('anon','public.gym_check_in(bigint)','EXECUTE')
  AND NOT has_function_privilege('anon','public.staff_save_training_plan(text,date,text,jsonb,boolean)','EXECUTE')
UNION ALL SELECT 'Hilfsfunktionen gesperrt', NOT has_function_privilege('authenticated','league_private.presence_streak(uuid)','EXECUTE')
  AND NOT has_function_privilege('authenticated','league_private.require_staff()','EXECUTE')
UNION ALL SELECT '3 Gruppen (2/3/5)', (SELECT string_agg(key||'='||weekly_target,',' ORDER BY sort_order) FROM public.training_groups)='newcomer=2,fortgeschritten=3,wettkampf=5'
UNION ALL SELECT 'Flag gym_training vorhanden und AUS', EXISTS (SELECT 1 FROM public.league_feature_flags WHERE feature_key='gym_training' AND NOT is_enabled)
UNION ALL SELECT 'Noch keine Einheiten, Pläne, Zuteilungen', (SELECT count(*) FROM public.gym_sessions)+(SELECT count(*) FROM public.training_plans)+(SELECT count(*) FROM public.training_group_members)=0;
