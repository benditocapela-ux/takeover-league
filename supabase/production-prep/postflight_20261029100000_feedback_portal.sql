-- Read-only Postflight nach 20261029100000_feedback_portal.sql (ändert nichts).
SELECT 'Tabelle mit RLS, keine direkten Rechte' AS check_name, ((SELECT relrowsecurity FROM pg_class WHERE oid='public.app_feedback'::regclass)
  AND NOT has_table_privilege('authenticated','public.app_feedback','SELECT') AND NOT has_table_privilege('anon','public.app_feedback','SELECT'))::text AS ok
UNION ALL SELECT 'Privater Speicher 5 MB, nur Bilder', EXISTS (SELECT 1 FROM storage.buckets WHERE id='feedback-shots' AND NOT public AND file_size_limit=5242880
  AND allowed_mime_types=ARRAY['image/png','image/jpeg','image/webp'])::text
UNION ALL SELECT '2 Speicher-Regeln (Upload eigener Ordner, Lesen eigen/Admin), keine Änderung/Löschung', ((SELECT count(*) FROM pg_policies WHERE schemaname='storage' AND tablename='objects'
  AND policyname IN ('feedback_shots_insert_own','feedback_shots_select_own_or_admin'))=2
  AND NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='storage' AND tablename='objects' AND cmd IN ('UPDATE','DELETE','ALL') AND (qual LIKE '%feedback-shots%' OR with_check LIKE '%feedback-shots%')))::text
UNION ALL SELECT '4 RPCs SECURITY DEFINER, nicht für anon', ((SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.prosecdef
  AND p.proconfig @> ARRAY['search_path=""'] AND p.proname IN ('submit_app_feedback','my_app_feedback','admin_list_app_feedback','admin_update_app_feedback'))=4
  AND NOT has_function_privilege('anon','public.submit_app_feedback(text,text,text,text,text,text[])','EXECUTE'))::text
UNION ALL SELECT 'Flag app_feedback aus', EXISTS (SELECT 1 FROM public.league_feature_flags WHERE feature_key='app_feedback' AND NOT is_enabled)::text
UNION ALL SELECT 'Referenz Speicher-Buckets', (SELECT string_agg(id||':'||public,',' ORDER BY id) FROM storage.buckets)
UNION ALL SELECT 'Referenz Speicher-Regeln', (SELECT string_agg(policyname,',' ORDER BY policyname) FROM pg_policies WHERE schemaname='storage' AND tablename='objects');
