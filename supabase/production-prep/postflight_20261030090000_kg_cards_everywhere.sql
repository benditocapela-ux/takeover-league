-- Read-only Postflight nach 20261030090000_kg_cards_everywhere.sql (ändert nichts).
SELECT 'Kartenliste: SECURITY DEFINER, leerer search_path, für Gäste und Angemeldete' AS check_name, ((SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public' AND p.proname='get_public_boxer_cards' AND p.prosecdef AND p.proconfig @> ARRAY['search_path=""'])=1
  AND has_function_privilege('anon','public.get_public_boxer_cards()','EXECUTE') AND has_function_privilege('authenticated','public.get_public_boxer_cards()','EXECUTE'))::text AS ok
UNION ALL SELECT 'Keine Preise, Coins oder Beschreibungen', (NOT (public.get_public_boxer_cards()::text ~ '"(price|coins|description|unlock|min_rank)"'))::text
UNION ALL SELECT 'Gleiche Namen wie öffentliche Looks', ((SELECT coalesce(string_agg(x->>'name',',' ORDER BY x->>'name'),'') FROM jsonb_array_elements(public.get_public_boxer_cards()) x)
  =(SELECT coalesce(string_agg(x->>'name',',' ORDER BY x->>'name'),'') FROM jsonb_array_elements(public.get_public_boxer_looks()) x))::text
UNION ALL SELECT 'Referenz Ausrüstung (Zeilen / md5)', (SELECT count(*)||' / '||md5(coalesce(string_agg(x::text,'|' ORDER BY x.profile_id),'')) FROM public.kg_equipped x)
UNION ALL SELECT 'Referenz point_transactions n/exp/points', (SELECT count(*)||' / '||coalesce(sum(exp),0)||' / '||coalesce(sum(points),0) FROM public.point_transactions);
