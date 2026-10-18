-- PREPARED rollback. V2 RPCs only; no legacy RPCs or data affected.
-- Review before production use. Never run after live challenge activity.
BEGIN;
DROP FUNCTION IF EXISTS public.coach_challenge_v2_settle_manual(uuid);
DROP FUNCTION IF EXISTS public.coach_challenge_v2_review_manual(uuid,uuid,boolean,text);
DROP FUNCTION IF EXISTS public.coach_challenge_v2_review_candidates(uuid);
DROP FUNCTION IF EXISTS public.coach_challenge_v2_review_status(uuid);
DROP FUNCTION IF EXISTS public.coach_challenge_v2_begin_reviews(uuid);
DROP FUNCTION IF EXISTS public.coach_challenge_v2_progress(uuid);
DROP FUNCTION IF EXISTS public.coach_challenge_v2_goal_details(uuid);
DROP FUNCTION IF EXISTS public.coach_challenge_v2_list();
DROP FUNCTION IF EXISTS public.coach_challenge_v2_activate(uuid);
DROP FUNCTION IF EXISTS public.coach_challenge_v2_withdraw(uuid);
DROP FUNCTION IF EXISTS public.coach_challenge_v2_join(uuid);
DROP FUNCTION IF EXISTS public.coach_challenge_v2_manage(uuid,text);
DROP FUNCTION IF EXISTS public.coach_challenge_v2_set_reward(uuid,integer);
DROP FUNCTION IF EXISTS public.coach_challenge_v2_set_goal(uuid,text,text,numeric,text);
DROP FUNCTION IF EXISTS public.coach_challenge_v2_save_goal_reward(uuid,text,text,integer,numeric,text);
DROP FUNCTION IF EXISTS public.coach_challenge_v2_edit_draft(uuid,text,text,text,integer);
DROP FUNCTION IF EXISTS public.coach_challenge_v2_create_draft(text,text,text,integer);
DROP FUNCTION IF EXISTS league_private.coach_v2_actor();
DROP SCHEMA IF EXISTS league_private RESTRICT;
COMMIT;
