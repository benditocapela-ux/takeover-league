-- Disposable PostgreSQL: challenge read authorization and visibility.
BEGIN;
INSERT INTO public.profiles(id,auth_user_id,display_name,role,is_active)
VALUES
 ('e0000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','Coach','coach',true),
 ('e0000000-0000-0000-0000-000000000002','e1000000-0000-0000-0000-000000000002','Boxer A','boxer',true),
 ('e0000000-0000-0000-0000-000000000003','e1000000-0000-0000-0000-000000000003','Boxer B','boxer',true),
 ('e0000000-0000-0000-0000-000000000004','e1000000-0000-0000-0000-000000000004','Inactive','boxer',false),
 ('e0000000-0000-0000-0000-000000000005','e1000000-0000-0000-0000-000000000005','Other coach','coach',true),
 ('e0000000-0000-0000-0000-000000000006','e1000000-0000-0000-0000-000000000006','Administrator','admin',true);
INSERT INTO public.league_coach_challenges(id,created_by,title,challenge_kind,duration_days,status)
VALUES
 ('e2000000-0000-0000-0000-000000000001','e0000000-0000-0000-0000-000000000001','Private draft','individual',7,'draft'),
 ('e2000000-0000-0000-0000-000000000002','e0000000-0000-0000-0000-000000000001','Open challenge','competition',14,'open'),
 ('e2000000-0000-0000-0000-000000000003','e0000000-0000-0000-0000-000000000001','Cancelled enrolled','coach_goal',30,'cancelled'),
 ('e2000000-0000-0000-0000-000000000004','e0000000-0000-0000-0000-000000000005','Other coach private','individual',7,'draft');
INSERT INTO public.league_coach_challenge_entries(challenge_id,boxer_id,status)
VALUES
 ('e2000000-0000-0000-0000-000000000002','e0000000-0000-0000-0000-000000000002','joined'),
 ('e2000000-0000-0000-0000-000000000003','e0000000-0000-0000-0000-000000000002','withdrawn');
SELECT set_config('test.auth_uid','e1000000-0000-0000-0000-000000000002',true);
DO $test$
BEGIN
 BEGIN
  PERFORM public.coach_challenge_v2_list();
  RAISE EXCEPTION 'Disabled list succeeded';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Disabled list succeeded' THEN RAISE; END IF;
  IF SQLERRM NOT LIKE 'Coach challenges are not enabled%' THEN RAISE; END IF;
 END;
END $test$;
UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='coach_challenges';
DO $test$
BEGIN
 IF (SELECT count(*) FROM public.coach_challenge_v2_list())<>2 THEN
  RAISE EXCEPTION 'Boxer saw private challenge or lost enrolled challenge';
 END IF;
 IF (SELECT count(*) FROM public.coach_challenge_v2_list()
     WHERE title='Private draft')<>0 THEN
  RAISE EXCEPTION 'Boxer saw private draft';
 END IF;
 IF (SELECT joined_count FROM public.coach_challenge_v2_list()
     WHERE title='Open challenge')<>1 THEN
  RAISE EXCEPTION 'Joined count incorrect';
 END IF;
 IF (SELECT my_enrollment_status FROM public.coach_challenge_v2_list()
     WHERE title='Cancelled enrolled')<>'withdrawn' THEN
  RAISE EXCEPTION 'Own historical enrollment hidden';
 END IF;
 PERFORM set_config('test.auth_uid','e1000000-0000-0000-0000-000000000003',true);
 IF (SELECT count(*) FROM public.coach_challenge_v2_list())<>1 THEN
  RAISE EXCEPTION 'Unenrolled boxer saw hidden challenges';
 END IF;
 PERFORM set_config('test.auth_uid','e1000000-0000-0000-0000-000000000001',true);
 IF (SELECT count(*) FROM public.coach_challenge_v2_list())<>3 THEN
  RAISE EXCEPTION 'Coach lost own or published challenges, or saw private draft';
 END IF;
 PERFORM set_config('test.auth_uid','e1000000-0000-0000-0000-000000000005',true);
 IF (SELECT count(*) FROM public.coach_challenge_v2_list())<>2 THEN
  RAISE EXCEPTION 'Other coach saw private cancelled challenge or lost public challenges';
 END IF;
 IF (SELECT count(*) FROM public.coach_challenge_v2_list() WHERE title IN ('Private draft','Cancelled enrolled'))<>0 THEN
  RAISE EXCEPTION 'Other coach saw another coach private or cancelled challenge';
 END IF;
 PERFORM set_config('test.auth_uid','e1000000-0000-0000-0000-000000000006',true);
 IF (SELECT count(*) FROM public.coach_challenge_v2_list())<>4 THEN
  RAISE EXCEPTION 'Admin did not see all challenge statuses and owners';
 END IF;
 IF (SELECT count(*) FROM public.coach_challenge_v2_list()
     WHERE title IN ('Private draft','Other coach private','Cancelled enrolled'))<>3 THEN
  RAISE EXCEPTION 'Admin could not audit private and cancelled challenges';
 END IF;
 PERFORM set_config('test.auth_uid','e1000000-0000-0000-0000-000000000004',true);
 BEGIN
  PERFORM public.coach_challenge_v2_list();
  RAISE EXCEPTION 'Inactive boxer read challenges';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Inactive boxer read challenges' THEN RAISE; END IF;
  IF SQLERRM NOT LIKE 'Not authorized%' THEN RAISE; END IF;
 END;
END $test$;
ROLLBACK;
