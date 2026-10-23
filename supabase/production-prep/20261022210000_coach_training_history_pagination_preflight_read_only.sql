-- READ ONLY. Run against the intended target before applying the migration.
SELECT jsonb_build_object(
 'project_database',current_database(),
 'migration_target',to_regprocedure('public.coach_list_training_history(text,uuid,bigint,date,date,text,integer,integer)') IS NULL,
 'required_columns_present',(
  SELECT count(*)=11 FROM information_schema.columns
  WHERE table_schema='public' AND table_name='training_submissions'
    AND column_name IN ('id','boxer_id','training_type_id','training_date','notes','status','jogging_km','technique_minutes','created_at','reviewed_at','reviewed_by')
 ) AND EXISTS (
  SELECT 1 FROM information_schema.columns
  WHERE table_schema='public' AND table_name='profiles' AND column_name='auth_user_id'
 ) AND EXISTS (
  SELECT 1 FROM information_schema.columns
  WHERE table_schema='public' AND table_name='training_types' AND column_name='name'
 ),
 'training_rows', (SELECT count(*) FROM public.training_submissions),
 'point_rows', (SELECT count(*) FROM public.point_transactions),
 'enabled_feature_flags', (SELECT coalesce(jsonb_agg(feature_key ORDER BY feature_key),'[]'::jsonb) FROM public.league_feature_flags WHERE is_enabled)
) AS coach_training_history_preflight;
