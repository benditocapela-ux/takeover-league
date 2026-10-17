-- Disposable PostgreSQL only: execute automatic progress against real synthetic submissions.
BEGIN;
INSERT INTO public.profiles(id,auth_user_id,display_name,role,is_active) VALUES
('f0000000-0000-0000-0000-000000000001','f1000000-0000-0000-0000-000000000001','Progress coach','coach',true),
('f0000000-0000-0000-0000-000000000002','f1000000-0000-0000-0000-000000000002','Other coach','coach',true),
('f0000000-0000-0000-0000-000000000003','f1000000-0000-0000-0000-000000000003','Progress boxer','boxer',true);
UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='coach_challenges';
DO $test$
DECLARE cid uuid; coach_id uuid := 'f0000000-0000-0000-0000-000000000001';
 boxer_id uuid := 'f0000000-0000-0000-0000-000000000003'; v numeric;
BEGIN
 PERFORM set_config('test.auth_uid','f1000000-0000-0000-0000-000000000001',true);
 cid:=public.coach_challenge_v2_create_draft('Progress smoke','','individual',7);
 PERFORM public.coach_challenge_v2_set_goal(cid,'Complete approved road work','automatic',10,'jogging_km');
 UPDATE public.league_coach_challenges SET status='active',
 starts_at='2026-10-01 00:00:00+02',ends_at='2026-10-08 00:00:00+02'
 WHERE id=cid;
 INSERT INTO public.league_coach_challenge_entries(challenge_id,boxer_id)
 VALUES(cid,boxer_id);
 INSERT INTO public.training_submissions(id,boxer_id,training_date,status,jogging_km) VALUES
 ('f2000000-0000-0000-0000-000000000001',boxer_id,'2026-10-02','approved',6),
 ('f2000000-0000-0000-0000-000000000002',boxer_id,'2026-10-03','pending',50),
 ('f2000000-0000-0000-0000-000000000003',boxer_id,'2026-09-30','approved',50),
 ('f2000000-0000-0000-0000-000000000004',boxer_id,'2026-10-07','approved',4),
 ('f2000000-0000-0000-0000-000000000005',boxer_id,'2026-10-08','approved',50);
 SELECT achieved INTO v FROM public.coach_challenge_v2_progress(cid);
 IF v<>10 THEN RAISE EXCEPTION 'Approved training window progress incorrect: %',v; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.coach_challenge_v2_progress(cid)
 WHERE completed=true AND target=10) THEN RAISE EXCEPTION 'Completion incorrect'; END IF;
 PERFORM set_config('test.auth_uid','f1000000-0000-0000-0000-000000000003',true);
 IF (SELECT count(*) FROM public.coach_challenge_v2_progress(cid))<>1 THEN
  RAISE EXCEPTION 'Boxer cannot read own progress';
 END IF;
 PERFORM set_config('test.auth_uid','f1000000-0000-0000-0000-000000000002',true);
 BEGIN
  PERFORM public.coach_challenge_v2_progress(cid);
  RAISE EXCEPTION 'Other coach accessed progress';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Other coach accessed progress' THEN RAISE; END IF;
  IF SQLERRM<>'Not challenge owner' THEN RAISE; END IF;
 END;
END $test$;
ROLLBACK;
