-- Rollback für 20261028180000_coach_ratings_style_test.sql
-- Entfernt nur die neuen Funktionen. Tabellen (Bewertungen, Tests, Freigaben) und die Feature-Flags bleiben
-- mit allen Daten erhalten, damit nichts verloren geht. Vorher die Flags coach_ratings/style_test ausschalten.
BEGIN;
DROP FUNCTION IF EXISTS public.get_my_performance();
DROP FUNCTION IF EXISTS public.get_performance_card(text);
DROP FUNCTION IF EXISTS public.staff_list_performance();
DROP FUNCTION IF EXISTS public.staff_get_rating(uuid);
DROP FUNCTION IF EXISTS public.staff_rate_boxer(uuid,jsonb,text);
DROP FUNCTION IF EXISTS public.submit_style_test(smallint[]);
DROP FUNCTION IF EXISTS public.staff_unlock_style_test(uuid);
DROP FUNCTION IF EXISTS league_private.style_pair(uuid);
DROP FUNCTION IF EXISTS league_private.rating_full(uuid);
DROP FUNCTION IF EXISTS league_private.rating_row(uuid,integer);
DROP FUNCTION IF EXISTS league_private.active_viewer();
DROP FUNCTION IF EXISTS league_private.style_state(uuid);
DROP FUNCTION IF EXISTS league_private.month_start(timestamptz);
DROP FUNCTION IF EXISTS league_private.style_scores(smallint[]);
DROP FUNCTION IF EXISTS league_private.style_weights();
DROP FUNCTION IF EXISTS league_private.rating_summary(jsonb);
DROP FUNCTION IF EXISTS league_private.rating_scores_valid(jsonb);
DROP FUNCTION IF EXISTS league_private.rating_categories();
DROP FUNCTION IF EXISTS league_private.flag_on(text);
NOTIFY pgrst, 'reload schema';
COMMIT;
