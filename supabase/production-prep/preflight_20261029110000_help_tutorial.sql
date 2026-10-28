-- Read-only Preflight vor 20261029110000_help_tutorial.sql (ändert nichts).
SELECT 'Hilfsfunktionen vorhanden' AS check_name, (to_regprocedure('league_private.active_viewer()') IS NOT NULL AND to_regprocedure('league_private.flag_on(text)') IS NOT NULL)::text AS ok
UNION ALL SELECT 'Noch keine FAQ/Tour-Tabellen', (to_regclass('public.faq_entries') IS NULL AND to_regclass('public.profile_onboarding') IS NULL)::text;
