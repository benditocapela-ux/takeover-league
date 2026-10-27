-- Rollback für 20261028190000_training_groups_gym.sql
-- Entfernt nur die Funktionen. Gruppen, Einheiten, Anwesenheiten, Wochenpläne und das Flag bleiben mit allen Daten erhalten.
-- Vorher das Flag gym_training ausschalten. Bereits bestätigte Trainings bleiben normale bestätigte Trainings.
BEGIN;
DROP FUNCTION IF EXISTS public.get_my_week_plan(date);
DROP FUNCTION IF EXISTS public.staff_save_training_plan(text,date,text,jsonb,boolean);
DROP FUNCTION IF EXISTS public.staff_get_training_plan(text,date);
DROP FUNCTION IF EXISTS public.staff_presence_overview();
DROP FUNCTION IF EXISTS public.get_my_presence();
DROP FUNCTION IF EXISTS public.gym_check_in(bigint);
DROP FUNCTION IF EXISTS public.my_gym_sessions_today();
DROP FUNCTION IF EXISTS public.staff_confirm_gym_session(bigint);
DROP FUNCTION IF EXISTS public.staff_cancel_gym_session(bigint);
DROP FUNCTION IF EXISTS public.staff_set_gym_attendance(bigint,uuid,boolean);
DROP FUNCTION IF EXISTS public.staff_get_gym_session(bigint);
DROP FUNCTION IF EXISTS public.staff_list_gym_sessions(integer);
DROP FUNCTION IF EXISTS public.staff_open_gym_session(bigint,integer,text,text);
DROP FUNCTION IF EXISTS public.admin_set_group_target(text,integer);
DROP FUNCTION IF EXISTS public.staff_set_training_group(uuid,text);
DROP FUNCTION IF EXISTS public.staff_list_group_members();
DROP FUNCTION IF EXISTS public.list_training_groups();
DROP FUNCTION IF EXISTS league_private.plan_items_valid(jsonb);
DROP FUNCTION IF EXISTS league_private.presence_streak(uuid);
DROP FUNCTION IF EXISTS league_private.presence_weeks(uuid,integer);
DROP FUNCTION IF EXISTS league_private.approved_count(uuid,date,date);
DROP FUNCTION IF EXISTS league_private.group_json(public.training_groups);
DROP FUNCTION IF EXISTS league_private.group_of(uuid);
DROP FUNCTION IF EXISTS league_private.require_staff();
DROP FUNCTION IF EXISTS league_private.week_monday(date);
DROP FUNCTION IF EXISTS league_private.zurich_today();
NOTIFY pgrst, 'reload schema';
COMMIT;
