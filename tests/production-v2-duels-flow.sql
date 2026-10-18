-- Isolated PostgreSQL 16-only Duels V2 role, scoring, and EXP tests.
-- Never execute on a production Supabase database.
DO $rights$
DECLARE sig text;
BEGIN
 FOREACH sig IN ARRAY ARRAY[
 'duel_v2_eligible_boxers()','duel_v2_invite(uuid,uuid,integer)',
 'duel_v2_list_mine()','duel_v2_reconcile(uuid)',
 'duel_v2_reconcile_due(boolean,uuid)','duel_v2_respond(uuid,boolean)'] LOOP
 IF pg_catalog.has_function_privilege('anon','public.'||sig,'EXECUTE')
 OR NOT pg_catalog.has_function_privilege('authenticated','public.'||sig,'EXECUTE')
 THEN RAISE EXCEPTION 'Invalid Duels V2 RPC privilege for %',sig; END IF;
 END LOOP;
END $rights$;
SET ROLE authenticated;
SET request.jwt.claim.sub='11111111-1111-4111-8111-111111111111';
DO $disabled$
DECLARE blocked boolean:=false;
BEGIN
 BEGIN PERFORM public.duel_v2_eligible_boxers(); EXCEPTION WHEN OTHERS THEN blocked:=true; END;
 IF NOT blocked THEN RAISE EXCEPTION 'Disabled feature was accessible'; END IF;
END $disabled$;
RESET ROLE;
UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='duels';

-- Boxer A initiates a 7-day duel against E; cannot challenge on E's behalf.
SET ROLE authenticated;
SET request.jwt.claim.sub='11111111-1111-4111-8111-111111111111';
DO $invite$
DECLARE created uuid; rejected boolean:=false;
BEGIN
 IF (SELECT count(*) FROM public.duel_v2_eligible_boxers())<>2
 THEN RAISE EXCEPTION 'Eligible boxer list missing active boxers'; END IF;
 BEGIN
  PERFORM public.duel_v2_invite('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
   'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',7);
 EXCEPTION WHEN OTHERS THEN rejected:=true; END;
 IF NOT rejected THEN RAISE EXCEPTION 'Boxer impersonated another challenger'; END IF;
 created:=public.duel_v2_invite('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',7);
 IF created IS NULL THEN RAISE EXCEPTION 'No duel id returned'; END IF;
 PERFORM pg_catalog.set_config('test.duel_id',created::text,false);
 IF (SELECT count(*) FROM public.duel_v2_list_mine() WHERE id=created)<>1
 THEN RAISE EXCEPTION 'New duel not visible to challenger'; END IF;
 rejected:=false;
 BEGIN
  PERFORM public.duel_v2_invite('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',7);
 EXCEPTION WHEN OTHERS THEN rejected:=true; END;
 IF NOT rejected THEN RAISE EXCEPTION 'Duplicate pending duel created'; END IF;
END $invite$;
RESET ROLE;

-- Boxer E accepts; boxer A cannot accept an invitation addressed to E.
SET ROLE authenticated;
SET request.jwt.claim.sub='11111111-1111-4111-8111-111111111111';
DO $wrongRecipient$
DECLARE rejected boolean:=false;
BEGIN
 BEGIN PERFORM public.duel_v2_respond(current_setting('test.duel_id')::uuid,true);
 EXCEPTION WHEN OTHERS THEN rejected:=true; END;
 IF NOT rejected THEN RAISE EXCEPTION 'Challenger accepted own duel'; END IF;
END $wrongRecipient$;
RESET ROLE;
SET ROLE authenticated;
SET request.jwt.claim.sub='55555555-5555-4555-8555-555555555555';
DO $accept$
BEGIN
 IF public.duel_v2_respond(current_setting('test.duel_id')::uuid,true) IS NULL
 THEN RAISE EXCEPTION 'Opponent acceptance returned null'; END IF;
 IF (SELECT count(*) FROM public.duel_v2_list_mine() WHERE status='active')<>1
 THEN RAISE EXCEPTION 'Accepted duel not active'; END IF;
END $accept$;
RESET ROLE;

-- Advance time inside this throwaway fixture; no production data is altered.
UPDATE public.league_duels
SET accepted_at=now()-INTERVAL '8 days',
    ends_at=now()-INTERVAL '8 days'+INTERVAL '7 days'
WHERE id=current_setting('test.duel_id')::uuid;
INSERT INTO public.training_submissions(id,boxer_id,training_date,status,created_at)
VALUES
 ('11111111-aaaa-4111-8111-111111111111','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
 (now()-INTERVAL '3 days')::date,'approved',now()-INTERVAL '3 days'),
 ('22222222-bbbb-4222-8222-222222222222','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
 (now()-INTERVAL '3 days')::date,'approved',now()-INTERVAL '3 days'),
 ('33333333-cccc-4333-8333-333333333333','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
 (now()-INTERVAL '2 days')::date,'pending',now()-INTERVAL '2 days');
INSERT INTO public.point_transactions(submission_id,boxer_id,points,exp,category,description,effective_date)
VALUES
 ('11111111-aaaa-4111-8111-111111111111','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
 70,70,'training','Duel test A',(now()-INTERVAL '3 days')::date),
 ('22222222-bbbb-4222-8222-222222222222','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
 40,40,'training','Duel test E',(now()-INTERVAL '3 days')::date);

SET ROLE authenticated;
SET request.jwt.claim.sub='22222222-2222-4222-8222-222222222222';
DO $pending$
DECLARE outcome text;
BEGIN
 outcome:=public.duel_v2_reconcile(current_setting('test.duel_id')::uuid);
 IF outcome<>'awaiting_reviews' THEN
 RAISE EXCEPTION 'Pending training did not delay settlement: %',outcome; END IF;
END $pending$;
RESET ROLE;
UPDATE public.training_submissions SET status='rejected'
WHERE id='33333333-cccc-4333-8333-333333333333';

SET ROLE authenticated;
SET request.jwt.claim.sub='22222222-2222-4222-8222-222222222222';
DO $settle$
DECLARE outcome text;
BEGIN
 outcome:=public.duel_v2_reconcile(current_setting('test.duel_id')::uuid);
 IF outcome<>'settled' THEN RAISE EXCEPTION 'Duel not settled: %',outcome; END IF;
 outcome:=public.duel_v2_reconcile(current_setting('test.duel_id')::uuid);
 IF outcome NOT IN ('settled','unchanged') THEN RAISE EXCEPTION 'Idempotent duel reconcile failed: %',outcome; END IF;
END $settle$;
RESET ROLE;

DO $verify$
DECLARE duel uuid:=current_setting('test.duel_id')::uuid;
BEGIN
 IF (SELECT challenger_score FROM public.league_duels WHERE id=duel)<>70
 OR (SELECT opponent_score FROM public.league_duels WHERE id=duel)<>40
 OR (SELECT winner_id FROM public.league_duels WHERE id=duel)
    <>'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'::uuid
 THEN RAISE EXCEPTION 'Duel score or winner incorrect'; END IF;
 IF (SELECT count(*) FROM public.league_duel_exp_ledger WHERE duel_id=duel)<>2
 THEN RAISE EXCEPTION 'Missing or duplicated boxer EXP ledger'; END IF;
 IF (SELECT awarded_exp FROM public.league_duel_exp_ledger
 WHERE duel_id=duel AND boxer_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')<>100
 OR (SELECT awarded_exp FROM public.league_duel_exp_ledger
 WHERE duel_id=duel AND boxer_id='eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee')<>25
 THEN RAISE EXCEPTION 'Incorrect winner/loser EXP'; END IF;
 IF (SELECT count(*) FROM public.point_transactions
 WHERE category='duel_exp' AND description='Duel reward: '||duel::text)<>2
 THEN RAISE EXCEPTION 'Duplicate or missing EXP payout transactions'; END IF;
END $verify$;

-- Clear all duel test records, including their training and payout fixtures.
DELETE FROM public.league_duel_exp_ledger;
DELETE FROM public.league_duel_events;
DELETE FROM public.league_duels;
DELETE FROM public.point_transactions
 WHERE description LIKE 'Duel reward:%' OR description IN ('Duel test A','Duel test E');
DELETE FROM public.training_submissions;
UPDATE public.league_feature_flags SET is_enabled=false WHERE feature_key='duels';
SELECT 'Duel V2 role, settlement and EXP tests passed' AS result;
