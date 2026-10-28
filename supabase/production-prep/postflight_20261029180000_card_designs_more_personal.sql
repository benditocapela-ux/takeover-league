-- Read-only Postflight nach 20261029180000_card_designs_more_personal.sql (ändert nichts).
SELECT '26 Designs (1 Start, 8 Rang, 13 Shop, 3 Auszeichnung, 1 eigenes)' AS check_name, ((SELECT string_agg(unlock||':'||n,',' ORDER BY unlock) FROM (SELECT unlock,count(*) n FROM public.card_designs GROUP BY unlock) x)
  ='award:3,personal:1,rank:8,shop:13,start:1')::text AS ok
UNION ALL SELECT 'Eigene Designs: Tabelle mit RLS, ohne direkte Rechte', ((SELECT relrowsecurity FROM pg_class WHERE oid='public.card_personal_designs'::regclass)
  AND NOT has_table_privilege('authenticated','public.card_personal_designs','SELECT') AND NOT has_table_privilege('anon','public.card_personal_designs','SELECT'))::text
UNION ALL SELECT '4 RPCs SECURITY DEFINER, leerer search_path, nicht für anon', ((SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.prosecdef
  AND p.proconfig @> ARRAY['search_path=""'] AND p.proname IN ('get_my_personal_design','save_my_personal_design','admin_list_personal_designs','admin_set_personal_design'))=4
  AND NOT has_function_privilege('anon','public.save_my_personal_design(text,jsonb)','EXECUTE')
  AND NOT has_function_privilege('authenticated','league_private.card_personal_clean(jsonb)','EXECUTE'))::text
UNION ALL SELECT 'Noch keine eigenen Designs vergeben', (NOT EXISTS (SELECT 1 FROM public.card_personal_designs))::text
UNION ALL SELECT 'Referenz Käufe / Auswahl / Auszeichnungen', (SELECT count(*) FROM public.card_design_purchases)||' / '||(SELECT count(*) FROM public.card_design_equipped)||' / '||(SELECT count(*) FROM public.card_awards)
UNION ALL SELECT 'Referenz kg_ledger (Anzahl / Summe)', (SELECT count(*)||' / '||coalesce(sum(amount),0) FROM public.kg_ledger)
UNION ALL SELECT 'Referenz point_transactions n/exp/points', (SELECT count(*)||' / '||coalesce(sum(exp),0)||' / '||coalesce(sum(points),0) FROM public.point_transactions);
