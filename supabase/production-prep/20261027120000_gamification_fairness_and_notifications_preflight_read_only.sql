-- READ ONLY preflight for 20261027120000_gamification_fairness_and_notifications.sql.
-- Expected: production project iqarjivcrddcixrvqbfb. Every md5 below must match the 27.10.2026 state;
-- a different hash means the function changed since the review and the migration must be re-checked.
SELECT current_database() AS database_name, current_user AS database_role;
SELECT n.nspname||'.'||p.proname AS fn, md5(pg_get_functiondef(p.oid)) AS md5,
  CASE n.nspname||'.'||p.proname
   WHEN 'league_v21_private.season_transition_core' THEN '5a1a75bf55609ebb9a1a2874b7ddda38'
   WHEN 'league_v21_private.global_close_core' THEN '51ad4fbdf4c1898e9d1fdfc6ab472272'
   WHEN 'league_v21_private.global_edit_core' THEN '033156e00f673519959c6880d88cbcc2'
   WHEN 'league_v21_private.refresh_public_records_core' THEN 'fb492598f1dd3c112b8c81a611e5e6c7'
   WHEN 'league_v21_private.sync_public_badges_core' THEN 'c9e2c09b27c9e42fba145e603671f1e2'
   WHEN 'league_v21_private.sync_public_duel_history' THEN '1e6011e510e01c9f93a10c3c03d66784'
   WHEN 'public._notify_training_decision' THEN '9d8a73039c7c5959c7535774db953807'
   WHEN 'public._notify_coach_feedback' THEN 'b9c76921edbcb32ae86690ef93dda717'
   WHEN 'public.get_boxer_exp_level_rank' THEN '101b64bb40bca6ae5693b6ffc34f4b3a'
  END AS expected_md5
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE (n.nspname='league_v21_private' AND p.proname IN ('season_transition_core','global_close_core','global_edit_core',
        'refresh_public_records_core','sync_public_badges_core','sync_public_duel_history'))
   OR (n.nspname='public' AND p.proname IN ('_notify_training_decision','_notify_coach_feedback','get_boxer_exp_level_rank'))
ORDER BY 1;
-- Must not exist yet:
SELECT to_regprocedure('league_v21_private.notify_level_up()') AS level_up_fn,
       to_regprocedure('league_v21_private.public_display_name(uuid)') AS display_name_fn,
       (SELECT count(*) FROM pg_trigger WHERE tgname IN ('league_v21_notify_level_up','league_v21_notify_achievement','league_v21_publish_badges_when_public')) AS new_triggers;
SELECT pg_get_constraintdef(oid) AS notification_type_check FROM pg_constraint WHERE conname='boxer_notifications_notification_type_check';
-- Baseline counts (postflight must show the same numbers except notifications):
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
