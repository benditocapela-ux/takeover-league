-- READ ONLY Pre-/Postflight für 20261028160000_admin_set_profile_display_name.sql (Produktion iqarjivcrddcixrvqbfb).
SELECT to_regprocedure('public.admin_set_profile_display_name(uuid,text)') IS NOT NULL AS rpc_present,
 has_function_privilege('anon','public.admin_set_profile_email(uuid,text)','EXECUTE') AS anon_email_reference,
 (SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname='profile_admin_audit_action_check') AS audit_actions;
SELECT count(*) AS profiles, count(DISTINCT lower(display_name)) AS distinct_names,
 (SELECT count(*) FROM public.profile_admin_audit) AS audit_rows FROM public.profiles;
SELECT (SELECT count(*) FROM public.point_transactions) AS pt_rows, (SELECT coalesce(sum(exp),0) FROM public.point_transactions) AS exp_sum,
 (SELECT count(*) FROM public.training_submissions) AS trainings;
