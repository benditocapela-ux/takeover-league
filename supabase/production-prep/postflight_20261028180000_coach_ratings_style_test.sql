-- Read-only Postflight nach 20261028180000_coach_ratings_style_test.sql (ändert nichts).
SELECT 'Tabellen vorhanden, RLS aktiv' AS check_name,
 (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='public' AND c.relname IN ('boxer_ratings','style_tests','style_test_unlocks') AND c.relrowsecurity)=3 AS ok
UNION ALL SELECT 'Keine direkten Tabellenrechte für anon/authenticated',
 NOT EXISTS (SELECT 1 FROM information_schema.role_table_grants WHERE table_schema='public'
  AND table_name IN ('boxer_ratings','style_tests','style_test_unlocks') AND grantee IN ('anon','authenticated','PUBLIC'))
UNION ALL SELECT '7 RPCs vorhanden, SECURITY DEFINER mit festem search_path',
 (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.prosecdef
  AND p.proconfig @> ARRAY['search_path=""']
  AND p.proname IN ('get_my_performance','get_performance_card','staff_list_performance','staff_get_rating','staff_rate_boxer','submit_style_test','staff_unlock_style_test'))=7
UNION ALL SELECT 'anon darf keine der RPCs ausführen',
 NOT has_function_privilege('anon','public.get_my_performance()','EXECUTE')
 AND NOT has_function_privilege('anon','public.get_performance_card(text)','EXECUTE')
 AND NOT has_function_privilege('anon','public.staff_rate_boxer(uuid,jsonb,text)','EXECUTE')
 AND NOT has_function_privilege('anon','public.submit_style_test(smallint[])','EXECUTE')
 AND NOT has_function_privilege('anon','public.staff_unlock_style_test(uuid)','EXECUTE')
UNION ALL SELECT 'authenticated darf die RPCs ausführen',
 has_function_privilege('authenticated','public.get_my_performance()','EXECUTE')
 AND has_function_privilege('authenticated','public.staff_rate_boxer(uuid,jsonb,text)','EXECUTE')
UNION ALL SELECT 'Hilfsfunktionen nicht direkt aufrufbar',
 NOT has_function_privilege('authenticated','league_private.rating_summary(jsonb)','EXECUTE')
 AND NOT has_function_privilege('authenticated','league_private.style_state(uuid)','EXECUTE')
UNION ALL SELECT 'Flags vorhanden und AUS',
 (SELECT count(*) FROM public.league_feature_flags WHERE feature_key IN ('coach_ratings','style_test') AND NOT is_enabled)=2
UNION ALL SELECT 'Bewertung all 7 ergibt Gesamt 70',
 (SELECT (league_private.rating_summary(jsonb_object_agg(k,7))->>'overall')::int FROM unnest(ARRAY['jab','cross','hook','upper','body','combo','guard','block','slip','roll','parry','counter','stance','steps','angles','ring','endur','pace','recov','timing','dist','plan','focus','heart','coach']) k)=70;
