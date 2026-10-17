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
 -- Cross-profile references in legacy transaction data must not affect scores.
 INSERT INTO public.training_submissions(id,boxer_id,training_date,status,created_at)
 VALUES ('20000000-0000-0000-0000-000000000007',a,current_date-3,'approved',now()-interval '3 days');
 INSERT INTO public.point_transactions(id,boxer_id,submission_id,points,exp,category,description,effective_date,created_by)
 VALUES ('30000000-0000-0000-0000-000000000007',b,
         '20000000-0000-0000-0000-000000000007',90,90,'training','Legacy mismatch',current_date-3,coach);
 -- Boxers must never invoke coach-only settlement or batch reconciliation.
 BEGIN
  PERFORM public.duel_v2_reconcile(duel);
  RAISE EXCEPTION 'Boxer bypassed coach-only settlement';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Boxer bypassed coach-only settlement' THEN RAISE; END IF;
 END;
 BEGIN
  PERFORM public.duel_v2_reconcile_due();
  RAISE EXCEPTION 'Boxer bypassed coach-only batch settlement';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Boxer bypassed coach-only batch settlement' THEN RAISE; END IF;
 END;
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
 -- Duplicate training awards must fail before issuing either EXP payout.
 INSERT INTO public.point_transactions(id,boxer_id,submission_id,points,exp,category,description,effective_date,created_by)
 VALUES ('30000000-0000-0000-0000-000000000008',a,
         '20000000-0000-0000-0000-000000000001',50,50,'training',
         'Duplicate legacy award',current_date-3,coach);
 BEGIN
  PERFORM public.duel_v2_reconcile(duel);
  RAISE EXCEPTION 'Duplicate training award was counted';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Duplicate training award was counted' THEN RAISE; END IF;
  IF SQLERRM NOT LIKE 'Duplicate duel scoring transactions%' THEN
   RAISE EXCEPTION 'Unexpected duplicate award error: %',SQLERRM;
  END IF;
 END;
 IF (SELECT count(*) FROM public.point_transactions WHERE category='duel_exp')<>0 THEN
  RAISE EXCEPTION 'Duplicate scoring minted EXP despite rejection';
 END IF;
 -- A legacy-import duplicate must be rejected by the same guard.
 UPDATE public.point_transactions SET category='legacy_import'
 WHERE id='30000000-0000-0000-0000-000000000008';
 BEGIN
  PERFORM public.duel_v2_reconcile(duel);
  RAISE EXCEPTION 'Legacy duplicate training award was counted';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Legacy duplicate training award was counted' THEN RAISE; END IF;
  IF SQLERRM NOT LIKE 'Duplicate duel scoring transactions%' THEN
   RAISE EXCEPTION 'Unexpected legacy duplicate error: %',SQLERRM;
  END IF;
 END;
 IF (SELECT count(*) FROM public.point_transactions WHERE category='duel_exp')<>0 THEN
  RAISE EXCEPTION 'Legacy duplicate scoring minted EXP';
 END IF;
 DELETE FROM public.point_transactions WHERE id='30000000-0000-0000-0000-000000000008';
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
 -- A late-created backdated submission must not change a finished duel.
 INSERT INTO public.training_submissions(id,boxer_id,training_date,status,created_at)
 VALUES ('20000000-0000-0000-0000-000000000005',b,
         current_date-interval '3 days','approved',now());
 INSERT INTO public.point_transactions(id,boxer_id,submission_id,points,exp,category,description,effective_date,created_by)
 VALUES ('30000000-0000-0000-0000-000000000005',b,
         '20000000-0000-0000-0000-000000000005',500,500,'training','Late entry',current_date-3,coach);
 result:=public.duel_v2_reconcile(duel);
 IF result<>'settled' OR
    (SELECT winner_id FROM public.league_duels WHERE id=duel) IS NOT NULL
    OR (SELECT count(*) FROM public.league_duel_exp_ledger
        WHERE duel_id=duel AND awarded_exp=50)<>2 THEN
  RAISE EXCEPTION 'Late-created backdated submission changed completed duel';
 END IF;
 -- A late-created pending submission must not hold or reopen settlement.
 INSERT INTO public.training_submissions(id,boxer_id,training_date,status,created_at)
 VALUES ('20000000-0000-0000-0000-000000000006',a,
         current_date-interval '3 days','pending',now());
 result:=public.duel_v2_reconcile(duel);
 IF result<>'settled' OR
    (SELECT status FROM public.league_duels WHERE id=duel)<>'settled' THEN
  RAISE EXCEPTION 'Late-created pending submission reopened completed duel';
 END IF;
 -- A disabled feature flag must block coach settlement without altering rewards.
 UPDATE public.league_feature_flags SET is_enabled=false WHERE feature_key='duels';
 BEGIN
  PERFORM public.duel_v2_reconcile(duel);
  RAISE EXCEPTION 'Disabled duels feature allowed reconciliation';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Disabled duels feature allowed reconciliation' THEN RAISE; END IF;
  IF SQLERRM NOT LIKE 'Duels are not enabled%' THEN
   RAISE EXCEPTION 'Unexpected disabled-feature failure: %',SQLERRM;
  END IF;
 END;
 UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='duels';
 IF (SELECT count(*) FROM public.point_transactions WHERE category='duel_exp')<>2 THEN
  RAISE EXCEPTION 'Feature toggle altered reward transactions';
 END IF;
 -- Corrupt a paid transaction and ensure reconciliation fails closed.
 UPDATE public.point_transactions SET exp=999
 WHERE id=(SELECT transaction_id FROM public.league_duel_exp_ledger
           WHERE duel_id=duel AND boxer_id=a);
 BEGIN
  PERFORM public.duel_v2_reconcile(duel);
  RAISE EXCEPTION 'Tampered payout was silently accepted';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Tampered payout was silently accepted' THEN RAISE; END IF;
  IF SQLERRM NOT LIKE 'Duel reward ledger mismatch%' THEN
   RAISE EXCEPTION 'Unexpected tampered payout failure: %',SQLERRM;
  END IF;
 END;
 IF (SELECT count(*) FROM public.point_transactions WHERE category='duel_exp')<>2 THEN
  RAISE EXCEPTION 'Tampered payout triggered duplicate reward';
 END IF;
END $test$;
ROLLBACK;
