-- Read-only Postflight nach 20261029140000_boxer_holo.sql (ändert nichts).
SELECT 'Katalog: 18 Frisuren, 58 Items, 3 Bundles' AS check_name, ((SELECT count(*) FROM public.holo_items WHERE slot='hair')=18
  AND (SELECT count(*) FROM public.holo_items)=58 AND (SELECT count(*) FROM public.holo_bundles)=3
  AND NOT EXISTS (SELECT 1 FROM public.holo_bundles b, LATERAL pg_catalog.unnest(b.items) k WHERE NOT EXISTS (SELECT 1 FROM public.holo_items i WHERE i.key=k)))::text AS ok
UNION ALL SELECT 'Tabellen mit RLS, keine direkten Rechte', ((SELECT bool_and(relrowsecurity) FROM pg_class WHERE oid IN ('public.holo_items'::regclass,'public.holo_bundles'::regclass,
  'public.holo_owned'::regclass,'public.holo_config'::regclass)) AND NOT has_table_privilege('authenticated','public.holo_config','SELECT')
  AND NOT has_table_privilege('authenticated','public.holo_owned','INSERT'))::text
UNION ALL SELECT '6 RPCs SECURITY DEFINER, nicht für anon', ((SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.prosecdef
  AND p.proconfig @> ARRAY['search_path=""'] AND p.proname IN ('get_my_holo','save_my_holo','buy_holo_item','buy_holo_bundle','get_holo_looks','admin_grant_holo_item'))=6
  AND NOT has_function_privilege('anon','public.buy_holo_item(text)','EXECUTE') AND NOT has_function_privilege('authenticated','league_private.holo_clean(uuid,jsonb,boolean)','EXECUTE'))::text
UNION ALL SELECT 'Flag boxer_holo aus, noch keine Holos', (EXISTS (SELECT 1 FROM public.league_feature_flags WHERE feature_key='boxer_holo' AND NOT is_enabled)
  AND NOT EXISTS (SELECT 1 FROM public.holo_config) AND NOT EXISTS (SELECT 1 FROM public.holo_owned))::text
UNION ALL SELECT 'Referenz kg_ledger (Anzahl / Summe)', (SELECT count(*)||' / '||coalesce(sum(amount),0) FROM public.kg_ledger)
UNION ALL SELECT 'Referenz point_transactions n/exp/points', (SELECT count(*)||' / '||coalesce(sum(exp),0)||' / '||coalesce(sum(points),0) FROM public.point_transactions);
