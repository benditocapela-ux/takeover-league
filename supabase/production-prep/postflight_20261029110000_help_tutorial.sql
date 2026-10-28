-- Read-only Postflight nach 20261029110000_help_tutorial.sql (ändert nichts).
SELECT 'Tabellen mit RLS, keine direkten Rechte' AS check_name, ((SELECT bool_and(relrowsecurity) FROM pg_class WHERE oid IN ('public.faq_entries'::regclass,'public.profile_onboarding'::regclass))
  AND NOT has_table_privilege('anon','public.faq_entries','SELECT') AND NOT has_table_privilege('authenticated','public.profile_onboarding','SELECT'))::text AS ok
UNION ALL SELECT 'FAQ-Startinhalt (14) veröffentlicht', ((SELECT count(*) FROM public.faq_entries WHERE is_published)>=14)::text
UNION ALL SELECT 'FAQ lesbar für Gäste, pflegen nur angemeldet (Admin-Prüfung im Server)', (has_function_privilege('anon','public.get_faq()','EXECUTE')
  AND NOT has_function_privilege('anon','public.admin_save_faq(bigint,text,text,text,integer,boolean)','EXECUTE')
  AND NOT has_function_privilege('anon','public.mark_tour_seen(integer)','EXECUTE'))::text
UNION ALL SELECT 'Flag tutorial aus', EXISTS (SELECT 1 FROM public.league_feature_flags WHERE feature_key='tutorial' AND NOT is_enabled)::text;
