-- TEST PROJECT ONLY: transaction-scoped coach approval / boxer denial / notification.
-- No changes persist because the outer transaction ends with ROLLBACK.
BEGIN;
DO $prepare$
DECLARE c record; b record; t record; new_training uuid; denied_training uuid;
BEGIN
 IF to_regclass('public.league_test_boxers') IS NULL THEN RAISE EXCEPTION 'TEST DATABASE SENTINEL MISSING'; END IF;
 SELECT p.id,p.auth_user_id INTO c FROM public.profiles p JOIN auth.users u ON u.id=p.auth_user_id WHERE p.role='coach' AND p.is_active LIMIT 1;
 SELECT p.id,p.auth_user_id INTO b FROM public.profiles p JOIN auth.users u ON u.id=p.auth_user_id WHERE p.role='boxer' AND p.is_active LIMIT 1;
 SELECT id,points INTO t FROM public.training_types WHERE is_active ORDER BY id LIMIT 1;
 IF c.id IS NULL OR b.id IS NULL OR t.id IS NULL THEN RAISE EXCEPTION 'Test coach/boxer/type missing'; END IF;
 INSERT INTO public.league_feature_flags(feature_key,display_name,is_enabled)
 VALUES ('notifications','Notifications (rollback-only test)',true)
 ON CONFLICT(feature_key) DO UPDATE SET is_enabled=true;
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,status,notes)
 VALUES (b.id,t.id,CURRENT_DATE,'pending','Test coach approve ROLLBACK')
 RETURNING id INTO new_training;
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,status,notes)
 VALUES (b.id,t.id,CURRENT_DATE,'pending','Test boxer denial ROLLBACK')
 RETURNING id INTO denied_training;
 PERFORM set_config('coach_test.coach_user',c.auth_user_id::text,true);
 PERFORM set_config('coach_test.coach_profile',c.id::text,true);
 PERFORM set_config('coach_test.boxer_user',b.auth_user_id::text,true);
 PERFORM set_config('coach_test.boxer_profile',b.id::text,true);
 PERFORM set_config('coach_test.submission',new_training::text,true);
 PERFORM set_config('coach_test.denied',denied_training::text,true);
 PERFORM set_config('coach_test.points',t.points::text,true);
END $prepare$;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',current_setting('coach_test.coach_user'),true);
DO $coach$
DECLARE result jsonb; cols text; n integer;
BEGIN
 IF NOT public.is_league_coach() OR public.is_league_admin() THEN
  RAISE EXCEPTION 'Coach actor check failed';
 END IF;
 SELECT pg_get_function_result('public.coach_list_boxers()'::regprocedure) INTO cols;
 IF cols ILIKE '%auth_user_id%' OR cols NOT ILIKE '%display_name%' THEN
  RAISE EXCEPTION 'coach_list_boxers exposes inappropriate columns';
 END IF;
 SELECT count(*) INTO n FROM public.coach_list_boxers()
 WHERE id=current_setting('coach_test.boxer_profile')::uuid;
 IF n<>1 THEN RAISE EXCEPTION 'Coach list cannot read boxer'; END IF;
 SELECT public.review_training(current_setting('coach_test.submission')::uuid,'approved') INTO result;
 IF result->>'status'<>'approved' OR (result->>'points_awarded')::int<>current_setting('coach_test.points')::int THEN
  RAISE EXCEPTION 'Approval result mismatch: %',result;
 END IF;
 SELECT count(*) INTO n FROM public.point_transactions
 WHERE submission_id=current_setting('coach_test.submission')::uuid
 AND points=current_setting('coach_test.points')::int AND exp=current_setting('coach_test.points')::int
 AND created_by=current_setting('coach_test.coach_profile')::uuid;
 IF n<>1 THEN RAISE EXCEPTION 'Coach ledger missing / mismatched'; END IF;
 RAISE NOTICE 'PASS: active coach approved training, generated points and EXP, boxer list limited';
END $coach$;
SELECT set_config('request.jwt.claim.sub',current_setting('coach_test.boxer_user'),true);
DO $boxer$
DECLARE denied boolean:=false; n integer;
BEGIN
 IF public.is_league_coach() THEN RAISE EXCEPTION 'Boxer wrongly recognized as coach'; END IF;
 BEGIN
  PERFORM public.review_training(current_setting('coach_test.denied')::uuid,'approved');
 EXCEPTION WHEN OTHERS THEN
  denied:=true;
 END;
 IF NOT denied THEN RAISE EXCEPTION 'Boxer can approve a training'; END IF;
 BEGIN
  INSERT INTO public.point_transactions(boxer_id,points,exp,category,description,effective_date)
  VALUES (current_setting('coach_test.boxer_profile')::uuid,9999,9999,'training','Forbidden',CURRENT_DATE);
 EXCEPTION WHEN OTHERS THEN denied:=true; END;
 SELECT count(*) INTO n FROM public.point_transactions WHERE points=9999 AND description='Forbidden';
 IF n>0 THEN RAISE EXCEPTION 'Boxer can insert points directly'; END IF;
 RAISE NOTICE 'PASS: boxer cannot approve training or credit points';
END $boxer$;
RESET ROLE;
UPDATE public.profiles SET is_active=false WHERE id=current_setting('coach_test.coach_profile')::uuid;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',current_setting('coach_test.coach_user'),true);
DO $inactive$
DECLARE denied boolean:=false;
BEGIN
 IF public.is_league_coach() THEN RAISE EXCEPTION 'Disabled coach retains trainer permissions'; END IF;
 BEGIN
  PERFORM public.coach_list_boxers();
 EXCEPTION WHEN OTHERS THEN denied:=true;
 END;
 IF NOT denied THEN RAISE EXCEPTION 'Disabled coach can read boxer list'; END IF;
 denied:=false;
 BEGIN
  PERFORM public.review_training(current_setting('coach_test.denied')::uuid,'approved');
 EXCEPTION WHEN OTHERS THEN denied:=true;
 END;
 IF NOT denied THEN RAISE EXCEPTION 'Disabled coach can approve training'; END IF;
 RAISE NOTICE 'PASS: deactivated coach cannot read trainer data or approve training';
END $inactive$;
RESET ROLE;
DO $finish$
DECLARE n integer;
BEGIN
 SELECT count(*) INTO n FROM public.boxer_notifications
 WHERE recipient_id=current_setting('coach_test.boxer_profile')::uuid
 AND notification_type='training_approved';
 IF n<1 THEN RAISE EXCEPTION 'Approval notification missing'; END IF;
 SELECT count(*) INTO n FROM public.training_submissions
 WHERE id=current_setting('coach_test.denied')::uuid AND status='pending';
 IF n<>1 THEN RAISE EXCEPTION 'Denied boxer attempt changed training'; END IF;
 RAISE NOTICE 'PASS: notification exists for boxer; unauthorized training unchanged';
END $finish$;
ROLLBACK;
