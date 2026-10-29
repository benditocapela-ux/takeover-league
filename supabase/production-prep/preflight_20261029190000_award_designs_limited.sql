-- Read-only Preflight vor 20261029190000_award_designs_limited.sql (ändert nichts).
SELECT 'Etappe 12 eingespielt (26 Designs, eigenes Design)' AS check_name, ((SELECT count(*) FROM public.card_designs)=26 AND to_regclass('public.card_personal_designs') IS NOT NULL)::text AS ok
UNION ALL SELECT 'Funktionen wie Etappe 12 / 7d (Fingerprint)', md5(pg_get_functiondef('league_private.card_design_available(uuid,public.card_designs)'::regprocedure)
  ||pg_get_functiondef('league_private.card_award_json(public.card_awards)'::regprocedure)||pg_get_functiondef('public.get_my_card_designs()'::regprocedure)
  ||pg_get_functiondef('public.staff_confirm_card_award(text,date,uuid,text)'::regprocedure))
UNION ALL SELECT 'Noch nicht befristet', (to_regprocedure('league_private.card_award_until(uuid,text)') IS NULL)::text
UNION ALL SELECT 'Referenz Auszeichnungen aktiv / zurückgenommen', (SELECT count(*) FILTER (WHERE revoked_at IS NULL)||' / '||count(*) FILTER (WHERE revoked_at IS NOT NULL) FROM public.card_awards)
UNION ALL SELECT 'Referenz Auswahl Auszeichnungs-Designs', (SELECT count(*)::text FROM public.card_design_equipped WHERE design_key IN ('cotw','cotm','poty'))
UNION ALL SELECT 'Referenz Käufe / Auswahl / eigene Designs', (SELECT count(*) FROM public.card_design_purchases)||' / '||(SELECT count(*) FROM public.card_design_equipped)||' / '||(SELECT count(*) FROM public.card_personal_designs)
UNION ALL SELECT 'Referenz kg_ledger (Anzahl / Summe)', (SELECT count(*)||' / '||coalesce(sum(amount),0) FROM public.kg_ledger)
UNION ALL SELECT 'Referenz point_transactions n/exp/points', (SELECT count(*)||' / '||coalesce(sum(exp),0)||' / '||coalesce(sum(points),0) FROM public.point_transactions);
