-- Read-only Postflight nach 20261029170000_looks_everywhere.sql (ändert nichts).
SELECT 'kg_look mit Rang-Standard, gesperrt' AS check_name, (pg_get_functiondef('league_private.kg_look(uuid)'::regprocedure) LIKE '%f_rang_e%'
  AND NOT has_function_privilege('authenticated','league_private.kg_look(uuid)','EXECUTE') AND NOT has_function_privilege('anon','league_private.kg_look(uuid)','EXECUTE'))::text AS ok
UNION ALL SELECT 'get_public_boxer_looks: SECURITY DEFINER, leerer search_path, für anon und authenticated', ((SELECT prosecdef AND proconfig @> ARRAY['search_path=""'] FROM pg_proc WHERE oid='public.get_public_boxer_looks()'::regprocedure)
  AND has_function_privilege('anon','public.get_public_boxer_looks()','EXECUTE') AND has_function_privilege('authenticated','public.get_public_boxer_looks()','EXECUTE'))::text
UNION ALL SELECT 'Sichtbare Boxer mit Looks / mit Rahmen / mit Titel', (SELECT count(*)||' / '||count(*) FILTER (WHERE x->'rahmen'<>'null'::jsonb)||' / '||count(*) FILTER (WHERE x->'titel'<>'null'::jsonb)
  FROM pg_catalog.jsonb_array_elements(public.get_public_boxer_looks()) x)
UNION ALL SELECT 'Referenz kg_equipped (Zeilen / Rahmen / Titel gewählt)', (SELECT count(*)||' / '||count(rahmen)||' / '||count(titel) FROM public.kg_equipped)
UNION ALL SELECT 'Referenz kg_ledger (Anzahl / Summe)', (SELECT count(*)||' / '||coalesce(sum(amount),0) FROM public.kg_ledger)
UNION ALL SELECT 'Referenz point_transactions n/exp/points', (SELECT count(*)||' / '||coalesce(sum(exp),0)||' / '||coalesce(sum(points),0) FROM public.point_transactions);
