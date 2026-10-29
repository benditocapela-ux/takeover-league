-- Read-only Postflight nach 20261029230000_club_types_selfservice.sql (ändert nichts).
SELECT 'Sperre nur mit club_checkin_only, für App-Rollen gesperrt' AS check_name, (pg_get_functiondef('league_private.training_insert_guard()'::regprocedure) LIKE '%flag_on(''club_checkin_only'')%'
  AND NOT has_function_privilege('authenticated','league_private.training_insert_guard()','EXECUTE'))::text AS ok
UNION ALL SELECT 'Trigger aktiv', (SELECT count(*)::text FROM pg_trigger WHERE tgname='league_training_insert_guard' AND tgrelid='public.training_submissions'::regclass)
UNION ALL SELECT 'Schalter club_checkin_only aus', (EXISTS (SELECT 1 FROM public.league_feature_flags WHERE feature_key='club_checkin_only' AND NOT is_enabled))::text
UNION ALL SELECT 'Referenz training_submissions / point_transactions', (SELECT count(*) FROM public.training_submissions)||' / '||(SELECT count(*)||' / '||coalesce(sum(exp),0)||' / '||coalesce(sum(points),0) FROM public.point_transactions);
