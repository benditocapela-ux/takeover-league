-- REVIEW ONLY. Read recorded manual decisions; no EXP payout.
BEGIN;
CREATE OR REPLACE FUNCTION public.coach_challenge_v2_review_status(p_challenge_id uuid)
RETURNS TABLE(boxer_id uuid, approved boolean, reason text, reviewed_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $fn$
DECLARE actor public.profiles%ROWTYPE; c public.league_coach_challenges%ROWTYPE;
BEGIN
 SELECT * INTO actor FROM public.profiles WHERE auth_user_id=(SELECT auth.uid())
 AND is_active=true AND role IN ('boxer','coach','admin');
 IF NOT FOUND THEN RAISE EXCEPTION 'Not authorized'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.league_feature_flags
 WHERE feature_key='coach_challenges' AND is_enabled=true) THEN
  RAISE EXCEPTION 'Coach challenges are disabled';
 END IF;
 SELECT * INTO c FROM public.league_coach_challenges WHERE id=p_challenge_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Challenge not found'; END IF;
 IF actor.role='coach' AND c.created_by<>actor.id THEN RAISE EXCEPTION 'Not challenge owner'; END IF;
 IF c.goal_spec->>'review_mode'<>'manual' OR c.status NOT IN ('awaiting_reviews','settled') THEN
  RAISE EXCEPTION 'Manual review unavailable';
 END IF;
 RETURN QUERY
 SELECT v.boxer_id,v.approved,
 CASE WHEN actor.role='boxer' THEN NULL::text ELSE v.reason END,
 v.reviewed_at
 FROM public.league_coach_challenge_reviews v
 WHERE v.challenge_id=p_challenge_id
 AND (actor.role<>'boxer' OR v.boxer_id=actor.id);
END $fn$;
REVOKE ALL ON FUNCTION public.coach_challenge_v2_review_status(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.coach_challenge_v2_review_status(uuid) TO authenticated;
COMMIT;
