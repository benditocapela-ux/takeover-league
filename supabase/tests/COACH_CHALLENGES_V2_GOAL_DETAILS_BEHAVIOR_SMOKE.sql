-- Disposable PostgreSQL only: draft goal details visible only to owner or admin.
BEGIN;
INSERT INTO public.profiles(id,auth_user_id,display_name,role,is_active) VALUES
('e0000000-0000-0000-0000-000000000051','e1000000-0000-0000-0000-000000000051','Owner coach','coach',true),
('e0000000-0000-0000-0000-000000000052','e1000000-0000-0000-0000-000000000052','Other coach','coach',true),
('e0000000-0000-0000-0000-000000000053','e1000000-0000-0000-0000-000000000053','Boxer','boxer',true);
UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='coach_challenges';
DO $test$
DECLARE cid uuid; details jsonb;
BEGIN
 PERFORM set_config('test.auth_uid','e1000000-0000-0000-0000-000000000051',true);
 cid:=public.coach_challenge_v2_create_draft('Goal details smoke','','individual',7);
 details:=public.coach_challenge_v2_goal_details(cid);
 IF details<>'{}'::jsonb THEN RAISE EXCEPTION 'New draft details not empty'; END IF;
 PERFORM public.coach_challenge_v2_save_goal_reward(cid,'Improve boxing footwork','manual',150);
 details:=public.coach_challenge_v2_goal_details(cid);
 IF details->>'goal_text'<>'Improve boxing footwork' OR details->>'reward_exp'<>'150'
 THEN RAISE EXCEPTION 'Saved draft goal not returned'; END IF;
 PERFORM set_config('test.auth_uid','e1000000-0000-0000-0000-000000000052',true);
 BEGIN
  PERFORM public.coach_challenge_v2_goal_details(cid);
  RAISE EXCEPTION 'Other coach read private draft goal';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Other coach read private draft goal' THEN RAISE; END IF;
  IF SQLERRM<>'Not challenge owner' THEN RAISE; END IF;
 END;
 PERFORM set_config('test.auth_uid','e1000000-0000-0000-0000-000000000053',true);
 BEGIN
  PERFORM public.coach_challenge_v2_goal_details(cid);
  RAISE EXCEPTION 'Boxer read private draft goal';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Boxer read private draft goal' THEN RAISE; END IF;
  IF SQLERRM<>'Coach authorization required' THEN RAISE; END IF;
 END;
 PERFORM set_config('test.auth_uid','e1000000-0000-0000-0000-000000000051',true);
 UPDATE public.league_coach_challenges SET status='open' WHERE id=cid;
 BEGIN
  PERFORM public.coach_challenge_v2_goal_details(cid);
  RAISE EXCEPTION 'Open goal editable via draft reader';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Open goal editable via draft reader' THEN RAISE; END IF;
  IF SQLERRM<>'Only drafts can be edited' THEN RAISE; END IF;
 END;
END $test$;
ROLLBACK;
