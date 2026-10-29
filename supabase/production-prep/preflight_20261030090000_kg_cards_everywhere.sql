-- Read-only Preflight vor 20261030090000_kg_cards_everywhere.sql (ändert nichts).
SELECT 'Voraussetzungen (kg_look, öffentliche Looks)' AS check_name, (to_regprocedure('league_private.kg_look(uuid)') IS NOT NULL
  AND to_regprocedure('public.get_public_boxer_looks()') IS NOT NULL AND to_regprocedure('league_private.flag_on(text)') IS NOT NULL)::text AS ok
UNION ALL SELECT 'Noch keine Kartenliste', (to_regprocedure('public.get_public_boxer_cards()') IS NULL)::text
UNION ALL SELECT 'Kampfgeist-Shop an', coalesce((SELECT is_enabled::text FROM public.league_feature_flags WHERE feature_key='kampfgeist_shop'),'fehlt')
UNION ALL SELECT 'Referenz Ausrüstung (Zeilen / md5)', (SELECT count(*)||' / '||md5(coalesce(string_agg(x::text,'|' ORDER BY x.profile_id),'')) FROM public.kg_equipped x)
UNION ALL SELECT 'Referenz point_transactions n/exp/points', (SELECT count(*)||' / '||coalesce(sum(exp),0)||' / '||coalesce(sum(points),0) FROM public.point_transactions);
