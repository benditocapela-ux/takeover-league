-- STAGING ONLY. Entire fixture is rolled back.
BEGIN;
SELECT set_config('s21.admin',(SELECT auth_user_id::text FROM public.profiles
 WHERE role='admin' AND is_active AND auth_user_id IS NOT NULL LIMIT 1),true);
SELECT set_config('s21.boxer',(SELECT auth_user_id::text FROM public.profiles
 WHERE role='boxer' AND is_active AND auth_user_id IS NOT NULL LIMIT 1),true);
SELECT set_config('s21.owner',(SELECT id::text FROM public.profiles
 WHERE role='boxer' AND is_active AND auth_user_id IS NOT NULL LIMIT 1),true);
SELECT set_config('request.jwt.claim.sub',current_setting('s21.boxer'),true);
SET LOCAL ROLE authenticated;
DO $security$ BEGIN
 BEGIN
  PERFORM public.league_v21_admin_create_season('Test expired season',
    current_date-450,current_date-420);
  RAISE EXCEPTION 'Boxer created privileged season';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
END $security$;
SELECT set_config('request.jwt.claim.sub',current_setting('s21.admin'),true);
SELECT set_config('s21.id',public.league_v21_admin_create_season('Test expired season',
 current_date-450,current_date-420)::text,true);
SELECT public.league_v21_admin_season_action(current_setting('s21.id')::uuid,'activate');
RESET ROLE;
WITH inserted AS (
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,status,created_at)
 VALUES(current_setting('s21.owner')::uuid,
  (SELECT id FROM public.training_types WHERE is_active ORDER BY id LIMIT 1),
  current_date-430,'pending',now()-interval '430 days')
 RETURNING id
) SELECT set_config('s21.submission',id::text,true) FROM inserted;
SET LOCAL ROLE authenticated;
DO $assert$ BEGIN
 BEGIN
  PERFORM public.league_v21_admin_season_action(current_setting('s21.id')::uuid,'close');
  RAISE EXCEPTION 'Season closed with unreviewed training';
 EXCEPTION WHEN check_violation THEN NULL;
 END;
END $assert$;
RESET ROLE;
UPDATE public.training_submissions SET status='rejected'
 WHERE id=current_setting('s21.submission')::uuid;
SET LOCAL ROLE authenticated;
DO $assert$
DECLARE result jsonb; repeat jsonb; begin
 SELECT public.league_v21_admin_season_action(current_setting('s21.id')::uuid,'close') INTO result;
 SELECT public.league_v21_admin_season_action(current_setting('s21.id')::uuid,'close') INTO repeat;
 IF result->>'status'<>'closed' OR repeat->>'unchanged'<>'true' THEN
  RAISE EXCEPTION 'Season settlement/duplicate closure failed %, %',result,repeat;
 END IF;
END $assert$;
RESET ROLE;
DO $assert$ BEGIN
 IF (SELECT count(*) FROM public.league_season_results_v21
   WHERE season_id=current_setting('s21.id')::uuid)<2 THEN
  RAISE EXCEPTION 'Final season standings missing active boxer results';
 END IF;
 IF (SELECT count(*) FROM public.league_season_results_v21
   WHERE season_id=current_setting('s21.id')::uuid AND rank_position=1)<2 THEN
  RAISE EXCEPTION 'Equal zero-score boxers must share rank 1';
 END IF;
 IF (SELECT count(*) FROM public.league_hall_of_fame_v21
   WHERE season_id=current_setting('s21.id')::uuid)<2 THEN
  RAISE EXCEPTION 'Tied podium winners missing public honors';
 END IF;
END $assert$;
ROLLBACK;