-- Standalone disposable PostgreSQL security regression test.
-- Reproduces production SECURITY DEFINER trigger ownership, not production data.
\set ON_ERROR_STOP on
CREATE ROLE service_role NOLOGIN;
CREATE OR REPLACE FUNCTION public.recalculate_boxer_achievements_v2(p_boxer_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $func$
BEGIN
 UPDATE public.point_transactions SET exp=exp+25
 WHERE boxer_id=p_boxer_id AND description='Achievement permission fixture';
END $func$;
GRANT EXECUTE ON FUNCTION public.recalculate_boxer_achievements_v2(uuid) TO service_role;

CREATE OR REPLACE FUNCTION public._award_achievements_on_approval()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $func$
BEGIN
 IF NEW.status='approved' AND OLD.status<>'approved' THEN
  PERFORM public.recalculate_boxer_achievements_v2(NEW.boxer_id);
 END IF;
 RETURN NEW;
END $func$;
CREATE TRIGGER achievement_permission_fixture_trigger
AFTER UPDATE OF status ON public.training_submissions
FOR EACH ROW EXECUTE FUNCTION public._award_achievements_on_approval();

DO $preflight$
BEGIN
 IF NOT pg_catalog.has_function_privilege('anon','public.recalculate_boxer_achievements_v2(uuid)','EXECUTE')
 THEN RAISE EXCEPTION 'Fixture must begin with vulnerable anonymous RPC grant'; END IF;
END $preflight$;
INSERT INTO public.point_transactions(boxer_id,points,exp,category,description,effective_date)
VALUES('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',0,0,'training',
 'Achievement permission fixture',CURRENT_DATE);
INSERT INTO public.training_submissions
 (id,boxer_id,training_date,status)
VALUES('94000000-0000-4000-8000-000000000001',
 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',CURRENT_DATE,'pending');

\i supabase/production-prep/20261018_restrict_achievement_recalculation.sql

SET ROLE anon;
DO $anon$
DECLARE denied boolean:=false;
BEGIN
 BEGIN
  PERFORM public.recalculate_boxer_achievements_v2('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'::uuid);
 EXCEPTION WHEN insufficient_privilege THEN denied:=true;
 END;
 IF NOT denied THEN RAISE EXCEPTION 'Anonymous client can still mint Achievement EXP'; END IF;
END $anon$;
RESET ROLE;
SET ROLE authenticated;
DO $authenticated$
DECLARE denied boolean:=false;
BEGIN
 BEGIN
  PERFORM public.recalculate_boxer_achievements_v2('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'::uuid);
 EXCEPTION WHEN insufficient_privilege THEN denied:=true;
 END;
 IF NOT denied THEN RAISE EXCEPTION 'Signed-in client can still call achievement reconciliation'; END IF;
END $authenticated$;
RESET ROLE;

-- Owner-owned training approval must continue awarding legitimate achievement EXP.
UPDATE public.training_submissions SET status='approved'
WHERE id='94000000-0000-4000-8000-000000000001';
DO $postflight$
BEGIN
 IF (SELECT exp FROM public.point_transactions
 WHERE description='Achievement permission fixture')<>25
 THEN RAISE EXCEPTION 'Legitimate approval trigger lost achievement EXP'; END IF;
 IF NOT pg_catalog.has_function_privilege('service_role',
 'public.recalculate_boxer_achievements_v2(uuid)','EXECUTE')
 THEN RAISE EXCEPTION 'Service role cannot run trusted achievement reconciliation'; END IF;
 IF (SELECT count(*) FROM public.point_transactions WHERE description='Achievement permission fixture')<>1
 THEN RAISE EXCEPTION 'Achievement permission test made duplicate transaction'; END IF;
END $postflight$;
SELECT 'Achievement revoke / anon-auth denial / owner trigger / service execution passed' AS result;
