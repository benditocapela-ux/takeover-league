-- Read-only Preflight vor 20261031090000_training_v2_classification.sql (ändert nichts).
SELECT 'Voraussetzungen (Stufen, Stundenplan, review_training, admin_edit_training, club_checkin_only)' AS check_name,
 (to_regclass('public.club_tiers') IS NOT NULL AND to_regclass('public.club_schedule') IS NOT NULL
  AND to_regprocedure('public.review_training(uuid,text)') IS NOT NULL
  AND to_regprocedure('public.admin_edit_training(uuid,uuid,bigint,date,text,text)') IS NOT NULL
  AND EXISTS (SELECT 1 FROM public.league_feature_flags WHERE feature_key='club_checkin_only'))::text AS ok
UNION ALL SELECT 'Sperre wie 20261029230000 (Fingerprint)', md5(pg_get_functiondef('league_private.training_insert_guard()'::regprocedure))
UNION ALL SELECT 'Wertung training_value (Fingerprint)', md5(pg_get_functiondef('league_private.training_value(uuid)'::regprocedure))
UNION ALL SELECT 'Trainingsarten für Ergänzung vorhanden', (SELECT string_agg(name,', ' ORDER BY name) FROM public.training_types WHERE name IN ('Sandsack / Rundenarbeit','Krafttraining','Techniktraining','Reguläres Boxtraining'))
UNION ALL SELECT 'Stufen', (SELECT string_agg(tier||'='||exp||'/'||coins||'/'||pass_points,', ' ORDER BY tier) FROM public.club_tiers)
UNION ALL SELECT 'Stundenplan aktiv', (SELECT string_agg(dow||':'||label||'('||coalesce(tier,'-')||')',', ' ORDER BY dow, sort_order) FROM public.club_schedule WHERE is_active)
UNION ALL SELECT 'Offene Trainings', (SELECT count(*)::text FROM public.training_submissions WHERE status='pending')
UNION ALL SELECT 'Referenz training_submissions / point_transactions', (SELECT count(*) FROM public.training_submissions)||' / '||(SELECT count(*)||' / '||coalesce(sum(exp),0)||' / '||coalesce(sum(points),0) FROM public.point_transactions);
