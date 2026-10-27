-- READ ONLY postflight for 20261027120000_gamification_fairness_and_notifications.sql.
SELECT current_database() AS database_name, current_user AS database_role;
SELECT
 position('p.is_listed is true' in pg_get_functiondef('league_v21_private.season_transition_core(uuid,text)'::regprocedure))>0 AS season_public_only,
 position('r.points>0' in pg_get_functiondef('league_v21_private.season_transition_core(uuid,text)'::regprocedure))>0 AS hof_needs_points,
 position('public_display_name' in pg_get_functiondef('league_v21_private.global_close_core(uuid)'::regprocedure))>0 AS challenge_names_masked,
 position('league_challenges' in pg_get_functiondef('league_v21_private.global_edit_core(uuid,text,text,text,numeric,timestamptz,timestamptz,boolean)'::regprocedure))=0 AS edit_without_legacy_flag,
 position('p.is_listed' in pg_get_functiondef('league_v21_private.refresh_public_records_core(integer,uuid)'::regprocedure))>0 AS records_public_only,
 position('p.is_listed' in pg_get_functiondef('league_v21_private.sync_public_badges_core()'::regprocedure))>0 AS badges_public_only,
 position('public_display_name' in pg_get_functiondef('league_v21_private.sync_public_duel_history()'::regprocedure))>0 AS duel_names_masked,
 position('bestätigt' in pg_get_functiondef('public._notify_training_decision()'::regprocedure))>0 AS umlauts_fixed,
 position('league_level_from_exp_v2' in pg_get_functiondef('public.get_boxer_exp_level_rank(uuid)'::regprocedure))>0 AS one_level_curve;
SELECT tgname, tgrelid::regclass AS on_table FROM pg_trigger
WHERE tgname IN ('league_v21_notify_level_up','league_v21_notify_achievement','league_v21_publish_badges_when_public') ORDER BY 1;
SELECT p.proname, p.proacl::text FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='league_v21_private' AND p.proname IN ('public_display_name','notifications_enabled','rank_for_level','notify_level_up','notify_achievement','publish_badges_when_public')
ORDER BY 1;
SELECT p.proacl::text AS level_rank_rpc_acl FROM pg_proc p WHERE p.oid='public.get_boxer_exp_level_rank(uuid)'::regprocedure;
SELECT pg_get_constraintdef(oid) AS notification_type_check FROM pg_constraint WHERE conname='boxer_notifications_notification_type_check';
-- Must equal the preflight baseline (notifications may only grow):
SELECT (SELECT count(*) FROM public.profiles) AS profiles,
       (SELECT count(*) FROM public.training_submissions) AS trainings,
       (SELECT count(*) FROM public.point_transactions) AS point_transactions,
       (SELECT coalesce(sum(points),0) FROM public.point_transactions) AS points_sum,
       (SELECT coalesce(sum(exp),0) FROM public.point_transactions) AS exp_sum,
       (SELECT count(*) FROM public.league_public_badges_v21) AS public_badges,
       (SELECT count(*) FROM public.league_public_records_v21) AS public_records,
       (SELECT count(*) FROM public.league_season_results_v21) AS season_results,
       (SELECT count(*) FROM public.league_hall_of_fame_v21) AS hall_of_fame,
       (SELECT count(*) FROM public.boxer_notifications) AS notifications,
       (SELECT string_agg(feature_key||'='||is_enabled,', ' ORDER BY feature_key) FROM public.league_feature_flags) AS flags;
