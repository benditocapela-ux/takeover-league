-- Disposable CI PostgreSQL ONLY. Exercise the actual settlement RPC and ledger.
BEGIN;
INSERT INTO public.profiles(id,auth_user_id,role,is_active) VALUES
 ('00000000-0000-0000-0000-0000000000a1','10000000-0000-0000-0000-0000000000a1','boxer',true),
 ('00000000-0000-0000-0000-0000000000b2','10000000-0000-0000-0000-0000000000b2','boxer',true),
 ('00000000-0000-0000-0000-0000000000c3','10000000-0000-0000-0000-0000000000c3','coach',true);
UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='duels';
DO $test$
DECLARE
 a uuid := '00000000-0000-0000-0000-0000000000a1';
 b uuid := '00000000-0000-0000-0000-0000000000b2';
 coach uuid := '00000000-0000-0000-0000-0000000000c3';
 duel uuid;
 result text;
BEGIN
 PERFORM set_config('test.auth_uid','10000000-0000-0000-0000-0000000000a1',true);
 duel:=public.duel_v2_invite(a,b,7);
 PERFORM set_config('test.auth_uid','10000000-0000-0000-0000-0000000000b2',true);
 result:=public.duel_v2_respond(duel,true);
 IF result<>'active' THEN RAISE EXCEPTION 'Duel not activated'; END IF;
 UPDATE public.league_duels SET accepted_at=now()-interval '8 days',
   ends_at=now()-interval '1 day' WHERE id=duel;
 INSERT INTO public.training_submissions(id,boxer_id,training_date,status,created_at)
 VALUES ('20000000-0000-0000-0000-000000000001',a,current_date-interval '3 days','approved',now()-interval '3 days');
 INSERT INTO public.point_transactions(id,boxer_id,submission_id,points,exp,category,description,effective_date,created_by)
 VALUES ('30000000-0000-0000-0000-000000000001',a,
         '20000000-0000-0000-0000-000000000001',50,50,'training','Training',current_date-3,coach);
 PERFORM set_config('test.auth_uid','10000000-0000-0000-0000-0000000000c3',true);
 -- Timely pending training blocks first payout, without minting EXP.
 INSERT INTO public.training_submissions(id,boxer_id,training_date,status,created_at)
 VALUES ('20000000-0000-0000-0000-000000000003',b,current_date-interval '3 days','pending',now()-interval '3 days');
 result:=public.duel_v2_reconcile(duel);
 IF result<>'awaiting_reviews' OR
    (SELECT status FROM public.league_duels WHERE id=duel)<>'awaiting_reviews' OR
    (SELECT count(*) FROM public.point_transactions WHERE category='duel_exp')<>0 THEN
  RAISE EXCEPTION 'Pending review must block settlement and EXP payout';
 END IF;
 -- Repeated attempts must remain blocked and not duplicate awaiting events.
 result:=public.duel_v2_reconcile(duel);
 IF result<>'awaiting_reviews' OR
    (SELECT count(*) FROM public.league_duel_events
     WHERE duel_id=duel AND event_type='awaiting_reviews')<>1 THEN
  RAISE EXCEPTION 'Pending review retries must be idempotent';
 END IF;
 UPDATE public.training_submissions SET status='rejected'
 WHERE id='20000000-0000-0000-0000-000000000003';
 result:=public.duel_v2_reconcile(duel);
 IF result<>'settled' THEN RAISE EXCEPTION 'Expected settled, got %',result; END IF;
 IF (SELECT count(*) FROM public.league_duel_exp_ledger WHERE duel_id=duel AND transaction_id IS NOT NULL)<>2 THEN
  RAISE EXCEPTION 'Expected exactly two payout ledger entries';
 END IF;
 IF (SELECT sum(t.exp) FROM public.point_transactions t JOIN public.league_duel_exp_ledger l
     ON l.transaction_id=t.id WHERE l.duel_id=duel)<>125 THEN
  RAISE EXCEPTION 'Expected 100 winner EXP and 25 loser EXP';
 END IF;
 IF (SELECT count(*) FROM public.point_transactions t JOIN public.league_duel_exp_ledger l
     ON l.transaction_id=t.id WHERE l.duel_id=duel AND t.points<>0)<>0 THEN
  RAISE EXCEPTION 'Duel reward incorrectly awarded league points';
 END IF;
 result:=public.duel_v2_reconcile(duel);
 IF result<>'settled' OR (SELECT count(*) FROM public.point_transactions WHERE category='duel_exp')<>2 THEN
  RAISE EXCEPTION 'Repeated reconciliation created duplicate payouts';
 END IF;
 -- A newly discovered timely pending submission after payout must preserve the ledger.
 INSERT INTO public.training_submissions(id,boxer_id,training_date,status,created_at)
 VALUES ('20000000-0000-0000-0000-000000000004',b,current_date-interval '3 days','pending',now()-interval '3 days');
 result:=public.duel_v2_reconcile(duel);
 IF result<>'pending_correction' OR
    (SELECT status FROM public.league_duels WHERE id=duel)<>'settled' OR
    (SELECT count(*) FROM public.point_transactions WHERE category='duel_exp')<>2 OR
    (SELECT sum(awarded_exp) FROM public.league_duel_exp_ledger WHERE duel_id=duel)<>125 THEN
  RAISE EXCEPTION 'Pending post-settlement review must preserve prior payout';
 END IF;
 UPDATE public.training_submissions SET status='rejected'
 WHERE id='20000000-0000-0000-0000-000000000004';
 result:=public.duel_v2_reconcile(duel);
 IF result<>'settled' OR
    (SELECT count(*) FROM public.point_transactions WHERE category='duel_exp')<>2 THEN
  RAISE EXCEPTION 'Post-settlement review resolution must remain idempotent';
 END IF;
 -- A reviewed training correction reverses the winner without minting new rewards.
 INSERT INTO public.training_submissions(id,boxer_id,training_date,status,created_at)
 VALUES ('20000000-0000-0000-0000-000000000002',b,current_date-interval '3 days','approved',now()-interval '3 days');
 INSERT INTO public.point_transactions(id,boxer_id,submission_id,points,exp,category,description,effective_date,created_by)
 VALUES ('30000000-0000-0000-0000-000000000002',b,
         '20000000-0000-0000-0000-000000000002',70,70,'training','Corrected training',current_date-3,coach);
 result:=public.duel_v2_reconcile(duel);
 IF result<>'settled' THEN RAISE EXCEPTION 'Correction reconciliation failed'; END IF;
 IF (SELECT winner_id FROM public.league_duels WHERE id=duel)<>b THEN
  RAISE EXCEPTION 'Correction did not reverse winner';
 END IF;
 IF (SELECT awarded_exp FROM public.league_duel_exp_ledger WHERE duel_id=duel AND boxer_id=a)<>25
    OR (SELECT awarded_exp FROM public.league_duel_exp_ledger WHERE duel_id=duel AND boxer_id=b)<>100 THEN
  RAISE EXCEPTION 'Corrected EXP distribution is wrong';
 END IF;
 IF (SELECT count(*) FROM public.point_transactions WHERE category='duel_exp')<>2 THEN
  RAISE EXCEPTION 'Correction minted duplicate EXP transactions';
 END IF;
 IF (SELECT count(*) FROM public.league_duel_events WHERE duel_id=duel AND event_type='corrected')<>1 THEN
  RAISE EXCEPTION 'Correction audit event missing';
 END IF;
 -- A subsequent score tie should update existing transactions to 50 EXP each.
 UPDATE public.point_transactions SET points=50
 WHERE id='30000000-0000-0000-0000-000000000002';
 result:=public.duel_v2_reconcile(duel);
 IF result<>'settled' OR
    (SELECT winner_id FROM public.league_duels WHERE id=duel) IS NOT NULL THEN
  RAISE EXCEPTION 'Corrected tie did not settle';
 END IF;
 IF (SELECT count(*) FROM public.league_duel_exp_ledger
     WHERE duel_id=duel AND awarded_exp=50)<>2 THEN
  RAISE EXCEPTION 'Tie EXP correction failed';
 END IF;
 IF (SELECT count(*) FROM public.point_transactions WHERE category='duel_exp')<>2 THEN
  RAISE EXCEPTION 'Tie correction minted duplicate rewards';
 END IF;
END $test$;
ROLLBACK;
