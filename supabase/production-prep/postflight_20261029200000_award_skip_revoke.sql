-- Read-only Postflight nach 20261029200000_award_skip_revoke.sql (ändert nichts).
SELECT '«Nicht vergeben»: Tabelle mit RLS, ohne direkte Rechte, einmal pro Zeitraum' AS check_name, ((SELECT relrowsecurity FROM pg_class WHERE oid='public.card_award_skips'::regclass)
  AND NOT has_table_privilege('authenticated','public.card_award_skips','SELECT') AND NOT has_table_privilege('anon','public.card_award_skips','SELECT')
  AND to_regclass('public.card_award_skips_one_active') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.card_award_skips))::text AS ok
UNION ALL SELECT '4 RPCs SECURITY DEFINER, leerer search_path, nicht für anon', ((SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.prosecdef
  AND p.proconfig @> ARRAY['search_path=""'] AND p.proname IN ('staff_skip_card_award','staff_unskip_card_award','staff_card_award_overview','staff_confirm_card_award'))=4
  AND NOT has_function_privilege('anon','public.staff_skip_card_award(text,date,text)','EXECUTE') AND has_function_privilege('authenticated','public.staff_unskip_card_award(bigint)','EXECUTE')
  AND NOT has_function_privilege('authenticated','league_private.card_skip_json(public.card_award_skips,public.profiles)','EXECUTE')
  AND pg_get_functiondef('public.staff_confirm_card_award(text,date,uuid,text)'::regprocedure) LIKE '%card_award_skips%')::text
UNION ALL SELECT 'Referenz Auszeichnungen aktiv / zurückgenommen', (SELECT count(*) FILTER (WHERE revoked_at IS NULL)||' / '||count(*) FILTER (WHERE revoked_at IS NOT NULL) FROM public.card_awards)
UNION ALL SELECT 'Referenz kg_ledger (Anzahl / Summe)', (SELECT count(*)||' / '||coalesce(sum(amount),0) FROM public.kg_ledger)
UNION ALL SELECT 'Referenz point_transactions n/exp/points', (SELECT count(*)||' / '||coalesce(sum(exp),0)||' / '||coalesce(sum(points),0) FROM public.point_transactions);
