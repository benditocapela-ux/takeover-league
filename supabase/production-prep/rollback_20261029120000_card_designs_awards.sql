-- Rollback für 20261029120000_card_designs_awards.sql (Etappe 7d): RPCs entfernen, Flag aus.
-- Designs, Käufe (inkl. Coin-Buchungen), ausgewählte Designs und Auszeichnungen bleiben gespeichert (nichts wird gelöscht).
BEGIN;
DROP FUNCTION IF EXISTS public.get_my_card_designs();
DROP FUNCTION IF EXISTS public.equip_card_design(text);
DROP FUNCTION IF EXISTS public.buy_card_design(text);
DROP FUNCTION IF EXISTS public.get_card_looks(text[]);
DROP FUNCTION IF EXISTS public.get_card_awards();
DROP FUNCTION IF EXISTS public.staff_card_award_overview();
DROP FUNCTION IF EXISTS public.staff_confirm_card_award(text,date,uuid,text);
DROP FUNCTION IF EXISTS public.staff_revoke_card_award(bigint,text);
UPDATE public.league_feature_flags SET is_enabled=false WHERE feature_key='card_designs';
NOTIFY pgrst, 'reload schema';
COMMIT;
