-- Rücknahme von 20261030090000_kg_cards_everywhere.sql: entfernt nur die lesende Kartenliste. Keine Daten betroffen.
BEGIN;
DROP FUNCTION IF EXISTS public.get_public_boxer_cards();
NOTIFY pgrst, 'reload schema';
COMMIT;
