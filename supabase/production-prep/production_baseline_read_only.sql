-- READ-ONLY PRODUCTION PREFLIGHT. Safe to run before and after an explicitly approved release.
-- Returns only aggregate counts; does not export individual boxer identities.
SELECT pg_catalog.jsonb_pretty(pg_catalog.jsonb_build_object(
 'checked_at_utc',now(),
 'postgres_version',current_setting('server_version'),
 'profile_count',(SELECT count(*) FROM public.profiles),
 'active_boxers',(SELECT count(*) FROM public.profiles WHERE role='boxer' AND is_active),
 'active_admins',(SELECT count(*) FROM public.profiles WHERE role='admin' AND is_active),
 'active_coaches',(SELECT count(*) FROM public.profiles WHERE role='coach' AND is_active),
 'linked_profiles',(SELECT count(*) FROM public.profiles WHERE auth_user_id IS NOT NULL),
 'training_submissions',(SELECT count(*) FROM public.training_submissions),
 'training_pending',(SELECT count(*) FROM public.training_submissions WHERE status='pending'),
 'training_approved',(SELECT count(*) FROM public.training_submissions WHERE status='approved'),
 'point_transactions',(SELECT count(*) FROM public.point_transactions),
 'point_total',(SELECT coalesce(sum(points),0) FROM public.point_transactions),
 'exp_total',(SELECT coalesce(sum(exp),0) FROM public.point_transactions),
 'point_transaction_categories',(
   SELECT coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
    'category',category,'transactions',n,'points',points,'exp',exp) ORDER BY category),'[]'::jsonb)
   FROM (SELECT category,count(*) AS n,sum(points) AS points,sum(exp) AS exp
     FROM public.point_transactions GROUP BY category) categories
 ),
 'v2_tables_present',(SELECT count(*) FROM pg_catalog.pg_class c
  JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public'
  AND c.relkind IN ('r','p') AND c.relname IN
  ('league_coach_challenges','league_coach_challenge_entries','league_coach_challenge_reviews',
   'league_coach_challenge_exp_ledger','league_duels','league_duel_events','league_duel_exp_ledger')),
 'v2_rpcs_present',(SELECT count(*) FROM pg_catalog.pg_proc p
 JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public'
 AND (p.proname LIKE 'coach_challenge_v2_%' OR p.proname LIKE 'duel_v2_%')),
 'v2_enabled_flags',(SELECT count(*) FROM public.league_feature_flags
 WHERE feature_key IN ('coach_challenges','duels') AND is_enabled),
 'anon_can_recalculate_achievement_exp',
 pg_catalog.has_function_privilege('anon','public.recalculate_boxer_achievements_v2(uuid)','EXECUTE'),
 'archived_wal_segments',(SELECT archived_count FROM pg_catalog.pg_stat_archiver),
 'wal_archive_failures',(SELECT failed_count FROM pg_catalog.pg_stat_archiver)
)) AS production_audit;
