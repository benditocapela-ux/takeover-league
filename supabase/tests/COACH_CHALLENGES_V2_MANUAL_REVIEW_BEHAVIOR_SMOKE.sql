-- Disposable PostgreSQL only. Manual review authorization and one-decision audit.
BEGIN;
INSERT INTO public.profiles(id,auth_user_id,display_name,role,is_active) VALUES
('e0000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','Review coach','coach',true),
('e0000000-0000-0000-0000-000000000002','e1000000-0000-0000-0000-000000000002','Other review coach','coach',true),
('e0000000-0000-0000-0000-000000000003','e1000000-0000-0000-0000-000000000003','Review boxer','boxer',true);
UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='coach_challenges';
DO $test$
DECLARE cid uuid;
BEGIN
 PERFORM set_config('test.auth_uid','e1000000-0000-0000-0000-000000000001',true);
 cid:=public.coach_challenge_v2_create_draft('Manual review smoke','','coach_goal',7);
 PERFORM public.coach_challenge_v2_set_goal(cid,'Improve boxing technique','manual');
 UPDATE public.league_coach_challenges SET status='awaiting_reviews',
 starts_at='2026-09-01 00:00:00+02',ends_at='2026-09-08 00:00:00+02' WHERE id=cid;
 INSERT INTO public.league_coach_challenge_entries(challenge_id,boxer_id)
 VALUES(cid,'e0000000-0000-0000-0000-000000000003');
 PERFORM set_config('test.auth_uid','e1000000-0000-0000-0000-000000000003',true);
 BEGIN
  PERFORM public.coach_challenge_v2_review_manual(cid,'e0000000-0000-0000-0000-000000000003',true,'Boxer approved');
  RAISE EXCEPTION 'Boxer reviewed challenge';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Boxer reviewed challenge' THEN RAISE; END IF;
  IF SQLERRM<>'Coach authorization required' THEN RAISE; END IF;
 END;
 PERFORM set_config('test.auth_uid','e1000000-0000-0000-0000-000000000002',true);
 BEGIN
  PERFORM public.coach_challenge_v2_review_manual(cid,'e0000000-0000-0000-0000-000000000003',true,'Unauthorized review');
  RAISE EXCEPTION 'Other coach reviewed challenge';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Other coach reviewed challenge' THEN RAISE; END IF;
  IF SQLERRM<>'Not challenge owner' THEN RAISE; END IF;
 END;
 PERFORM set_config('test.auth_uid','e1000000-0000-0000-0000-000000000001',true);
 IF public.coach_challenge_v2_review_manual(cid,'e0000000-0000-0000-0000-000000000003',true,'Goal successfully verified')<>'review_recorded' THEN
  RAISE EXCEPTION 'Manual review failed';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.league_coach_challenge_reviews
 WHERE challenge_id=cid AND approved=true AND reviewed_by='e0000000-0000-0000-0000-000000000001') THEN
  RAISE EXCEPTION 'Audit record missing';
 END IF;
 BEGIN
  PERFORM public.coach_challenge_v2_review_manual(cid,'e0000000-0000-0000-0000-000000000003',false,'Attempted duplicate');
  RAISE EXCEPTION 'Duplicate review accepted';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Duplicate review accepted' THEN RAISE; END IF;
  IF SQLERRM<>'Review already recorded' THEN RAISE; END IF;
 END;
 IF EXISTS(SELECT 1 FROM public.league_coach_challenge_exp_ledger WHERE challenge_id=cid) THEN
  RAISE EXCEPTION 'Review issued EXP without settlement';
 END IF;
END $test$;
ROLLBACK;
