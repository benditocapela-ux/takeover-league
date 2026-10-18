-- Disposable PostgreSQL only: goal authoring, role and state checks.
BEGIN;
INSERT INTO public.profiles(id,auth_user_id,display_name,role,is_active) VALUES
('f0000000-0000-0000-0000-000000000001','f1000000-0000-0000-0000-000000000001','Goal coach','coach',true),
('f0000000-0000-0000-0000-000000000002','f1000000-0000-0000-0000-000000000002','Other coach','coach',true),
('f0000000-0000-0000-0000-000000000003','f1000000-0000-0000-0000-000000000003','Goal boxer','boxer',true);
UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='coach_challenges';
SELECT set_config('test.auth_uid','f1000000-0000-0000-0000-000000000001',true);
DO $test$
DECLARE challenge uuid;
BEGIN
 challenge:=public.coach_challenge_v2_create_draft('Goal test','','individual',14);
 IF public.coach_challenge_v2_set_goal(challenge,'Improve defensive footwork','manual',NULL)<>'goal_saved'
 THEN RAISE EXCEPTION 'Manual goal save failed'; END IF;
 IF (SELECT goal_spec->>'review_mode' FROM public.league_coach_challenges WHERE id=challenge)<>'manual'
 THEN RAISE EXCEPTION 'Manual goal not persisted'; END IF;
 IF public.coach_challenge_v2_set_goal(challenge,'Run an approved total distance','automatic',30,'jogging_km')<>'goal_saved'
 THEN RAISE EXCEPTION 'Automatic goal save failed'; END IF;
 IF (SELECT goal_spec->>'metric' FROM public.league_coach_challenges WHERE id=challenge)<>'jogging_km'
 THEN RAISE EXCEPTION 'Automatic metric not persisted'; END IF;
 IF (SELECT (goal_spec->>'target_value')::numeric FROM public.league_coach_challenges WHERE id=challenge)<>30
 THEN RAISE EXCEPTION 'Automatic target not persisted'; END IF;
 BEGIN
  PERFORM public.coach_challenge_v2_set_goal(challenge,'No target permitted','automatic',NULL);
  RAISE EXCEPTION 'Missing automatic target accepted';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Missing automatic target accepted' THEN RAISE; END IF;
  IF SQLERRM<>'Invalid challenge goal definition' THEN RAISE; END IF;
 END;
 BEGIN
  PERFORM public.coach_challenge_v2_set_goal(challenge,'Missing automatic metric','automatic',30);
  RAISE EXCEPTION 'Missing metric accepted';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Missing metric accepted' THEN RAISE; END IF;
  IF SQLERRM<>'Invalid challenge goal definition' THEN RAISE; END IF;
 END;
 BEGIN
  PERFORM public.coach_challenge_v2_set_goal(challenge,'Unknown metric','automatic',30,'unverified_points');
  RAISE EXCEPTION 'Unknown metric accepted';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Unknown metric accepted' THEN RAISE; END IF;
  IF SQLERRM<>'Invalid challenge goal definition' THEN RAISE; END IF;
 END;
 PERFORM set_config('test.auth_uid','f1000000-0000-0000-0000-000000000002',true);
 BEGIN
  PERFORM public.coach_challenge_v2_set_goal(challenge,'Other coach takeover','manual',NULL);
  RAISE EXCEPTION 'Other coach changed goal';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Other coach changed goal' THEN RAISE; END IF;
  IF SQLERRM<>'Not challenge owner' THEN RAISE; END IF;
 END;
 PERFORM set_config('test.auth_uid','f1000000-0000-0000-0000-000000000003',true);
 BEGIN
  PERFORM public.coach_challenge_v2_set_goal(challenge,'Boxer takeover','manual',NULL);
  RAISE EXCEPTION 'Boxer changed goal';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Boxer changed goal' THEN RAISE; END IF;
  IF SQLERRM<>'Coach authorization required' THEN RAISE; END IF;
 END;
 PERFORM set_config('test.auth_uid','f1000000-0000-0000-0000-000000000001',true);
 PERFORM public.coach_challenge_v2_manage(challenge,'open');
 BEGIN
  PERFORM public.coach_challenge_v2_set_goal(challenge,'Late edit forbidden','manual',NULL);
  RAISE EXCEPTION 'Open challenge goal modified';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Open challenge goal modified' THEN RAISE; END IF;
  IF SQLERRM<>'Only drafts can be edited' THEN RAISE; END IF;
 END;
END $test$;
ROLLBACK;
