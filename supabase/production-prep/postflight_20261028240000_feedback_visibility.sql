-- Read-only Postflight nach 20261028240000_feedback_visibility.sql (ändert nichts).
SELECT 'Spalten vorhanden, sichtbar bis Pflicht' AS check_name, ((SELECT count(*) FROM information_schema.columns WHERE table_schema='public' AND table_name='boxer_coach_feedback'
  AND column_name IN ('visible_until','withdrawn_at','withdrawn_by','updated_at','updated_by'))=5
  AND (SELECT is_nullable FROM information_schema.columns WHERE table_schema='public' AND table_name='boxer_coach_feedback' AND column_name='visible_until')='NO')::text AS ok
UNION ALL SELECT 'Bestehende Feedbacks: sichtbar bis = Versand + 7, keines zurückgezogen', (NOT EXISTS (SELECT 1 FROM public.boxer_coach_feedback
  WHERE visible_until<>(created_at AT TIME ZONE 'Europe/Zurich')::date+7 OR withdrawn_at IS NOT NULL))::text
UNION ALL SELECT 'Lese-Policy blendet Zurückgezogene für Boxer aus', EXISTS (SELECT 1 FROM pg_policies WHERE tablename='boxer_coach_feedback' AND policyname='feedback_select_enabled' AND qual LIKE '%withdrawn_at IS NULL%')::text
UNION ALL SELECT '3 RPCs SECURITY DEFINER, nicht für anon', ((SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.prosecdef
  AND p.proconfig @> ARRAY['search_path=""'] AND p.proname IN ('get_my_feedback','staff_list_feedback','staff_update_feedback'))=3
  AND NOT has_function_privilege('anon','public.staff_update_feedback(uuid,date,boolean)','EXECUTE'))::text
UNION ALL SELECT 'Einreich-Schutz aktiv', EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='league_feedback_insert_guard')::text
UNION ALL SELECT 'Referenz Feedbacks (Anzahl / Boxer)', (SELECT count(*)||' / '||count(DISTINCT boxer_id) FROM public.boxer_coach_feedback)
UNION ALL SELECT 'Referenz Fingerabdruck Inhalte (unverändert)', (SELECT md5(coalesce(string_agg(id::text||title||message||boxer_id::text||coach_id::text||created_at::text,'|' ORDER BY id),'')) FROM public.boxer_coach_feedback);
