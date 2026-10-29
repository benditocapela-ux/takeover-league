-- Read-only Preflight vor 20261029240000_admin_bonus_exp.sql (ändert nichts).
SELECT 'Kategorien trainer_bonus und adjustment erlaubt' AS check_name, (pg_get_constraintdef((SELECT oid FROM pg_constraint WHERE conrelid='public.point_transactions'::regclass AND conname='point_transactions_category_check')) LIKE '%trainer_bonus%'
  AND pg_get_constraintdef((SELECT oid FROM pg_constraint WHERE conrelid='public.point_transactions'::regclass AND conname='point_transactions_category_check')) LIKE '%adjustment%')::text AS ok
UNION ALL SELECT 'Mitteilungstyp general erlaubt', (SELECT pg_get_constraintdef(c.oid) LIKE '%general%' FROM pg_constraint c WHERE c.conrelid='public.boxer_notifications'::regclass AND pg_get_constraintdef(c.oid) LIKE '%notification_type%' LIMIT 1)::text
UNION ALL SELECT 'Noch kein Bonus-Werkzeug', (to_regprocedure('public.admin_give_bonus(uuid,integer,boolean,text)') IS NULL AND to_regclass('public.bonus_revocations') IS NULL)::text
UNION ALL SELECT 'Referenz trainer_bonus (Anzahl / Punkte / EXP)', (SELECT count(*)||' / '||coalesce(sum(points),0)||' / '||coalesce(sum(exp),0) FROM public.point_transactions WHERE category='trainer_bonus')
UNION ALL SELECT 'Referenz point_transactions n/exp/points', (SELECT count(*)||' / '||coalesce(sum(exp),0)||' / '||coalesce(sum(points),0) FROM public.point_transactions);
