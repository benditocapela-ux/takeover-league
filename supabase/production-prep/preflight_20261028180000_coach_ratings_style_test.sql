-- Read-only Preflight vor 20261028180000_coach_ratings_style_test.sql (ändert nichts).
SELECT 'profiles: Spalten archived_at/is_listed/role/is_active vorhanden' AS check_name,
 (SELECT count(*) FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles'
   AND column_name IN ('archived_at','is_listed','role','is_active','auth_user_id','display_name'))=6 AS ok
UNION ALL SELECT 'league_feature_flags vorhanden', to_regclass('public.league_feature_flags') IS NOT NULL
UNION ALL SELECT 'Schema league_private vorhanden', EXISTS (SELECT 1 FROM pg_namespace WHERE nspname='league_private')
UNION ALL SELECT 'Tabellen noch nicht vorhanden (oder leer)', coalesce((SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
   WHERE n.nspname='public' AND c.relname IN ('boxer_ratings','style_tests','style_test_unlocks')),0)=0
UNION ALL SELECT 'Flags coach_ratings/style_test noch nicht eingeschaltet',
 NOT EXISTS (SELECT 1 FROM public.league_feature_flags WHERE feature_key IN ('coach_ratings','style_test') AND is_enabled)
UNION ALL SELECT 'Keine gleichnamigen Funktionen vorhanden',
 NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public'
   AND p.proname IN ('get_my_performance','get_performance_card','staff_list_performance','staff_get_rating','staff_rate_boxer','submit_style_test','staff_unlock_style_test'));
