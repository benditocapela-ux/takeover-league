-- Read-only Postflight nach 20261029120000_card_designs_awards.sql (ändert nichts).
SELECT '13 Designs (1 Start, 6 Rang, 3 Shop, 3 Auszeichnung)' AS check_name, ((SELECT string_agg(unlock||'='||n,',' ORDER BY unlock) FROM (SELECT unlock,count(*) n FROM public.card_designs GROUP BY unlock) x)
  ='award=3,rank=6,shop=3,start=1')::text AS ok
UNION ALL SELECT 'Tabellen mit RLS, keine direkten Rechte', ((SELECT bool_and(relrowsecurity) FROM pg_class WHERE oid IN ('public.card_designs'::regclass,'public.card_design_purchases'::regclass,
  'public.card_design_equipped'::regclass,'public.card_awards'::regclass)) AND NOT has_table_privilege('authenticated','public.card_awards','SELECT'))::text
UNION ALL SELECT '8 RPCs SECURITY DEFINER, nicht für anon', ((SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.prosecdef
  AND p.proconfig @> ARRAY['search_path=""'] AND p.proname IN ('get_my_card_designs','equip_card_design','buy_card_design','get_card_looks','get_card_awards',
  'staff_card_award_overview','staff_confirm_card_award','staff_revoke_card_award'))=8 AND NOT has_function_privilege('anon','public.staff_confirm_card_award(text,date,uuid,text)','EXECUTE'))::text
UNION ALL SELECT 'Flag card_designs aus, noch keine Auszeichnungen', (EXISTS (SELECT 1 FROM public.league_feature_flags WHERE feature_key='card_designs' AND NOT is_enabled)
  AND NOT EXISTS (SELECT 1 FROM public.card_awards))::text
UNION ALL SELECT 'Referenz kg_ledger (Anzahl / Summe)', (SELECT count(*)||' / '||coalesce(sum(amount),0) FROM public.kg_ledger)
UNION ALL SELECT 'Referenz point_transactions n/exp/points', (SELECT count(*)||' / '||coalesce(sum(exp),0)||' / '||coalesce(sum(points),0) FROM public.point_transactions);
