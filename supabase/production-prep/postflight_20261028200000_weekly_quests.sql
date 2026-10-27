-- Read-only Postflight nach 20261028200000_weekly_quests.sql (ändert nichts).
SELECT '2 Tabellen vorhanden, RLS aktiv' AS check_name, (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='public' AND c.relrowsecurity AND c.relname IN ('quest_definitions','quest_claims'))=2 AS ok
UNION ALL SELECT 'Keine direkten Tabellenrechte', NOT EXISTS (SELECT 1 FROM information_schema.role_table_grants WHERE table_schema='public'
  AND table_name IN ('quest_definitions','quest_claims') AND grantee IN ('anon','authenticated','PUBLIC'))
UNION ALL SELECT '5 RPCs SECURITY DEFINER mit festem search_path', (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public' AND p.prosecdef AND p.proconfig @> ARRAY['search_path=""']
  AND p.proname IN ('get_my_quests','claim_quest','staff_quest_overview','admin_list_quests','admin_update_quest'))=5
UNION ALL SELECT 'anon darf keine RPC ausführen', NOT has_function_privilege('anon','public.claim_quest(text,date)','EXECUTE')
  AND NOT has_function_privilege('anon','public.get_my_quests(date)','EXECUTE')
  AND NOT has_function_privilege('anon','public.admin_update_quest(text,integer,integer,integer,boolean,jsonb)','EXECUTE')
UNION ALL SELECT 'Hilfsfunktionen gesperrt', NOT has_function_privilege('authenticated','league_private.quest_progress(uuid,text,date,date)','EXECUTE')
  AND NOT has_function_privilege('authenticated','league_private.quest_week(uuid,date)','EXECUTE')
UNION ALL SELECT '5 Wochenquests, 1 Truhe, 4 Tagesquests', (SELECT string_agg(kind||'='||n,',' ORDER BY kind) FROM (SELECT kind,count(*) n FROM public.quest_definitions GROUP BY kind) x)='chest=1,daily=4,weekly=5'
UNION ALL SELECT 'Max. EXP pro Woche = 175', (SELECT sum(exp) FILTER (WHERE kind IN ('weekly','chest')) + 7*max(exp) FILTER (WHERE kind='daily') FROM public.quest_definitions)=175
UNION ALL SELECT 'Flag weekly_quests vorhanden und AUS', EXISTS (SELECT 1 FROM public.league_feature_flags WHERE feature_key='weekly_quests' AND NOT is_enabled)
UNION ALL SELECT 'Noch keine Abholungen und keine Quest-Buchungen', NOT EXISTS (SELECT 1 FROM public.quest_claims)
  AND NOT EXISTS (SELECT 1 FROM public.point_transactions WHERE description LIKE 'Quest-Belohnung:%');
