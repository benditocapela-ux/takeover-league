-- REVIEW ONLY. Owner-only draft goal details for safe edit form prefill.
BEGIN;
CREATE OR REPLACE FUNCTION public.coach_challenge_v2_goal_details(p_challenge_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $fn$
DECLARE actor public.profiles%ROWTYPE; c public.league_coach_challenges%ROWTYPE;
BEGIN
 SELECT * INTO actor FROM public.profiles
 WHERE auth_user_id=(SELECT auth.uid()) AND is_active=true
 AND role IN ('coach','admin');
 IF NOT FOUND THEN RAISE EXCEPTION 'Coach authorization required'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.league_feature_flags
 WHERE feature_key='coach_challenges' AND is_enabled=true) THEN
 RAISE EXCEPTION 'Coach challenges are disabled'; END IF;
 SELECT * INTO c FROM public.league_coach_challenges WHERE id=p_challenge_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Challenge not found'; END IF;
 IF actor.role<>'admin' AND c.created_by<>actor.id THEN
 RAISE EXCEPTION 'Not challenge owner'; END IF;
 IF c.status<>'draft' THEN RAISE EXCEPTION 'Only drafts can be edited'; END IF;
 RETURN COALESCE(c.goal_spec,'{}'::jsonb);
END $fn$;
REVOKE ALL ON FUNCTION public.coach_challenge_v2_goal_details(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.coach_challenge_v2_goal_details(uuid) TO authenticated;
COMMIT;
