-- Read-only Postflight nach 20261029210000_card_scale_92.sql (ändert nichts).
SELECT 'Hilfsfunktionen gesperrt, RPCs nur für angemeldete' AS check_name, (NOT has_function_privilege('authenticated','league_private.rating_public(jsonb,integer)','EXECUTE')
  AND NOT has_function_privilege('authenticated','league_private.rating_card_best(uuid)','EXECUTE')
  AND NOT has_function_privilege('anon','public.get_rating_card_scale(uuid)','EXECUTE') AND has_function_privilege('authenticated','public.get_rating_card_scale(uuid)','EXECUTE')
  AND NOT has_function_privilege('anon','public.get_performance_card(text)','EXECUTE')
  AND (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.prosecdef AND p.proconfig @> ARRAY['search_path=""']
       AND p.proname IN ('get_performance_card','staff_list_performance','get_rating_card_scale'))=3)::text AS ok
UNION ALL SELECT 'Beste echte Gesamtwertung → öffentlich', (SELECT coalesce(b::text,'–')||' → '||coalesce((league_private.rating_public(jsonb_build_object('overall',b,'categories','{}'::jsonb),b)->>'overall'),'–')
  FROM (SELECT league_private.rating_card_best(NULL) b) x)
UNION ALL SELECT 'Echt → öffentlich je Boxer', (SELECT string_agg(p.display_name||' '||(s->>'overall')||'→'||(league_private.rating_public(s,league_private.rating_card_best(NULL))->>'overall'),', ' ORDER BY (s->>'overall')::int DESC)
  FROM public.profiles p CROSS JOIN LATERAL league_private.rating_row(p.id,0) r CROSS JOIN LATERAL (SELECT league_private.rating_summary(r.scores,r.scale) s) y
  WHERE r.id IS NOT NULL AND p.is_active AND p.archived_at IS NULL AND p.role IN ('boxer','coach'))
UNION ALL SELECT 'Referenz Bewertungen (Anzahl / Boxer / Prüfsumme)', (SELECT count(*)||' / '||count(DISTINCT boxer_id)||' / '||md5(coalesce(string_agg(scores::text||scale,'|' ORDER BY id),'')) FROM public.boxer_ratings)
UNION ALL SELECT 'Referenz point_transactions n/exp/points', (SELECT count(*)||' / '||coalesce(sum(exp),0)||' / '||coalesce(sum(points),0) FROM public.point_transactions);
