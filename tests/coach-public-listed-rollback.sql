-- Only the isolated test project; ROLLBACK deliberately removes every test change.
-- Verifies "coach is boxer" and unpublished profile privacy in all public rankings.
BEGIN;
DO $fixture$
DECLARE c record;tt bigint;sid uuid;
BEGIN
 IF to_regclass('public.league_test_boxers') IS NULL THEN RAISE EXCEPTION 'TEST ONLY'; END IF;
 SELECT id,display_name INTO c FROM public.profiles WHERE role='coach' AND is_active LIMIT 1;
 IF c.id IS NULL THEN RAISE EXCEPTION 'no active test coach'; END IF;
 SELECT id INTO tt FROM public.training_types WHERE is_active LIMIT 1;
 UPDATE public.profiles SET is_listed=false WHERE id=c.id;
 IF EXISTS(SELECT 1 FROM public.get_award_leaderboard('consistent','month') a WHERE a.boxer_name=c.display_name)
  OR EXISTS(SELECT 1 FROM public.get_public_levels() l WHERE l.boxer_name=c.display_name)
  OR EXISTS(SELECT 1 FROM public.get_public_boxer_avatars() l WHERE l.boxer_name=c.display_name)
  OR EXISTS(SELECT 1 FROM public.get_public_leaderboard() l WHERE l.boxer_name=c.display_name)
  OR EXISTS(SELECT 1 FROM public.get_monthly_awards(CURRENT_DATE) l WHERE l.boxer_name=c.display_name)
 THEN RAISE EXCEPTION 'Coach appears publicly while unlisted';END IF;
 UPDATE public.profiles SET is_listed=true WHERE id=c.id;
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,status,notes)
 VALUES(c.id,tt,CURRENT_DATE,'approved','Coach listing test ROLLBACK') RETURNING id INTO sid;
 INSERT INTO public.point_transactions(boxer_id,submission_id,points,exp,category,description,effective_date)
 VALUES(c.id,sid,150,150,'training','Coach listing test ROLLBACK',CURRENT_DATE);
 IF NOT EXISTS(SELECT 1 FROM public.get_award_leaderboard('consistent','month') a WHERE a.boxer_name=c.display_name)
 OR NOT EXISTS(SELECT 1 FROM public.get_public_levels() a WHERE a.boxer_name=c.display_name)
 OR NOT EXISTS(SELECT 1 FROM public.get_public_leaderboard() a WHERE a.boxer_name=c.display_name)
 OR NOT EXISTS(SELECT 1 FROM public.get_public_boxer_avatars() a WHERE a.boxer_name=c.display_name)
 THEN RAISE EXCEPTION 'Active listed coach with approved session missing from public rankings';END IF;
 RAISE NOTICE 'PASS: Coach publicly listed when allowed and hidden when not';
END $fixture$;
ROLLBACK;
