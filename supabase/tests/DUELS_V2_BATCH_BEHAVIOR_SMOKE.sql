-- Disposable CI PostgreSQL only: coach batch reconciliation skips active periods.
BEGIN;
INSERT INTO public.profiles(id,auth_user_id,role,is_active) VALUES
 ('00000000-0000-0000-0000-0000000000a1','10000000-0000-0000-0000-0000000000a1','boxer',true),
 ('00000000-0000-0000-0000-0000000000b2','10000000-0000-0000-0000-0000000000b2','boxer',true),
 ('00000000-0000-0000-0000-0000000000d4','10000000-0000-0000-0000-0000000000d4','boxer',true),
 ('00000000-0000-0000-0000-0000000000e5','10000000-0000-0000-0000-0000000000e5','boxer',true),
 ('00000000-0000-0000-0000-0000000000c3','10000000-0000-0000-0000-0000000000c3','coach',true);
UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='duels';
DO $test$
DECLARE
 ended1 uuid;
 ended2 uuid;
 ongoing uuid;
 batch_count integer;
BEGIN
 PERFORM set_config('test.auth_uid','10000000-0000-0000-0000-0000000000c3',true);
 INSERT INTO public.league_duels(challenger_id,opponent_id,created_by,duration_days,status,accepted_at,ends_at)
 VALUES
 ('00000000-0000-0000-0000-0000000000a1','00000000-0000-0000-0000-0000000000b2',
  '00000000-0000-0000-0000-0000000000c3',7,'active',now()-interval '8 days',now()-interval '1 day')
 RETURNING id INTO ended1;
 INSERT INTO public.league_duels(challenger_id,opponent_id,created_by,duration_days,status,accepted_at,ends_at)
 VALUES
 ('00000000-0000-0000-0000-0000000000d4','00000000-0000-0000-0000-0000000000e5',
  '00000000-0000-0000-0000-0000000000c3',7,'active',now()-interval '8 days',now()-interval '1 day')
 RETURNING id INTO ended2;
 INSERT INTO public.league_duels(challenger_id,opponent_id,created_by,duration_days,status,accepted_at,ends_at)
 VALUES
 ('00000000-0000-0000-0000-0000000000a1','00000000-0000-0000-0000-0000000000d4',
  '00000000-0000-0000-0000-0000000000c3',7,'active',now(),now()+interval '7 days')
 RETURNING id INTO ongoing;
 SELECT count(*) INTO batch_count FROM public.duel_v2_reconcile_due();
 IF batch_count<>2 THEN RAISE EXCEPTION 'Batch must process exactly two ended duels, got %',batch_count; END IF;
 IF (SELECT count(*) FROM public.league_duels WHERE id IN (ended1,ended2) AND status='settled')<>2 THEN
  RAISE EXCEPTION 'Batch did not settle both ended duels';
 END IF;
 IF (SELECT status FROM public.league_duels WHERE id=ongoing)<>'active' THEN
  RAISE EXCEPTION 'Batch prematurely settled ongoing duel';
 END IF;
 IF (SELECT count(*) FROM public.point_transactions WHERE category='duel_exp')<>4 THEN
  RAISE EXCEPTION 'Batch must issue exactly four payout transactions';
 END IF;
 SELECT count(*) INTO batch_count FROM public.duel_v2_reconcile_due();
 IF batch_count<>0 THEN RAISE EXCEPTION 'Repeated default batch must skip settled duels'; END IF;
 SELECT count(*) INTO batch_count FROM public.duel_v2_reconcile_due(true);
 IF batch_count<>2 OR (SELECT count(*) FROM public.point_transactions WHERE category='duel_exp')<>4 THEN
  RAISE EXCEPTION 'Explicit settled recheck must not duplicate rewards';
 END IF;
 -- UUID pagination must exclude rows at/before the cursor without extra payouts.
 SELECT count(*) INTO batch_count
 FROM public.duel_v2_reconcile_due(true,LEAST(ended1,ended2));
 IF batch_count<>1 THEN
  RAISE EXCEPTION 'Batch cursor should return one later settled duel, got %',batch_count;
 END IF;
 SELECT count(*) INTO batch_count
 FROM public.duel_v2_reconcile_due(true,GREATEST(ended1,ended2));
 IF batch_count<>0 THEN
  RAISE EXCEPTION 'Batch cursor beyond final settled duel returned rows';
 END IF;
 IF (SELECT count(*) FROM public.point_transactions WHERE category='duel_exp')<>4 THEN
  RAISE EXCEPTION 'Cursor pagination minted duplicate rewards';
 END IF;
 -- A due duel with a timely pending submission stays unpaid until review.
 INSERT INTO public.league_duels(challenger_id,opponent_id,created_by,duration_days,status,accepted_at,ends_at)
 VALUES ('00000000-0000-0000-0000-0000000000a1','00000000-0000-0000-0000-0000000000e5',
         '00000000-0000-0000-0000-0000000000c3',7,'active',
         now()-interval '8 days',now()-interval '1 day')
 RETURNING id INTO ended1;
 INSERT INTO public.training_submissions(id,boxer_id,training_date,status,created_at)
 VALUES ('20000000-0000-0000-0000-000000000099',
         '00000000-0000-0000-0000-0000000000a1',current_date-3,
         'pending',now()-interval '3 days');
 SELECT count(*) INTO batch_count FROM public.duel_v2_reconcile_due();
 IF batch_count<>1 OR
    (SELECT status FROM public.league_duels WHERE id=ended1)<>'awaiting_reviews'
    OR (SELECT count(*) FROM public.point_transactions WHERE category='duel_exp')<>4 THEN
  RAISE EXCEPTION 'Batch must defer pending-review duel without paying rewards';
 END IF;
 UPDATE public.training_submissions SET status='rejected'
 WHERE id='20000000-0000-0000-0000-000000000099';
 SELECT count(*) INTO batch_count FROM public.duel_v2_reconcile_due();
 IF batch_count<>1 OR
    (SELECT status FROM public.league_duels WHERE id=ended1)<>'settled'
    OR (SELECT count(*) FROM public.point_transactions WHERE category='duel_exp')<>6 THEN
  RAISE EXCEPTION 'Batch did not settle newly reviewed duel exactly once';
 END IF;
END $test$;
ROLLBACK;
