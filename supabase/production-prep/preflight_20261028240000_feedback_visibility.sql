-- Read-only Preflight vor 20261028240000_feedback_visibility.sql (ändert nichts).
SELECT 'Feedback-Tabelle ohne neue Spalten' AS check_name, (to_regclass('public.boxer_coach_feedback') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM information_schema.columns
  WHERE table_schema='public' AND table_name='boxer_coach_feedback' AND column_name IN ('visible_until','withdrawn_at')))::text AS ok
UNION ALL SELECT 'Lese-Policy feedback_select_enabled vorhanden', EXISTS (SELECT 1 FROM pg_policies WHERE tablename='boxer_coach_feedback' AND policyname='feedback_select_enabled')::text
UNION ALL SELECT 'Hilfsfunktionen vorhanden', (to_regprocedure('league_private.require_staff()') IS NOT NULL AND to_regprocedure('public.is_league_admin()') IS NOT NULL)::text
UNION ALL SELECT 'Referenz Feedbacks (Anzahl / Boxer)', (SELECT count(*)||' / '||count(DISTINCT boxer_id) FROM public.boxer_coach_feedback)
UNION ALL SELECT 'Referenz Fingerabdruck Inhalte', (SELECT md5(coalesce(string_agg(id::text||title||message||boxer_id::text||coach_id::text||created_at::text,'|' ORDER BY id),'')) FROM public.boxer_coach_feedback);
