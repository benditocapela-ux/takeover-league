-- Disposable PostgreSQL only: boxer withdrawal and enrollment integrity.
BEGIN;
INSERT INTO public.profiles(id,auth_user_id,display_name,role,is_active)
VALUES
 ('d0000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001','Coach','coach',true),
 ('d0000000-0000-0000-0000-000000000002','d1000000-0000-0000-0000-000000000002','Boxer','boxer',true),
 ('d0000000-0000-0000-0000-000000000003','d1000000-0000-0000-0000-000000000003','Other boxer','boxer',true);
UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='coach_challenges';
SELECT set_config('test.auth_uid','d1000000-0000-0000-0000-000000000001',true);
DO $test$
DECLARE challenge uuid;
BEGIN
 challenge:=public.coach_challenge_v2_create_draft('Withdrawal test','','individual',7);
 PERFORM public.coach_challenge_v2_manage(challenge,'open');
 PERFORM set_config('test.auth_uid','d1000000-0000-0000-0000-000000000002',true);
 IF public.coach_challenge_v2_join(challenge)<>'joined' THEN
  RAISE EXCEPTION 'Initial enrollment failed';
 END IF;
 PERFORM set_config('test.auth_uid','d1000000-0000-0000-0000-000000000003',true);
 BEGIN
  PERFORM public.coach_challenge_v2_withdraw(challenge);
  RAISE EXCEPTION 'Other boxer withdrew enrollment';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Other boxer withdrew enrollment' THEN RAISE; END IF;
  IF SQLERRM NOT LIKE 'No active enrollment%' THEN RAISE; END IF;
 END;
 PERFORM set_config('test.auth_uid','d1000000-0000-0000-0000-000000000002',true);
 IF public.coach_challenge_v2_withdraw(challenge)<>'withdrawn' THEN
  RAISE EXCEPTION 'Withdrawal failed';
 END IF;
 IF (SELECT status FROM public.league_coach_challenge_entries
     WHERE challenge_id=challenge AND boxer_id='d0000000-0000-0000-0000-000000000002')<>'withdrawn'
 THEN RAISE EXCEPTION 'Withdrawal was not persisted'; END IF;
 BEGIN
  PERFORM public.coach_challenge_v2_withdraw(challenge);
  RAISE EXCEPTION 'Duplicate withdrawal accepted';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Duplicate withdrawal accepted' THEN RAISE; END IF;
  IF SQLERRM NOT LIKE 'No active enrollment%' THEN RAISE; END IF;
 END;
 BEGIN
  PERFORM public.coach_challenge_v2_join(challenge);
  RAISE EXCEPTION 'Withdrawn boxer rejoined without approved policy';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Withdrawn boxer rejoined without approved policy' THEN RAISE; END IF;
  IF SQLERRM NOT LIKE 'Already enrolled%' THEN RAISE; END IF;
 END;
 IF (SELECT count(*) FROM public.league_coach_challenge_entries
     WHERE challenge_id=challenge AND boxer_id='d0000000-0000-0000-0000-000000000002'
       AND status='withdrawn')<>1
 THEN RAISE EXCEPTION 'Rejoin attempt modified withdrawal history'; END IF;
 PERFORM set_config('test.auth_uid','d1000000-0000-0000-0000-000000000001',true);
 PERFORM public.coach_challenge_v2_manage(challenge,'cancel');
 PERFORM set_config('test.auth_uid','d1000000-0000-0000-0000-000000000002',true);
 BEGIN
  PERFORM public.coach_challenge_v2_withdraw(challenge);
  RAISE EXCEPTION 'Cancelled challenge allowed withdrawal';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Cancelled challenge allowed withdrawal' THEN RAISE; END IF;
  IF SQLERRM NOT LIKE 'Only open challenges%' THEN RAISE; END IF;
 END;
 IF (SELECT count(*) FROM public.league_coach_challenge_entries WHERE challenge_id=challenge)<>1
 THEN RAISE EXCEPTION 'Withdrawal deleted enrollment audit row'; END IF;
END $test$;
ROLLBACK;
