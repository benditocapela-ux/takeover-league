-- Read-only Preflight vor 20261029160000_self_rating.sql (ändert nichts).
SELECT 'Coach-Bewertung 1–20 und Mitteilungen vorhanden' AS check_name, (to_regclass('public.boxer_ratings') IS NOT NULL AND to_regclass('public.boxer_notifications') IS NOT NULL
  AND to_regprocedure('league_private.rating_scores_valid(jsonb,integer)') IS NOT NULL AND to_regprocedure('league_private.rating_summary(jsonb,integer)') IS NOT NULL
  AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='boxer_ratings' AND column_name='scale'))::text AS ok
UNION ALL SELECT 'Noch keine Selbsteinschätzung', (to_regclass('public.rating_self_reviews') IS NULL AND NOT EXISTS (SELECT 1 FROM public.league_feature_flags WHERE feature_key='self_rating'))::text
UNION ALL SELECT 'Referenz boxer_ratings (Anzahl / Boxer)', (SELECT count(*)||' / '||count(DISTINCT boxer_id) FROM public.boxer_ratings)
UNION ALL SELECT 'Referenz boxer_notifications', (SELECT count(*)::text FROM public.boxer_notifications)
UNION ALL SELECT 'Referenz point_transactions n/exp/points', (SELECT count(*)||' / '||coalesce(sum(exp),0)||' / '||coalesce(sum(points),0) FROM public.point_transactions);
