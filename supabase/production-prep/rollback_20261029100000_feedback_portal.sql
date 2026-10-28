-- Rollback für 20261029100000_feedback_portal.sql (Etappe 7b): RPCs und Speicher-Regeln entfernen.
-- Meldungen (public.app_feedback), Screenshots und der private Speicher bleiben erhalten (nichts wird gelöscht);
-- ohne RPCs und Regeln kommt niemand mehr an sie heran. Das Flag app_feedback bleibt (aus).
BEGIN;
DROP FUNCTION IF EXISTS public.submit_app_feedback(text,text,text,text,text,text[]);
DROP FUNCTION IF EXISTS public.my_app_feedback();
DROP FUNCTION IF EXISTS public.admin_list_app_feedback(text,integer);
DROP FUNCTION IF EXISTS public.admin_update_app_feedback(uuid,text,text);
DROP FUNCTION IF EXISTS league_private.app_feedback_json(public.app_feedback,boolean);
DROP POLICY IF EXISTS feedback_shots_insert_own ON storage.objects;
DROP POLICY IF EXISTS feedback_shots_select_own_or_admin ON storage.objects;
UPDATE public.league_feature_flags SET is_enabled=false WHERE feature_key='app_feedback';
NOTIFY pgrst, 'reload schema';
COMMIT;
