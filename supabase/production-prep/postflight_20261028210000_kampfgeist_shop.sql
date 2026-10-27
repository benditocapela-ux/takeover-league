-- Read-only Postflight nach 20261028210000_kampfgeist_shop.sql (ändert nichts).
SELECT '5 Tabellen vorhanden, RLS aktiv' AS check_name, ((SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='public' AND c.relrowsecurity AND c.relname IN ('kg_settings','kg_items','kg_ledger','kg_inventory','kg_equipped'))=5)::text AS ok
UNION ALL SELECT 'Keine direkten Tabellenrechte', (NOT EXISTS (SELECT 1 FROM information_schema.role_table_grants WHERE table_schema='public'
  AND table_name IN ('kg_settings','kg_items','kg_ledger','kg_inventory','kg_equipped') AND grantee IN ('anon','authenticated','PUBLIC')))::text
UNION ALL SELECT '8 RPCs SECURITY DEFINER mit festem search_path', ((SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public' AND p.prosecdef AND p.proconfig @> ARRAY['search_path=""'] AND p.proname IN ('get_my_kampfgeist','buy_kg_item','equip_kg_item',
  'get_kg_look','admin_kg_overview','admin_adjust_coins','admin_update_kg_item','admin_update_kg_settings'))=8)::text
UNION ALL SELECT 'anon darf keine RPC ausführen', (NOT has_function_privilege('anon','public.buy_kg_item(text)','EXECUTE')
  AND NOT has_function_privilege('anon','public.get_my_kampfgeist(boolean)','EXECUTE') AND NOT has_function_privilege('anon','public.admin_adjust_coins(uuid,integer,text)','EXECUTE'))::text
UNION ALL SELECT 'Hilfsfunktionen gesperrt', (NOT has_function_privilege('authenticated','league_private.kg_sync(uuid)','EXECUTE')
  AND NOT has_function_privilege('authenticated','league_private.kg_look(uuid)','EXECUTE'))::text
UNION ALL SELECT 'Katalog: 114 Items, 93 im Shop, 9 Start, 12 Rang-Belohnungen', ((SELECT count(*) FROM public.kg_items)=114
  AND (SELECT count(*) FROM public.kg_items WHERE unlock='shop')=93 AND (SELECT count(*) FROM public.kg_items WHERE unlock='start')=9
  AND (SELECT count(*) FROM public.kg_items WHERE unlock='rank')=12)::text
UNION ALL SELECT 'Einstellungen 100 Start / 10 pro Training', (EXISTS (SELECT 1 FROM public.kg_settings WHERE start_coins=100 AND coins_per_training=10))::text
UNION ALL SELECT 'Flag kampfgeist_shop vorhanden und AUS', (EXISTS (SELECT 1 FROM public.league_feature_flags WHERE feature_key='kampfgeist_shop' AND NOT is_enabled))::text
UNION ALL SELECT 'Noch keine Coin-Buchungen, Käufe, Ausrüstung', (NOT EXISTS (SELECT 1 FROM public.kg_ledger) AND NOT EXISTS (SELECT 1 FROM public.kg_inventory)
  AND NOT EXISTS (SELECT 1 FROM public.kg_equipped))::text
UNION ALL SELECT 'Quest-Coins noch nicht angefasst', (NOT EXISTS (SELECT 1 FROM public.quest_claims WHERE coins_credited_at IS NOT NULL))::text;
