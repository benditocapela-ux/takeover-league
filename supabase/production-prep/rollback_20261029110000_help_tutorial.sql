-- Rollback für 20261029110000_help_tutorial.sql (Etappe 7c): RPCs entfernen.
-- FAQ-Einträge und der Tour-Stand bleiben gespeichert (nichts wird gelöscht). Das Flag tutorial wird ausgeschaltet.
BEGIN;
DROP FUNCTION IF EXISTS public.get_my_onboarding();
DROP FUNCTION IF EXISTS public.mark_tour_seen(integer);
DROP FUNCTION IF EXISTS public.get_faq();
DROP FUNCTION IF EXISTS public.admin_save_faq(bigint,text,text,text,integer,boolean);
UPDATE public.league_feature_flags SET is_enabled=false WHERE feature_key='tutorial';
NOTIFY pgrst, 'reload schema';
COMMIT;
