-- AUTHENTICATED V2 RPC END-TO-END TESTS. Disposable PostgreSQL only.
-- Uses a mock auth.uid() reading a test-only request.jwt.claim.sub setting.
DO $privileges$
DECLARE signature text;
BEGIN
 FOREACH signature IN ARRAY ARRAY[
 'coach_challenge_v2_create_draft(text,text,text,integer)',
 'coach_challenge_v2_edit_draft(uuid,text,text,text,integer)',
 'coach_challenge_v2_save_goal_reward(uuid,text,text,integer,numeric,text)',
 'coach_challenge_v2_set_goal(uuid,text,text,numeric,text)',
 'coach_challenge_v2_set_reward(uuid,integer)',
 'coach_challenge_v2_manage(uuid,text)',
 'coach_challenge_v2_join(uuid)',
 'coach_challenge_v2_withdraw(uuid)',
 'coach_challenge_v2_activate(uuid)',
 'coach_challenge_v2_list()',
 'coach_challenge_v2_goal_details(uuid)',
 'coach_challenge_v2_progress(uuid)',
 'coach_challenge_v2_review_status(uuid)',
 'coach_challenge_v2_review_candidates(uuid)',
 'coach_challenge_v2_begin_reviews(uuid)',
 'coach_challenge_v2_review_manual(uuid,uuid,boolean,text)',
 'coach_challenge_v2_settle_manual(uuid)'] LOOP
 IF has_function_privilege('anon','public.'||signature,'EXECUTE') THEN
 RAISE EXCEPTION 'Anonymous EXECUTE unexpectedly granted to %',signature;
 END IF;
 IF NOT has_function_privilege('authenticated','public.'||signature,'EXECUTE') THEN
 RAISE EXCEPTION 'Authenticated EXECUTE missing on %',signature;
 END IF;
 END LOOP;
END $privileges$;

SET ROLE authenticated;
SET request.jwt.claim.sub='22222222-2222-4222-8222-222222222222';
DO $off$
BEGIN
 BEGIN
  PERFORM public.coach_challenge_v2_list();
  RAISE EXCEPTION 'Disabled feature gate allowed read';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
END $off$;
RESET ROLE;
SET ROLE anon;
DO $anonymous$
BEGIN
 BEGIN
  PERFORM public.coach_challenge_v2_list();
  RAISE EXCEPTION 'Anonymous function execution permitted';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
END $anonymous$;
RESET ROLE;

-- Turn the V2 flag on in this disposable fixture, never in production.
UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='coach_challenges';
INSERT INTO public.profiles(id,auth_user_id,display_name,role)
VALUES
 ('cccccccc-cccc-4ccc-8ccc-cccccccccccc','33333333-3333-4333-8333-333333333333','Test Admin','admin'),
 ('dddddddd-dddd-4ddd-8ddd-dddddddddddd','44444444-4444-4444-8444-444444444444','Other Coach','coach');

SET ROLE authenticated;
SET request.jwt.claim.sub='22222222-2222-4222-8222-222222222222';
DO $coach$
DECLARE cid uuid; other_id uuid; data jsonb; goal jsonb;
BEGIN
 data:=public.coach_challenge_v2_create_draft('Sparring Progress','Manual coach challenge','individual',7);
 cid:=(data->>'id')::uuid;
 PERFORM pg_catalog.set_config('test.challenge_id',cid::text,false);
 data:=public.coach_challenge_v2_list();
 IF pg_catalog.jsonb_array_length(data)<>1 THEN RAISE EXCEPTION 'Coach draft missing'; END IF;
 goal:=public.coach_challenge_v2_goal_details(cid);
 IF goal->>'status'<>'draft' THEN RAISE EXCEPTION 'Incorrect draft status'; END IF;
 BEGIN
  PERFORM public.coach_challenge_v2_manage(cid,'open');
  RAISE EXCEPTION 'Draft opened without configured reward';
 EXCEPTION WHEN invalid_parameter_value THEN NULL;
 END;
 PERFORM public.coach_challenge_v2_edit_draft(cid,'Sparring Skills','Individual review','coach_goal',14);
 PERFORM public.coach_challenge_v2_set_goal(cid,'Improve ring defense and focus','manual',NULL,NULL);
 PERFORM public.coach_challenge_v2_set_reward(cid,150);
 PERFORM public.coach_challenge_v2_save_goal_reward(cid,'Finish coach review','manual',150,NULL,NULL);
 data:=public.coach_challenge_v2_progress(cid);
 IF data->>'status'<>'draft' THEN RAISE EXCEPTION 'Progress status mismatch'; END IF;
 data:=public.coach_challenge_v2_review_status(cid);
 IF (data->>'joined_count')::integer<>0 THEN RAISE EXCEPTION 'Unexpected draft participants'; END IF;
 data:=public.coach_challenge_v2_manage(cid,'open');
 IF data->>'status'<>'open' THEN RAISE EXCEPTION 'Challenge not published'; END IF;
 other_id:=(public.coach_challenge_v2_create_draft('Cancelled Draft','Fixture','individual',7)->>'id')::uuid;
 PERFORM pg_catalog.set_config('test.cancelled_id',other_id::text,false);
 PERFORM public.coach_challenge_v2_manage(other_id,'cancel');
END $coach$;
RESET ROLE;

-- A different coach must not take over another trainer's challenge.
SET ROLE authenticated;
SET request.jwt.claim.sub='44444444-4444-4444-8444-444444444444';
DO $othercoach$
BEGIN
 BEGIN
  PERFORM public.coach_challenge_v2_activate(current_setting('test.challenge_id')::uuid);
  RAISE EXCEPTION 'Foreign coach management permitted';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
END $othercoach$;
RESET ROLE;

-- Admin may view and manage all challenge drafts, but cannot bypass state transitions.
SET ROLE authenticated;
SET request.jwt.claim.sub='33333333-3333-4333-8333-333333333333';
DO $admin$
DECLARE data jsonb;
BEGIN
 data:=public.coach_challenge_v2_list();
 IF pg_catalog.jsonb_array_length(data)<>2 THEN
 RAISE EXCEPTION 'Admin missing challenge visibility'; END IF;
 data:=public.coach_challenge_v2_review_status(current_setting('test.challenge_id')::uuid);
 IF data->>'status'<>'open' THEN RAISE EXCEPTION 'Admin status unavailable'; END IF;
END $admin$;
RESET ROLE;

SET ROLE authenticated;
SET request.jwt.claim.sub='11111111-1111-4111-8111-111111111111';
DO $boxer$
DECLARE cid uuid:=current_setting('test.challenge_id')::uuid; data jsonb;
BEGIN
 BEGIN
  PERFORM public.coach_challenge_v2_create_draft('Boxer Escalation','No permission','individual',7);
  RAISE EXCEPTION 'Boxer created a coach challenge';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 data:=public.coach_challenge_v2_list();
 IF pg_catalog.jsonb_array_length(data)<>1 THEN RAISE EXCEPTION 'Incorrect boxer visibility'; END IF;
 data:=public.coach_challenge_v2_join(cid);
 IF data->>'status'<>'joined' THEN RAISE EXCEPTION 'Boxer join failed'; END IF;
 PERFORM public.coach_challenge_v2_join(cid);
 PERFORM public.coach_challenge_v2_withdraw(cid);
 PERFORM public.coach_challenge_v2_join(cid);
 data:=public.coach_challenge_v2_progress(cid);
 IF data->>'my_enrollment_status'<>'joined' THEN RAISE EXCEPTION 'Enrollment progress missing'; END IF;
 BEGIN
  PERFORM public.coach_challenge_v2_review_candidates(cid);
  RAISE EXCEPTION 'Boxer loaded private review candidates';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
END $boxer$;
RESET ROLE;

SET ROLE authenticated;
SET request.jwt.claim.sub='22222222-2222-4222-8222-222222222222';
DO $activate$
DECLARE cid uuid:=current_setting('test.challenge_id')::uuid;
BEGIN
 PERFORM public.coach_challenge_v2_activate(cid);
 BEGIN
  PERFORM public.coach_challenge_v2_begin_reviews(cid);
  RAISE EXCEPTION 'Review started before deadline';
 EXCEPTION WHEN invalid_parameter_value THEN NULL;
 END;
END $activate$;
RESET ROLE;

-- Fast-forward dates in fixture as the database owner; not an application privilege.
UPDATE public.league_coach_challenges
SET starts_at=now()-INTERVAL '15 days', ends_at=now()-INTERVAL '1 day'
WHERE id=current_setting('test.challenge_id')::uuid;

SET ROLE authenticated;
SET request.jwt.claim.sub='22222222-2222-4222-8222-222222222222';
DO $settlement$
DECLARE cid uuid:=current_setting('test.challenge_id')::uuid; data jsonb;
BEGIN
 PERFORM public.coach_challenge_v2_begin_reviews(cid);
 data:=public.coach_challenge_v2_review_candidates(cid);
 IF pg_catalog.jsonb_array_length(data)<>1 THEN RAISE EXCEPTION 'Missing manual candidate'; END IF;
 BEGIN
  PERFORM public.coach_challenge_v2_settle_manual(cid);
  RAISE EXCEPTION 'Settlement permitted before review';
 EXCEPTION WHEN invalid_parameter_value THEN NULL;
 END;
 PERFORM public.coach_challenge_v2_review_manual(
 cid,'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',true,'Successful test sparring');
 data:=public.coach_challenge_v2_review_status(cid);
 IF (data->>'pending_count')::integer<>0 OR (data->>'approved_count')::integer<>1
 THEN RAISE EXCEPTION 'Review counts incorrect'; END IF;
 data:=public.coach_challenge_v2_settle_manual(cid);
 IF (data->>'awards')::integer<>1 THEN RAISE EXCEPTION 'EXP award missing'; END IF;
 data:=public.coach_challenge_v2_settle_manual(cid);
 IF data->>'already_settled'<>'true' THEN RAISE EXCEPTION 'Repeated settlement not idempotent'; END IF;
END $settlement$;
RESET ROLE;

DO $verify$
DECLARE cid uuid:=current_setting('test.challenge_id')::uuid;
BEGIN
 IF (SELECT count(*) FROM public.point_transactions
 WHERE category='challenge_exp' AND exp=150 AND points=0
 AND description LIKE 'Coach Challenge:%')<>1
 THEN RAISE EXCEPTION 'EXP award duplicated or malformed'; END IF;
 IF (SELECT count(*) FROM public.league_coach_challenge_exp_ledger
 WHERE challenge_id=cid AND awarded_exp=150)<>1
 THEN RAISE EXCEPTION 'EXP ledger duplicated'; END IF;
 IF (SELECT count(*) FROM public.league_coach_challenge_entries
 WHERE challenge_id=cid AND status='completed')<>1
 THEN RAISE EXCEPTION 'Enrollment not settled'; END IF;
END $verify$;

-- Empty all newly created V2 records to exercise the prepared rollback.
DELETE FROM public.league_coach_challenge_exp_ledger;
DELETE FROM public.league_coach_challenge_reviews;
DELETE FROM public.league_coach_challenge_entries;
DELETE FROM public.league_coach_challenges;
DELETE FROM public.point_transactions WHERE description LIKE 'Coach Challenge:%';
UPDATE public.league_feature_flags SET is_enabled=false WHERE feature_key='coach_challenges';
SELECT 'V2 authenticated coach/boxer/admin RPC tests passed' AS result;
