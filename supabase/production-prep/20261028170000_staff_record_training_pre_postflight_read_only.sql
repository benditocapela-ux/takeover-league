-- READ ONLY Pre-/Postflight für 20261028170000_staff_record_training.sql (Produktion iqarjivcrddcixrvqbfb).
-- Vorher: review_training muss der geprüften Version entsprechen (md5 27.10.2026).
SELECT md5(pg_get_functiondef('public.review_training(uuid,text)'::regprocedure)) AS review_md5,
 '5750d61913043bc4666aa6d6eb707252' AS expected,
 to_regprocedure('league_v21_private.require_training_details()') IS NOT NULL AS required_details_trigger_fn,
 to_regprocedure('public.staff_record_training(uuid,bigint,date,integer,text,numeric,uuid)') IS NOT NULL AS rpc_present,
 (SELECT count(*) FROM information_schema.columns WHERE table_schema='public' AND table_name='training_submissions' AND column_name='recorded_by') AS recorded_by_column;
SELECT has_function_privilege('anon','public.staff_record_training(uuid,bigint,date,integer,text,numeric,uuid)','EXECUTE') AS anon_exec
WHERE to_regprocedure('public.staff_record_training(uuid,bigint,date,integer,text,numeric,uuid)') IS NOT NULL;
SELECT (SELECT count(*) FROM public.point_transactions) AS pt_rows, (SELECT coalesce(sum(exp),0) FROM public.point_transactions) AS exp_sum,
 (SELECT coalesce(sum(points),0) FROM public.point_transactions) AS points_sum, (SELECT count(*) FROM public.training_submissions) AS trainings;
