-- READ ONLY: before any future production FREIGEBEN.
SELECT role,is_active,count(*) AS profile_count,count(*) FILTER(WHERE auth_user_id IS NULL) AS no_account
 FROM public.profiles GROUP BY role,is_active ORDER BY role,is_active;
SELECT p.display_name,count(DISTINCT s.id) AS trainings,count(DISTINCT t.id) AS ledger_entries
FROM public.profiles p
LEFT JOIN public.training_submissions s ON s.boxer_id=p.id
LEFT JOIN public.point_transactions t ON t.boxer_id=p.id
WHERE p.auth_user_id IS NULL
GROUP BY p.id,p.display_name ORDER BY p.display_name;
SELECT (SELECT count(*) FROM pg_trigger WHERE tgrelid='auth.users'::regclass AND NOT tgisinternal)
 AS existing_auth_triggers,
 to_regprocedure('public.is_league_admin()') IS NOT NULL AS admin_guard,
 to_regprocedure('public.is_league_coach()') IS NOT NULL AS coach_guard;
