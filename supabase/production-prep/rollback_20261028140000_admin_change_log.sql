-- Rollback for 20261028140000_admin_change_log.sql: removes the triggers. The log table is KEPT
-- (it may already contain history); drop it only on explicit decision.
BEGIN;
DROP TRIGGER IF EXISTS league_v21_audit_seasons ON public.league_seasons_v21;
DROP TRIGGER IF EXISTS league_v21_audit_global_challenges ON public.league_global_challenges_v21;
DROP TRIGGER IF EXISTS league_v21_audit_arena ON public.league_arena_duels_v21;
DROP TRIGGER IF EXISTS league_v21_audit_goals ON public.league_boxer_goals_v21;
DROP FUNCTION IF EXISTS league_v21_private.audit_admin_change();
COMMIT;
