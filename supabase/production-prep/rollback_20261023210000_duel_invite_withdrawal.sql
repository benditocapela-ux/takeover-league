-- Removes only the new RPC; no duel/event/score/EXP rows are changed.
BEGIN;
DROP FUNCTION IF EXISTS public.duel_v2_withdraw_invite(uuid);
NOTIFY pgrst, 'reload schema';
COMMIT;
