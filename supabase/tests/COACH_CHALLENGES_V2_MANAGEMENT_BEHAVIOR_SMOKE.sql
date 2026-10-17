-- Disposable PostgreSQL only: coach challenge management security and transitions.
BEGIN;
INSERT INTO public.profiles(id,auth_user_id,display_name,role,is_active)
VALUES
 ('c0000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000001','Owner coach','coach',true),
 ('c0000000-0000-0000-0000-000000000002','c1000000-0000-0000-0000-000000000002','Other coach','coach',true),
 ('c0000000-0000-0000-0000-000000000003','c1000000-0000-0000-0000-000000000003','Boxer','boxer',true);
UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='coach_challenges';
SELECT set_config('test.auth_uid','c1000000-0000-0000-0000-000000000001',true);
DO $test$
DECLARE challenge uuid;
BEGIN
 challenge:=public.coach_challenge_v2_create_draft('Management test','','individual',7);
 PERFORM set_config('test.auth_uid','c1000000-0000-0000-0000-000000000002',true);
 BEGIN
  PERFORM public.coach_challenge_v2_manage(challenge,'open');
  RAISE EXCEPTION 'Other coach published challenge';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Other coach published challenge' THEN RAISE; END IF;
  IF SQLERRM NOT LIKE 'Only the creating coach%' THEN RAISE; END IF;
 END;
 PERFORM set_config('test.auth_uid','c1000000-0000-0000-0000-000000000003',true);
 BEGIN
  PERFORM public.coach_challenge_v2_manage(challenge,'open');
  RAISE EXCEPTION 'Boxer published challenge';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Boxer published challenge' THEN RAISE; END IF;
  IF SQLERRM NOT LIKE 'Only a coach%' THEN RAISE; END IF;
 END;
 PERFORM set_config('test.auth_uid','c1000000-0000-0000-0000-000000000001',true);
 BEGIN
  PERFORM public.coach_challenge_v2_manage(challenge,'activate');
  RAISE EXCEPTION 'Unspecified activation was allowed';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Unspecified activation was allowed' THEN RAISE; END IF;
  IF SQLERRM NOT LIKE 'Unsupported challenge action%' THEN RAISE; END IF;
 END;
 IF public.coach_challenge_v2_manage(challenge,'open')<>'open' THEN
  RAISE EXCEPTION 'Coach failed to open challenge';
 END IF;
 BEGIN
  PERFORM public.coach_challenge_v2_manage(challenge,'open');
  RAISE EXCEPTION 'Second open succeeded';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Second open succeeded' THEN RAISE; END IF;
  IF SQLERRM NOT LIKE 'Only draft challenges%' THEN RAISE; END IF;
 END;
 IF public.coach_challenge_v2_manage(challenge,'cancel')<>'cancelled' THEN
  RAISE EXCEPTION 'Coach failed to cancel open challenge';
 END IF;
 BEGIN
  PERFORM public.coach_challenge_v2_manage(challenge,'open');
  RAISE EXCEPTION 'Cancelled challenge reopened';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Cancelled challenge reopened' THEN RAISE; END IF;
  IF SQLERRM NOT LIKE 'Only draft challenges%' THEN RAISE; END IF;
 END;
 IF (SELECT status FROM public.league_coach_challenges WHERE id=challenge)<>'cancelled'
 THEN RAISE EXCEPTION 'Challenge status changed after cancellation'; END IF;
END $test$;
ROLLBACK;
