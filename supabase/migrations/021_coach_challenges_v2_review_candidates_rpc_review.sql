-- REVIEW ONLY: trainer-only participant picker; no EXP payout.
BEGIN;
CREATE OR REPLACE FUNCTION public.coach_challenge_v2_review_candidates(p_challenge_id uuid)
RETURNS TABLE(boxer_id uuid, display_name text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $fn$
DECLARE actor public.profiles%ROWTYPE; challenge public.league_coach_challenges%ROWTYPE;
BEGIN
 SELECT * INTO actor FROM public.profiles
 WHERE auth_user_id=(SELECT auth.uid()) AND is_active=true AND role IN ('coach','admin');
 IF NOT FOUND THEN RAISE EXCEPTION 'Coach authorization required'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.league_feature_flags
 WHERE feature_key='coach_challenges' AND is_enabled=true) THEN
 RAISE EXCEPTION 'Coach challenges are disabled'; END IF;
 SELECT * INTO challenge FROM public.league_coach_challenges WHERE id=p_challenge_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Challenge not found'; END IF;
 IF actor.role<>'admin' AND challenge.created_by<>actor.id THEN
 RAISE EXCEPTION 'Not challenge owner'; END IF;
 IF challenge.status<>'awaiting_reviews' OR challenge.goal_spec->>'review_mode' IS DISTINCT FROM 'manual'
 OR challenge.ends_at IS NULL OR challenge.ends_at>pg_catalog.clock_timestamp() THEN
 RAISE EXCEPTION 'Manual review unavailable'; END IF;
 RETURN QUERY
 SELECT e.boxer_id,p.display_name AS display_name
 FROM public.league_coach_challenge_entries e
 JOIN public.profiles p ON p.id=e.boxer_id AND p.role='boxer' AND p.is_active=true
 WHERE e.challenge_id=p_challenge_id AND e.status='joined'
 AND NOT EXISTS (SELECT 1 FROM public.league_coach_challenge_reviews r
 WHERE r.challenge_id=e.challenge_id AND r.boxer_id=e.boxer_id)
 ORDER BY e.joined_at,e.boxer_id;
END $fn$;
REVOKE ALL ON FUNCTION public.coach_challenge_v2_review_candidates(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.coach_challenge_v2_review_candidates(uuid) TO authenticated;
COMMIT;
