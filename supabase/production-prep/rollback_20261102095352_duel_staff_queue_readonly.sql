-- Prepared rollback only. Requires separate authorization for production use.
-- Removes only the new read API/index. Never modifies duels, scoring, payouts or snapshots.
BEGIN;
DROP FUNCTION IF EXISTS public.duel_v2_staff_queue(text,integer,timestamptz,uuid,text,uuid);
DROP FUNCTION IF EXISTS league_v21_private.duel_staff_queue_core(text,integer,timestamptz,uuid,text,uuid);
DROP INDEX IF EXISTS public.league_duels_staff_cursor_idx;
NOTIFY pgrst,'reload schema';
COMMIT;
