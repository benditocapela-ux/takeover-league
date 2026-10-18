-- Disposable PostgreSQL only. Activation validation and one-way transition.
BEGIN;
INSERT INTO public.profiles(id,auth_user_id,display_name,role,is_active) VALUES
('e0000000-0000-0000-0000-000000000021','e1000000-0000-0000-0000-000000000021','Activation coach','coach',true),
('e0000000-0000-0000-0000-000000000022','e1000000-0000-0000-0000-000000000022','Activation boxer','boxer',true);
UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='coach_challenges';
DO $test$
DECLARE cid uuid; v_result text;
BEGIN
 PERFORM set_config('test.auth_uid','e1000000-0000-0000-0000-000000000021',true);
 cid:=public.coach_challenge_v2_create_draft('Activation smoke','','coach_goal',7);
 UPDATE public.league_coach_challenges SET status='open',goal_spec='{}'::jsonb WHERE id=cid;
 INSERT INTO public.league_coach_challenge_entries(challenge_id,boxer_id)
 VALUES(cid,'e0000000-0000-0000-0000-000000000022');
 BEGIN
  PERFORM public.coach_challenge_v2_activate(cid);
  RAISE EXCEPTION 'Empty goal was activated';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Empty goal was activated' THEN RAISE; END IF;
  IF SQLERRM<>'Valid goal required before activation' THEN RAISE; END IF;
 END;
 UPDATE public.league_coach_challenges SET status='draft' WHERE id=cid;
 PERFORM public.coach_challenge_v2_save_goal_reward(cid,'Attend technique practice','manual',100);
 UPDATE public.league_coach_challenges SET status='open' WHERE id=cid;
 v_result:=public.coach_challenge_v2_activate(cid);
 IF v_result<>'active' THEN RAISE EXCEPTION 'Activation did not return active'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.league_coach_challenges WHERE id=cid AND status='active'
 AND starts_at IS NOT NULL AND ends_at=starts_at+interval '7 days') THEN
 RAISE EXCEPTION 'Activation clock mismatch'; END IF;
 BEGIN
  PERFORM public.coach_challenge_v2_activate(cid);
  RAISE EXCEPTION 'Double activation accepted';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Double activation accepted' THEN RAISE; END IF;
  IF SQLERRM<>'Only open challenges can activate' THEN RAISE; END IF;
 END;
 IF EXISTS(SELECT 1 FROM public.league_coach_challenge_exp_ledger WHERE challenge_id=cid)
 THEN RAISE EXCEPTION 'Activation awarded EXP'; END IF;
END $test$;
ROLLBACK;
