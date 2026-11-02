\set ON_ERROR_STOP on
DO $$ BEGIN IF current_database() NOT LIKE 'league21_replay_%' THEN RAISE EXCEPTION 'Disposable database required'; END IF; END $$;
CREATE TEMP TABLE queue_rollback_witness AS SELECT jsonb_build_object(
 'duels',(SELECT jsonb_agg(to_jsonb(d) ORDER BY id) FROM public.league_duels d),
 'tx',(SELECT jsonb_agg(to_jsonb(t) ORDER BY id) FROM public.point_transactions t),
 'ledger',(SELECT jsonb_agg(to_jsonb(l) ORDER BY duel_id,boxer_id) FROM public.league_duel_exp_ledger l),
 'events',(SELECT count(*) FROM public.league_duel_events),
 'inbox',(SELECT count(*) FROM public.boxer_notifications),
 'scorer',pg_get_functiondef('league_v21_private.duel_reconcile_ranked_core(uuid)'::regprocedure)) value;
\i supabase/production-prep/rollback_20261102095352_duel_staff_queue_readonly.sql
DO $$ BEGIN IF to_regprocedure('public.duel_v2_staff_queue(text,integer,timestamptz,uuid,text,uuid)') IS NOT NULL
 OR to_regprocedure('league_v21_private.duel_staff_queue_core(text,integer,timestamptz,uuid,text,uuid)') IS NOT NULL
 OR to_regclass('public.league_duels_staff_cursor_idx') IS NOT NULL THEN RAISE EXCEPTION 'Queue rollback incomplete'; END IF; END $$;
\i supabase/migrations/20261102095352_duel_staff_queue_readonly.sql
DO $$ BEGIN IF (SELECT value FROM queue_rollback_witness) IS DISTINCT FROM jsonb_build_object(
 'duels',(SELECT jsonb_agg(to_jsonb(d) ORDER BY id) FROM public.league_duels d),
 'tx',(SELECT jsonb_agg(to_jsonb(t) ORDER BY id) FROM public.point_transactions t),
 'ledger',(SELECT jsonb_agg(to_jsonb(l) ORDER BY duel_id,boxer_id) FROM public.league_duel_exp_ledger l),
 'events',(SELECT count(*) FROM public.league_duel_events),
 'inbox',(SELECT count(*) FROM public.boxer_notifications),
 'scorer',pg_get_functiondef('league_v21_private.duel_reconcile_ranked_core(uuid)'::regprocedure))
 THEN RAISE EXCEPTION 'Queue rollback/reapply changed game state or scorer'; END IF;
 IF has_function_privilege('anon','public.duel_v2_staff_queue(text,integer,timestamptz,uuid,text,uuid)','EXECUTE')
 OR NOT has_function_privilege('authenticated','public.duel_v2_staff_queue(text,integer,timestamptz,uuid,text,uuid)','EXECUTE') THEN RAISE EXCEPTION 'Queue reapply grants invalid'; END IF; END $$;
DROP TABLE queue_rollback_witness;
\echo Staff queue rollback/reapply preserved game state and existing scorer.
