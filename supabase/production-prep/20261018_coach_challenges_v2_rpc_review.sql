-- Coach Challenges V2: read, review, and atomic EXP settlement RPCs (part 2/2).
-- PREPARED ONLY. Apply after _rpc_core; do not activate production feature flag.
BEGIN;
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
 'joined_count',(SELECT count(*) FROM public.league_coach_challenge_entries e
 WHERE e.challenge_id=c.id AND e.status IN ('joined','completed')),
 'my_enrollment_status',(SELECT e.status FROM public.league_coach_challenge_entries e
 WHERE e.challenge_id=c.id AND e.boxer_id=(a->>'id')::uuid),
 'my_review_approved',(SELECT r.approved FROM public.league_coach_challenge_reviews r
 WHERE r.challenge_id=c.id AND r.boxer_id=(a->>'id')::uuid)
 ) ORDER BY c.created_at DESC,c.id), '[]'::jsonb) INTO result
 FROM public.league_coach_challenges c
 WHERE a->>'role'='admin'
 OR (a->>'role'='coach' AND (c.created_by=(a->>'id')::uuid OR c.status IN ('open','active','awaiting_reviews','settled')))
 OR (a->>'role'='boxer' AND c.status IN ('open','active','awaiting_reviews','settled'));
 RETURN result;
END
$func$;

CREATE OR REPLACE FUNCTION public.coach_challenge_v2_goal_details(p_challenge_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $func$
DECLARE a jsonb:=league_private.coach_v2_actor(); c public.league_coach_challenges%ROWTYPE;
BEGIN
 SELECT * INTO c FROM public.league_coach_challenges WHERE id=p_challenge_id;
 IF c.id IS NULL OR
 (a->>'role'<>'admin' AND c.created_by<>(a->>'id')::uuid AND c.status NOT IN ('open','active','awaiting_reviews','settled'))
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
 (a->>'role'<>'admin' AND c.created_by<>(a->>'id')::uuid AND c.status NOT IN ('open','active','awaiting_reviews','settled'))
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

CREATE OR REPLACE FUNCTION public.coach_challenge_v2_review_status(p_challenge_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $func$
DECLARE a jsonb:=league_private.coach_v2_actor(); c public.league_coach_challenges%ROWTYPE;
DECLARE total integer; done integer; success integer;
BEGIN
 SELECT * INTO c FROM public.league_coach_challenges WHERE id=p_challenge_id;
 IF c.id IS NULL THEN RAISE EXCEPTION 'Challenge not found' USING ERRCODE='P0002'; END IF;
 IF a->>'role' NOT IN ('coach','admin') OR
 (a->>'role'<>'admin' AND c.created_by<>(a->>'id')::uuid)
 THEN RAISE EXCEPTION 'Not challenge manager' USING ERRCODE='42501'; END IF;
 SELECT count(*) INTO total FROM public.league_coach_challenge_entries e
 WHERE e.challenge_id=c.id AND e.status IN ('joined','completed');
 SELECT count(*),count(*) FILTER (WHERE r.approved) INTO done,success
 FROM public.league_coach_challenge_reviews r
 JOIN public.league_coach_challenge_entries e ON e.challenge_id=r.challenge_id AND e.boxer_id=r.boxer_id
 WHERE r.challenge_id=c.id AND e.status IN ('joined','completed');
 RETURN pg_catalog.jsonb_build_object('challenge_id',c.id,'status',c.status,
 'joined_count',total,'reviewed_count',done,'pending_count',total-done,
 'approved_count',success,'rejected_count',done-success);
END
$func$;

CREATE OR REPLACE FUNCTION public.coach_challenge_v2_review_candidates(p_challenge_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $func$
DECLARE a jsonb:=league_private.coach_v2_actor(); c public.league_coach_challenges%ROWTYPE; result jsonb;
BEGIN
 SELECT * INTO c FROM public.league_coach_challenges WHERE id=p_challenge_id;
 IF c.id IS NULL THEN RAISE EXCEPTION 'Challenge not found' USING ERRCODE='P0002'; END IF;
 IF a->>'role' NOT IN ('coach','admin') OR
 (a->>'role'<>'admin' AND c.created_by<>(a->>'id')::uuid)
 THEN RAISE EXCEPTION 'Not challenge manager' USING ERRCODE='42501'; END IF;
 IF c.status<>'awaiting_reviews' OR c.ends_at IS NULL OR c.ends_at>now()
 THEN RAISE EXCEPTION 'Reviews unavailable' USING ERRCODE='22023'; END IF;
 SELECT COALESCE(pg_catalog.jsonb_agg(
 pg_catalog.jsonb_build_object('boxer_id',e.boxer_id,'display_name',p.display_name)
 ORDER BY p.display_name,e.boxer_id), '[]'::jsonb) INTO result
 FROM public.league_coach_challenge_entries e
 JOIN public.profiles p ON p.id=e.boxer_id
 WHERE e.challenge_id=c.id AND e.status='joined'
 AND NOT EXISTS (SELECT 1 FROM public.league_coach_challenge_reviews r
 WHERE r.challenge_id=e.challenge_id AND r.boxer_id=e.boxer_id);
 RETURN result;
END
$func$;

CREATE OR REPLACE FUNCTION public.coach_challenge_v2_begin_reviews(p_challenge_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $func$
DECLARE a jsonb:=league_private.coach_v2_actor(); c public.league_coach_challenges%ROWTYPE;
BEGIN
 IF a->>'role' NOT IN ('coach','admin') THEN RAISE EXCEPTION 'Coach role required' USING ERRCODE='42501'; END IF;
 SELECT * INTO c FROM public.league_coach_challenges WHERE id=p_challenge_id FOR UPDATE;
 IF c.id IS NULL THEN RAISE EXCEPTION 'Challenge not found' USING ERRCODE='P0002'; END IF;
 IF a->>'role'<>'admin' AND c.created_by<>(a->>'id')::uuid
 THEN RAISE EXCEPTION 'Not challenge owner' USING ERRCODE='42501'; END IF;
 IF c.status<>'active' OR c.ends_at IS NULL OR c.ends_at>now()
 THEN RAISE EXCEPTION 'Challenge still active' USING ERRCODE='22023'; END IF;
 UPDATE public.league_coach_challenges SET status='awaiting_reviews',updated_at=now() WHERE id=c.id;
 RETURN pg_catalog.jsonb_build_object('id',c.id,'status','awaiting_reviews');
END
$func$;

CREATE OR REPLACE FUNCTION public.coach_challenge_v2_review_manual(
 p_challenge_id uuid,p_boxer_id uuid,p_approved boolean,p_reason text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $func$
DECLARE a jsonb:=league_private.coach_v2_actor(); c public.league_coach_challenges%ROWTYPE;
BEGIN
 IF a->>'role' NOT IN ('coach','admin') THEN RAISE EXCEPTION 'Coach role required' USING ERRCODE='42501'; END IF;
 SELECT * INTO c FROM public.league_coach_challenges WHERE id=p_challenge_id FOR UPDATE;
 IF c.id IS NULL THEN RAISE EXCEPTION 'Challenge not found' USING ERRCODE='P0002'; END IF;
 IF a->>'role'<>'admin' AND c.created_by<>(a->>'id')::uuid
 THEN RAISE EXCEPTION 'Not challenge owner' USING ERRCODE='42501'; END IF;
 IF c.status<>'awaiting_reviews' OR c.ends_at IS NULL OR c.ends_at>now()
 THEN RAISE EXCEPTION 'Manual review unavailable' USING ERRCODE='22023'; END IF;
 IF p_approved IS NULL OR char_length(pg_catalog.btrim(COALESCE(p_reason,''))) NOT BETWEEN 5 AND 1000
 THEN RAISE EXCEPTION 'Valid decision and reason required' USING ERRCODE='22023'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.league_coach_challenge_entries
 WHERE challenge_id=c.id AND boxer_id=p_boxer_id AND status='joined')
 THEN RAISE EXCEPTION 'Boxer not enrolled' USING ERRCODE='42501'; END IF;
 INSERT INTO public.league_coach_challenge_reviews(challenge_id,boxer_id,reviewed_by,approved,reason)
 VALUES(c.id,p_boxer_id,(a->>'id')::uuid,p_approved,pg_catalog.btrim(p_reason))
 ON CONFLICT (challenge_id,boxer_id) DO UPDATE SET
 reviewed_by=excluded.reviewed_by,approved=excluded.approved,reason=excluded.reason,reviewed_at=now();
 RETURN pg_catalog.jsonb_build_object('challenge_id',c.id,'boxer_id',p_boxer_id,'approved',p_approved);
END
$func$;

CREATE OR REPLACE FUNCTION public.coach_challenge_v2_settle_manual(p_challenge_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $func$
DECLARE a jsonb:=league_private.coach_v2_actor(); c public.league_coach_challenges%ROWTYPE;
DECLARE e record; v_reward integer; v_transaction uuid; v_awards integer:=0; v_pending integer;
DECLARE v_existing_id uuid; v_existing_reward integer; v_description text; v_found boolean;
BEGIN
 IF a->>'role' NOT IN ('coach','admin') THEN RAISE EXCEPTION 'Coach role required' USING ERRCODE='42501'; END IF;
 SELECT * INTO c FROM public.league_coach_challenges WHERE id=p_challenge_id FOR UPDATE;
 IF c.id IS NULL THEN RAISE EXCEPTION 'Challenge not found' USING ERRCODE='P0002'; END IF;
 IF a->>'role'<>'admin' AND c.created_by<>(a->>'id')::uuid
 THEN RAISE EXCEPTION 'Not challenge owner' USING ERRCODE='42501'; END IF;
 IF c.status='settled' THEN
 -- Repeated settlement is idempotent, but corruption must never look successful.
 -- Check payout references and catch stray transactions for this immutable challenge id.
 IF EXISTS (
  SELECT 1 FROM public.league_coach_challenge_exp_ledger l
  LEFT JOIN public.point_transactions t ON t.id=l.transaction_id
  WHERE l.challenge_id=c.id
  AND (t.id IS NULL OR t.boxer_id<>l.boxer_id OR t.category<>'challenge_exp'
   OR t.exp<>l.awarded_exp OR t.points<>0
   OR t.description IS DISTINCT FROM 'Coach Challenge: '||c.id::text||' | '||c.title)
 ) OR EXISTS (
  SELECT 1 FROM public.point_transactions t
  WHERE t.category='challenge_exp'
  AND t.description LIKE 'Coach Challenge: '||c.id::text||' | %'
  AND NOT EXISTS (SELECT 1 FROM public.league_coach_challenge_exp_ledger l
   WHERE l.challenge_id=c.id AND l.boxer_id=t.boxer_id AND l.transaction_id=t.id)
 ) OR EXISTS (
  SELECT 1 FROM public.league_coach_challenge_entries j
  JOIN public.league_coach_challenge_reviews r
   ON r.challenge_id=j.challenge_id AND r.boxer_id=j.boxer_id
  WHERE j.challenge_id=c.id AND j.status='completed' AND r.approved
  AND NOT EXISTS (SELECT 1 FROM public.league_coach_challenge_exp_ledger l
   WHERE l.challenge_id=j.challenge_id AND l.boxer_id=j.boxer_id)
 ) OR EXISTS (
  SELECT 1 FROM public.league_coach_challenge_exp_ledger l
  LEFT JOIN public.league_coach_challenge_entries j
   ON j.challenge_id=l.challenge_id AND j.boxer_id=l.boxer_id
  LEFT JOIN public.league_coach_challenge_reviews r
   ON r.challenge_id=l.challenge_id AND r.boxer_id=l.boxer_id
  WHERE l.challenge_id=c.id
  AND (j.status IS DISTINCT FROM 'completed' OR r.approved IS DISTINCT FROM TRUE)
 ) OR EXISTS (
  SELECT 1 FROM public.league_coach_challenge_entries j
  LEFT JOIN public.league_coach_challenge_reviews r
   ON r.challenge_id=j.challenge_id AND r.boxer_id=j.boxer_id
  WHERE j.challenge_id=c.id
  AND (j.status='joined' OR (j.status='completed' AND r.approved IS NULL))
 ) THEN RAISE EXCEPTION 'Settled challenge payout ledger is inconsistent: %',c.id USING ERRCODE='23514'; END IF;
 RETURN pg_catalog.jsonb_build_object('id',c.id,'status','settled','already_settled',true,'awards',0);
 END IF;
 IF c.status<>'awaiting_reviews' OR c.ends_at IS NULL OR c.ends_at>now()
 THEN RAISE EXCEPTION 'Challenge not ready for settlement' USING ERRCODE='22023'; END IF;
 IF c.goal_spec->>'review_mode' IS DISTINCT FROM 'manual'
 THEN RAISE EXCEPTION 'Only manual reviews supported' USING ERRCODE='22023'; END IF;
 v_reward:=(c.goal_spec->>'reward_exp')::integer;
 IF v_reward IS NULL OR v_reward NOT IN (25,50,100,150,200)
 THEN RAISE EXCEPTION 'Invalid configured EXP reward' USING ERRCODE='22023'; END IF;
 SELECT count(*) INTO v_pending FROM public.league_coach_challenge_entries j
 WHERE j.challenge_id=c.id AND j.status='joined'
 AND NOT EXISTS (SELECT 1 FROM public.league_coach_challenge_reviews r
 WHERE r.challenge_id=j.challenge_id AND r.boxer_id=j.boxer_id);
 IF v_pending>0 THEN RAISE EXCEPTION 'Unreviewed enrollments: %',v_pending USING ERRCODE='22023'; END IF;
 -- Include immutable challenge UUID in EXP descriptions for safe orphan detection.
 -- Different challenges may legitimately share the same title.
 v_description:='Coach Challenge: '||c.id::text||' | '||c.title;
 FOR e IN SELECT j.boxer_id,r.approved FROM public.league_coach_challenge_entries j
 JOIN public.league_coach_challenge_reviews r ON r.challenge_id=j.challenge_id AND r.boxer_id=j.boxer_id
 WHERE j.challenge_id=c.id AND j.status='joined' ORDER BY j.boxer_id LOOP
  SELECT l.transaction_id,l.awarded_exp INTO v_existing_id,v_existing_reward
  FROM public.league_coach_challenge_exp_ledger l
  WHERE l.challenge_id=c.id AND l.boxer_id=e.boxer_id FOR UPDATE;
  v_found:=FOUND;
  IF NOT e.approved THEN
   IF v_found OR EXISTS(
     SELECT 1 FROM public.point_transactions t
     WHERE t.boxer_id=e.boxer_id AND t.category='challenge_exp'
     AND t.description LIKE 'Coach Challenge: '||c.id::text||' | %'
   ) THEN RAISE EXCEPTION 'Rejected boxer has challenge EXP for %',c.id USING ERRCODE='23514'; END IF;
   CONTINUE;
  END IF;
  IF v_found THEN
   IF (SELECT count(*) FROM public.point_transactions t
       WHERE t.boxer_id=e.boxer_id AND t.category='challenge_exp'
       AND t.description LIKE 'Coach Challenge: '||c.id::text||' | %')<>1
   THEN RAISE EXCEPTION 'Duplicate or missing challenge payout for %',c.id USING ERRCODE='23514'; END IF;
   -- Fail closed: never treat an orphaned/malformed ledger as a paid reward.
   IF v_existing_id IS NULL OR v_existing_reward IS DISTINCT FROM v_reward OR
    NOT EXISTS(
     SELECT 1 FROM public.point_transactions t WHERE t.id=v_existing_id
     AND t.boxer_id=e.boxer_id AND t.category='challenge_exp'
     AND t.points=0 AND t.exp=v_reward AND t.description=v_description
    ) THEN RAISE EXCEPTION 'Challenge EXP ledger/transaction mismatch for %',c.id USING ERRCODE='23514'; END IF;
  ELSE
   -- An orphaned payout would otherwise be paid twice if its ledger row is missing.
   IF EXISTS(SELECT 1 FROM public.point_transactions t
     WHERE t.boxer_id=e.boxer_id AND t.category='challenge_exp'
     AND t.description LIKE 'Coach Challenge: '||c.id::text||' | %'
   ) THEN RAISE EXCEPTION 'Orphaned challenge payout for % boxer %',c.id,e.boxer_id USING ERRCODE='23514'; END IF;
   INSERT INTO public.point_transactions(boxer_id,points,exp,category,description,effective_date,created_by)
   VALUES(e.boxer_id,0,v_reward,'challenge_exp',v_description,
   (now() AT TIME ZONE 'Europe/Zurich')::date,(a->>'id')::uuid)
   RETURNING id INTO v_transaction;
   INSERT INTO public.league_coach_challenge_exp_ledger(challenge_id,boxer_id,transaction_id,awarded_exp)
   VALUES(c.id,e.boxer_id,v_transaction,v_reward);
   v_awards:=v_awards+1;
  END IF;
 END LOOP;
 UPDATE public.league_coach_challenge_entries SET status='completed'
 WHERE challenge_id=c.id AND status='joined';
 UPDATE public.league_coach_challenges SET status='settled',settled_at=now(),updated_at=now()
 WHERE id=c.id;
 RETURN pg_catalog.jsonb_build_object('id',c.id,'status','settled',
 'already_settled',false,'awards',v_awards);
END
$func$;

DO $grant$
DECLARE sig text;
BEGIN
 FOREACH sig IN ARRAY ARRAY[
 'coach_challenge_v2_list()',
 'coach_challenge_v2_goal_details(uuid)',
 'coach_challenge_v2_progress(uuid)',
 'coach_challenge_v2_review_status(uuid)',
 'coach_challenge_v2_review_candidates(uuid)',
 'coach_challenge_v2_begin_reviews(uuid)',
 'coach_challenge_v2_review_manual(uuid,uuid,boolean,text)',
 'coach_challenge_v2_settle_manual(uuid)'] LOOP
 EXECUTE 'REVOKE ALL ON FUNCTION public.'||sig||' FROM PUBLIC, anon';
 EXECUTE 'GRANT EXECUTE ON FUNCTION public.'||sig||' TO authenticated';
END LOOP;
END
$grant$;
COMMIT;
