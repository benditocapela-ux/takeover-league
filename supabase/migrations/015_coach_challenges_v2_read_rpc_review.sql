-- Coach Challenges V2: restricted list RPC (REVIEW ONLY; NOT FOR LIVE EXECUTION).
-- Boxer visibility: open challenges and own enrollment; no participant roster.
-- Coach/admin visibility: all challenges, with aggregate joined counts only.
BEGIN;
CREATE OR REPLACE FUNCTION public.coach_challenge_v2_list()
RETURNS TABLE(
 id uuid,title text,description text,challenge_kind text,
 duration_days integer,status text,starts_at timestamptz,ends_at timestamptz,
 joined_count bigint,my_enrollment_status text,is_creator boolean
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $fn$
DECLARE v_actor public.profiles%ROWTYPE;
BEGIN
 SELECT * INTO v_actor FROM public.profiles
 WHERE auth_user_id=(SELECT auth.uid()) AND is_active=true
   AND role IN ('boxer','coach','admin');
 IF NOT FOUND THEN RAISE EXCEPTION 'Not authorized'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.league_feature_flags
               WHERE feature_key='coach_challenges' AND is_enabled=true) THEN
  RAISE EXCEPTION 'Coach challenges are not enabled';
 END IF;
 RETURN QUERY
 SELECT c.id,c.title,c.description,c.challenge_kind,c.duration_days,
        c.status,c.starts_at,c.ends_at,
        (SELECT count(*) FROM public.league_coach_challenge_entries e
         WHERE e.challenge_id=c.id AND e.status='joined') AS joined_count,
        (SELECT e.status FROM public.league_coach_challenge_entries e
         WHERE e.challenge_id=c.id AND e.boxer_id=v_actor.id) AS my_enrollment_status,
        (c.created_by=v_actor.id) AS is_creator
 FROM public.league_coach_challenges c
 WHERE v_actor.role IN ('coach','admin')
    OR c.status='open'
    OR EXISTS(SELECT 1 FROM public.league_coach_challenge_entries e
              WHERE e.challenge_id=c.id AND e.boxer_id=v_actor.id)
 ORDER BY c.created_at DESC,c.id DESC
 LIMIT 100;
END $fn$;
REVOKE ALL ON FUNCTION public.coach_challenge_v2_list() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.coach_challenge_v2_list() TO authenticated;
COMMIT;
