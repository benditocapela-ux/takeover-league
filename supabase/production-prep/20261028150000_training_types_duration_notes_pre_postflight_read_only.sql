-- READ ONLY Pre-/Postflight für 20261028150000_training_types_duration_notes.sql (Produktion iqarjivcrddcixrvqbfb).
-- Vorher: Bonusfunktionen müssen der geprüften Version entsprechen (md5 vom 27.10.2026).
SELECT p.oid::regprocedure AS fn, md5(pg_get_functiondef(p.oid)) AS md5,
 CASE p.oid::regprocedure::text
  WHEN 'recalculate_boxer_bonuses(uuid)' THEN '24cc76de6220ba40685f7988ad168033'
  WHEN 'league_private.coach_training_bonus_refresh(uuid)' THEN 'd801cebb44393261cb17be787a2e07b1' END AS expected_before,
 (SELECT count(*) FROM regexp_matches(pg_get_functiondef(p.oid), '''Sparring''', 'g')) AS sparring_literals,
 (SELECT count(*) FROM regexp_matches(pg_get_functiondef(p.oid), '''Wettkampfsparring''', 'g')) AS wettkampfsparring_literals
FROM pg_proc p WHERE p.proname IN ('recalculate_boxer_bonuses','coach_training_bonus_refresh');
-- Trainingsarten (vorher 6, nachher 15 in 5 Bereichen)
SELECT id, name, points, is_active,
 (SELECT column_name FROM information_schema.columns WHERE table_schema='public' AND table_name='training_types' AND column_name='category') AS has_category
FROM public.training_types ORDER BY id;
-- Pflichtprüfung und Spalten
SELECT (SELECT count(*) FROM pg_trigger WHERE tgname='league_v21_require_training_details') AS require_trigger,
 (SELECT count(*) FROM information_schema.columns WHERE table_schema='public' AND column_name='duration_minutes'
   AND table_name IN ('training_submissions','training_drafts_v2')) AS duration_columns;
-- Daten dürfen sich nicht ändern
SELECT (SELECT count(*) FROM public.point_transactions) AS pt_rows, (SELECT coalesce(sum(exp),0) FROM public.point_transactions) AS exp_sum,
 (SELECT coalesce(sum(points),0) FROM public.point_transactions) AS points_sum, (SELECT count(*) FROM public.training_submissions) AS trainings,
 (SELECT count(*) FROM public.training_submissions WHERE status='pending') AS pending;
