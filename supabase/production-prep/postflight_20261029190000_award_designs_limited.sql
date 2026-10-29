-- Read-only Postflight nach 20261029190000_award_designs_limited.sql (ändert nichts).
SELECT 'Befristung aktiv: Hilfsfunktionen gesperrt' AS check_name, (to_regprocedure('league_private.card_award_until(uuid,text)') IS NOT NULL
  AND NOT has_function_privilege('authenticated','league_private.card_award_until(uuid,text)','EXECUTE') AND NOT has_function_privilege('anon','league_private.card_award_until(uuid,text)','EXECUTE')
  AND NOT has_function_privilege('authenticated','league_private.card_award_window(public.card_awards)','EXECUTE')
  AND pg_get_functiondef('league_private.card_design_available(uuid,public.card_designs)'::regprocedure) LIKE '%card_award_until%')::text AS ok
UNION ALL SELECT 'RPCs SECURITY DEFINER, leerer search_path, nicht für anon', ((SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.prosecdef
  AND p.proconfig @> ARRAY['search_path=""'] AND p.proname IN ('get_my_card_designs','staff_confirm_card_award'))=2
  AND NOT has_function_privilege('anon','public.get_my_card_designs()','EXECUTE') AND has_function_privilege('authenticated','public.staff_confirm_card_award(text,date,uuid,text)','EXECUTE'))::text
UNION ALL SELECT 'Referenz Auszeichnungen aktiv / zurückgenommen', (SELECT count(*) FILTER (WHERE revoked_at IS NULL)||' / '||count(*) FILTER (WHERE revoked_at IS NOT NULL) FROM public.card_awards)
UNION ALL SELECT 'Referenz Auswahl Auszeichnungs-Designs', (SELECT count(*)::text FROM public.card_design_equipped WHERE design_key IN ('cotw','cotm','poty'))
UNION ALL SELECT 'Referenz Käufe / Auswahl / eigene Designs', (SELECT count(*) FROM public.card_design_purchases)||' / '||(SELECT count(*) FROM public.card_design_equipped)||' / '||(SELECT count(*) FROM public.card_personal_designs)
UNION ALL SELECT 'Referenz kg_ledger (Anzahl / Summe)', (SELECT count(*)||' / '||coalesce(sum(amount),0) FROM public.kg_ledger)
UNION ALL SELECT 'Referenz point_transactions n/exp/points', (SELECT count(*)||' / '||coalesce(sum(exp),0)||' / '||coalesce(sum(points),0) FROM public.point_transactions);
