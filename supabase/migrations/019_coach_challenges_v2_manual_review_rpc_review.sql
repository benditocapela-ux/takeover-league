-- REVIEW ONLY. Manual challenge review decisions, without EXP settlement.
BEGIN;
CREATE TABLE IF NOT EXISTS public.league_coach_challenge_reviews (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 challenge_id uuid NOT NULL REFERENCES public.league_coach_challenges(id),
 boxer_id uuid NOT NULL REFERENCES public.profiles(id),
 reviewed_by uuid NOT NULL REFERENCES public.profiles(id),
 approved boolean NOT NULL,
 reason text NOT NULL CHECK (char_length(btrim(reason)) BETWEEN 5 AND 1000),
 reviewed_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(challenge_id,boxer_id)
);
ALTER TABLE public.league_coach_challenge_reviews ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.league_coach_challenge_reviews FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.coach_challenge_v2_review_manual(
 p_challenge_id uuid,p_boxer_id uuid,p_approved boolean,p_reason text)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $fn$
DECLARE actor public.profiles%ROWTYPE; c public.league_coach_challenges%ROWTYPE;
BEGIN
 SELECT * INTO actor FROM public.profiles
 WHERE auth_user_id=(SELECT auth.uid()) AND is_active=true AND role IN ('coach','admin');
 IF NOT FOUND THEN RAISE EXCEPTION 'Coach authorization required'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.league_feature_flags
 WHERE feature_key='coach_challenges' AND is_enabled=true) THEN
  RAISE EXCEPTION 'Coach challenges are disabled';
 END IF;
 SELECT * INTO c FROM public.league_coach_challenges WHERE id=p_challenge_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Challenge not found'; END IF;
 IF actor.role<>'admin' AND c.created_by<>actor.id THEN RAISE EXCEPTION 'Not challenge owner'; END IF;
 IF c.goal_spec->>'review_mode' IS DISTINCT FROM 'manual' OR c.status<>'awaiting_reviews'
 OR c.ends_at IS NULL OR c.ends_at>pg_catalog.clock_timestamp() THEN
  RAISE EXCEPTION 'Manual review unavailable';
 END IF;
 IF p_approved IS NULL OR p_reason IS NULL OR
 pg_catalog.char_length(pg_catalog.btrim(p_reason)) NOT BETWEEN 5 AND 1000 THEN
  RAISE EXCEPTION 'Review decision and reason required';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.league_coach_challenge_entries
 WHERE challenge_id=p_challenge_id AND boxer_id=p_boxer_id AND status='joined') THEN
  RAISE EXCEPTION 'Eligible participant not found';
 END IF;
 INSERT INTO public.league_coach_challenge_reviews(
 challenge_id,boxer_id,reviewed_by,approved,reason)
 VALUES(p_challenge_id,p_boxer_id,actor.id,p_approved,pg_catalog.btrim(p_reason))
 ON CONFLICT(challenge_id,boxer_id) DO NOTHING;
 IF NOT FOUND THEN RAISE EXCEPTION 'Review already recorded'; END IF;
 RETURN 'review_recorded';
END $fn$;
REVOKE ALL ON FUNCTION public.coach_challenge_v2_review_manual(uuid,uuid,boolean,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.coach_challenge_v2_review_manual(uuid,uuid,boolean,text) TO authenticated;
COMMIT;
