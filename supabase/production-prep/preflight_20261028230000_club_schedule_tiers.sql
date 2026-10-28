-- Read-only Preflight vor 20261028230000_club_schedule_tiers.sql (ändert nichts).
SELECT 'Etappe 5 vorhanden' AS check_name, (to_regprocedure('league_private.kg_pass_points(uuid,date)') IS NOT NULL AND to_regclass('public.kg_pass_tiers') IS NOT NULL)::text AS ok
UNION ALL SELECT 'admin_edit_training und training_audit vorhanden', (to_regprocedure('public.admin_edit_training(uuid,uuid,bigint,date,text,text)') IS NOT NULL AND to_regclass('public.training_audit') IS NOT NULL)::text
UNION ALL SELECT 'Genau eine Punktebuchung pro Training (UNIQUE submission_id)', EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.point_transactions'::regclass AND contype='u' AND pg_get_constraintdef(oid)='UNIQUE (submission_id)')::text
UNION ALL SELECT 'Trainingsarten für den Stundenplan vorhanden', ((SELECT count(*) FROM public.training_types WHERE name IN ('Sandsack / Rundenarbeit','Techniktraining','Krafttraining','Reguläres Boxtraining','Pratzentraining'))=5)::text
UNION ALL SELECT 'Noch kein Stundenplan / keine Stufen', (to_regclass('public.club_schedule') IS NULL AND to_regclass('public.club_tiers') IS NULL)::text
UNION ALL SELECT 'Keine abgeschlossene Saison betroffen', (SELECT count(*)::text FROM public.league_seasons_v21 WHERE status='closed')
UNION ALL SELECT 'Referenz Trainings approved', (SELECT count(*)::text FROM public.training_submissions WHERE status='approved')
UNION ALL SELECT 'Referenz point_transactions n/exp/points', (SELECT count(*)||' / '||coalesce(sum(exp),0)||' / '||coalesce(sum(points),0) FROM public.point_transactions);
