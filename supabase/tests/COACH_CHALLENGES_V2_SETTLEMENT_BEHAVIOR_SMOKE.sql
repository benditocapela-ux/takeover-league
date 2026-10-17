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
 starts_at=pg_catalog.date_trunc('second',pg_catalog.clock_timestamp())-interval '8 days',
 ends_at=pg_catalog.date_trunc('second',pg_catalog.clock_timestamp())-interval '1 day' WHERE id=cid;
 -- An awaiting-review challenge without participants cannot be settled.
 BEGIN
  PERFORM public.coach_challenge_v2_settle_manual(cid);
  RAISE EXCEPTION 'Empty challenge settlement accepted';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Empty challenge settlement accepted' THEN RAISE; END IF;
  IF SQLERRM<>'Cannot settle challenge without joined participants' THEN RAISE; END IF;
 END;
 -- An impossible challenge clock must prevent the first payout.
 UPDATE public.league_coach_challenges SET starts_at=ends_at WHERE id=cid;
 BEGIN
  PERFORM public.coach_challenge_v2_settle_manual(cid);
  RAISE EXCEPTION 'Invalid first-settlement clock accepted';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Invalid first-settlement clock accepted' THEN RAISE; END IF;
  IF SQLERRM<>'Manual settlement unavailable' THEN RAISE; END IF;
 END;
 UPDATE public.league_coach_challenges
 SET starts_at=ends_at-interval '7 days' WHERE id=cid;
 -- Corrupted goal metadata must prevent the first payout.
 UPDATE public.league_coach_challenges
 SET goal_spec=pg_catalog.jsonb_set(goal_spec,'{goal_text}','""'::jsonb)
 WHERE id=cid;
 BEGIN
  PERFORM public.coach_challenge_v2_settle_manual(cid);
  RAISE EXCEPTION 'Invalid first-settlement goal accepted';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Invalid first-settlement goal accepted' THEN RAISE; END IF;
  IF SQLERRM<>'Manual settlement unavailable' THEN RAISE; END IF;
 END;
 UPDATE public.league_coach_challenges
 SET goal_spec=pg_catalog.jsonb_set(goal_spec,'{goal_text}','"Practice controlled sparring"'::jsonb)
 WHERE id=cid;
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
 IF public.coach_challenge_v2_settle_manual(cid)<>'settled' THEN
 RAISE EXCEPTION 'Idempotent settlement retry failed'; END IF;
 -- A reviewed participant must remain eligible for the ledger to be valid.
 UPDATE public.league_coach_challenge_entries SET status='withdrawn'
 WHERE challenge_id=cid AND boxer_id='e0000000-0000-0000-0000-000000000043';
 BEGIN
  PERFORM public.coach_challenge_v2_settle_manual(cid);
  RAISE EXCEPTION 'Withdrawn reviewed boxer accepted';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Withdrawn reviewed boxer accepted' THEN RAISE; END IF;
  IF SQLERRM<>'Settled challenge payout integrity mismatch' THEN RAISE; END IF;
 END;
 UPDATE public.league_coach_challenge_entries SET status='joined'
 WHERE challenge_id=cid AND boxer_id='e0000000-0000-0000-0000-000000000043';
 -- A settled challenge with no remaining joined participants is invalid.
 UPDATE public.league_coach_challenge_entries SET status='withdrawn'
 WHERE challenge_id=cid;
 BEGIN
  PERFORM public.coach_challenge_v2_settle_manual(cid);
  RAISE EXCEPTION 'Settled empty participant roster accepted';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Settled empty participant roster accepted' THEN RAISE; END IF;
  IF SQLERRM<>'Settled challenge payout integrity mismatch' THEN RAISE; END IF;
 END;
 UPDATE public.league_coach_challenge_entries SET status='joined'
 WHERE challenge_id=cid;
 -- An orphan challenge EXP transaction must never be silently accepted.
 INSERT INTO public.point_transactions(boxer_id,points,exp,category,description,effective_date,created_by)
 VALUES('e0000000-0000-0000-0000-000000000043',0,150,'challenge_exp',
 'Challenge reward: '||cid::text,current_date,'e0000000-0000-0000-0000-000000000041');
 BEGIN
  PERFORM public.coach_challenge_v2_settle_manual(cid);
  RAISE EXCEPTION 'Orphan challenge transaction accepted';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Orphan challenge transaction accepted' THEN RAISE; END IF;
  IF SQLERRM<>'Settled challenge payout integrity mismatch' THEN RAISE; END IF;
 END;
 DELETE FROM public.point_transactions
 WHERE category='challenge_exp' AND boxer_id='e0000000-0000-0000-0000-000000000043'
 AND description='Challenge reward: '||cid::text;
 -- Nonzero training points are corruption even if EXP and ledger match.
 UPDATE public.point_transactions SET points=1
 WHERE category='challenge_exp' AND description='Challenge reward: '||cid::text
 AND boxer_id='e0000000-0000-0000-0000-000000000042';
 BEGIN
  PERFORM public.coach_challenge_v2_settle_manual(cid);
  RAISE EXCEPTION 'Corrupt challenge points accepted';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Corrupt challenge points accepted' THEN RAISE; END IF;
  IF SQLERRM<>'Settled challenge payout integrity mismatch' THEN RAISE; END IF;
 END;
 UPDATE public.point_transactions SET points=0
 WHERE category='challenge_exp' AND description='Challenge reward: '||cid::text
 AND boxer_id='e0000000-0000-0000-0000-000000000042';
 -- Missing transaction description must not bypass SQL three-valued checks.
 UPDATE public.point_transactions SET description=NULL
 WHERE category='challenge_exp' AND description='Challenge reward: '||cid::text
 AND boxer_id='e0000000-0000-0000-0000-000000000042';
 BEGIN
  PERFORM public.coach_challenge_v2_settle_manual(cid);
  RAISE EXCEPTION 'Missing payout description accepted';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Missing payout description accepted' THEN RAISE; END IF;
  IF SQLERRM<>'Settled challenge payout integrity mismatch' THEN RAISE; END IF;
 END;
 UPDATE public.point_transactions SET description='Challenge reward: '||cid::text
 WHERE category='challenge_exp' AND description IS NULL
 AND boxer_id='e0000000-0000-0000-0000-000000000042';
 -- A category changed after payout must invalidate settlement integrity.
 UPDATE public.point_transactions SET category='adjustment'
 WHERE category='challenge_exp' AND description='Challenge reward: '||cid::text
 AND boxer_id='e0000000-0000-0000-0000-000000000042';
 BEGIN
  PERFORM public.coach_challenge_v2_settle_manual(cid);
  RAISE EXCEPTION 'Changed payout category accepted';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Changed payout category accepted' THEN RAISE; END IF;
  IF SQLERRM<>'Settled challenge payout integrity mismatch' THEN RAISE; END IF;
 END;
 UPDATE public.point_transactions SET category='challenge_exp'
 WHERE category='adjustment' AND description='Challenge reward: '||cid::text
 AND boxer_id='e0000000-0000-0000-0000-000000000042';
 -- A settled challenge with an impossible start/end clock is corrupt.
 UPDATE public.league_coach_challenges SET starts_at=ends_at WHERE id=cid;
 BEGIN
  PERFORM public.coach_challenge_v2_settle_manual(cid);
  RAISE EXCEPTION 'Invalid settled challenge clock accepted';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Invalid settled challenge clock accepted' THEN RAISE; END IF;
  IF SQLERRM<>'Settled challenge metadata integrity mismatch' THEN RAISE; END IF;
 END;
 UPDATE public.league_coach_challenges
 SET starts_at=ends_at-interval '7 days' WHERE id=cid;
 -- Settlement cannot predate the challenge deadline.
 UPDATE public.league_coach_challenges SET settled_at=ends_at-interval '1 second'
 WHERE id=cid;
 BEGIN
  PERFORM public.coach_challenge_v2_settle_manual(cid);
  RAISE EXCEPTION 'Settlement timestamp before deadline accepted';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Settlement timestamp before deadline accepted' THEN RAISE; END IF;
  IF SQLERRM<>'Settled challenge metadata integrity mismatch' THEN RAISE; END IF;
 END;
 UPDATE public.league_coach_challenges SET settled_at=pg_catalog.clock_timestamp()
 WHERE id=cid;
 -- A payout must retain the responsible coach/admin actor.
 UPDATE public.point_transactions SET created_by=NULL
 WHERE category='challenge_exp' AND description='Challenge reward: '||cid::text
 AND boxer_id='e0000000-0000-0000-0000-000000000042';
 BEGIN
  PERFORM public.coach_challenge_v2_settle_manual(cid);
  RAISE EXCEPTION 'Missing payout author accepted';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Missing payout author accepted' THEN RAISE; END IF;
  IF SQLERRM<>'Settled challenge payout integrity mismatch' THEN RAISE; END IF;
 END;
 UPDATE public.point_transactions SET created_by=(SELECT created_by FROM public.league_coach_challenges WHERE id=cid)
 WHERE category='challenge_exp' AND description='Challenge reward: '||cid::text
 AND boxer_id='e0000000-0000-0000-0000-000000000042';
 -- Settled challenge must retain a meaningful, versioned goal.
 UPDATE public.league_coach_challenges
 SET goal_spec=pg_catalog.jsonb_set(goal_spec,'{goal_text}','""'::jsonb)
 WHERE id=cid;
 BEGIN
  PERFORM public.coach_challenge_v2_settle_manual(cid);
  RAISE EXCEPTION 'Empty settled challenge goal accepted';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Empty settled challenge goal accepted' THEN RAISE; END IF;
  IF SQLERRM<>'Settled challenge metadata integrity mismatch' THEN RAISE; END IF;
 END;
 UPDATE public.league_coach_challenges
 SET goal_spec=pg_catalog.jsonb_set(goal_spec,'{goal_text}','"Run the manual challenge goal"'::jsonb)
 WHERE id=cid;
 -- Simulate a damaged ledger; retry must reject it rather than claim success.
 UPDATE public.league_coach_challenge_exp_ledger SET awarded_exp=25
 WHERE challenge_id=cid AND boxer_id='e0000000-0000-0000-0000-000000000042';
 BEGIN
  PERFORM public.coach_challenge_v2_settle_manual(cid);
  RAISE EXCEPTION 'Corrupt settlement ledger accepted';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Corrupt settlement ledger accepted' THEN RAISE; END IF;
  IF SQLERRM<>'Settled challenge payout integrity mismatch' THEN RAISE; END IF;
 END;
 UPDATE public.league_coach_challenge_exp_ledger SET awarded_exp=150
 WHERE challenge_id=cid AND boxer_id='e0000000-0000-0000-0000-000000000042';
 IF public.coach_challenge_v2_settle_manual(cid)<>'settled'
 THEN RAISE EXCEPTION 'Repaired settlement could not be reverified'; END IF;
 IF (SELECT count(*) FROM public.point_transactions
 WHERE category='challenge_exp' AND description='Challenge reward: '||cid::text)<>1
 THEN RAISE EXCEPTION 'Duplicate payout after retry'; END IF;
END $test$;
ROLLBACK;
