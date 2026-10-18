-- SECURITY RELEASE GATE: achievement EXP recalculation must not be public.
-- PREPARED ONLY. Requires separate explicit approval before production execution.
-- The postgres-owned SECURITY DEFINER approval trigger keeps owner execute privileges.
BEGIN;
DO $preflight$
DECLARE fn oid; trigger_fn oid;
BEGIN
 fn:=pg_catalog.to_regprocedure('public.recalculate_boxer_achievements_v2(uuid)');
 trigger_fn:=pg_catalog.to_regprocedure('public._award_achievements_on_approval()');
 IF fn IS NULL OR trigger_fn IS NULL
 THEN RAISE EXCEPTION 'Missing achievement recalculation function or approval trigger; abort'; END IF;
 IF NOT EXISTS(
 SELECT 1 FROM pg_catalog.pg_proc p WHERE p.oid=fn
 AND p.proowner='postgres'::regrole AND p.prosecdef
 ) OR NOT EXISTS(
 SELECT 1 FROM pg_catalog.pg_proc p WHERE p.oid=trigger_fn
 AND p.proowner='postgres'::regrole AND p.prosecdef
 ) THEN RAISE EXCEPTION 'Achievement function ownership or SECURITY DEFINER differs; abort'; END IF;
 IF NOT EXISTS(
 SELECT 1 FROM pg_catalog.pg_trigger t WHERE t.tgfoid=trigger_fn
 AND t.tgrelid='public.training_submissions'::regclass AND NOT t.tgisinternal
 ) THEN RAISE EXCEPTION 'Approval trigger missing from training_submissions; abort'; END IF;
END $preflight$;
REVOKE EXECUTE ON FUNCTION public.recalculate_boxer_achievements_v2(uuid)
 FROM PUBLIC, anon, authenticated;
DO $postflight$
DECLARE fn oid:=pg_catalog.to_regprocedure('public.recalculate_boxer_achievements_v2(uuid)');
BEGIN
 IF pg_catalog.has_function_privilege('anon',fn,'EXECUTE')
 OR pg_catalog.has_function_privilege('authenticated',fn,'EXECUTE')
 OR NOT pg_catalog.has_function_privilege('postgres',fn,'EXECUTE')
 OR NOT pg_catalog.has_function_privilege('service_role',fn,'EXECUTE')
 THEN RAISE EXCEPTION 'Achievement EXECUTE privileges incorrect after revoke'; END IF;
END $postflight$;
COMMIT;
-- After explicit release approval, test direct anonymous/authenticated RPC denial
-- and legitimate training approval (plus achievement EXP and audit effects).
