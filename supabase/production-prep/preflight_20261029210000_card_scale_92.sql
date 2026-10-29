-- Read-only Preflight vor 20261029210000_card_scale_92.sql (ändert nichts).
SELECT 'Coach-Bewertung mit 20er-Skala vorhanden' AS check_name, (to_regprocedure('league_private.rating_summary(jsonb,integer)') IS NOT NULL AND to_regprocedure('league_private.rating_row(uuid,integer)') IS NOT NULL)::text AS ok
UNION ALL SELECT 'Karte / eigene Sicht / Trainer-Liste wie 20261029090000 (Fingerprint)', md5(pg_get_functiondef('public.get_performance_card(text)'::regprocedure)
  ||pg_get_functiondef('league_private.rating_full(uuid)'::regprocedure)||pg_get_functiondef('public.staff_list_performance()'::regprocedure))
UNION ALL SELECT 'Noch nicht skaliert', (to_regprocedure('league_private.rating_public(jsonb,integer)') IS NULL)::text
UNION ALL SELECT 'Referenz Bewertungen (Anzahl / Boxer / Prüfsumme)', (SELECT count(*)||' / '||count(DISTINCT boxer_id)||' / '||md5(coalesce(string_agg(scores::text||scale,'|' ORDER BY id),'')) FROM public.boxer_ratings)
UNION ALL SELECT 'Referenz point_transactions n/exp/points', (SELECT count(*)||' / '||coalesce(sum(exp),0)||' / '||coalesce(sum(points),0) FROM public.point_transactions);
