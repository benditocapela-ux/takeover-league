-- Rollback only removes the new RPC. No challenge or ledger rows are changed.
BEGIN;
DROP FUNCTION IF EXISTS public.coach_challenge_v2_delete_draft(uuid);
NOTIFY pgrst, 'reload schema';
COMMIT;
