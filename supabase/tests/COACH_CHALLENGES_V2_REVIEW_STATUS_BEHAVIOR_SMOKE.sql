-- Disposable PostgreSQL only: verify coach and boxer review visibility.
BEGIN;
INSERT INTO public.profiles(id,auth_user_id,display_name,role,is_active) VALUES
('d0000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001','Status coach','coach',true),
('d0000000-0000-0000-0000-000000000002','d1000000-0000-0000-0000-000000000002','Other status coach','coach',true),
('d0000000-0000-0000-0000-000000000003','d1000000-0000-0000-0000-000000000003','Status boxer','boxer',true),
('d0000000-0000-0000-0000-000000000004','d1000000-0000-0000-0000-000000000004','Other status boxer','boxer',true);
UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='coach_challenges';
DO $test$
DECLARE cid uuid; v_reason text;
BEGIN
 PERFORM set_config('test.auth_uid','d1000000-0000-0000-0000-000000000001',true);
 cid:=public.coach_challenge_v2_create_draft('Status smoke','','coach_goal',7);
 PERFORM public.coach_challenge_v2_set_goal(cid,'Improve guard and movement','manual');
 UPDATE public.league_coach_challenges SET status='awaiting_reviews',
 starts_at='2026-09-01 00:00:00+02',ends_at='2026-09-08 00:00:00+02' WHERE id=cid;
 INSERT INTO public.league_coach_challenge_entries(challenge_id,boxer_id)
 VALUES(cid,'d0000000-0000-0000-0000-000000000003');
 PERFORM public.coach_challenge_v2_review_manual(
 cid,'d0000000-0000-0000-0000-000000000003',true,'Technique improved markedly');
 SELECT reason INTO v_reason FROM public.coach_challenge_v2_review_status(cid);
 IF v_reason<>'Technique improved markedly' THEN RAISE EXCEPTION 'Coach review reason missing'; END IF;
 PERFORM set_config('test.auth_uid','d1000000-0000-0000-0000-000000000003',true);
 IF (SELECT count(*) FROM public.coach_challenge_v2_review_status(cid))<>1 THEN
  RAISE EXCEPTION 'Boxer review not visible';
 END IF;
 IF EXISTS(SELECT 1 FROM public.coach_challenge_v2_review_status(cid) WHERE reason IS NOT NULL) THEN
  RAISE EXCEPTION 'Private coach reason leaked';
 END IF;
 PERFORM set_config('test.auth_uid','d1000000-0000-0000-0000-000000000004',true);
 IF EXISTS(SELECT 1 FROM public.coach_challenge_v2_review_status(cid)) THEN
  RAISE EXCEPTION 'Other boxer can see private decision';
 END IF;
 PERFORM set_config('test.auth_uid','d1000000-0000-0000-0000-000000000002',true);
 BEGIN
  PERFORM public.coach_challenge_v2_review_status(cid);
  RAISE EXCEPTION 'Other coach accessed decision';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Other coach accessed decision' THEN RAISE; END IF;
  IF SQLERRM<>'Not challenge owner' THEN RAISE; END IF;
 END;
END $test$;
ROLLBACK;
