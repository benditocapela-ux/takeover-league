-- Read-only Preflight vor 20261029120000_card_designs_awards.sql (ändert nichts).
SELECT 'Kampfgeist-Grundlagen vorhanden' AS check_name, (to_regprocedure('league_private.kg_exp(uuid)') IS NOT NULL AND to_regprocedure('league_private.kg_balance(uuid)') IS NOT NULL
  AND to_regprocedure('league_private.kg_sync(uuid)') IS NOT NULL AND to_regclass('public.kg_ledger') IS NOT NULL)::text AS ok
UNION ALL SELECT 'Noch keine Karten-Designs', (to_regclass('public.card_designs') IS NULL AND to_regclass('public.card_awards') IS NULL)::text
UNION ALL SELECT 'Benachrichtigungstyp achievement erlaubt', EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.boxer_notifications'::regclass
  AND conname='boxer_notifications_notification_type_check' AND pg_get_constraintdef(oid) LIKE '%achievement%')::text
UNION ALL SELECT 'Referenz kg_ledger (Anzahl / Summe)', (SELECT count(*)||' / '||coalesce(sum(amount),0) FROM public.kg_ledger)
UNION ALL SELECT 'Referenz point_transactions n/exp/points', (SELECT count(*)||' / '||coalesce(sum(exp),0)||' / '||coalesce(sum(points),0) FROM public.point_transactions);
