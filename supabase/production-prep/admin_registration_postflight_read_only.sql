-- READ ONLY: TEST now, PROD only after new FREIGEBEN.
SELECT count(*) AS profiles,count(*) FILTER(WHERE role='admin' AND is_active) AS active_admins,
count(*) FILTER(WHERE is_listed) AS listed,
count(*) FILTER(WHERE NOT is_listed) AS unlisted,
count(*) FILTER(WHERE auth_user_id IS NULL) AS unlinked FROM public.profiles;
SELECT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='auth.users'::regclass AND tgname='on_auth_user_created' AND tgenabled='O') AS trigger_active,
 to_regprocedure('public.admin_list_profiles()') IS NOT NULL AS listing_available,
 to_regprocedure('public.admin_set_profile_role(uuid,text)') IS NOT NULL AS roles_available,
 to_regprocedure('public.admin_set_profile_active(uuid,boolean)') IS NOT NULL AS activation_available,
 to_regprocedure('public.admin_set_profile_listed(uuid,boolean)') IS NOT NULL AS listing_controls_available,
 to_regprocedure('public.admin_set_profile_email(uuid,text)') IS NOT NULL AS email_controls_available;
SELECT proname,pg_get_functiondef(oid) LIKE '%is_listed%' AS private_visibility_checked
FROM pg_proc WHERE pronamespace='public'::regnamespace AND proname IN
('get_public_leaderboard','get_public_levels','get_monthly_awards','get_public_boxer_avatars','get_boxer_duel_score')
ORDER BY proname;
SELECT count(*) AS duplicated_emails FROM
(SELECT lower(email) FROM public.profiles WHERE email IS NOT NULL GROUP BY lower(email) HAVING count(*)>1) d;
SELECT relrowsecurity AS audit_rls_active FROM pg_class WHERE oid='public.profile_admin_audit'::regclass;
