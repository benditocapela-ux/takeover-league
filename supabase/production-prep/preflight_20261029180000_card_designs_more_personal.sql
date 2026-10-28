-- Read-only Preflight vor 20261029180000_card_designs_more_personal.sql (ändert nichts).
SELECT 'Karten-Designs vorhanden (13)' AS check_name, (SELECT count(*)::text FROM public.card_designs) AS ok
UNION ALL SELECT 'card_look / card_design_available wie 7d (Fingerprint)', md5(pg_get_functiondef('league_private.card_look(uuid)'::regprocedure)||pg_get_functiondef('league_private.card_design_available(uuid,public.card_designs)'::regprocedure))
UNION ALL SELECT 'Noch kein eigenes Design', (to_regclass('public.card_personal_designs') IS NULL)::text
UNION ALL SELECT 'Referenz Käufe / Auswahl / Auszeichnungen', (SELECT count(*) FROM public.card_design_purchases)||' / '||(SELECT count(*) FROM public.card_design_equipped)||' / '||(SELECT count(*) FROM public.card_awards)
UNION ALL SELECT 'Referenz kg_ledger (Anzahl / Summe)', (SELECT count(*)||' / '||coalesce(sum(amount),0) FROM public.kg_ledger)
UNION ALL SELECT 'Referenz point_transactions n/exp/points', (SELECT count(*)||' / '||coalesce(sum(exp),0)||' / '||coalesce(sum(points),0) FROM public.point_transactions);
