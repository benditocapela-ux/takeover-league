-- TEST PROJECT ONLY: registration-role visibility and admin RPC rollback fixture.
-- Auth signup trigger source is checked in this fixture; end-to-end signUp
-- requires a real test registration through Supabase Auth (not simulated here).
BEGIN;
DO $init$
DECLARE a record;c record;b record;t record;pid uuid:=gen_random_uuid();submission uuid;
BEGIN
 IF to_regclass('public.league_test_boxers') IS NULL THEN RAISE EXCEPTION 'TEST ONLY'; END IF;
 SELECT p.id,p.auth_user_id INTO a FROM public.profiles p JOIN auth.users u ON u.id=p.auth_user_id
 WHERE p.role='admin' AND p.is_active LIMIT 1;
 SELECT p.id,p.auth_user_id INTO c FROM public.profiles p JOIN auth.users u ON u.id=p.auth_user_id
 WHERE p.role='coach' AND p.is_active LIMIT 1;
 SELECT p.id,p.auth_user_id INTO b FROM public.profiles p JOIN auth.users u ON u.id=p.auth_user_id
 WHERE p.role='boxer' AND p.is_active LIMIT 1;
 SELECT id,points INTO t FROM public.training_types WHERE is_active ORDER BY id LIMIT 1;
 IF a.id IS NULL OR b.id IS NULL OR c.id IS NULL OR t.id IS NULL THEN RAISE EXCEPTION 'Missing linked test identities'; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='on_auth_user_created' AND tgrelid='auth.users'::regclass AND tgenabled='O')
 THEN RAISE EXCEPTION 'Auth signup trigger missing'; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_proc p WHERE p.pronamespace='public'::regnamespace AND p.proname='handle_new_user' AND p.prosecdef)
 THEN RAISE EXCEPTION 'Security definer signup trigger missing'; END IF;
 INSERT INTO public.profiles(id,display_name,role,is_active,is_listed)
 VALUES(pid,'Sicherheitsprüfung Boxer','boxer',true,false);
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,status,notes,jogging_km)
 VALUES(pid,t.id,CURRENT_DATE,'approved','Admin fixture ROLLBACK',50.0)
 RETURNING id INTO submission;
 INSERT INTO public.point_transactions(boxer_id,submission_id,points,exp,category,description,effective_date)
 VALUES(pid,submission,400,400,'training','Admin fixture ROLLBACK',CURRENT_DATE);
 IF EXISTS(SELECT 1 FROM public.get_public_leaderboard() WHERE boxer_name='Sicherheitsprüfung Boxer') OR
    EXISTS(SELECT 1 FROM public.get_public_levels() WHERE boxer_name='Sicherheitsprüfung Boxer') OR
    EXISTS(SELECT 1 FROM public.get_monthly_awards(CURRENT_DATE) WHERE boxer_name='Sicherheitsprüfung Boxer') OR
    EXISTS(SELECT 1 FROM public.get_public_boxer_avatars() WHERE boxer_name='Sicherheitsprüfung Boxer')
 THEN RAISE EXCEPTION 'Private/unlisted test boxer appears in public projection'; END IF;
 PERFORM set_config('ar.admin',a.auth_user_id::text,true);
 PERFORM set_config('ar.admin_id',a.id::text,true);
 PERFORM set_config('ar.coach',c.auth_user_id::text,true);
 PERFORM set_config('ar.coach_id',c.id::text,true);
 PERFORM set_config('ar.boxer',b.auth_user_id::text,true);
 PERFORM set_config('ar.target',pid::text,true);
 RAISE NOTICE 'PASS: trigger installed, private boxer hidden in four public read APIs';
END $init$;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',current_setting('ar.admin'),true);
DO $admin$
DECLARE target uuid:=current_setting('ar.target')::uuid; n integer;denied boolean;
BEGIN
 SELECT count(*) INTO n FROM public.admin_list_profiles();
 IF n<4 THEN RAISE EXCEPTION 'Admin list omitted test row'; END IF;
 IF pg_get_function_result('public.admin_list_profiles()'::regprocedure) ILIKE '%auth_user_id%' THEN
  RAISE EXCEPTION 'Admin list leaks auth_user_id'; END IF;
 PERFORM public.admin_set_profile_email(target,'  FOO.BAR@Takeover.Test  ');
 IF NOT EXISTS(SELECT 1 FROM public.profiles WHERE id=target AND email='foo.bar@takeover.test')
 THEN RAISE EXCEPTION 'Admin email normalization failed';END IF;
 PERFORM public.admin_set_profile_role(target,'coach');
 PERFORM public.admin_set_profile_role(target,'boxer');
 PERFORM public.admin_set_profile_active(target,false);
 PERFORM public.admin_set_profile_active(target,true);
 PERFORM public.admin_set_profile_listed(target,true);
 IF NOT EXISTS(SELECT 1 FROM public.get_public_leaderboard() WHERE boxer_name='Sicherheitsprüfung Boxer') OR
    NOT EXISTS(SELECT 1 FROM public.get_public_levels() WHERE boxer_name='Sicherheitsprüfung Boxer') OR
    NOT EXISTS(SELECT 1 FROM public.get_public_boxer_avatars() WHERE boxer_name='Sicherheitsprüfung Boxer')
 THEN RAISE EXCEPTION 'Approved boxer still hidden';END IF;
 PERFORM public.admin_set_profile_listed(target,false);
 IF EXISTS(SELECT 1 FROM public.get_public_levels() WHERE boxer_name='Sicherheitsprüfung Boxer') THEN
  RAISE EXCEPTION 'Unlisted profile remains public';END IF;
 SELECT count(*) INTO n FROM public.profile_admin_audit WHERE profile_id=target AND changed_by=current_setting('ar.admin_id')::uuid;
 IF n<6 THEN RAISE EXCEPTION 'Admin audit too short';END IF;
 denied:=false;
 BEGIN PERFORM public.admin_set_profile_active(current_setting('ar.admin_id')::uuid,false);
 EXCEPTION WHEN SQLSTATE '42501' THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'Last admin may be disabled';END IF;
 denied:=false;
 BEGIN PERFORM public.admin_set_profile_role(current_setting('ar.admin_id')::uuid,'boxer');
 EXCEPTION WHEN SQLSTATE '42501' THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'Admin may be demoted';END IF;
 denied:=false;
 BEGIN PERFORM public.admin_set_profile_role(target,'admin');
 EXCEPTION WHEN SQLSTATE '22023' THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'Untrusted promotion to admin possible';END IF;
 RAISE NOTICE 'PASS: role and visibility changes, activation, email, audit, last-admin guard';
END $admin$;
SELECT set_config('request.jwt.claim.sub',current_setting('ar.boxer'),true);
DO $boxer$
DECLARE blocked boolean:=false;
BEGIN
 BEGIN PERFORM public.admin_set_profile_role(current_setting('ar.target')::uuid,'coach');
 EXCEPTION WHEN SQLSTATE '42501' THEN blocked:=true;END;
 IF NOT blocked THEN RAISE EXCEPTION 'Regular boxer may promote self or others';END IF;
 blocked:=false;
 BEGIN PERFORM 1 FROM public.admin_list_profiles();
 EXCEPTION WHEN SQLSTATE '42501' THEN blocked:=true;END;
 IF NOT blocked THEN RAISE EXCEPTION 'Regular boxer can read administration list';END IF;
 RAISE NOTICE 'PASS: boxer cannot manage accounts';
END $boxer$;
SELECT set_config('request.jwt.claim.sub',current_setting('ar.admin'),true);
SELECT public.admin_set_profile_active(current_setting('ar.coach_id')::uuid,false);
SELECT set_config('request.jwt.claim.sub',current_setting('ar.coach'),true);
DO $coach$
DECLARE denied boolean:=false;
BEGIN
 IF public.is_league_coach() THEN RAISE EXCEPTION 'Deactivated coach retains permissions';END IF;
 BEGIN PERFORM 1 FROM public.coach_list_boxers();
 EXCEPTION WHEN SQLSTATE '42501' THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'Inactive coach reads boxer list';END IF;
 RAISE NOTICE 'PASS: deactivated coach access blocked';
END $coach$;
RESET ROLE;
ROLLBACK;