-- Disposable PostgreSQL only. Draft editing access and state.
BEGIN;
INSERT INTO public.profiles(id,auth_user_id,display_name,role,is_active) VALUES
('f0000000-0000-0000-0000-000000000001','f1000000-0000-0000-0000-000000000001','Coach A','coach',true),
('f0000000-0000-0000-0000-000000000002','f1000000-0000-0000-0000-000000000002','Coach B','coach',true),
('f0000000-0000-0000-0000-000000000003','f1000000-0000-0000-0000-000000000003','Boxer','boxer',true);
UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='coach_challenges';
SELECT set_config('test.auth_uid','f1000000-0000-0000-0000-000000000001',true);
DO $test$
DECLARE cid uuid;
BEGIN
 cid:=public.coach_challenge_v2_create_draft('Old title','Old','individual',7);
 PERFORM set_config('test.auth_uid','f1000000-0000-0000-0000-000000000002',true);
 BEGIN
  PERFORM public.coach_challenge_v2_edit_draft(cid,'Other title','','competition',14);
  RAISE EXCEPTION 'Other coach edited draft';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Other coach edited draft' OR SQLERRM<>'Not challenge owner' THEN RAISE; END IF;
 END;
 PERFORM set_config('test.auth_uid','f1000000-0000-0000-0000-000000000003',true);
 BEGIN
  PERFORM public.coach_challenge_v2_edit_draft(cid,'Boxer title','','competition',14);
  RAISE EXCEPTION 'Boxer edited draft';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Boxer edited draft' OR SQLERRM<>'Coach authorization required' THEN RAISE; END IF;
 END;
 PERFORM set_config('test.auth_uid','f1000000-0000-0000-0000-000000000001',true);
 BEGIN
  PERFORM public.coach_challenge_v2_edit_draft(cid,'X','','competition',14);
  RAISE EXCEPTION 'Invalid title accepted';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Invalid title accepted' OR SQLERRM<>'Invalid draft fields' THEN RAISE; END IF;
 END;
 IF public.coach_challenge_v2_edit_draft(cid,'New title','New description','competition',14)<>'updated'
 THEN RAISE EXCEPTION 'Draft edit failed'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.league_coach_challenges
 WHERE id=cid AND title='New title' AND description='New description'
 AND challenge_kind='competition' AND duration_days=14 AND status='draft')
 THEN RAISE EXCEPTION 'Draft changes not persisted'; END IF;
 PERFORM public.coach_challenge_v2_manage(cid,'open');
 BEGIN
  PERFORM public.coach_challenge_v2_edit_draft(cid,'Changed again','','individual',7);
  RAISE EXCEPTION 'Open challenge edited';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Open challenge edited' OR SQLERRM<>'Only drafts can be edited' THEN RAISE; END IF;
 END;
END $test$;
ROLLBACK;
