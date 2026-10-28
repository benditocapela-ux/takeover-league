-- Rollback für 20261028240000_feedback_visibility.sql (Etappe 6b): RPCs und Einreich-Schutz entfernen, ursprüngliche Lese-Policy
-- wiederherstellen (dann sehen Boxer wieder alle eigenen Feedbacks, auch zurückgezogene). Spalten und Daten bleiben erhalten;
-- «sichtbar bis» bleibt mit Standardwert, damit das bisherige Senden weiter funktioniert.
BEGIN;
DROP FUNCTION IF EXISTS public.get_my_feedback();
DROP FUNCTION IF EXISTS public.staff_list_feedback(uuid,integer);
DROP FUNCTION IF EXISTS public.staff_update_feedback(uuid,date,boolean);
DROP FUNCTION IF EXISTS public.staff_send_feedback(uuid,text,text,date);
DROP TRIGGER IF EXISTS league_feedback_insert_guard ON public.boxer_coach_feedback;
DROP FUNCTION IF EXISTS league_private.feedback_insert_guard();
DROP FUNCTION IF EXISTS league_private.feedback_json(public.boxer_coach_feedback,date);
DROP POLICY IF EXISTS feedback_select_enabled ON public.boxer_coach_feedback;
CREATE POLICY feedback_select_enabled ON public.boxer_coach_feedback FOR SELECT TO authenticated USING (
 (EXISTS (SELECT 1 FROM public.league_feature_flags f WHERE f.feature_key='coach_feedback' AND f.is_enabled))
 AND (public.is_league_admin() OR (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=boxer_coach_feedback.boxer_id AND p.auth_user_id=(SELECT auth.uid())))));
NOTIFY pgrst, 'reload schema';
COMMIT;
