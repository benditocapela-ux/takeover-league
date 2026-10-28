-- Read-only Preflight vor 20261029140000_boxer_holo.sql (ändert nichts).
SELECT 'Kampfgeist und Duelle vorhanden' AS check_name, (to_regprocedure('league_private.kg_exp(uuid)') IS NOT NULL AND to_regprocedure('league_private.kg_balance(uuid)') IS NOT NULL
  AND to_regprocedure('league_private.kg_sync(uuid)') IS NOT NULL AND to_regclass('public.kg_ledger') IS NOT NULL AND to_regclass('public.league_duels') IS NOT NULL)::text AS ok
UNION ALL SELECT 'Noch kein Boxer-Holo', (to_regclass('public.holo_items') IS NULL AND to_regclass('public.holo_config') IS NULL)::text
UNION ALL SELECT 'Referenz kg_ledger (Anzahl / Summe)', (SELECT count(*)||' / '||coalesce(sum(amount),0) FROM public.kg_ledger)
UNION ALL SELECT 'Referenz point_transactions n/exp/points', (SELECT count(*)||' / '||coalesce(sum(exp),0)||' / '||coalesce(sum(points),0) FROM public.point_transactions);
