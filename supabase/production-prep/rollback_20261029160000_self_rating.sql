-- Rücknahme von 20261029160000_self_rating.sql.
-- Bricht ab, sobald Selbsteinschätzungen gespeichert sind (dann zuerst mit dem Owner klären). Bewertungen, die Trainer aus
-- Selbsteinschätzungen freigegeben haben, sind normale Coach-Bewertungen und bleiben in jedem Fall erhalten.
BEGIN;
DO $$ BEGIN
 IF to_regclass('public.rating_self_reviews') IS NOT NULL AND EXISTS (SELECT 1 FROM public.rating_self_reviews) THEN
  RAISE EXCEPTION 'Rücknahme abgebrochen: es gibt schon Selbsteinschätzungen';
 END IF;
END $$;
DROP FUNCTION IF EXISTS public.get_my_self_rating();
DROP FUNCTION IF EXISTS public.submit_self_rating(jsonb,text);
DROP FUNCTION IF EXISTS public.staff_list_self_ratings();
DROP FUNCTION IF EXISTS public.staff_decide_self_rating(bigint,text,jsonb,text);
DROP FUNCTION IF EXISTS league_private.self_review_state(uuid);
DROP FUNCTION IF EXISTS league_private.self_review_notify_path(bigint);
DROP TABLE IF EXISTS public.rating_self_reviews;
DELETE FROM public.league_feature_flags WHERE feature_key='self_rating';
NOTIFY pgrst, 'reload schema';
COMMIT;
