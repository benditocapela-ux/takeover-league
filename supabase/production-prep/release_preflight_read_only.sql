-- READ-ONLY V2 PRODUCTION MIGRATION PREFLIGHT.
-- Run only against iqarjivcrddcixrvqbfb BEFORE explicit FREIGEBEN/DDL.
-- No profile identities, auth tokens or user data are returned.
WITH checks AS (
 SELECT
  (pg_catalog.to_regnamespace('league_private') IS NULL) AS private_schema_available,
  (SELECT count(*)=0 FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname='public' AND (p.proname LIKE 'coach_challenge_v2_%' OR p.proname LIKE 'duel_v2_%')) AS rpc_names_available,
  (SELECT count(*)=0 FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
   WHERE n.nspname='public' AND c.relname IN ('league_coach_challenges',
    'league_coach_challenge_entries','league_coach_challenge_reviews',
    'league_coach_challenge_exp_ledger','league_duels','league_duel_events','league_duel_exp_ledger')) AS table_names_available,
  (SELECT count(*)=1 FROM pg_catalog.pg_constraint c
   WHERE c.conrelid='public.profiles'::regclass AND c.conname='profiles_role_check'
    AND pg_catalog.pg_get_constraintdef(c.oid) LIKE '%boxer%'
    AND pg_catalog.pg_get_constraintdef(c.oid) LIKE '%admin%') AS expected_role_constraint,
  (SELECT count(*)=1 FROM pg_catalog.pg_constraint c
   WHERE c.conrelid='public.point_transactions'::regclass
   AND c.conname='point_transactions_category_check'
   AND pg_catalog.pg_get_constraintdef(c.oid) LIKE '%achievement_exp%'
   AND pg_catalog.pg_get_constraintdef(c.oid) LIKE '%automatic_bonus%'
   AND pg_catalog.pg_get_constraintdef(c.oid) LIKE '%legacy_import%') AS expected_transaction_constraint,
  (SELECT count(*)=0 FROM public.league_feature_flags
   WHERE feature_key IN ('coach_challenges','duels') AND is_enabled) AS no_v2_features_enabled,
  (SELECT count(*)=0 FROM public.point_transactions
   WHERE category NOT IN ('training','trainer_bonus','adjustment','legacy_import',
    'automatic_bonus','achievement_exp','duel_exp','challenge_exp')) AS transaction_categories_known,
  (SELECT count(*)=1 FROM pg_catalog.pg_proc p
   WHERE p.oid=pg_catalog.to_regprocedure('public.recalculate_boxer_achievements_v2(uuid)')
   AND p.prosecdef AND p.proowner='postgres'::regrole) AS achievement_owner_expected,
  (SELECT count(*)=1 FROM pg_catalog.pg_proc p
   WHERE p.oid=pg_catalog.to_regprocedure('public._award_achievements_on_approval()')
   AND p.prosecdef AND p.proowner='postgres'::regrole) AS approval_owner_expected,
  (SELECT count(*)>0 FROM pg_catalog.pg_trigger t
   WHERE t.tgfoid=pg_catalog.to_regprocedure('public._award_achievements_on_approval()')
   AND t.tgrelid='public.training_submissions'::regclass AND NOT t.tgisinternal) AS approval_trigger_installed,
  pg_catalog.has_function_privilege('postgres',
   'public.recalculate_boxer_achievements_v2(uuid)','EXECUTE') AS achievement_owner_can_execute,
  pg_catalog.has_function_privilege('service_role',
   'public.recalculate_boxer_achievements_v2(uuid)','EXECUTE') AS achievement_service_can_execute
)
SELECT pg_catalog.jsonb_pretty(
 pg_catalog.to_jsonb(checks) || pg_catalog.jsonb_build_object(
 'ready_for_controlled_release',
  private_schema_available AND rpc_names_available AND table_names_available
  AND expected_role_constraint AND expected_transaction_constraint
  AND no_v2_features_enabled AND transaction_categories_known
  AND achievement_owner_expected AND approval_owner_expected
  AND approval_trigger_installed AND achievement_owner_can_execute
  AND achievement_service_can_execute
 )
) AS preflight_result
FROM checks;
