-- Read-only Preflight vor 20261028190000_training_groups_gym.sql (ändert nichts).
SELECT 'Voraussetzung staff_record_training vorhanden' AS check_name, to_regprocedure('public.staff_record_training(uuid,bigint,date,integer,text,numeric,uuid)') IS NOT NULL AS ok
UNION ALL SELECT 'Voraussetzung Etappe 1 (active_viewer, flag_on) vorhanden', to_regprocedure('league_private.active_viewer()') IS NOT NULL AND to_regprocedure('league_private.flag_on(text)') IS NOT NULL
UNION ALL SELECT 'training_types mit id/name/is_active', (SELECT count(*) FROM information_schema.columns WHERE table_schema='public' AND table_name='training_types' AND column_name IN ('id','name','is_active'))=3
UNION ALL SELECT 'Neue Tabellen noch nicht vorhanden', NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
   WHERE n.nspname='public' AND c.relname IN ('training_groups','training_group_members','gym_sessions','gym_attendance','training_plans'))
UNION ALL SELECT 'Flag gym_training noch nicht eingeschaltet', NOT EXISTS (SELECT 1 FROM public.league_feature_flags WHERE feature_key='gym_training' AND is_enabled)
UNION ALL SELECT 'Keine gleichnamigen RPCs', NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public'
   AND p.proname IN ('list_training_groups','staff_list_group_members','staff_set_training_group','admin_set_group_target','staff_open_gym_session',
   'staff_list_gym_sessions','staff_get_gym_session','staff_set_gym_attendance','staff_cancel_gym_session','staff_confirm_gym_session',
   'my_gym_sessions_today','gym_check_in','get_my_presence','staff_presence_overview','staff_get_training_plan','staff_save_training_plan','get_my_week_plan'));
