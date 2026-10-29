-- Read-only Preflight vor 20261029200000_award_skip_revoke.sql (ändert nichts).
SELECT 'Etappe 13 eingespielt (befristete Designs)' AS check_name, (to_regprocedure('league_private.card_award_until(uuid,text)') IS NOT NULL)::text AS ok
UNION ALL SELECT 'Übersicht wie 7d / Vergeben wie Etappe 13 (Fingerprint)', md5(pg_get_functiondef('public.staff_card_award_overview()'::regprocedure)
  ||pg_get_functiondef('public.staff_confirm_card_award(text,date,uuid,text)'::regprocedure))
UNION ALL SELECT 'Noch kein «nicht vergeben»', (to_regclass('public.card_award_skips') IS NULL)::text
UNION ALL SELECT 'Referenz Auszeichnungen aktiv / zurückgenommen', (SELECT count(*) FILTER (WHERE revoked_at IS NULL)||' / '||count(*) FILTER (WHERE revoked_at IS NOT NULL) FROM public.card_awards)
UNION ALL SELECT 'Referenz kg_ledger (Anzahl / Summe)', (SELECT count(*)||' / '||coalesce(sum(amount),0) FROM public.kg_ledger)
UNION ALL SELECT 'Referenz point_transactions n/exp/points', (SELECT count(*)||' / '||coalesce(sum(exp),0)||' / '||coalesce(sum(points),0) FROM public.point_transactions);
