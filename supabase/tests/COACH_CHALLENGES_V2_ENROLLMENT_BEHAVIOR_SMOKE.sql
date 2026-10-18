-- Disposable PostgreSQL only: challenge authorization and opt-in behavior.
BEGIN;
INSERT INTO public.profiles(id,auth_user_id,display_name,role,is_active)
VALUES
 ('b0000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','Coach','coach',true),
 ('b0000000-0000-0000-0000-000000000002','b1000000-0000-0000-0000-000000000002','Boxer','boxer',true),
 ('b0000000-0000-0000-0000-000000000003','b1000000-0000-0000-0000-000000000003','Inactive','boxer',false);
SELECT set_config('test.auth_uid','b1000000-0000-0000-0000-000000000001',true);
DO $test$
BEGIN
 BEGIN
  PERFORM public.coach_challenge_v2_create_draft('Test challenge','','individual',7);
  RAISE EXCEPTION 'Disabled flag permitted draft creation';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Disabled flag permitted draft creation' THEN RAISE; END IF;
  IF SQLERRM NOT LIKE 'Coach challenges are not enabled%' THEN RAISE; END IF;
 END;
END $test$;
UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='coach_challenges';
DO $test$
DECLARE challenge uuid;
BEGIN
 challenge:=public.coach_challenge_v2_create_draft('Test challenge','','individual',7);
 IF (SELECT status FROM public.league_coach_challenges WHERE id=challenge)<>'draft'
 THEN RAISE EXCEPTION 'Draft was not created in draft status'; END IF;
 PERFORM set_config('test.auth_uid','b1000000-0000-0000-0000-000000000002',true);
 BEGIN
  PERFORM public.coach_challenge_v2_join(challenge);
  RAISE EXCEPTION 'Draft challenge accepted enrollment';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Draft challenge accepted enrollment' THEN RAISE; END IF;
  IF SQLERRM NOT LIKE 'Challenge is not open%' THEN RAISE; END IF;
 END;
 BEGIN
  PERFORM public.coach_challenge_v2_create_draft('Wrong role','','individual',7);
  RAISE EXCEPTION 'Boxer created coach challenge';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Boxer created coach challenge' THEN RAISE; END IF;
  IF SQLERRM NOT LIKE 'Only a coach%' THEN RAISE; END IF;
 END;
 UPDATE public.league_coach_challenges SET status='open' WHERE id=challenge;
 IF public.coach_challenge_v2_join(challenge)<>'joined' THEN
  RAISE EXCEPTION 'Boxer failed to enroll'; END IF;
 BEGIN
  PERFORM public.coach_challenge_v2_join(challenge);
  RAISE EXCEPTION 'Duplicate join succeeded';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Duplicate join succeeded' THEN RAISE; END IF;
  IF SQLERRM NOT LIKE 'Already enrolled%' THEN RAISE; END IF;
 END;
 PERFORM set_config('test.auth_uid','b1000000-0000-0000-0000-000000000003',true);
 BEGIN
  PERFORM public.coach_challenge_v2_join(challenge);
  RAISE EXCEPTION 'Inactive boxer joined';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Inactive boxer joined' THEN RAISE; END IF;
  IF SQLERRM NOT LIKE 'Only an active boxer%' THEN RAISE; END IF;
 END;
 IF (SELECT count(*) FROM public.league_coach_challenge_entries WHERE challenge_id=challenge)<>1
 THEN RAISE EXCEPTION 'Unexpected challenge enrollment count'; END IF;
END $test$;
ROLLBACK;
