-- Rücknahme von 20261029220000_card_gallery.sql: entfernt nur die Kartengalerie (Lesefunktion). Ändert keine Daten.
BEGIN;
DROP FUNCTION IF EXISTS public.get_card_gallery();
NOTIFY pgrst, 'reload schema';
COMMIT;
