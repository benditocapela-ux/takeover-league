-- Only after quick-request callers are disabled/removed; does not change any trainings.
BEGIN;
DROP FUNCTION IF EXISTS public.submit_scheduled_club_training_today(integer);
NOTIFY pgrst, 'reload schema';
COMMIT;
