-- Disposable PostgreSQL only. Settlement pays once after complete reviews.
BEGIN;
INSERT INTO public.profiles(id,auth_user_id,display_name,role,is_active) VALUES
('e0000000-0000-0000-0000-000000000041','e1000000-0000-0000-0000-000000000041','Settlement coach','coach',true),
('e0000000-0000-0000-0000-000000000042','e1000000-0000-0000-0000-000000000042','Approved boxer','boxer',true),
('e0000000-0000-0000-0000-000000000043','e1000000-0000-0000-0000-000000000043','Rejected boxer','boxer',true);
UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='coach_challenges';
DO $test$
DECLARE cid uuid; v_count integer;
BEGIN
 PERFORM set_config('test.auth_uid','e1000000-0000-0000-0000-000000000041',true);
 cid:=public.coach_challenge_v2_create_draft('Settlement smoke','','coach_goal',7);
 PERFORM public.coach_challenge_v2_save_goal_reward(cid,'Practice controlled sparring','manual',150);
 UPDATE public.league_coach_challenges SET status='awaiting_reviews',
 starts_at=pg_catalog.clock_timestamp()-interval '8 days',
 ends_at=pg_catalog.clock_timestamp()-interval '1 day' WHERE id=cid;
 INSERT INTO public.league_coach_challenge_entries(challenge_id,boxer_id)
 VALUES(cid,'e0000000-0000-0000-0000-000000000042'),
 (cid,'e0000000-0000-0000-0000-000000000043');
 PERFORM public.coach_challenge_v2_review_manual(
 cid,'e0000000-0000-0000-0000-000000000042',true,'Achieved training target');
 BEGIN
  PERFORM public.coach_challenge_v2_settle_manual(cid);
  RAISE EXCEPTION 'Incomplete review accepted';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Incomplete review accepted' THEN RAISE; END IF;
  IF SQLERRM<>'All joined participants require a review' THEN RAISE; END IF;
 END;
 PERFORM public.coach_challenge_v2_review_manual(
 cid,'e0000000-0000-0000-0000-000000000043',false,'Goal was not completed');
 IF public.coach_challenge_v2_settle_manual(cid)<>'settled'
 THEN RAISE EXCEPTION 'Settlement failed'; END IF;
 SELECT count(*) INTO v_count FROM public.point_transactions
 WHERE category='challenge_exp' AND description='Challenge reward: '||cid::text
 AND boxer_id='e0000000-0000-0000-0000-000000000042' AND points=0 AND exp=150;
 IF v_count<>1 THEN RAISE EXCEPTION 'Approved boxer payout mismatch'; END IF;
 IF EXISTS(SELECT 1 FROM public.point_transactions
 WHERE category='challenge_exp' AND description='Challenge reward: '||cid::text
 AND boxer_id='e0000000-0000-0000-0000-000000000043') THEN
 RAISE EXCEPTION 'Rejected boxer received payout'; END IF;
 IF (SELECT count(*) FROM public.league_coach_challenge_exp_ledger WHERE challenge_id=cid)<>2
 THEN RAISE EXCEPTION 'Ledger count mismatch'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.league_coach_challenge_exp_ledger
 WHERE challenge_id=cid AND boxer_id='e0000000-0000-0000-0000-000000000043'
 AND awarded_exp=0 AND transaction_id IS NULL) THEN
 RAISE EXCEPTION 'Rejected boxer ledger mismatch'; END IF;
 BEGIN
  PERFORM public.coach_challenge_v2_settle_manual(cid);
  RAISE EXCEPTION 'Second settlement accepted';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Second settlement accepted' THEN RAISE; END IF;
  IF SQLERRM<>'Challenge already settled; payout integrity must be audited' THEN RAISE; END IF;
 END;
 IF (SELECT count(*) FROM public.point_transactions
 WHERE category='challenge_exp' AND description='Challenge reward: '||cid::text)<>1
 THEN RAISE EXCEPTION 'Duplicate payout after retry'; END IF;
END $test$;
ROLLBACK;
