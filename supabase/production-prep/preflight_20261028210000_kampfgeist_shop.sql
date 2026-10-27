-- Read-only Preflight vor 20261028210000_kampfgeist_shop.sql (ändert nichts).
SELECT 'Voraussetzung Etappe 1–3 (active_viewer, flag_on, quest_claims)' AS check_name,
  (to_regprocedure('league_private.active_viewer()') IS NOT NULL AND to_regprocedure('league_private.flag_on(text)') IS NOT NULL
   AND to_regclass('public.quest_claims') IS NOT NULL)::text AS ok
UNION ALL SELECT 'quest_claims mit coins/coins_credited_at', ((SELECT count(*) FROM information_schema.columns WHERE table_schema='public'
   AND table_name='quest_claims' AND column_name IN ('coins','coins_credited_at'))=2)::text
UNION ALL SELECT 'point_transactions mit boxer_id/exp', ((SELECT count(*) FROM information_schema.columns WHERE table_schema='public'
   AND table_name='point_transactions' AND column_name IN ('boxer_id','exp'))=2)::text
UNION ALL SELECT 'gen_random_uuid verfügbar', (to_regprocedure('pg_catalog.gen_random_uuid()') IS NOT NULL)::text
UNION ALL SELECT 'Neue Tabellen noch nicht vorhanden', (to_regclass('public.kg_items') IS NULL AND to_regclass('public.kg_ledger') IS NULL
   AND to_regclass('public.kg_inventory') IS NULL AND to_regclass('public.kg_equipped') IS NULL AND to_regclass('public.kg_settings') IS NULL)::text
UNION ALL SELECT 'Flag kampfgeist_shop nicht eingeschaltet', (NOT EXISTS (SELECT 1 FROM public.league_feature_flags WHERE feature_key='kampfgeist_shop' AND is_enabled))::text
UNION ALL SELECT 'Keine gleichnamigen RPCs', (NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public'
   AND p.proname IN ('get_my_kampfgeist','buy_kg_item','equip_kg_item','get_kg_look','admin_kg_overview','admin_adjust_coins','admin_update_kg_item','admin_update_kg_settings')))::text
UNION ALL SELECT 'Referenz genehmigte Trainings', (SELECT count(*) FROM public.training_submissions WHERE status='approved')::text
UNION ALL SELECT 'Referenz Buchungen / EXP / Punkte', (SELECT count(*)||' / '||coalesce(sum(exp),0)||' / '||coalesce(sum(points),0) FROM public.point_transactions)
UNION ALL SELECT 'Referenz Quest-Abholungen / offene Quest-Coins', (SELECT count(*)||' / '||coalesce(sum(coins) FILTER (WHERE coins_credited_at IS NULL),0) FROM public.quest_claims);
