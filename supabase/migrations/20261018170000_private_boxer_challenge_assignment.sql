-- Takeover League 2.0 | private, trainer-assigned personal challenges
-- RELEASE CANDIDATE ONLY. DO NOT APPLY TO PRODUCTION BEFORE EXPLICIT APPROVAL.
-- Prerequisite: 20261018131000_coach_challenges_v2.sql already installed.
-- No direct client access to target mapping; no modification to old points/EXP.
BEGIN;

CREATE TABLE public.league_coach_challenge_targets (
 challenge_id uuid PRIMARY KEY REFERENCES public.league_coach_challenges(id) ON DELETE RESTRICT,
 boxer_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
 assigned_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX league_coach_challenge_targets_boxer_idx
 ON public.league_coach_challenge_targets(boxer_id);
ALTER TABLE public.league_coach_challenge_targets ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.league_coach_challenge_targets
 FROM PUBLIC, anon, authenticated;

-- Trainer assigns a fully configured manual-review personal goal to one active
-- boxer, effective immediately. One atomic statement: no partial EXP or rows.
-- The recipient does not have to join a public challenge manually.
CREATE OR REPLACE FUNCTION public.league_assign_personal_challenge(
 p_boxer_id uuid, p_title text, p_description text,
 p_goal_text text, p_duration_days integer, p_reward_exp integer
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $func$
DECLARE a jsonb:=league_private.coach_v2_actor();
        v_id uuid; v_now timestamptz:=pg_catalog.clock_timestamp();
BEGIN
 IF a->>'role' NOT IN ('coach','admin')
 THEN RAISE EXCEPTION 'Coach role required' USING ERRCODE='42501'; END IF;
 IF p_boxer_id IS NULL OR NOT EXISTS (
   SELECT 1 FROM public.profiles p
   WHERE p.id=p_boxer_id AND p.role='boxer' AND p.is_active IS TRUE
 ) THEN RAISE EXCEPTION 'Active boxer required' USING ERRCODE='22023'; END IF;
 IF pg_catalog.char_length(pg_catalog.btrim(COALESCE(p_title,''))) NOT BETWEEN 3 AND 120
 OR pg_catalog.char_length(pg_catalog.btrim(COALESCE(p_goal_text,''))) NOT BETWEEN 5 AND 1000
 OR p_duration_days NOT IN (7,14,30) OR p_duration_days IS NULL
 OR p_reward_exp NOT IN (25,50,100,150,200) OR p_reward_exp IS NULL
 OR pg_catalog.char_length(COALESCE(p_description,''))>2000
 THEN RAISE EXCEPTION 'Invalid goal, duration or reward' USING ERRCODE='22023'; END IF;

 INSERT INTO public.league_coach_challenges(
  created_by,title,description,challenge_kind,duration_days,goal_spec,
  status,starts_at,ends_at,updated_at
 ) VALUES (
  (a->>'id')::uuid,pg_catalog.btrim(p_title),COALESCE(p_description,''),
  'individual',p_duration_days,
  pg_catalog.jsonb_build_object(
    'version',1,'goal_text',pg_catalog.btrim(p_goal_text),
    'review_mode','manual','reward_exp',p_reward_exp,
    'target_value',NULL,'metric',NULL),
  'active',v_now,v_now+pg_catalog.make_interval(days=>p_duration_days),v_now
 ) RETURNING id INTO v_id;

 INSERT INTO public.league_coach_challenge_targets(challenge_id,boxer_id)
 VALUES(v_id,p_boxer_id);
 INSERT INTO public.league_coach_challenge_entries(challenge_id,boxer_id,status)
 VALUES(v_id,p_boxer_id,'joined');

 RETURN pg_catalog.jsonb_build_object('challenge_id',v_id,
  'boxer_id',p_boxer_id,'status','active','reward_exp',p_reward_exp);
END
$func$;

-- Purpose-limited roster: only active coaches/admins can resolve the public
-- boxer name to a canonical database ID. Never return auth IDs or weight.
CREATE OR REPLACE FUNCTION public.league_personal_challenge_roster()
RETURNS TABLE(boxer_id uuid, display_name text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $func$
DECLARE a jsonb:=league_private.coach_v2_actor();
BEGIN
 IF a->>'role' NOT IN ('coach','admin')
 THEN RAISE EXCEPTION 'Coach role required' USING ERRCODE='42501'; END IF;
 RETURN QUERY
 SELECT p.id,p.display_name::text FROM public.profiles p
 WHERE p.role='boxer' AND p.is_active IS TRUE
 ORDER BY p.display_name,p.id;
END
$func$;

-- A trainer may correct a mistaken assignment before any review / payout.
-- The cancellation cannot debit, delete or forge a point transaction.
CREATE OR REPLACE FUNCTION public.league_cancel_personal_challenge(p_challenge_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $func$
DECLARE a jsonb:=league_private.coach_v2_actor(); c public.league_coach_challenges%ROWTYPE;
BEGIN
 IF a->>'role' NOT IN ('coach','admin')
 THEN RAISE EXCEPTION 'Coach role required' USING ERRCODE='42501'; END IF;
 SELECT * INTO c FROM public.league_coach_challenges WHERE id=p_challenge_id FOR UPDATE;
 IF c.id IS NULL OR NOT EXISTS (
   SELECT 1 FROM public.league_coach_challenge_targets t WHERE t.challenge_id=c.id)
 THEN RAISE EXCEPTION 'Personal challenge not found' USING ERRCODE='22023'; END IF;
 IF a->>'role'<>'admin' AND c.created_by<>(a->>'id')::uuid
 THEN RAISE EXCEPTION 'Not challenge owner' USING ERRCODE='42501'; END IF;
 IF c.status<>'active'
 OR EXISTS (SELECT 1 FROM public.league_coach_challenge_reviews r WHERE r.challenge_id=c.id)
 OR EXISTS (SELECT 1 FROM public.league_coach_challenge_exp_ledger l WHERE l.challenge_id=c.id)
 OR EXISTS (SELECT 1 FROM public.point_transactions p
            WHERE p.category='challenge_exp' AND p.description LIKE 'Coach Challenge: '||c.id::text||' | %')
 THEN RAISE EXCEPTION 'Only unreviewed, unpaid active assignments may be cancelled' USING ERRCODE='22023'; END IF;
 UPDATE public.league_coach_challenges SET status='cancelled',updated_at=now() WHERE id=c.id;
 UPDATE public.league_coach_challenge_entries SET status='withdrawn'
 WHERE challenge_id=c.id AND status='joined';
 RETURN pg_catalog.jsonb_build_object('challenge_id',c.id,'status','cancelled');
END
$func$;

REVOKE ALL ON FUNCTION public.league_personal_challenge_roster() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.league_personal_challenge_roster() TO authenticated;
REVOKE ALL ON FUNCTION public.league_assign_personal_challenge(uuid,text,text,text,integer,integer)
 FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.league_assign_personal_challenge(uuid,text,text,text,integer,integer)
 TO authenticated;
REVOKE ALL ON FUNCTION public.league_cancel_personal_challenge(uuid)
 FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.league_cancel_personal_challenge(uuid)
 TO authenticated;

-- Only the nominated boxer, owning trainer and admin can see private
-- assignments; regular open challenges preserve the previous behavior.

CREATE OR REPLACE FUNCTION public.coach_challenge_v2_list()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $func$
DECLARE a jsonb:=league_private.coach_v2_actor(); result jsonb;
BEGIN
 SELECT COALESCE(pg_catalog.jsonb_agg(
 pg_catalog.jsonb_build_object(
 'id',c.id,'title',c.title,'description',c.description,'challenge_kind',c.challenge_kind,
 'duration_days',c.duration_days,'goal_spec',c.goal_spec,'status',c.status,
 'created_by',c.created_by,'created_at',c.created_at,'starts_at',c.starts_at,
 'ends_at',c.ends_at,'settled_at',c.settled_at,
 'is_creator',c.created_by=(a->>'id')::uuid,
 'is_personal_assignment',EXISTS(SELECT 1 FROM public.league_coach_challenge_targets t WHERE t.challenge_id=c.id),
 'target_boxer_name',(SELECT p.display_name FROM public.league_coach_challenge_targets t JOIN public.profiles p ON p.id=t.boxer_id WHERE t.challenge_id=c.id),
 'joined_count',(SELECT count(*) FROM public.league_coach_challenge_entries e
 WHERE e.challenge_id=c.id AND e.status IN ('joined','completed')),
 'my_enrollment_status',(SELECT e.status FROM public.league_coach_challenge_entries e
 WHERE e.challenge_id=c.id AND e.boxer_id=(a->>'id')::uuid),
 'my_review_approved',(SELECT r.approved FROM public.league_coach_challenge_reviews r
 WHERE r.challenge_id=c.id AND r.boxer_id=(a->>'id')::uuid)
 ) ORDER BY c.created_at DESC,c.id), '[]'::jsonb) INTO result
 FROM public.league_coach_challenges c
 WHERE (a->>'role'='admin'
 OR (a->>'role'='coach' AND (c.created_by=(a->>'id')::uuid OR c.status IN ('open','active','awaiting_reviews','settled')))
 OR (a->>'role'='boxer' AND c.status IN ('open','active','awaiting_reviews','settled')))
 AND (NOT EXISTS (SELECT 1 FROM public.league_coach_challenge_targets t WHERE t.challenge_id=c.id)
   OR a->>'role'='admin' OR c.created_by=(a->>'id')::uuid
   OR EXISTS (SELECT 1 FROM public.league_coach_challenge_targets t
      WHERE t.challenge_id=c.id AND t.boxer_id=(a->>'id')::uuid));
 RETURN result;
END
$func$;

CREATE OR REPLACE FUNCTION public.coach_challenge_v2_join(p_challenge_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $func$
DECLARE a jsonb:=league_private.coach_v2_actor(); c public.league_coach_challenges%ROWTYPE; current_status text;
BEGIN
 IF a->>'role'<>'boxer' THEN RAISE EXCEPTION 'Boxer role required' USING ERRCODE='42501'; END IF;
 SELECT * INTO c FROM public.league_coach_challenges WHERE id=p_challenge_id FOR UPDATE;
 IF c.id IS NULL OR c.status<>'open' THEN RAISE EXCEPTION 'Challenge not open' USING ERRCODE='22023'; END IF;
 IF EXISTS(SELECT 1 FROM public.league_coach_challenge_targets t
    WHERE t.challenge_id=c.id AND t.boxer_id<>(a->>'id')::uuid)
 THEN RAISE EXCEPTION 'Personal challenge belongs to another boxer' USING ERRCODE='42501'; END IF;
 SELECT status INTO current_status FROM public.league_coach_challenge_entries
 WHERE challenge_id=c.id AND boxer_id=(a->>'id')::uuid FOR UPDATE;
 IF current_status='completed' THEN RAISE EXCEPTION 'Entry already completed' USING ERRCODE='22023'; END IF;
 IF current_status='withdrawn' THEN
 UPDATE public.league_coach_challenge_entries
 SET status='joined',joined_at=now() WHERE challenge_id=c.id AND boxer_id=(a->>'id')::uuid;
 ELSIF current_status IS NULL THEN
 INSERT INTO public.league_coach_challenge_entries(challenge_id,boxer_id)
 VALUES(c.id,(a->>'id')::uuid);
 END IF;
 RETURN pg_catalog.jsonb_build_object('challenge_id',c.id,'status','joined');
END
$func$;

CREATE OR REPLACE FUNCTION public.coach_challenge_v2_goal_details(p_challenge_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $func$
DECLARE a jsonb:=league_private.coach_v2_actor(); c public.league_coach_challenges%ROWTYPE;
BEGIN
 SELECT * INTO c FROM public.league_coach_challenges WHERE id=p_challenge_id;
 IF c.id IS NULL OR
 (a->>'role'<>'admin' AND c.created_by<>(a->>'id')::uuid AND c.status NOT IN ('open','active','awaiting_reviews','settled')) OR (a->>'role'<>'admin' AND c.created_by<>(a->>'id')::uuid AND EXISTS (
  SELECT 1 FROM public.league_coach_challenge_targets t
  WHERE t.challenge_id=c.id AND t.boxer_id<>(a->>'id')::uuid))
 THEN RAISE EXCEPTION 'Challenge not visible' USING ERRCODE='42501'; END IF;
 RETURN pg_catalog.jsonb_build_object('challenge_id',c.id,'status',c.status,
 'challenge_kind',c.challenge_kind,'goal_spec',c.goal_spec,
 'starts_at',c.starts_at,'ends_at',c.ends_at);
END
$func$;

CREATE OR REPLACE FUNCTION public.coach_challenge_v2_progress(p_challenge_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $func$
DECLARE a jsonb:=league_private.coach_v2_actor(); c public.league_coach_challenges%ROWTYPE;
DECLARE participants integer; reviews integer; v_enrollment text; v_approved boolean;
BEGIN
 SELECT * INTO c FROM public.league_coach_challenges WHERE id=p_challenge_id;
 IF c.id IS NULL OR
 (a->>'role'<>'admin' AND c.created_by<>(a->>'id')::uuid AND c.status NOT IN ('open','active','awaiting_reviews','settled')) OR (a->>'role'<>'admin' AND c.created_by<>(a->>'id')::uuid AND EXISTS (
  SELECT 1 FROM public.league_coach_challenge_targets t
  WHERE t.challenge_id=c.id AND t.boxer_id<>(a->>'id')::uuid))
 THEN RAISE EXCEPTION 'Challenge not visible' USING ERRCODE='42501'; END IF;
 SELECT count(*) INTO participants FROM public.league_coach_challenge_entries
 WHERE challenge_id=c.id AND status IN ('joined','completed');
 SELECT count(*) INTO reviews FROM public.league_coach_challenge_reviews r
 JOIN public.league_coach_challenge_entries e ON e.challenge_id=r.challenge_id
 AND e.boxer_id=r.boxer_id
 WHERE r.challenge_id=c.id AND e.status IN ('joined','completed');
 SELECT status INTO v_enrollment FROM public.league_coach_challenge_entries
 WHERE challenge_id=c.id AND boxer_id=(a->>'id')::uuid;
 SELECT approved INTO v_approved FROM public.league_coach_challenge_reviews
 WHERE challenge_id=c.id AND boxer_id=(a->>'id')::uuid;
 RETURN pg_catalog.jsonb_build_object('challenge_id',c.id,'status',c.status,
 'joined_count',participants,'reviewed_count',reviews,'pending_count',participants-reviews,
 'my_enrollment_status',v_enrollment,'my_review_approved',v_approved,
 'goal_spec',c.goal_spec,'starts_at',c.starts_at,'ends_at',c.ends_at);
END
$func$;

-- Do not widen the public interface of these existing RPCs.
DO $verify$
BEGIN
 IF (SELECT count(*) FROM pg_catalog.pg_proc p
   JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname='public' AND p.proname IN
   ('league_assign_personal_challenge','league_cancel_personal_challenge','league_personal_challenge_roster')
   AND p.prosecdef
   AND pg_catalog.has_function_privilege('authenticated',p.oid,'EXECUTE')
   AND NOT pg_catalog.has_function_privilege('anon',p.oid,'EXECUTE'))<>3
 THEN RAISE EXCEPTION 'Personal challenge RPC permissions invalid'; END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_class c
   WHERE c.oid='public.league_coach_challenge_targets'::regclass
   AND c.relrowsecurity)
 OR pg_catalog.has_table_privilege('anon','public.league_coach_challenge_targets','SELECT')
 OR pg_catalog.has_table_privilege('authenticated','public.league_coach_challenge_targets','SELECT')
 THEN RAISE EXCEPTION 'Target mapping table is accessible without authorization'; END IF;
END
$verify$;

NOTIFY pgrst, 'reload schema';
COMMIT;
