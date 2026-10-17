-- Takeover League 2.0: restricted duel read RPCs (REVIEW ONLY).
-- Requires migration 007. No client grants on duel tables are needed.
-- Do not run in live Supabase before integration testing.
BEGIN;

CREATE OR REPLACE FUNCTION public.duel_v2_list_mine()
RETURNS TABLE (
 id uuid, challenger_id uuid, challenger_name text,
 opponent_id uuid, opponent_name text, status text,
 duration_days integer, invited_at timestamptz, expires_at timestamptz,
 accepted_at timestamptz, ends_at timestamptz, settled_at timestamptz,
 challenger_score integer, opponent_score integer, winner_id uuid
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $$
DECLARE v_profile uuid;
BEGIN
 SELECT p.id INTO v_profile FROM public.profiles p
 WHERE p.auth_user_id=(SELECT auth.uid()) AND p.is_active=true
 AND p.role IN ('boxer','admin','coach');
 IF v_profile IS NULL THEN RAISE EXCEPTION 'Not authorized'; END IF;
 RETURN QUERY
 SELECT d.id,d.challenger_id,c.display_name::text,
        d.opponent_id,o.display_name::text,d.status,d.duration_days,
        d.invited_at,d.expires_at,d.accepted_at,d.ends_at,d.settled_at,
        d.challenger_score,d.opponent_score,d.winner_id
 FROM public.league_duels d
 JOIN public.profiles c ON c.id=d.challenger_id
 JOIN public.profiles o ON o.id=d.opponent_id
 WHERE d.challenger_id=v_profile OR d.opponent_id=v_profile
    OR EXISTS(SELECT 1 FROM public.profiles p WHERE p.id=v_profile
              AND p.role IN ('admin','coach'))
 ORDER BY d.invited_at DESC LIMIT 100;
END $$;

CREATE OR REPLACE FUNCTION public.duel_v2_eligible_boxers()
RETURNS TABLE (id uuid, display_name text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $$
DECLARE v_profile uuid;
BEGIN
 SELECT p.id INTO v_profile FROM public.profiles p
 WHERE p.auth_user_id=(SELECT auth.uid()) AND p.is_active=true
 AND p.role IN ('boxer','admin','coach');
 IF v_profile IS NULL THEN RAISE EXCEPTION 'Not authorized'; END IF;
 RETURN QUERY
 SELECT p.id,p.display_name::text FROM public.profiles p
 WHERE p.role='boxer' AND p.is_active=true
 ORDER BY p.display_name,p.id;
END $$;

REVOKE ALL ON FUNCTION public.duel_v2_list_mine() FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.duel_v2_eligible_boxers() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.duel_v2_list_mine() TO authenticated;
GRANT EXECUTE ON FUNCTION public.duel_v2_eligible_boxers() TO authenticated;
COMMIT;
