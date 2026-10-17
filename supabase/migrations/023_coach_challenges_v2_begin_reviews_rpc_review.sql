-- REVIEW ONLY. Transition expired manual challenges into trainer review.
-- No payout, no settlement and no direct table grants.
BEGIN;
CREATE OR REPLACE FUNCTION public.coach_challenge_v2_begin_reviews(p_challenge_id uuid)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $fn$
DECLARE actor public.profiles%ROWTYPE; c public.league_coach_challenges%ROWTYPE;
BEGIN
 SELECT * INTO actor FROM public.profiles WHERE auth_user_id=(SELECT auth.uid())
 AND is_active=true AND role IN ('coach','admin');
 IF NOT FOUND THEN RAISE EXCEPTION 'Coach authorization required'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.league_feature_flags
 WHERE feature_key='coach_challenges' AND is_enabled=true) THEN
 RAISE EXCEPTION 'Coach challenges disabled'; END IF;
 SELECT * INTO c FROM public.league_coach_challenges WHERE id=p_challenge_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Challenge not found'; END IF;
 IF actor.role<>'admin' AND c.created_by<>actor.id THEN
 RAISE EXCEPTION 'Not challenge owner'; END IF;
 IF c.status<>'active' OR c.goal_spec->>'review_mode'<>'manual'
 OR c.ends_at IS NULL OR c.ends_at>pg_catalog.clock_timestamp() THEN
 RAISE EXCEPTION 'Challenge not ready for review'; END IF;
 UPDATE public.league_coach_challenges SET status='awaiting_reviews',
 updated_at=pg_catalog.clock_timestamp() WHERE id=c.id;
 RETURN 'awaiting_reviews';
END $fn$;
REVOKE ALL ON FUNCTION public.coach_challenge_v2_begin_reviews(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.coach_challenge_v2_begin_reviews(uuid) TO authenticated;
COMMIT;
