-- Read-only Postflight nach 20261029220000_card_gallery.sql (ändert nichts).
SELECT 'get_card_gallery: SECURITY DEFINER, leerer search_path, nur für angemeldete' AS check_name, ((SELECT prosecdef AND proconfig @> ARRAY['search_path=""'] FROM pg_proc WHERE oid='public.get_card_gallery()'::regprocedure)
  AND NOT has_function_privilege('anon','public.get_card_gallery()','EXECUTE') AND has_function_privilege('authenticated','public.get_card_gallery()','EXECUTE'))::text AS ok
UNION ALL SELECT 'Referenz Bewertungen (Anzahl / Boxer)', (SELECT count(*)||' / '||count(DISTINCT boxer_id) FROM public.boxer_ratings)
UNION ALL SELECT 'Referenz point_transactions n/exp/points', (SELECT count(*)||' / '||coalesce(sum(exp),0)||' / '||coalesce(sum(points),0) FROM public.point_transactions);
