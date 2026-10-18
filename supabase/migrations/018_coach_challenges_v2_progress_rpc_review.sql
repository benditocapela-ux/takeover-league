-- REVIEW ONLY: automatic challenge progress, no EXP payout.
BEGIN;
CREATE OR REPLACE FUNCTION public.coach_challenge_v2_progress(p_challenge_id uuid)
RETURNS TABLE(boxer_id uuid, achieved numeric, target numeric, completed boolean)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $fn$
DECLARE actor public.profiles%ROWTYPE; c public.league_coach_challenges%ROWTYPE;
 v_metric text; v_target numeric;
BEGIN
 SELECT * INTO actor FROM public.profiles
 WHERE auth_user_id=(SELECT auth.uid()) AND is_active=true
 AND role IN ('boxer','coach','admin');
 IF NOT FOUND THEN RAISE EXCEPTION 'Not authorized'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.league_feature_flags
 WHERE feature_key='coach_challenges' AND is_enabled=true) THEN
  RAISE EXCEPTION 'Coach challenges are disabled';
 END IF;
 SELECT * INTO c FROM public.league_coach_challenges WHERE id=p_challenge_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Challenge not found'; END IF;
 IF actor.role='coach' AND c.created_by<>actor.id THEN RAISE EXCEPTION 'Not challenge owner'; END IF;
 IF c.status NOT IN ('active','awaiting_reviews','settled') OR c.starts_at IS NULL OR c.ends_at IS NULL
 OR c.goal_spec->>'review_mode'<>'automatic' THEN
  RAISE EXCEPTION 'Automatic progress unavailable';
 END IF;
 v_metric:=c.goal_spec->>'metric';
 IF v_metric IS NULL OR v_metric NOT IN ('jogging_km','technique_minutes') THEN
  RAISE EXCEPTION 'Unsupported metric';
 END IF;
 v_target:=(c.goal_spec->>'target_value')::numeric;
 IF v_target IS NULL OR v_target<=0 OR v_target>1000000 THEN
  RAISE EXCEPTION 'Invalid target';
 END IF;
 RETURN QUERY
 SELECT e.boxer_id,
 COALESCE(SUM(CASE WHEN v_metric='jogging_km' THEN s.jogging_km
                   ELSE s.technique_minutes END),0)::numeric AS achieved,
 v_target AS target,
 COALESCE(SUM(CASE WHEN v_metric='jogging_km' THEN s.jogging_km
                   ELSE s.technique_minutes END),0)>=v_target AS completed
 FROM public.league_coach_challenge_entries e
 LEFT JOIN public.training_submissions s ON s.boxer_id=e.boxer_id
  AND s.status='approved'
  AND s.training_date >= (c.starts_at AT TIME ZONE 'Europe/Zurich')::date
  AND s.training_date < (c.ends_at AT TIME ZONE 'Europe/Zurich')::date
 WHERE e.challenge_id=c.id AND e.status='joined'
 AND (actor.role<>'boxer' OR e.boxer_id=actor.id)
 GROUP BY e.boxer_id;
END $fn$;
REVOKE ALL ON FUNCTION public.coach_challenge_v2_progress(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.coach_challenge_v2_progress(uuid) TO authenticated;
COMMIT;
