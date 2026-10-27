-- Rollback for 20261028130000_duel_notifications.sql (notifications already sent stay).
BEGIN;
DROP TRIGGER IF EXISTS league_v21_notify_duel_events ON public.league_duels;
DROP FUNCTION IF EXISTS league_v21_private.notify_duel_events();
COMMIT;
