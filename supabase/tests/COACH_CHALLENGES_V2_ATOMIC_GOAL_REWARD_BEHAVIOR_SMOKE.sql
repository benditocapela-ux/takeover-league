-- Disposable PostgreSQL only. Atomic goal+reward validation.
BEGIN;
INSERT INTO public.profiles(id,auth_user_id,display_name,role,is_active) VALUES
('e0000000-0000-0000-0000-000000000031','e1000000-0000-0000-0000-000000000031','Goal coach','coach',true);
UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='coach_challenges';
DO $test$
DECLARE cid uuid; spec jsonb;
BEGIN
 PERFORM set_config('test.auth_uid','e1000000-0000-0000-0000-000000000031',true);
 cid:=public.coach_challenge_v2_create_draft('Atomic goal smoke','','coach_goal',7);
 IF public.coach_challenge_v2_save_goal_reward(cid,'Improve footwork','manual',150)<>'goal_reward_saved'
 THEN RAISE EXCEPTION 'Atomic save failed'; END IF;
 SELECT goal_spec INTO spec FROM public.league_coach_challenges WHERE id=cid;
 IF spec->>'goal_text'<>'Improve footwork' OR spec->>'reward_exp'<>'150'
 OR spec->>'review_mode'<>'manual' THEN RAISE EXCEPTION 'Goal reward mismatch'; END IF;
 BEGIN
  PERFORM public.coach_challenge_v2_save_goal_reward(cid,'Changed text','manual',99);
  RAISE EXCEPTION 'Unsupported reward accepted';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Unsupported reward accepted' THEN RAISE; END IF;
  IF SQLERRM<>'Invalid challenge goal or reward' THEN RAISE; END IF;
 END;
 IF (SELECT goal_spec FROM public.league_coach_challenges WHERE id=cid)<>spec
 THEN RAISE EXCEPTION 'Failed save mutated goal'; END IF;
 UPDATE public.league_coach_challenges SET status='open' WHERE id=cid;
 BEGIN
  PERFORM public.coach_challenge_v2_save_goal_reward(cid,'Another goal','manual',100);
  RAISE EXCEPTION 'Open challenge edited';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Open challenge edited' THEN RAISE; END IF;
  IF SQLERRM<>'Only drafts can be edited' THEN RAISE; END IF;
 END;
 IF EXISTS(SELECT 1 FROM public.league_coach_challenge_exp_ledger WHERE challenge_id=cid)
 THEN RAISE EXCEPTION 'Saving goal awarded EXP'; END IF;
END $test$;
ROLLBACK;
