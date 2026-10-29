-- Read-only Postflight nach 20261029240000_admin_bonus_exp.sql (ändert nichts).
SELECT 'Rücknahmen: Tabelle mit RLS, ohne direkte Rechte' AS check_name, ((SELECT relrowsecurity FROM pg_class WHERE oid='public.bonus_revocations'::regclass)
  AND NOT has_table_privilege('authenticated','public.bonus_revocations','SELECT') AND NOT has_table_privilege('anon','public.bonus_revocations','SELECT'))::text AS ok
UNION ALL SELECT '3 RPCs SECURITY DEFINER, leerer search_path, nicht für anon', ((SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.prosecdef
  AND p.proconfig @> ARRAY['search_path=""'] AND p.proname IN ('admin_give_bonus','admin_revoke_bonus','admin_list_bonuses'))=3
  AND NOT has_function_privilege('anon','public.admin_give_bonus(uuid,integer,boolean,text)','EXECUTE') AND has_function_privilege('authenticated','public.admin_give_bonus(uuid,integer,boolean,text)','EXECUTE'))::text
UNION ALL SELECT 'Referenz trainer_bonus (Anzahl / Punkte / EXP)', (SELECT count(*)||' / '||coalesce(sum(points),0)||' / '||coalesce(sum(exp),0) FROM public.point_transactions WHERE category='trainer_bonus')
UNION ALL SELECT 'Referenz point_transactions n/exp/points', (SELECT count(*)||' / '||coalesce(sum(exp),0)||' / '||coalesce(sum(points),0) FROM public.point_transactions);
