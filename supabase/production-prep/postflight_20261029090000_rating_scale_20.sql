-- Read-only Postflight nach 20261029090000_rating_scale_20.sql (ändert nichts).
SELECT 'Skala-Spalte, bestehende Bewertungen auf 10' AS check_name, (EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='boxer_ratings'
  AND column_name='scale' AND is_nullable='NO') AND NOT EXISTS (SELECT 1 FROM public.boxer_ratings WHERE scale NOT IN (10,20)))::text AS ok
UNION ALL SELECT 'Bewerten nur noch mit Skala-Parameter, nicht für anon', (to_regprocedure('public.staff_rate_boxer(uuid,jsonb,text)') IS NULL
  AND to_regprocedure('public.staff_rate_boxer(uuid,jsonb,text,integer)') IS NOT NULL
  AND NOT has_function_privilege('anon','public.staff_rate_boxer(uuid,jsonb,text,integer)','EXECUTE')
  AND NOT has_function_privilege('authenticated','league_private.rating_summary(jsonb,integer)','EXECUTE'))::text
UNION ALL SELECT 'Gesamtwerte bestehender Bewertungen unverändert', (NOT EXISTS (SELECT 1 FROM public.boxer_ratings WHERE scale=10
  AND (league_private.rating_summary(scores)->>'overall')<>(league_private.rating_summary(scores,scale)->>'overall')))::text
UNION ALL SELECT 'Referenz Bewertungen (Anzahl / Gesamtwerte)', (SELECT count(*)||' / '||coalesce(string_agg((league_private.rating_summary(scores,scale)->>'overall'),',' ORDER BY id),'') FROM public.boxer_ratings)
UNION ALL SELECT 'Referenz Fingerabdruck Bewertungen', (SELECT md5(coalesce(string_agg(id::text||scores::text||coalesce(note,'')||created_at::text,'|' ORDER BY id),'')) FROM public.boxer_ratings);
