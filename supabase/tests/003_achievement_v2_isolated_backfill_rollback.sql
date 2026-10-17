-- ISOLATED DATABASE ONLY. NEVER RUN ON LIVE SUPABASE.
-- Requires a disposable database cloned from the pre-activation state,
-- with migration 002 AND the reviewed migration 006 installed.
-- This script deliberately enables the feature flag and writes EXP
-- inside a transaction, then ROLLBACK. A crash can leave the session
-- transaction open; use a disposable database only.
BEGIN;
SET LOCAL statement_timeout = '30s';
SET LOCAL lock_timeout = '5s';

DO $check$
DECLARE
 v_flag_count integer;
 v_royce uuid;
 v_baseline integer;
 v_awards integer;
 v_exp integer;
 v_events integer;
 v_after integer;
 v_bad integer;
BEGIN
 SELECT count(*) INTO v_flag_count FROM public.league_feature_flags
 WHERE feature_key='achievements' AND is_enabled=false;
 IF v_flag_count<>1 THEN
  RAISE EXCEPTION 'Fixture invalid: achievements flag must be false';
 END IF;

 SELECT count(*) INTO v_bad FROM public.achievement_exp_ledger;
 IF v_bad<>0 THEN RAISE EXCEPTION 'Fixture invalid: ledger not empty'; END IF;
 SELECT count(*) INTO v_bad FROM public.point_transactions WHERE category='achievement_exp';
 IF v_bad<>0 THEN RAISE EXCEPTION 'Fixture invalid: achievement EXP transactions exist'; END IF;

 SELECT count(*) INTO v_bad FROM public.achievement_v2_rules;
 IF v_bad<>32 THEN RAISE EXCEPTION 'Expected 32 strict rules; found %',v_bad; END IF;

 SELECT id INTO STRICT v_royce FROM public.profiles
 WHERE display_name ILIKE 'Royce%' AND role='boxer' AND is_active=true;

 SELECT coalesce(sum(exp),0)::integer INTO v_baseline
 FROM public.point_transactions WHERE boxer_id=v_royce;

 UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='achievements';

 -- Backfill each active boxer using internal helper as database owner.
 PERFORM public.recalculate_boxer_achievements_v2(p.id)
 FROM public.profiles p WHERE p.role='boxer' AND p.is_active=true ORDER BY p.id;

 SELECT count(*),coalesce(sum(exp_amount),0)::integer
 INTO v_awards,v_exp FROM public.achievement_exp_ledger WHERE is_earned=true;
 IF v_awards<>1 OR v_exp<>25 THEN
  RAISE EXCEPTION 'Backfill mismatch: awards %, EXP % (expected 1/25)',v_awards,v_exp;
 END IF;

 SELECT count(*) INTO v_bad FROM public.achievement_exp_ledger l
 JOIN public.achievement_definitions d ON d.id=l.achievement_id
 WHERE l.is_earned AND (l.boxer_id<>v_royce OR d.code<>'training_10');
 IF v_bad<>0 THEN RAISE EXCEPTION 'Unexpected boxer or achievement awarded'; END IF;

 SELECT coalesce(sum(exp),0)::integer INTO v_after
 FROM public.point_transactions WHERE boxer_id=v_royce;
 IF v_after<>v_baseline+25 THEN
  RAISE EXCEPTION 'Royce EXP mismatch: before %, after %',v_baseline,v_after;
 END IF;

 SELECT count(*) INTO v_bad FROM public.point_transactions
 WHERE category='achievement_exp' AND (points<>0 OR exp<>25);
 IF v_bad<>0 THEN RAISE EXCEPTION 'Incorrect achievement transaction points/EXP'; END IF;

 SELECT count(*) INTO v_events FROM public.achievement_exp_events;
 IF v_events<>1 THEN RAISE EXCEPTION 'Expected 1 earned event, got %',v_events; END IF;

 -- Idempotence: a second reconciliation must not create more events or EXP.
 PERFORM public.recalculate_boxer_achievements_v2(p.id)
 FROM public.profiles p WHERE p.role='boxer' AND p.is_active=true ORDER BY p.id;
 SELECT count(*) INTO v_bad FROM public.achievement_exp_events;
 IF v_bad<>1 THEN RAISE EXCEPTION 'Duplicate event on second pass'; END IF;
 SELECT count(*) INTO v_bad FROM public.point_transactions WHERE category='achievement_exp';
 IF v_bad<>1 THEN RAISE EXCEPTION 'Duplicate EXP transaction on second pass'; END IF;

 RAISE NOTICE 'PASS: 32 rules, Royce +25 EXP, zero points, one event, idempotent';
END
$check$;

ROLLBACK;
-- EXPECTED: NOTICE PASS, then ROLLBACK. No changes persist.
