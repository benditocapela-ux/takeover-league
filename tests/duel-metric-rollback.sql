\set ON_ERROR_STOP on
DO $$ BEGIN IF current_database() NOT LIKE 'league21_replay_%' THEN RAISE EXCEPTION 'Disposable database required'; END IF; END $$;
CREATE TEMP TABLE metric_rollback_witness AS SELECT jsonb_build_object(
 'duels',(SELECT jsonb_agg(to_jsonb(d) ORDER BY d.id) FROM public.league_duels d),
 'tx',(SELECT jsonb_agg(to_jsonb(t) ORDER BY t.id) FROM public.point_transactions t),
 'ledger',(SELECT jsonb_agg(to_jsonb(l) ORDER BY l.duel_id,l.boxer_id) FROM public.league_duel_exp_ledger l),
 'inbox',(SELECT jsonb_agg(to_jsonb(n) ORDER BY n.id) FROM public.boxer_notifications n)) value;
\i supabase/production-prep/rollback_20261102095422_duel_metric_contracts_disabled.sql
DO $$ BEGIN
 IF to_regprocedure('public.duel_v3_options()') IS NOT NULL THEN RAISE EXCEPTION 'Metric API remained after empty rollback'; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='public.league_duels'::regclass AND conname='duel_end_date'
  AND position('scoring_metric' IN pg_get_constraintdef(oid))=0) THEN RAISE EXCEPTION 'Legacy end rule was not restored'; END IF;
END $$;
\i supabase/migrations/20261102095422_duel_metric_contracts_disabled.sql
DO $$ BEGIN
 IF (SELECT value FROM metric_rollback_witness) IS DISTINCT FROM jsonb_build_object(
 'duels',(SELECT jsonb_agg(to_jsonb(d) ORDER BY d.id) FROM public.league_duels d),
 'tx',(SELECT jsonb_agg(to_jsonb(t) ORDER BY t.id) FROM public.point_transactions t),
 'ledger',(SELECT jsonb_agg(to_jsonb(l) ORDER BY l.duel_id,l.boxer_id) FROM public.league_duel_exp_ledger l),
 'inbox',(SELECT jsonb_agg(to_jsonb(n) ORDER BY n.id) FROM public.boxer_notifications n))
 THEN RAISE EXCEPTION 'Empty metric rollback/reapply changed existing game data'; END IF;
 IF (SELECT count(*) FROM league_v21_private.duel_metric_config WHERE NOT enabled AND reward_rule IS NULL AND jogging_training_type_id IS NULL)<>2
 THEN RAISE EXCEPTION 'Reapply unexpectedly activated/configured metrics'; END IF;
END $$;
DROP TABLE metric_rollback_witness;
\echo Empty metric rollback/reapply preserved all old game data and left new metrics disabled.
