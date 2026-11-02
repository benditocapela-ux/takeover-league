-- Prepared only; no data or economic state is changed. Revert dependent Studio client first.
BEGIN;
DROP FUNCTION public.get_my_studio_training_history(text,timestamptz,uuid);
DROP FUNCTION public.get_my_studio_training_summary();
DROP FUNCTION league_studio_private.studio_training_history_core(text,timestamptz,uuid);
DROP FUNCTION league_studio_private.studio_training_summary_core();
DROP INDEX public.training_submissions_own_history_cursor_idx;
DROP INDEX public.training_submissions_own_status_cursor_idx;
DROP SCHEMA league_studio_private;
NOTIFY pgrst,'reload schema';
COMMIT;
