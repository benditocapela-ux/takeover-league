\set ON_ERROR_STOP on
-- Runs after tests/gamification-fairness-notifications-schema.sql in the same disposable database.
\ir ../supabase/production-prep/rollback_20261027120000_gamification_fairness_and_notifications.sql
DO $t$ BEGIN
 IF EXISTS(SELECT 1 FROM pg_trigger WHERE tgname IN ('league_v21_notify_level_up','league_v21_notify_achievement','league_v21_publish_badges_when_public')) THEN
  RAISE EXCEPTION 'Rollback left new triggers behind'; END IF;
 IF to_regprocedure('league_v21_private.public_display_name(uuid)') IS NOT NULL THEN RAISE EXCEPTION 'Rollback left helper behind'; END IF;
 IF EXISTS(SELECT 1 FROM public.boxer_notifications WHERE notification_type='level_up') THEN RAISE EXCEPTION 'level_up rows not re-typed'; END IF;
 IF (SELECT count(*) FROM public.boxer_notifications WHERE notification_type='general')=0 THEN RAISE EXCEPTION 'Notifications must be kept'; END IF;
 IF position('league_challenges' in pg_get_functiondef('league_v21_private.global_edit_core(uuid,text,text,text,numeric,timestamptz,timestamptz,boolean)'::regprocedure))=0 THEN
  RAISE EXCEPTION 'Previous edit definition not restored'; END IF;
 IF (SELECT count(*) FROM public.point_transactions)=0 OR (SELECT count(*) FROM public.league_season_results_v21)=0 THEN
  RAISE EXCEPTION 'Rollback must not delete ledger or snapshot rows'; END IF;
END $t$;
-- Re-apply after rollback works.
\ir ../supabase/migrations/20261027120000_gamification_fairness_and_notifications.sql
SELECT 'PASS: rollback restores previous definitions, keeps all rows, re-apply works' AS result;
