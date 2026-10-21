-- READ-ONLY POSTFLIGHT. Run after explicitly approved Coach/Duel migrations,
-- before feature enablement and after activation. Never writes boxer data.
WITH checks AS (
 SELECT
  (SELECT count(*) FROM pg_catalog.pg_class c
   JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
   WHERE n.nspname='public' AND c.relkind IN ('r','p') AND
   c.relname IN ('league_coach_challenges','league_coach_challenge_entries',
    'league_coach_challenge_reviews','league_coach_challenge_exp_ledger',
    'league_duels','league_duel_events','league_duel_exp_ledger')) AS v2_tables,
  (SELECT count(*) FROM pg_catalog.pg_class c
   JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
   WHERE n.nspname='public' AND c.relrowsecurity AND
   c.relname IN ('league_coach_challenges','league_coach_challenge_entries',
    'league_coach_challenge_reviews','league_coach_challenge_exp_ledger',
    'league_duels','league_duel_events','league_duel_exp_ledger')) AS rls_protected_tables,
  (SELECT count(*) FROM pg_catalog.pg_proc p
   JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname='public' AND p.proname LIKE 'coach_challenge_v2_%') AS challenge_rpcs,
  (SELECT count(*) FROM pg_catalog.pg_proc p
   JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname='public' AND p.proname LIKE 'duel_v2_%') AS duel_rpcs,
  (SELECT count(*) FROM pg_catalog.pg_proc p
   JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname='public' AND
    (p.proname LIKE 'coach_challenge_v2_%' OR p.proname LIKE 'duel_v2_%')
    AND p.prosecdef AND pg_catalog.has_function_privilege('authenticated',p.oid,'EXECUTE')
    AND NOT pg_catalog.has_function_privilege('anon',p.oid,'EXECUTE')
    AND EXISTS (SELECT 1 FROM pg_catalog.unnest(p.proconfig) AS cfg(setting)
      WHERE cfg.setting LIKE 'search_path=%')
  ) AS protected_authenticated_rpcs,
  (SELECT count(*) FROM pg_catalog.pg_class c
    JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND
    c.relname IN ('league_coach_challenges','league_coach_challenge_entries',
     'league_coach_challenge_reviews','league_coach_challenge_exp_ledger',
     'league_duels','league_duel_events','league_duel_exp_ledger')
    AND NOT pg_catalog.has_table_privilege('anon',c.oid,'SELECT')
    AND NOT pg_catalog.has_table_privilege('authenticated',c.oid,'SELECT')
    AND NOT pg_catalog.has_table_privilege('anon',c.oid,'INSERT')
    AND NOT pg_catalog.has_table_privilege('authenticated',c.oid,'INSERT')
    AND NOT pg_catalog.has_table_privilege('anon',c.oid,'UPDATE')
    AND NOT pg_catalog.has_table_privilege('authenticated',c.oid,'UPDATE')
    AND NOT pg_catalog.has_table_privilege('anon',c.oid,'DELETE')
    AND NOT pg_catalog.has_table_privilege('authenticated',c.oid,'DELETE')
  ) AS tables_without_client_dml,
  (SELECT count(*) FROM public.league_feature_flags
   WHERE feature_key IN ('coach_challenges','duels')) AS v2_flags,
  (SELECT count(*) FROM public.league_feature_flags
   WHERE feature_key IN ('coach_challenges','duels') AND is_enabled) AS v2_flags_enabled,
  (SELECT count(*)=1 FROM pg_catalog.pg_constraint c
   WHERE c.conrelid='public.profiles'::regclass AND c.conname='profiles_role_check'
   AND pg_catalog.pg_get_constraintdef(c.oid) LIKE '%coach%') AS coach_role_allowed,
  (SELECT count(*)=1 FROM pg_catalog.pg_constraint c
   WHERE c.conrelid='public.point_transactions'::regclass
    AND c.conname='point_transactions_category_check'
    AND pg_catalog.pg_get_constraintdef(c.oid) LIKE '%duel_exp%'
    AND pg_catalog.pg_get_constraintdef(c.oid) LIKE '%challenge_exp%') AS v2_exp_categories_allowed,
  (NOT pg_catalog.has_function_privilege('anon',
    'public.recalculate_boxer_achievements_v2(uuid)','EXECUTE')
   AND NOT pg_catalog.has_function_privilege('authenticated',
    'public.recalculate_boxer_achievements_v2(uuid)','EXECUTE')
   AND pg_catalog.has_function_privilege('service_role',
    'public.recalculate_boxer_achievements_v2(uuid)','EXECUTE')) AS achievement_security_fixed,
  (SELECT count(*) FROM public.league_coach_challenge_exp_ledger l
   LEFT JOIN public.point_transactions t ON t.id=l.transaction_id
   WHERE t.id IS NULL OR t.boxer_id<>l.boxer_id OR t.category<>'challenge_exp'
    OR t.exp<>l.awarded_exp OR t.points<>0) AS invalid_challenge_exp_ledgers,
  (SELECT count(*) FROM public.league_duel_exp_ledger l
   LEFT JOIN public.point_transactions t ON t.id=l.transaction_id
   WHERE t.id IS NULL OR t.boxer_id<>l.boxer_id OR t.category<>'duel_exp'
    OR t.exp<>l.awarded_exp OR t.points<>0) AS invalid_duel_exp_ledgers,
  (SELECT count(*) FROM public.league_coach_challenge_exp_ledger) AS challenge_rewards,
  (SELECT count(*) FROM public.league_duel_exp_ledger) AS duel_rewards
)
SELECT pg_catalog.jsonb_pretty(pg_catalog.to_jsonb(checks) ||
 pg_catalog.jsonb_build_object('release_integrity_passed',
  v2_tables=7 AND rls_protected_tables=7
  AND challenge_rpcs=17 + CASE WHEN pg_catalog.to_regprocedure('public.coach_challenge_v2_admin_edit(uuid,text,text,text,integer,text,integer)') IS NOT NULL THEN 1 ELSE 0 END
  AND duel_rpcs=6
  AND protected_authenticated_rpcs=23 + CASE WHEN pg_catalog.to_regprocedure('public.coach_challenge_v2_admin_edit(uuid,text,text,text,integer,text,integer)') IS NOT NULL THEN 1 ELSE 0 END
  AND tables_without_client_dml=7
  AND v2_flags=2 AND coach_role_allowed AND v2_exp_categories_allowed
  AND achievement_security_fixed AND invalid_challenge_exp_ledgers=0
  AND invalid_duel_exp_ledgers=0
 )) AS postflight_result FROM checks;
