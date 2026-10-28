-- Read-only Preflight vor 20261029170000_looks_everywhere.sql (ändert nichts).
SELECT 'kg_look wie Etappe 5 (Fingerprint)' AS check_name, md5(pg_get_functiondef('league_private.kg_look(uuid)'::regprocedure)) AS ok
UNION ALL SELECT 'Rang-Rahmen und Rang-Titel vorhanden (12)', (SELECT count(*)::text FROM public.kg_items WHERE unlock='rank' AND category IN ('rahmen','titel'))
UNION ALL SELECT 'Noch keine öffentlichen Looks', (to_regprocedure('public.get_public_boxer_looks()') IS NULL)::text
UNION ALL SELECT 'Referenz kg_equipped (Zeilen / Rahmen / Titel gewählt)', (SELECT count(*)||' / '||count(rahmen)||' / '||count(titel) FROM public.kg_equipped)
UNION ALL SELECT 'Referenz kg_ledger (Anzahl / Summe)', (SELECT count(*)||' / '||coalesce(sum(amount),0) FROM public.kg_ledger)
UNION ALL SELECT 'Referenz point_transactions n/exp/points', (SELECT count(*)||' / '||coalesce(sum(exp),0)||' / '||coalesce(sum(points),0) FROM public.point_transactions);
