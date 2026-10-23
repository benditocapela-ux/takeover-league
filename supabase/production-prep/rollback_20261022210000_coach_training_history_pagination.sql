-- Reversible rollback for coach_list_training_history only.
-- No data, points, EXP, roles, or feature flags are modified.
BEGIN;
DROP FUNCTION IF EXISTS public.coach_list_training_history(text,uuid,bigint,date,date,text,integer,integer);
NOTIFY pgrst, 'reload schema';
COMMIT;
