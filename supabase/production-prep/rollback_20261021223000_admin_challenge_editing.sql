-- Rollback for 20261021223000_admin_challenge_editing.sql.
-- Use only after reverting the frontend that calls these RPCs. No data rows are deleted.
BEGIN;
DROP FUNCTION IF EXISTS public.league_v21_admin_edit_global_challenge(uuid,text,text,text,numeric,timestamptz,timestamptz,boolean);
DROP FUNCTION IF EXISTS league_v21_private.global_edit_core(uuid,text,text,text,numeric,timestamptz,timestamptz,boolean);
DROP FUNCTION IF EXISTS public.coach_challenge_v2_admin_edit(uuid,text,text,text,integer,text,integer);
COMMIT;
