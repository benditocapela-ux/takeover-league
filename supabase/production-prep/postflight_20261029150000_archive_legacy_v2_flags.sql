-- Read-only Postflight nach 20261029150000_archive_legacy_v2_flags.sql (ändert nichts).
SELECT '7 alte Schalter entfernt' AS check_name, (NOT EXISTS (SELECT 1 FROM public.league_feature_flags WHERE feature_key IN
  ('boxer_duels','coach_goals','hall_of_fame','league_challenges','palmares','public_boxer_profiles','seasons')))::text AS ok
UNION ALL SELECT '9 Tabellen und 16 Funktionen im Archiv, keine mehr in public', ((SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='legacy_v2_archive' AND c.relkind='r')=9 AND (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='legacy_v2_archive')=16
  AND to_regclass('public.boxer_duels') IS NULL AND to_regclass('public.league_seasons') IS NULL AND to_regclass('public.boxer_coach_goals') IS NULL
  AND to_regprocedure('public.coach_create_boxer_duel(uuid,uuid,text,text,text,date,date,numeric)') IS NULL)::text
UNION ALL SELECT 'Archiv gesperrt (anon, authenticated, service_role ohne Zugriff)', (NOT has_schema_privilege('anon','legacy_v2_archive','USAGE')
  AND NOT has_schema_privilege('authenticated','legacy_v2_archive','USAGE') AND NOT has_schema_privilege('service_role','legacy_v2_archive','USAGE'))::text
UNION ALL SELECT 'Regeln und Indizes mitgewandert', ((SELECT count(*) FROM pg_policy p JOIN pg_class c ON c.oid=p.polrelid JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='legacy_v2_archive')=18 AND (SELECT count(*) FROM pg_indexes WHERE schemaname='legacy_v2_archive')>=24)::text
UNION ALL SELECT 'Neue Strukturen unberührt', (to_regclass('public.league_duels') IS NOT NULL AND to_regclass('public.league_seasons_v21') IS NOT NULL
  AND to_regclass('public.league_global_challenges_v21') IS NOT NULL AND to_regclass('public.league_hall_of_fame_v21') IS NOT NULL)::text
UNION ALL SELECT 'Referenz Schalter gesamt / an', (SELECT count(*)||' / '||count(*) FILTER (WHERE is_enabled) FROM public.league_feature_flags)
UNION ALL SELECT 'Referenz point_transactions n/exp/points', (SELECT count(*)||' / '||coalesce(sum(exp),0)||' / '||coalesce(sum(points),0) FROM public.point_transactions);
