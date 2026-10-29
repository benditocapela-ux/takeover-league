-- Read-only Preflight vor 20261029220000_card_gallery.sql (ändert nichts).
SELECT 'Öffentliche Kartenwerte eingespielt (Etappe 15)' AS check_name, (to_regprocedure('league_private.rating_public(jsonb,integer)') IS NOT NULL AND to_regprocedure('league_private.rating_card_best(uuid)') IS NOT NULL)::text AS ok
UNION ALL SELECT 'Noch keine Kartengalerie', (to_regprocedure('public.get_card_gallery()') IS NULL)::text
UNION ALL SELECT 'Referenz Bewertungen (Anzahl / Boxer)', (SELECT count(*)||' / '||count(DISTINCT boxer_id) FROM public.boxer_ratings)
UNION ALL SELECT 'Referenz point_transactions n/exp/points', (SELECT count(*)||' / '||coalesce(sum(exp),0)||' / '||coalesce(sum(points),0) FROM public.point_transactions);
