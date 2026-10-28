-- Read-only Preflight vor 20261029100000_feedback_portal.sql (ändert nichts).
SELECT 'Hilfsfunktionen und Benachrichtigungen vorhanden' AS check_name, (to_regprocedure('league_private.active_viewer()') IS NOT NULL
  AND to_regprocedure('league_private.flag_on(text)') IS NOT NULL AND to_regclass('public.boxer_notifications') IS NOT NULL)::text AS ok
UNION ALL SELECT 'Noch kein Feedback-Portal', (to_regclass('public.app_feedback') IS NULL AND NOT EXISTS (SELECT 1 FROM storage.buckets WHERE id='feedback-shots'))::text
UNION ALL SELECT 'Benachrichtigungstyp general erlaubt', EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.boxer_notifications'::regclass
  AND conname='boxer_notifications_notification_type_check' AND pg_get_constraintdef(oid) LIKE '%general%')::text
UNION ALL SELECT 'Referenz Speicher-Buckets', (SELECT string_agg(id||':'||public,',' ORDER BY id) FROM storage.buckets)
UNION ALL SELECT 'Referenz Speicher-Regeln', (SELECT string_agg(policyname,',' ORDER BY policyname) FROM pg_policies WHERE schemaname='storage' AND tablename='objects');
