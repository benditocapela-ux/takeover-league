-- Takeover League V2: Boxer duels (prepared, not deployed).
-- Depends on previously tested Coach Challenges V2 compatibility migration:
-- the duels feature flag exists and is disabled, coach role and duel_exp category are allowed.
-- Copies six reviewed SECURITY DEFINER RPC definitions from the isolated Supabase test project.
BEGIN;
DO $preflight$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.league_feature_flags WHERE feature_key='duels' AND is_enabled IS FALSE)
 THEN RAISE EXCEPTION 'Duels flag missing or enabled; apply compatibility migration first'; END IF;
 IF EXISTS(SELECT 1 FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public' AND p.proname LIKE 'duel_v2_%')
 THEN RAISE EXCEPTION 'V2 duel RPCs already exist; collision review required'; END IF;
 IF pg_catalog.to_regclass('public.league_duels') IS NOT NULL OR
    pg_catalog.to_regclass('public.league_duel_exp_ledger') IS NOT NULL OR
    pg_catalog.to_regclass('public.league_duel_events') IS NOT NULL
 THEN RAISE EXCEPTION 'V2 duel tables already exist; collision review required'; END IF;
END $preflight$;

CREATE TABLE public.league_duels (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 challenger_id uuid NOT NULL REFERENCES public.profiles(id),
 opponent_id uuid NOT NULL REFERENCES public.profiles(id),
 created_by uuid REFERENCES public.profiles(id),
 initiated_by_coach boolean NOT NULL DEFAULT false,
 status text NOT NULL DEFAULT 'pending'
  CHECK (status IN ('pending','active','awaiting_reviews','settled','declined','expired','cancelled')),
 duration_days integer NOT NULL CHECK (duration_days IN (7,14)),
 invited_at timestamptz NOT NULL DEFAULT now(),
 expires_at timestamptz NOT NULL DEFAULT (now() + INTERVAL '48 hours'),
 accepted_at timestamptz,
 ends_at timestamptz,
 settled_at timestamptz,
 challenger_score integer NOT NULL DEFAULT 0 CHECK (challenger_score>=0),
 opponent_score integer NOT NULL DEFAULT 0 CHECK (opponent_score>=0),
 winner_id uuid REFERENCES public.profiles(id),
 updated_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT duel_distinct_boxers CHECK (challenger_id<>opponent_id),
 CONSTRAINT duel_invitation_expiry CHECK (expires_at>invited_at),
 CONSTRAINT duel_active_dates CHECK (status<>'active' OR (accepted_at IS NOT NULL AND ends_at IS NOT NULL)),
 CONSTRAINT duel_end_date CHECK (ends_at IS NULL OR (accepted_at IS NOT NULL AND ends_at=accepted_at + duration_days*INTERVAL '1 day')),
 CONSTRAINT duel_valid_winner CHECK (winner_id IS NULL OR winner_id IN (challenger_id,opponent_id))
);
CREATE UNIQUE INDEX league_duels_one_pending_per_pair
 ON public.league_duels(LEAST(challenger_id,opponent_id),GREATEST(challenger_id,opponent_id))
 WHERE status='pending';
CREATE UNIQUE INDEX league_duels_one_active_per_pair
 ON public.league_duels(LEAST(challenger_id,opponent_id),GREATEST(challenger_id,opponent_id))
 WHERE status='active';
CREATE INDEX league_duels_challenger_status_idx ON public.league_duels(challenger_id,status,ends_at);
CREATE INDEX league_duels_opponent_status_idx ON public.league_duels(opponent_id,status,ends_at);

CREATE TABLE public.league_duel_events (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 duel_id uuid NOT NULL REFERENCES public.league_duels(id),
 boxer_id uuid REFERENCES public.profiles(id),
 event_type text NOT NULL CHECK (event_type IN
 ('invited','accepted','declined','expired','awaiting_reviews','settled','corrected','cancelled')),
 payload jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.league_duel_exp_ledger (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 duel_id uuid NOT NULL REFERENCES public.league_duels(id),
 boxer_id uuid NOT NULL REFERENCES public.profiles(id),
 transaction_id uuid UNIQUE REFERENCES public.point_transactions(id),
 awarded_exp integer NOT NULL DEFAULT 0 CHECK (awarded_exp IN (0,25,50,100)),
 updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE (duel_id,boxer_id)
);
ALTER TABLE public.league_duels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.league_duel_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.league_duel_exp_ledger ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.league_duels,public.league_duel_events,
 public.league_duel_exp_ledger FROM PUBLIC,anon,authenticated;

-- Reviewed copies of the six V2 RPC functions from the test database.

CREATE OR REPLACE FUNCTION public.duel_v2_eligible_boxers()
 RETURNS TABLE(id uuid, display_name text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_profile uuid;
BEGIN
 SELECT p.id INTO v_profile FROM public.profiles p
 WHERE p.auth_user_id=(SELECT auth.uid()) AND p.is_active=true
 AND p.role IN ('boxer','admin','coach');
 IF v_profile IS NULL THEN RAISE EXCEPTION 'Not authorized'; END IF;
 IF NOT EXISTS (
  SELECT 1 FROM public.league_feature_flags
  WHERE feature_key='duels' AND is_enabled=true
 ) THEN RAISE EXCEPTION 'Duels are not enabled'; END IF;
 RETURN QUERY
 SELECT p.id,p.display_name::text FROM public.profiles p
 WHERE p.role='boxer' AND p.is_active=true
 ORDER BY p.display_name,p.id;
END $function$;

CREATE OR REPLACE FUNCTION public.duel_v2_invite(p_challenger uuid, p_opponent uuid, p_duration_days integer DEFAULT 7)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
 v_actor public.profiles%ROWTYPE;
 v_first uuid;
 v_second uuid;
 v_duel uuid;
 v_now timestamptz := clock_timestamp();
BEGIN
 SELECT * INTO v_actor FROM public.profiles
 WHERE auth_user_id=(SELECT auth.uid()) AND is_active=true;
 IF NOT FOUND OR v_actor.role NOT IN ('boxer','admin','coach') THEN
  RAISE EXCEPTION 'Not authorized to create a duel';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.league_feature_flags WHERE feature_key='duels' AND is_enabled=true) THEN
  RAISE EXCEPTION 'Duels are not enabled';
 END IF;
 IF p_challenger IS NULL OR p_opponent IS NULL OR p_challenger=p_opponent THEN
  RAISE EXCEPTION 'Two different boxers required';
 END IF;
 IF p_duration_days IS NULL OR p_duration_days NOT IN (7,14) THEN
  RAISE EXCEPTION 'Duel duration must be 7 or 14 days';
 END IF;
 IF v_actor.role='boxer' AND v_actor.id<>p_challenger THEN
  RAISE EXCEPTION 'Boxer may only challenge on own behalf';
 END IF;

 -- Serialize invitation and acceptance decisions for each boxer pair.
 v_first:=least(p_challenger,p_opponent);
 v_second:=greatest(p_challenger,p_opponent);
 PERFORM 1 FROM public.profiles WHERE id IN (v_first,v_second)
 ORDER BY id FOR UPDATE;
 IF (SELECT count(*) FROM public.profiles
     WHERE id IN (v_first,v_second) AND role='boxer' AND is_active=true)<>2 THEN
  RAISE EXCEPTION 'Both participants must be active boxers';
 END IF;
 -- Invitation timestamps and expired-pair cleanup use time after lock wait.
 v_now:=clock_timestamp();

 -- Ended active duels must release the pair uniqueness constraint for rematches.
 UPDATE public.league_duels SET status='awaiting_reviews',updated_at=v_now
 WHERE status='active' AND ends_at<=v_now
 AND least(challenger_id,opponent_id)=v_first
 AND greatest(challenger_id,opponent_id)=v_second;

 -- Expired pending invites should not block future invites.
 UPDATE public.league_duels SET status='expired',updated_at=v_now
 WHERE status='pending' AND expires_at<=v_now
 AND least(challenger_id,opponent_id)=v_first
 AND greatest(challenger_id,opponent_id)=v_second;

 IF EXISTS (
  SELECT 1 FROM public.league_duels
  WHERE least(challenger_id,opponent_id)=v_first
    AND greatest(challenger_id,opponent_id)=v_second
    AND (status='pending' OR
         (status IN ('active','awaiting_reviews','settled') AND ends_at>v_now))
 ) THEN RAISE EXCEPTION 'This boxer pair already has a pending or ongoing duel'; END IF;

 INSERT INTO public.league_duels
  (challenger_id,opponent_id,created_by,initiated_by_coach,duration_days,
   invited_at,expires_at)
 VALUES
  (p_challenger,p_opponent,v_actor.id,v_actor.role<>'boxer',
   p_duration_days,v_now,v_now+interval '48 hours')
 RETURNING id INTO v_duel;
 INSERT INTO public.league_duel_events(duel_id,boxer_id,event_type)
 VALUES(v_duel,v_actor.id,'invited');
 RETURN v_duel;
END $function$;

CREATE OR REPLACE FUNCTION public.duel_v2_list_mine()
 RETURNS TABLE(id uuid, challenger_id uuid, challenger_name text, opponent_id uuid, opponent_name text, status text, duration_days integer, invited_at timestamp with time zone, expires_at timestamp with time zone, accepted_at timestamp with time zone, ends_at timestamp with time zone, settled_at timestamp with time zone, challenger_score integer, opponent_score integer, winner_id uuid)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_profile uuid;
BEGIN
 SELECT p.id INTO v_profile FROM public.profiles p
 WHERE p.auth_user_id=(SELECT auth.uid()) AND p.is_active=true
 AND p.role IN ('boxer','admin','coach');
 IF v_profile IS NULL THEN RAISE EXCEPTION 'Not authorized'; END IF;
 IF NOT EXISTS (
  SELECT 1 FROM public.league_feature_flags
  WHERE feature_key='duels' AND is_enabled=true
 ) THEN RAISE EXCEPTION 'Duels are not enabled'; END IF;
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
END $function$;

CREATE OR REPLACE FUNCTION public.duel_v2_reconcile(p_duel_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
 d public.league_duels%ROWTYPE;
 actor public.profiles%ROWTYPE;
 v_clock timestamptz := clock_timestamp();
 actor_found boolean;
 p1 integer;
 p2 integer;
 pending_count integer;
 target_exp integer;
 boxer uuid;
 old_exp integer;
 old_tx uuid;
 new_tx uuid;
 existing_status text;
BEGIN
 SELECT * INTO actor FROM public.profiles
 WHERE auth_user_id=(SELECT auth.uid()) AND is_active=true;
 actor_found:=FOUND;
 IF NOT EXISTS(SELECT 1 FROM public.league_feature_flags WHERE feature_key='duels' AND is_enabled=true) THEN
  RAISE EXCEPTION 'Duels are not enabled';
 END IF;
 IF NOT actor_found OR actor.role NOT IN ('admin','coach') THEN
  RAISE EXCEPTION 'Only a coach may reconcile duels';
 END IF;
 -- Lock boxer profiles before the duel row, matching invite/respond.
 SELECT * INTO d FROM public.league_duels WHERE id=p_duel_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Duel not found'; END IF;
 PERFORM 1 FROM public.profiles
 WHERE id IN (d.challenger_id,d.opponent_id) ORDER BY id FOR UPDATE;
 SELECT * INTO d FROM public.league_duels WHERE id=p_duel_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Duel not found'; END IF;
 -- A lock wait may cross the duel end timestamp; decide using fresh time.
 v_clock:=clock_timestamp();
 IF d.status NOT IN ('active','awaiting_reviews','settled') THEN
  RAISE EXCEPTION 'Duel not active or completed';
 END IF;
 IF d.ends_at>v_clock THEN RETURN 'in_progress'; END IF;

 -- Lock the qualifying training submissions before counting and scoring.
 -- This serializes concurrent review/edit updates against settlement, so a
 -- submission cannot switch status between pending check and point summation.
 -- Existing review functions must be checked for consistent lock order.
 PERFORM 1 FROM public.training_submissions s
 WHERE s.boxer_id IN (d.challenger_id,d.opponent_id)
   AND s.training_date >= (d.accepted_at AT TIME ZONE 'Europe/Zurich')::date
   AND s.training_date <= (d.ends_at AT TIME ZONE 'Europe/Zurich')::date
   AND s.created_at<=d.ends_at
 ORDER BY s.id FOR UPDATE;

 -- Only timely submitted, not-yet-reviewed entries delay settlement.
 SELECT count(*) INTO pending_count
 FROM public.training_submissions s
 WHERE s.boxer_id IN (d.challenger_id,d.opponent_id)
   AND s.status='pending'
   AND s.training_date >= (d.accepted_at AT TIME ZONE 'Europe/Zurich')::date
   AND s.training_date <= (d.ends_at AT TIME ZONE 'Europe/Zurich')::date
   AND s.created_at<=d.ends_at;
 IF pending_count>0 THEN
  -- Never reopen an already-paid duel: preserve existing EXP until
  -- pending submissions are reviewed and a coach reconciles again.
  IF d.status='settled' THEN RETURN 'pending_correction'; END IF;
  IF d.status<>'awaiting_reviews' THEN
   UPDATE public.league_duels SET status='awaiting_reviews',updated_at=v_clock
   WHERE id=d.id;
   INSERT INTO public.league_duel_events(duel_id,event_type,payload)
   VALUES(d.id,'awaiting_reviews',pg_catalog.jsonb_build_object('pending',pending_count));
  END IF;
  RETURN 'awaiting_reviews';
 END IF;

 -- Fail closed on duplicate scoring transactions for the same submission.
 -- Such rows otherwise inflate the score and could award the wrong winner.
 IF EXISTS (
  SELECT 1
  FROM public.training_submissions s
  JOIN public.point_transactions t ON t.submission_id=s.id
   AND t.boxer_id=s.boxer_id
  WHERE s.boxer_id IN(d.challenger_id,d.opponent_id)
    AND s.status='approved' AND s.created_at<=d.ends_at
    AND s.training_date >= (d.accepted_at AT TIME ZONE 'Europe/Zurich')::date
    AND s.training_date <= (d.ends_at AT TIME ZONE 'Europe/Zurich')::date
    AND t.category IN('training','legacy_import')
  GROUP BY s.id HAVING count(*)>1
 ) THEN
  RAISE EXCEPTION 'Duplicate duel scoring transactions: manual review required';
 END IF;

 -- Training date is date-only. Both boundary dates are included. This is
 -- a deliberate calendar-day approximation to acceptance's exact timestamp.
 SELECT COALESCE(sum(t.points) FILTER(WHERE s.boxer_id=d.challenger_id),0)::integer,
        COALESCE(sum(t.points) FILTER(WHERE s.boxer_id=d.opponent_id),0)::integer
 INTO p1,p2
 FROM public.training_submissions s
 -- Legacy data can contain a transaction linked to another boxer's submission.
 -- Never attribute such a transaction to either duel participant.
 JOIN public.point_transactions t ON t.submission_id=s.id AND t.boxer_id=s.boxer_id
 WHERE s.boxer_id IN(d.challenger_id,d.opponent_id)
   AND s.status='approved'
   AND s.created_at<=d.ends_at
   AND s.training_date >= (d.accepted_at AT TIME ZONE 'Europe/Zurich')::date
   AND s.training_date <= (d.ends_at AT TIME ZONE 'Europe/Zurich')::date
   AND t.category IN('training','legacy_import');

 IF p1<0 OR p2<0 THEN RAISE EXCEPTION 'Negative duel scores are not supported'; END IF;

 existing_status:=d.status;
 UPDATE public.league_duels
 SET status='settled',settled_at=COALESCE(settled_at,v_clock),
     challenger_score=p1,opponent_score=p2,
     winner_id=CASE WHEN p1=p2 THEN NULL WHEN p1>p2 THEN d.challenger_id ELSE d.opponent_id END,
     updated_at=v_clock
 WHERE id=d.id;

 FOREACH boxer IN ARRAY ARRAY[d.challenger_id,d.opponent_id] LOOP
  target_exp:=CASE WHEN p1=p2 THEN 50
                   WHEN (p1>p2 AND boxer=d.challenger_id)
                     OR (p2>p1 AND boxer=d.opponent_id) THEN 100
                   ELSE 25 END;

  INSERT INTO public.league_duel_exp_ledger(duel_id,boxer_id,awarded_exp)
  VALUES(d.id,boxer,0)
  ON CONFLICT(duel_id,boxer_id) DO NOTHING;

  SELECT awarded_exp,transaction_id INTO old_exp,old_tx
  FROM public.league_duel_exp_ledger
  WHERE duel_id=d.id AND boxer_id=boxer FOR UPDATE;

  IF old_tx IS NULL THEN
   -- A settled duel must already have a payout transaction for each boxer.
   -- Never silently reconstruct a missing payout during a correction.
   IF existing_status='settled' THEN
    RAISE EXCEPTION 'Settled duel payout transaction missing for duel % boxer %',d.id,boxer;
   END IF;
   -- A missing transaction reference is valid only for a new, unpaid ledger.
   -- Do not create another reward if the ledger already claims EXP was paid.
   IF old_exp IS DISTINCT FROM 0 THEN
    RAISE EXCEPTION 'Duel reward ledger claims EXP without transaction for duel % boxer %',d.id,boxer;
   END IF;
   -- Never create a second payout if a duel_exp transaction already exists
   -- but the ledger reference was lost (including on a first settlement).
   IF EXISTS (
    SELECT 1 FROM public.point_transactions t
    WHERE t.boxer_id=boxer AND t.category='duel_exp'
      AND t.description='Duel reward: '||d.id::text
   ) THEN
    RAISE EXCEPTION 'Orphaned duel payout transaction for duel % boxer %',d.id,boxer;
   END IF;
   INSERT INTO public.point_transactions
    (boxer_id,points,exp,category,description,effective_date,created_by)
   VALUES(boxer,0,target_exp,'duel_exp',
          'Duel reward: '||d.id::text,
          (d.ends_at AT TIME ZONE 'Europe/Zurich')::date,actor.id)
   RETURNING id INTO new_tx;
   UPDATE public.league_duel_exp_ledger
   SET transaction_id=new_tx,awarded_exp=target_exp,updated_at=v_clock
   WHERE duel_id=d.id AND boxer_id=boxer;
  ELSIF old_exp IS NULL THEN
   RAISE EXCEPTION 'Duel reward ledger has NULL EXP for duel % boxer %',d.id,boxer;
  ELSIF NOT EXISTS(
   SELECT 1 FROM public.point_transactions t
   WHERE t.id=old_tx AND t.boxer_id=boxer AND t.category='duel_exp'
     AND t.points=0 AND t.exp=old_exp
     AND t.description='Duel reward: '||d.id::text
     AND t.effective_date=(d.ends_at AT TIME ZONE 'Europe/Zurich')::date
  ) THEN
   RAISE EXCEPTION 'Duel reward ledger mismatch for duel % boxer %',d.id,boxer;
  ELSIF old_exp<>target_exp THEN
   -- A payout ledger must never update an unrelated or missing transaction.
   -- A broken reference is a release-blocking integrity error, not a silent success.
   UPDATE public.point_transactions SET exp=target_exp
   WHERE id=old_tx AND boxer_id=boxer AND category='duel_exp';
   IF NOT FOUND THEN
    RAISE EXCEPTION 'Duel reward transaction missing or mismatched for duel % boxer %',d.id,boxer;
   END IF;
   UPDATE public.league_duel_exp_ledger
   SET awarded_exp=target_exp,updated_at=v_clock
   WHERE duel_id=d.id AND boxer_id=boxer;
  END IF;
 END LOOP;

 IF existing_status<>'settled' OR p1<>d.challenger_score OR p2<>d.opponent_score THEN
  INSERT INTO public.league_duel_events(duel_id,event_type,payload)
  VALUES(d.id,CASE WHEN existing_status='settled' THEN 'corrected' ELSE 'settled' END,
   pg_catalog.jsonb_build_object('previous_scores',pg_catalog.jsonb_build_array(d.challenger_score,d.opponent_score),
                                'scores',pg_catalog.jsonb_build_array(p1,p2)));
 END IF;
 RETURN 'settled';
END $function$;

CREATE OR REPLACE FUNCTION public.duel_v2_reconcile_due(p_include_settled boolean DEFAULT false, p_after uuid DEFAULT NULL::uuid)
 RETURNS TABLE(duel_id uuid, outcome text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
 actor_role text;
 item record;
BEGIN
 SELECT p.role INTO actor_role FROM public.profiles p
 WHERE p.auth_user_id=(SELECT auth.uid()) AND p.is_active=true;
 IF actor_role IS NULL OR actor_role NOT IN ('admin','coach') THEN
  RAISE EXCEPTION 'Only a coach may reconcile duels';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.league_feature_flags
               WHERE feature_key='duels' AND is_enabled=true) THEN
  RAISE EXCEPTION 'Duels are not enabled';
 END IF;
 FOR item IN
  SELECT d.id FROM public.league_duels d
  WHERE (d.status IN ('active','awaiting_reviews')
         OR (p_include_settled AND d.status='settled'))
    AND d.ends_at<=clock_timestamp()
    AND (p_after IS NULL OR d.id>p_after)
  ORDER BY d.id LIMIT 100
 LOOP
  duel_id:=item.id;
  outcome:=public.duel_v2_reconcile(item.id);
  RETURN NEXT;
 END LOOP;
END $function$;

CREATE OR REPLACE FUNCTION public.duel_v2_respond(p_duel_id uuid, p_accept boolean)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
 v_actor public.profiles%ROWTYPE;
 v_duel public.league_duels%ROWTYPE;
 v_now timestamptz := clock_timestamp();
 v_count integer;
BEGIN
 SELECT * INTO v_actor FROM public.profiles
 WHERE auth_user_id=(SELECT auth.uid()) AND role='boxer' AND is_active=true;
 IF NOT FOUND THEN RAISE EXCEPTION 'Only an active boxer may respond'; END IF;
 -- Resolve participants without taking a duel row lock; all duel mutations
 -- acquire participant profile locks first, then the duel row lock.
 SELECT * INTO v_duel FROM public.league_duels WHERE id=p_duel_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Duel not found'; END IF;
 PERFORM 1 FROM public.profiles
 WHERE id IN (v_duel.challenger_id,v_duel.opponent_id)
 ORDER BY id FOR UPDATE;
 SELECT * INTO v_duel FROM public.league_duels WHERE id=p_duel_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Duel not found'; END IF;
 -- Refresh the clock after any lock wait; expiry must use decision time.
 v_now:=clock_timestamp();
 IF NOT EXISTS(SELECT 1 FROM public.league_feature_flags WHERE feature_key='duels' AND is_enabled=true) THEN
  RAISE EXCEPTION 'Duels are not enabled';
 END IF;
 IF v_actor.id<>v_duel.opponent_id THEN
  RAISE EXCEPTION 'Only the invited boxer may respond';
 END IF;
 IF v_duel.status<>'pending' THEN RAISE EXCEPTION 'Invitation is no longer pending'; END IF;
 IF p_accept IS NULL THEN RAISE EXCEPTION 'Explicit acceptance or decline required'; END IF;
 IF v_duel.expires_at<=v_now THEN
  UPDATE public.league_duels SET status='expired',updated_at=v_now WHERE id=p_duel_id;
  INSERT INTO public.league_duel_events(duel_id,event_type) VALUES(p_duel_id,'expired');
  RETURN 'expired';
 END IF;
 IF p_accept=false THEN
  UPDATE public.league_duels SET status='declined',updated_at=v_now WHERE id=p_duel_id;
  INSERT INTO public.league_duel_events(duel_id,boxer_id,event_type)
  VALUES(p_duel_id,v_actor.id,'declined');
  RETURN 'declined';
 END IF;

 -- Participant profile locks were already acquired before the duel row lock.
 -- Do not reacquire them in a different lock order.
 IF (SELECT count(*) FROM public.profiles
     WHERE id IN (v_duel.challenger_id,v_duel.opponent_id)
       AND role='boxer' AND is_active=true)<>2 THEN
  RAISE EXCEPTION 'Both boxers must be active';
 END IF;
 SELECT count(*) INTO v_count FROM public.league_duels d
 WHERE d.status='active' AND d.ends_at>v_now
 AND (d.challenger_id=v_duel.challenger_id OR d.opponent_id=v_duel.challenger_id);
 IF v_count>=3 THEN RAISE EXCEPTION 'Challenger has three active duels'; END IF;
 SELECT count(*) INTO v_count FROM public.league_duels d
 WHERE d.status='active' AND d.ends_at>v_now
 AND (d.challenger_id=v_duel.opponent_id OR d.opponent_id=v_duel.opponent_id);
 IF v_count>=3 THEN RAISE EXCEPTION 'Opponent has three active duels'; END IF;

 -- An opposite-direction pending invite cannot be activated alongside this
 -- invitation; pair uniqueness is guaranteed for active duels by index.
 -- The index also protects simultaneous acceptances across sessions.
 IF EXISTS (
  SELECT 1 FROM public.league_duels d
  WHERE d.id<>p_duel_id
    AND d.status='active' AND d.ends_at>v_now
    AND least(d.challenger_id,d.opponent_id)=least(v_duel.challenger_id,v_duel.opponent_id)
    AND greatest(d.challenger_id,d.opponent_id)=greatest(v_duel.challenger_id,v_duel.opponent_id)
 ) THEN
  RAISE EXCEPTION 'This boxer pair already has an active duel';
 END IF;

 -- An earlier duel can have elapsed while this invitation was pending.
 -- Release its active-pair index slot without discarding pending settlement.
 UPDATE public.league_duels SET status='awaiting_reviews',updated_at=v_now
 WHERE status='active' AND ends_at<=v_now
 AND least(challenger_id,opponent_id)=least(v_duel.challenger_id,v_duel.opponent_id)
 AND greatest(challenger_id,opponent_id)=greatest(v_duel.challenger_id,v_duel.opponent_id);

 UPDATE public.league_duels
 SET status='active',accepted_at=v_now,
     ends_at=v_now+(duration_days * interval '1 day'),updated_at=v_now
 WHERE id=p_duel_id;
 INSERT INTO public.league_duel_events(duel_id,boxer_id,event_type)
 VALUES(p_duel_id,v_actor.id,'accepted');
 RETURN 'active';
END $function$;

-- PostgreSQL grants EXECUTE to PUBLIC when functions are created; immediately revoke it.
DO $grants$
DECLARE signature text;
BEGIN
 FOREACH signature IN ARRAY ARRAY[
 'duel_v2_eligible_boxers()',
 'duel_v2_invite(uuid,uuid,integer)',
 'duel_v2_list_mine()',
 'duel_v2_reconcile(uuid)',
 'duel_v2_reconcile_due(boolean,uuid)',
 'duel_v2_respond(uuid,boolean)'] LOOP
 EXECUTE 'REVOKE ALL ON FUNCTION public.'||signature||' FROM PUBLIC,anon';
 EXECUTE 'GRANT EXECUTE ON FUNCTION public.'||signature||' TO authenticated';
 END LOOP;
END $grants$;

DO $postflight$
DECLARE n integer; exposed integer; t text;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.league_feature_flags WHERE feature_key='duels' AND is_enabled IS FALSE)
 THEN RAISE EXCEPTION 'Duels feature accidentally enabled'; END IF;
 SELECT count(*),count(*) FILTER (WHERE pg_catalog.has_function_privilege('anon',p.oid,'EXECUTE'))
 INTO n,exposed
 FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace x ON x.oid=p.pronamespace
 WHERE x.nspname='public' AND p.proname LIKE 'duel_v2_%';
 IF n<>6 OR exposed<>0 THEN RAISE EXCEPTION 'Unexpected duel RPC count/grants: %/%',n,exposed; END IF;
 FOREACH t IN ARRAY ARRAY['league_duels','league_duel_events','league_duel_exp_ledger'] LOOP
 IF NOT EXISTS(SELECT 1 FROM pg_catalog.pg_class WHERE oid=('public.'||t)::regclass AND relrowsecurity)
 THEN RAISE EXCEPTION 'RLS missing for %',t; END IF;
 IF pg_catalog.has_table_privilege('anon','public.'||t,'SELECT') OR
 pg_catalog.has_table_privilege('authenticated','public.'||t,'SELECT')
 THEN RAISE EXCEPTION 'Excessive duel table access: %',t; END IF;
 END LOOP;
END $postflight$;
-- Inform Supabase PostgREST that newly created RPCs exist after transaction commit.
NOTIFY pgrst, 'reload schema';
COMMIT;
