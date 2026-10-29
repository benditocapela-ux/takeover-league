-- Read-only Preflight vor 20261029230000_club_types_selfservice.sql (ändert nichts).
SELECT 'Sperre wie 20261028230000 (Fingerprint)' AS check_name, md5(pg_get_functiondef('league_private.training_insert_guard()'::regprocedure)) AS ok
UNION ALL SELECT 'Trigger aktiv', (SELECT count(*)::text FROM pg_trigger WHERE tgname='league_training_insert_guard' AND tgrelid='public.training_submissions'::regclass)
UNION ALL SELECT 'Vereinstrainings (club_only, aktiv)', (SELECT string_agg(name,', ' ORDER BY sort_order) FROM public.training_types WHERE club_only AND is_active)
UNION ALL SELECT 'Schalter gym_training / club_checkin_only', (SELECT coalesce(string_agg(feature_key||'='||is_enabled,', ' ORDER BY feature_key),'–') FROM public.league_feature_flags WHERE feature_key IN ('gym_training','club_checkin_only'))
UNION ALL SELECT 'Referenz training_submissions / point_transactions', (SELECT count(*) FROM public.training_submissions)||' / '||(SELECT count(*)||' / '||coalesce(sum(exp),0)||' / '||coalesce(sum(points),0) FROM public.point_transactions);
