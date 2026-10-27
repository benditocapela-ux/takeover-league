-- Rollback für 20261028170000_staff_record_training.sql – behält alle Daten.
-- Entfernt die RPC. Bereits eingetragene und bestätigte Trainings, Punkte und EXP bleiben;
-- die Spalte recorded_by bleibt bestehen (Nachvollziehbarkeit).
BEGIN;
DROP FUNCTION IF EXISTS public.staff_record_training(uuid,bigint,date,integer,text,numeric,uuid);
NOTIFY pgrst, 'reload schema';
COMMIT;
