-- PREPARED ONLY. Never execute before the user's explicit "FREIGEBEN".
-- Activate ONLY after the Achievement patch, both V2 migrations, CI and
-- read-only release_postflight_read_only.sql have all been verified.
BEGIN;
DO $release_gate$
DECLARE rpc_ch integer; rpc_duel integer; protected_rpc integer; protected_tables integer;
        admin_challenge_edit boolean; expected_challenge_rpcs integer; expected_protected_rpc integer;
BEGIN
 SELECT count(*) FILTER(WHERE p.proname LIKE 'coach_challenge_v2_%'),
        count(*) FILTER(WHERE p.proname LIKE 'duel_v2_%'),
        count(*) FILTER(WHERE p.prosecdef AND
          pg_catalog.has_function_privilege('authenticated',p.oid,'EXECUTE')
          AND NOT pg_catalog.has_function_privilege('anon',p.oid,'EXECUTE'))
 INTO rpc_ch,rpc_duel,protected_rpc
 FROM pg_catalog.pg_proc p
 JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND
 (p.proname LIKE 'coach_challenge_v2_%' OR p.proname LIKE 'duel_v2_%');
 admin_challenge_edit := pg_catalog.to_regprocedure('public.coach_challenge_v2_admin_edit(uuid,text,text,text,integer,text,integer)') IS NOT NULL;
 expected_challenge_rpcs := 17 + CASE WHEN admin_challenge_edit THEN 1 ELSE 0 END;
 expected_protected_rpc := 23 + CASE WHEN admin_challenge_edit THEN 1 ELSE 0 END;
 IF rpc_ch<>expected_challenge_rpcs OR rpc_duel<>6 OR protected_rpc<>expected_protected_rpc
 THEN RAISE EXCEPTION 'V2 RPCs incomplete or insufficiently protected: %/%/%',
 rpc_ch,rpc_duel,protected_rpc; END IF;
 SELECT count(*) INTO protected_tables
 FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname='public' AND c.relrowsecurity AND c.relname IN
 ('league_coach_challenges','league_coach_challenge_entries','league_coach_challenge_reviews',
 'league_coach_challenge_exp_ledger','league_duels','league_duel_events','league_duel_exp_ledger')
 AND NOT pg_catalog.has_table_privilege('anon',c.oid,'SELECT')
 AND NOT pg_catalog.has_table_privilege('authenticated',c.oid,'SELECT')
 AND NOT pg_catalog.has_table_privilege('anon',c.oid,'INSERT')
 AND NOT pg_catalog.has_table_privilege('authenticated',c.oid,'INSERT')
 AND NOT pg_catalog.has_table_privilege('anon',c.oid,'UPDATE')
 AND NOT pg_catalog.has_table_privilege('authenticated',c.oid,'UPDATE')
 AND NOT pg_catalog.has_table_privilege('anon',c.oid,'DELETE')
 AND NOT pg_catalog.has_table_privilege('authenticated',c.oid,'DELETE');
 IF protected_tables<>7 THEN
  RAISE EXCEPTION 'Seven RLS-protected V2 tables required; found %',protected_tables;
 END IF;
 IF pg_catalog.has_function_privilege('anon',
    'public.recalculate_boxer_achievements_v2(uuid)','EXECUTE')
 OR pg_catalog.has_function_privilege('authenticated',
    'public.recalculate_boxer_achievements_v2(uuid)','EXECUTE')
 THEN RAISE EXCEPTION 'Achievement EXP security patch has not been applied'; END IF;
 IF (SELECT count(*) FROM public.league_feature_flags
 WHERE feature_key IN ('coach_challenges','duels') AND is_enabled IS FALSE)<>2
 THEN RAISE EXCEPTION 'Both V2 features must exist and be disabled before activation'; END IF;
 IF (SELECT count(*) FROM public.league_coach_challenge_exp_ledger l
 LEFT JOIN public.point_transactions t ON t.id=l.transaction_id
 WHERE t.id IS NULL OR t.category<>'challenge_exp' OR t.points<>0 OR
  t.exp<>l.awarded_exp OR t.boxer_id<>l.boxer_id)<>0
 THEN RAISE EXCEPTION 'Challenge payout corruption blocks activation'; END IF;
 IF (SELECT count(*) FROM public.league_duel_exp_ledger l
 LEFT JOIN public.point_transactions t ON t.id=l.transaction_id
 WHERE t.id IS NULL OR t.category<>'duel_exp' OR t.points<>0 OR
  t.exp<>l.awarded_exp OR t.boxer_id<>l.boxer_id)<>0
 THEN RAISE EXCEPTION 'Duel payout corruption blocks activation'; END IF;
END $release_gate$;
UPDATE public.league_feature_flags
SET is_enabled=true,updated_at=now()
WHERE feature_key IN ('coach_challenges','duels') AND is_enabled=false;
DO $postflight$
BEGIN
 IF (SELECT count(*) FROM public.league_feature_flags
 WHERE feature_key IN ('coach_challenges','duels') AND is_enabled)<>2
 THEN RAISE EXCEPTION 'V2 activation did not enable exactly two feature flags'; END IF;
END $postflight$;
COMMIT;
