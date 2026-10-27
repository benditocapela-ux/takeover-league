-- Rollback für 20261028200000_weekly_quests.sql
-- Entfernt nur die Funktionen. Quest-Definitionen, Abholungen (inkl. gespeicherter Coins) und das Flag bleiben erhalten.
-- Vorher das Flag weekly_quests ausschalten. Bereits gutgeschriebene Quest-EXP bleiben als normale Buchungen bestehen.
BEGIN;
DROP FUNCTION IF EXISTS public.admin_update_quest(text,integer,integer,integer,boolean,jsonb);
DROP FUNCTION IF EXISTS public.admin_list_quests();
DROP FUNCTION IF EXISTS public.staff_quest_overview();
DROP FUNCTION IF EXISTS public.claim_quest(text,date);
DROP FUNCTION IF EXISTS public.get_my_quests(date);
DROP FUNCTION IF EXISTS league_private.quest_week(uuid,date);
DROP FUNCTION IF EXISTS league_private.quest_state(uuid,public.quest_definitions,date,date);
DROP FUNCTION IF EXISTS league_private.daily_quest_key(date);
DROP FUNCTION IF EXISTS league_private.quest_progress(uuid,text,date,date);
DROP FUNCTION IF EXISTS league_private.plan_pct(uuid,date);
DROP FUNCTION IF EXISTS league_private.quest_title(public.quest_definitions,integer);
DROP FUNCTION IF EXISTS league_private.quest_target(public.quest_definitions,uuid);
NOTIFY pgrst, 'reload schema';
COMMIT;
