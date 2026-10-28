-- Read-only Postflight nach 20261029160000_self_rating.sql (ändert nichts).
SELECT 'Tabelle mit RLS, ohne direkte Rechte, eine offene pro Boxer' AS check_name, ((SELECT relrowsecurity FROM pg_class WHERE oid='public.rating_self_reviews'::regclass)
  AND NOT has_table_privilege('authenticated','public.rating_self_reviews','SELECT') AND NOT has_table_privilege('anon','public.rating_self_reviews','SELECT')
  AND to_regclass('public.rating_self_reviews_one_pending') IS NOT NULL)::text AS ok
UNION ALL SELECT '4 RPCs SECURITY DEFINER, leerer search_path, nicht für anon', ((SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public'
  AND p.prosecdef AND p.proconfig @> ARRAY['search_path=""'] AND p.proname IN ('get_my_self_rating','submit_self_rating','staff_list_self_ratings','staff_decide_self_rating'))=4
  AND NOT has_function_privilege('anon','public.submit_self_rating(jsonb,text)','EXECUTE')
  AND has_function_privilege('authenticated','public.staff_decide_self_rating(bigint,text,jsonb,text)','EXECUTE')
  AND NOT has_function_privilege('authenticated','league_private.self_review_state(uuid)','EXECUTE'))::text
UNION ALL SELECT 'Flag self_rating aus, noch keine Einträge', (EXISTS (SELECT 1 FROM public.league_feature_flags WHERE feature_key='self_rating' AND NOT is_enabled)
  AND NOT EXISTS (SELECT 1 FROM public.rating_self_reviews))::text
UNION ALL SELECT 'Referenz boxer_ratings (Anzahl / Boxer)', (SELECT count(*)||' / '||count(DISTINCT boxer_id) FROM public.boxer_ratings)
UNION ALL SELECT 'Referenz boxer_notifications', (SELECT count(*)::text FROM public.boxer_notifications)
UNION ALL SELECT 'Referenz point_transactions n/exp/points', (SELECT count(*)||' / '||coalesce(sum(exp),0)||' / '||coalesce(sum(points),0) FROM public.point_transactions);
