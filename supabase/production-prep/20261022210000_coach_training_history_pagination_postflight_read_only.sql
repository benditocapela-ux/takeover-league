-- READ ONLY. Run after applying the migration; does not call or mutate the RPC.
SELECT jsonb_build_object(
 'function_exists',to_regprocedure('public.coach_list_training_history(text,uuid,bigint,date,date,text,integer,integer)') IS NOT NULL,
 'security_definer',(
  SELECT p.prosecdef FROM pg_proc p
  WHERE p.oid=to_regprocedure('public.coach_list_training_history(text,uuid,bigint,date,date,text,integer,integer)')
 ),
 'authenticated_can_execute',has_function_privilege('authenticated','public.coach_list_training_history(text,uuid,bigint,date,date,text,integer,integer)','EXECUTE'),
 'anon_cannot_execute',NOT has_function_privilege('anon','public.coach_list_training_history(text,uuid,bigint,date,date,text,integer,integer)','EXECUTE'),
 'public_cannot_execute',NOT has_function_privilege('public','public.coach_list_training_history(text,uuid,bigint,date,date,text,integer,integer)','EXECUTE'),
 'training_rows', (SELECT count(*) FROM public.training_submissions),
 'point_rows', (SELECT count(*) FROM public.point_transactions),
 'enabled_feature_flags', (SELECT coalesce(jsonb_agg(feature_key ORDER BY feature_key),'[]'::jsonb) FROM public.league_feature_flags WHERE is_enabled)
) AS coach_training_history_postflight;
