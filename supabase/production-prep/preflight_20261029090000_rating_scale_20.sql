-- Read-only Preflight vor 20261029090000_rating_scale_20.sql (ändert nichts).
SELECT 'Bewertungstabelle ohne Skala' AS check_name, (to_regclass('public.boxer_ratings') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM information_schema.columns
  WHERE table_schema='public' AND table_name='boxer_ratings' AND column_name='scale'))::text AS ok
UNION ALL SELECT 'Bisherige Bewertungsfunktion (1–10) vorhanden', (to_regprocedure('public.staff_rate_boxer(uuid,jsonb,text)') IS NOT NULL
  AND to_regprocedure('league_private.rating_summary(jsonb)') IS NOT NULL)::text
UNION ALL SELECT 'Fingerabdruck bisherige Funktionen (Rollback-Stand)', (SELECT md5(string_agg(pg_get_functiondef(p.oid),'' ORDER BY n.nspname,p.proname))
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE (n.nspname,p.proname) IN (('league_private','rating_full'),('public','get_performance_card'),('public','staff_list_performance'),('public','staff_rate_boxer')))
UNION ALL SELECT 'Referenz Bewertungen (Anzahl / Gesamtwerte)', (SELECT count(*)||' / '||coalesce(string_agg((league_private.rating_summary(scores)->>'overall'),',' ORDER BY id),'') FROM public.boxer_ratings)
UNION ALL SELECT 'Referenz Fingerabdruck Bewertungen', (SELECT md5(coalesce(string_agg(id::text||scores::text||coalesce(note,'')||created_at::text,'|' ORDER BY id),'')) FROM public.boxer_ratings);
