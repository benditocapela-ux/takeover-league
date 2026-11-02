\set ON_ERROR_STOP on
DO $$ BEGIN
 IF current_database() NOT LIKE 'league21_replay_%' THEN RAISE EXCEPTION 'Disposable database required'; END IF;
END $$;
CREATE TEMP TABLE duel_preview_rollback_witness AS
SELECT jsonb_build_object(
 'duels',(SELECT jsonb_agg(to_jsonb(d) ORDER BY d.id) FROM public.league_duels d),
 'tx',(SELECT jsonb_agg(to_jsonb(t) ORDER BY t.id) FROM public.point_transactions t),
 'ledger',(SELECT jsonb_agg(to_jsonb(l) ORDER BY l.duel_id,l.boxer_id) FROM public.league_duel_exp_ledger l),
 'events',(SELECT jsonb_agg(to_jsonb(e) ORDER BY e.id) FROM public.league_duel_events e),
 'inbox',(SELECT jsonb_agg(to_jsonb(n) ORDER BY n.id) FROM public.boxer_notifications n)) value;
\i supabase/production-prep/rollback_20261102084519_duel_points_shared_preview_close.sql
DO $$ BEGIN
 IF to_regprocedure('public.duel_v2_close_preview(uuid)') IS NOT NULL
 OR to_regprocedure('public.duel_v2_close_confirm(uuid,boolean,text)') IS NOT NULL
 THEN RAISE EXCEPTION 'Rollback left new public APIs'; END IF;
 IF position('duel_points_snapshot' IN pg_get_functiondef('league_v21_private.duel_reconcile_ranked_core(uuid)'::regprocedure))>0
 THEN RAISE EXCEPTION 'Rollback did not restore existing reconciler'; END IF;
END $$;
\i supabase/migrations/20261102084519_duel_points_shared_preview_close.sql
DO $$ BEGIN
 IF (SELECT value FROM duel_preview_rollback_witness) IS DISTINCT FROM jsonb_build_object(
 'duels',(SELECT jsonb_agg(to_jsonb(d) ORDER BY d.id) FROM public.league_duels d),
 'tx',(SELECT jsonb_agg(to_jsonb(t) ORDER BY t.id) FROM public.point_transactions t),
 'ledger',(SELECT jsonb_agg(to_jsonb(l) ORDER BY l.duel_id,l.boxer_id) FROM public.league_duel_exp_ledger l),
 'events',(SELECT jsonb_agg(to_jsonb(e) ORDER BY e.id) FROM public.league_duel_events e),
 'inbox',(SELECT jsonb_agg(to_jsonb(n) ORDER BY n.id) FROM public.boxer_notifications n))
 THEN RAISE EXCEPTION 'Rollback/reapply changed game data'; END IF;
 IF NOT has_function_privilege('authenticated','public.duel_v2_close_preview(uuid)','EXECUTE')
 OR has_function_privilege('anon','public.duel_v2_close_preview(uuid)','EXECUTE')
 THEN RAISE EXCEPTION 'Reapply changed API permissions'; END IF;
END $$;
DROP TABLE duel_preview_rollback_witness;
\echo Duel preview rollback/reapply preserved all fixture game data.
