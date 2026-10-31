-- Read-only Postflight nach 20261031090000_training_v2_classification.sql (ändert nichts).
SELECT 'Schalter training_v2 aus' AS check_name, (EXISTS (SELECT 1 FROM public.league_feature_flags WHERE feature_key='training_v2' AND NOT is_enabled))::text AS ok
UNION ALL SELECT 'Neue RPCs nur für angemeldete Nutzer', (has_function_privilege('authenticated','public.staff_review_training(uuid,text,text,bigint,date,integer,text,boolean)','EXECUTE')
  AND NOT has_function_privilege('anon','public.staff_review_training(uuid,text,text,bigint,date,integer,text,boolean)','EXECUTE')
  AND NOT has_function_privilege('anon','public.staff_list_trainings(text,text,text,uuid,date,date,integer,integer)','EXECUTE'))::text
UNION ALL SELECT 'Hilfsfunktionen für App-Rollen gesperrt', (NOT has_function_privilege('authenticated','league_private.training_reward(bigint,text)','EXECUTE')
  AND NOT has_function_privilege('authenticated','league_private.training_insert_guard()','EXECUTE'))::text
UNION ALL SELECT 'Trigger aktiv (Einfügen, Ändern)', (SELECT count(*)::text FROM pg_trigger WHERE tgname IN ('league_training_insert_guard','league_training_request_update_guard') AND tgrelid='public.training_submissions'::regclass)
UNION ALL SELECT 'Ergänzungstrainings', (SELECT string_agg(key||'='||label,', ' ORDER BY sort_order) FROM public.club_extra_trainings)
UNION ALL SELECT 'Wertung identisch zur bisherigen Formel (alle Trainings)', (NOT EXISTS (SELECT 1 FROM public.training_submissions s JOIN public.training_types t ON t.id=s.training_type_id
  LEFT JOIN public.club_tiers ct ON ct.tier=s.club_tier
  WHERE league_private.training_value(s.id)<>CASE WHEN s.status<>'approved' THEN 0 ELSE GREATEST(coalesce(ct.exp,0), t.points) END))::text
UNION ALL SELECT 'Referenz training_submissions / point_transactions', (SELECT count(*) FROM public.training_submissions)||' / '||(SELECT count(*)||' / '||coalesce(sum(exp),0)||' / '||coalesce(sum(points),0) FROM public.point_transactions);
