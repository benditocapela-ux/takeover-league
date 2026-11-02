-- Existing points duels keep inclusive Zurich dates and the accepted rank reward rules.
-- No data backfill, feature activation, settlement or reward runs in this migration.
BEGIN;

DO $preflight$ BEGIN
 IF pg_catalog.to_regprocedure('league_v21_private.duel_reconcile_ranked_core(uuid)') IS NULL
 OR pg_catalog.to_regprocedure('league_duel_private.duel_v2_live_scores_core(uuid)') IS NULL
 OR NOT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public'
  AND table_name='profiles' AND column_name='archived_at') THEN
  RAISE EXCEPTION 'Current ranked-duel, live-score and profile-archive migrations are required';
 END IF;
END $preflight$;

-- Internal, one-snapshot scoring contract. No API role can call this helper directly.
-- A broken ledger returns null scores, never a plausible partial/zero result.
CREATE OR REPLACE FUNCTION league_v21_private.duel_points_snapshot(
 p_duel public.league_duels, p_as_of timestamptz)
RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path=''
AS $sql$
 WITH relevant AS MATERIALIZED (
  SELECT s.id,s.boxer_id,s.status
  FROM public.training_submissions s
  WHERE s.boxer_id IN (p_duel.challenger_id,p_duel.opponent_id)
   AND s.created_at<=least(p_as_of,p_duel.ends_at)
   AND s.training_date BETWEEN (p_duel.accepted_at AT TIME ZONE 'Europe/Zurich')::date
       AND least((p_duel.ends_at AT TIME ZONE 'Europe/Zurich')::date,
                 (p_as_of AT TIME ZONE 'Europe/Zurich')::date)
 ), scored AS (
  SELECT s.id,s.boxer_id,count(t.id) ledger_count,coalesce(sum(t.points),0) points
  FROM relevant s LEFT JOIN public.point_transactions t
   ON t.submission_id=s.id AND t.boxer_id=s.boxer_id
   AND t.category IN ('training','legacy_import')
  WHERE s.status='approved' GROUP BY s.id,s.boxer_id
 ), totals AS (
  SELECT count(*) FILTER (WHERE ledger_count=0)::integer missing_ledger,
   count(*) FILTER (WHERE ledger_count>1)::integer duplicate_ledger,
   coalesce(sum(points) FILTER (WHERE boxer_id=p_duel.challenger_id),0) p1,
   coalesce(sum(points) FILTER (WHERE boxer_id=p_duel.opponent_id),0) p2
  FROM scored
 )
 SELECT pg_catalog.jsonb_build_object(
  'challenger_score',CASE WHEN missing_ledger=0 AND duplicate_ledger=0 AND p1>=0 AND p2>=0 THEN p1::integer END,
  'opponent_score',CASE WHEN missing_ledger=0 AND duplicate_ledger=0 AND p1>=0 AND p2>=0 THEN p2::integer END,
  'pending',(SELECT count(*) FROM relevant WHERE status='pending'),
  'approved',(SELECT count(*) FROM relevant WHERE status='approved'),
  'rejected',(SELECT count(*) FROM relevant WHERE status='rejected'),
  'missing_ledger',missing_ledger,'duplicate_ledger',duplicate_ledger,
  'negative_score',p1<0 OR p2<0,
  'valid',missing_ledger=0 AND duplicate_ledger=0 AND p1>=0 AND p2>=0)
 FROM totals
$sql$;
REVOKE ALL ON FUNCTION league_v21_private.duel_points_snapshot(public.league_duels,timestamptz)
 FROM PUBLIC,anon,authenticated;

-- Existing reward arithmetic, shared by the preview and the settlement core.
CREATE OR REPLACE FUNCTION league_v21_private.duel_points_reward(
 p_tie boolean,p_won boolean,p_snapshots integer,p_self_rank integer,p_other_rank integer)
RETURNS integer LANGUAGE sql IMMUTABLE SECURITY INVOKER SET search_path=''
AS $sql$
 SELECT CASE WHEN p_tie THEN 50
  WHEN p_snapshots=0 THEN CASE WHEN p_won THEN 100 ELSE 25 END
  WHEN p_won THEN CASE WHEN p_self_rank=p_other_rank THEN 100
                      WHEN p_self_rank<p_other_rank THEN 150 ELSE 50 END
  ELSE CASE WHEN p_self_rank>p_other_rank THEN -50 ELSE 25 END END
$sql$;
REVOKE ALL ON FUNCTION league_v21_private.duel_points_reward(boolean,boolean,integer,integer,integer)
 FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION league_duel_private.duel_v2_live_scores_core(p_duel_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=''
AS $fn$
DECLARE actor public.profiles%ROWTYPE; d public.league_duels%ROWTYPE; score jsonb;
BEGIN
 SELECT * INTO actor FROM public.profiles
 WHERE auth_user_id=(SELECT auth.uid()) AND is_active AND archived_at IS NULL
  AND role IN ('boxer','coach','admin');
 IF NOT FOUND THEN RAISE EXCEPTION 'Authentication required' USING errcode='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.league_feature_flags WHERE feature_key='duels' AND is_enabled)
 THEN RAISE EXCEPTION 'Duels are not enabled' USING errcode='42501'; END IF;
 SELECT * INTO d FROM public.league_duels WHERE id=p_duel_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Duel not found' USING errcode='22023'; END IF;
 IF actor.role='boxer' AND actor.id NOT IN (d.challenger_id,d.opponent_id)
 THEN RAISE EXCEPTION 'Not a duel participant' USING errcode='42501'; END IF;
 IF d.status NOT IN ('active','awaiting_reviews') OR d.accepted_at IS NULL OR d.ends_at IS NULL
 THEN RAISE EXCEPTION 'No live score for this duel' USING errcode='22023'; END IF;
 score:=league_v21_private.duel_points_snapshot(d,statement_timestamp());
 IF NOT (score->>'valid')::boolean THEN
  RAISE EXCEPTION 'Approved duel training has missing, duplicate or invalid scoring ledger'
   USING errcode='23514';
 END IF;
 RETURN pg_catalog.jsonb_build_object('challenger_score',score->'challenger_score',
  'opponent_score',score->'opponent_score','pending',score->'pending',
  'status',d.status,'provisional',true);
END $fn$;

-- Staff preview is strictly read-only: no row locks, writes, events or reward booking.
CREATE OR REPLACE FUNCTION league_v21_private.duel_close_preview_core(p_duel_id uuid,p_as_of timestamptz)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=''
AS $fn$
DECLARE d public.league_duels%ROWTYPE; actor public.profiles%ROWTYPE; score jsonb;
 blockers jsonb:='[]'; rewards jsonb:='[]'; result jsonb; snapshots integer;
 cr integer; opr integer; p1 integer; p2 integer; boxer uuid; reward integer;
 ledger public.league_duel_exp_ledger%ROWTYPE; ledger_found boolean;
 payout_valid boolean; all_payouts_valid boolean:=true; winner uuid;
BEGIN
 SELECT * INTO actor FROM public.profiles WHERE auth_user_id=(SELECT auth.uid())
  AND is_active AND archived_at IS NULL AND role IN ('coach','admin');
 IF NOT FOUND THEN RAISE EXCEPTION 'Only active staff may preview closure' USING errcode='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.league_feature_flags WHERE feature_key='duels' AND is_enabled)
 THEN RAISE EXCEPTION 'Duels are not enabled' USING errcode='42501'; END IF;
 SELECT * INTO d FROM public.league_duels WHERE id=p_duel_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Duel not found' USING errcode='22023'; END IF;
 IF d.status NOT IN ('active','awaiting_reviews','settled') OR d.accepted_at IS NULL OR d.ends_at IS NULL
 THEN RAISE EXCEPTION 'Duel has no accepted scoring period' USING errcode='22023'; END IF;
 score:=league_v21_private.duel_points_snapshot(d,p_as_of);
 p1:=(score->>'challenger_score')::integer; p2:=(score->>'opponent_score')::integer;
 IF d.ends_at>p_as_of THEN
  blockers:=blockers||pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object('code','in_progress','message','Der Duellzeitraum läuft noch.'));
 END IF;
 IF (score->>'pending')::integer>0 THEN
  blockers:=blockers||pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object('code','pending_reviews','message','Rechtzeitig eingereichte Trainings warten auf Prüfung.'));
 END IF;
 IF NOT (score->>'valid')::boolean THEN
  blockers:=blockers||pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object('code','scoring_ledger_invalid','message','Punktebuchungen fehlen, sind doppelt oder ergeben eine ungültige Wertung.'));
 END IF;
 SELECT count(*),max(rank_index) FILTER(WHERE boxer_id=d.challenger_id),
  max(rank_index) FILTER(WHERE boxer_id=d.opponent_id) INTO snapshots,cr,opr
 FROM public.league_duel_rank_snapshots_v21 WHERE duel_id=d.id;
 IF snapshots NOT IN (0,2) OR (snapshots=2 AND (cr IS NULL OR opr IS NULL)) THEN
  blockers:=blockers||pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object('code','rank_snapshot_invalid','message','Die gespeicherte Rangregel ist unvollständig.'));
 END IF;
 winner:=CASE WHEN p1>p2 THEN d.challenger_id WHEN p2>p1 THEN d.opponent_id END;
 FOREACH boxer IN ARRAY ARRAY[d.challenger_id,d.opponent_id] LOOP
  reward:=NULL;
  IF (score->>'valid')::boolean AND (snapshots=0 OR (snapshots=2 AND cr IS NOT NULL AND opr IS NOT NULL)) THEN
   reward:=league_v21_private.duel_points_reward(p1=p2,boxer=winner,snapshots,
    CASE WHEN boxer=d.challenger_id THEN cr ELSE opr END,
    CASE WHEN boxer=d.challenger_id THEN opr ELSE cr END);
  END IF;
  SELECT * INTO ledger FROM public.league_duel_exp_ledger WHERE duel_id=d.id AND boxer_id=boxer;
  ledger_found:=FOUND;
  IF NOT ledger_found OR ledger.transaction_id IS NULL THEN
   payout_valid:=d.status<>'settled' AND (NOT ledger_found OR ledger.awarded_exp=0)
    AND NOT EXISTS(SELECT 1 FROM public.point_transactions t WHERE t.boxer_id=boxer
      AND t.category='duel_exp' AND t.description='Duel reward: '||d.id::text);
  ELSE
   payout_valid:=EXISTS(SELECT 1 FROM public.point_transactions t
    WHERE t.id=ledger.transaction_id AND t.boxer_id=boxer AND t.category='duel_exp'
     AND t.points=0 AND t.exp=ledger.awarded_exp AND t.description='Duel reward: '||d.id::text
     AND t.effective_date=(d.ends_at AT TIME ZONE 'Europe/Zurich')::date);
  END IF;
  all_payouts_valid:=all_payouts_valid AND payout_valid;
  rewards:=rewards||pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
   'boxer_id',boxer,'planned_exp',reward,
   'booked_exp',CASE WHEN payout_valid THEN CASE WHEN ledger_found THEN ledger.awarded_exp ELSE 0 END END,
   'delta_exp',CASE WHEN payout_valid THEN reward-CASE WHEN ledger_found THEN ledger.awarded_exp ELSE 0 END END,
   'transaction_id',ledger.transaction_id));
 END LOOP;
 IF NOT all_payouts_valid THEN
  blockers:=blockers||pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object('code','reward_ledger_invalid','message','Die bestehende EXP-Buchung muss vor dem Abschluss geprüft werden.'));
 END IF;
 result:=pg_catalog.jsonb_build_object('duel_id',d.id,'status',d.status,
  'starts_at',d.accepted_at,'ends_at',d.ends_at,
  'rule',pg_catalog.jsonb_build_object('metric','points','unit','Trainingspunkte',
   'timezone','Europe/Zurich','time_rule','legacy_inclusive_zurich_dates',
   'start_day',(d.accepted_at AT TIME ZONE 'Europe/Zurich')::date,
   'end_day',(d.ends_at AT TIME ZONE 'Europe/Zurich')::date,
   'reward_rule',CASE WHEN snapshots=0 THEN 'legacy_v2' ELSE 'rank_snapshot_v21' END),
  'scores',score-'missing_ledger'-'duplicate_ledger'-'negative_score'-'valid',
  'winner_id',winner,'tie',p1=p2,'provisional',true,
  'can_close',d.status IN ('active','awaiting_reviews') AND blockers='[]'::jsonb,
  'can_correct',d.status='settled' AND blockers='[]'::jsonb
    AND (p1 IS DISTINCT FROM d.challenger_score OR p2 IS DISTINCT FROM d.opponent_score
       OR EXISTS(SELECT 1 FROM pg_catalog.jsonb_array_elements(rewards) r WHERE (r->>'delta_exp')::integer<>0)),
  'blockers',blockers,'rewards',rewards,'review_path','coach.html');
 RETURN result||pg_catalog.jsonb_build_object('revision',pg_catalog.md5(result::text));
END $fn$;
REVOKE ALL ON FUNCTION league_v21_private.duel_close_preview_core(uuid,timestamptz) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION league_v21_private.duel_close_preview_core(uuid,timestamptz) TO authenticated;
CREATE OR REPLACE FUNCTION public.duel_v2_close_preview(p_duel_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path=''
AS $fn$ SELECT league_v21_private.duel_close_preview_core(p_duel_id,statement_timestamp()) $fn$;
REVOKE ALL ON FUNCTION public.duel_v2_close_preview(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.duel_v2_close_preview(uuid) TO authenticated;

-- Existing ranked settlement: locks, audit trail and payout-ledger checks preserved.
CREATE OR REPLACE FUNCTION league_v21_private.duel_reconcile_ranked_core(p_duel_id uuid)
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
 score jsonb;
 target_exp integer;
 boxer uuid;
 old_exp integer;
 old_tx uuid;
 new_tx uuid;
 existing_status text;
 challenger_rank integer; opponent_rank integer; winner_rank integer; loser_rank integer; snapshots integer;
BEGIN
 SELECT * INTO actor FROM public.profiles
 WHERE auth_user_id=(SELECT auth.uid()) AND is_active=true AND archived_at IS NULL;
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

 -- Shared scoring validation is evaluated after the existing submission locks.
 score:=league_v21_private.duel_points_snapshot(d,d.ends_at);
 pending_count:=(score->>'pending')::integer;
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

 IF NOT (score->>'valid')::boolean THEN
  RAISE EXCEPTION 'Approved duel training has missing, duplicate or invalid scoring ledger'
   USING errcode='23514';
 END IF;
 p1:=(score->>'challenger_score')::integer;
 p2:=(score->>'opponent_score')::integer;

 -- Snapshot at acceptance is mandatory for V2.1 ranked duels; older duels keep legacy rules.
 SELECT count(*) INTO snapshots FROM public.league_duel_rank_snapshots_v21 s WHERE s.duel_id=d.id;
 IF snapshots NOT IN (0,2) THEN RAISE EXCEPTION 'Incomplete duel rank snapshots' using errcode='23514';END IF;
 IF snapshots=2 THEN
  SELECT s.rank_index INTO challenger_rank FROM public.league_duel_rank_snapshots_v21 s
   WHERE s.duel_id=d.id AND s.boxer_id=d.challenger_id;
  SELECT s.rank_index INTO opponent_rank FROM public.league_duel_rank_snapshots_v21 s
   WHERE s.duel_id=d.id AND s.boxer_id=d.opponent_id;
  IF challenger_rank IS NULL OR opponent_rank IS NULL THEN
   RAISE EXCEPTION 'Duel rank snapshot participants mismatch' using errcode='23514';
  END IF;
  winner_rank:=CASE WHEN p1>p2 THEN challenger_rank ELSE opponent_rank END;
  loser_rank:=CASE WHEN p1>p2 THEN opponent_rank ELSE challenger_rank END;
 END IF;
 existing_status:=d.status;
 UPDATE public.league_duels
 SET status='settled',settled_at=COALESCE(settled_at,v_clock),
     challenger_score=p1,opponent_score=p2,
     winner_id=CASE WHEN p1=p2 THEN NULL WHEN p1>p2 THEN d.challenger_id ELSE d.opponent_id END,
     updated_at=v_clock
 WHERE id=d.id;

 FOREACH boxer IN ARRAY ARRAY[d.challenger_id,d.opponent_id] LOOP
  target_exp:=league_v21_private.duel_points_reward(p1=p2,
   (p1>p2 AND boxer=d.challenger_id) OR (p2>p1 AND boxer=d.opponent_id),snapshots,
   CASE WHEN boxer=d.challenger_id THEN challenger_rank ELSE opponent_rank END,
   CASE WHEN boxer=d.challenger_id THEN opponent_rank ELSE challenger_rank END);

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

-- Explicit close/correction. Locks in the same order as invite/respond/reconcile.
-- A stale preview never causes a different reward to be silently approved.
CREATE OR REPLACE FUNCTION league_v21_private.duel_close_confirm_core(
 p_duel_id uuid,p_confirm boolean,p_expected_revision text)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=''
AS $fn$
DECLARE d public.league_duels%ROWTYPE; preview jsonb; after_preview jsonb;
 outcome text; bookings jsonb; changed boolean:=false;
BEGIN
 IF p_confirm IS DISTINCT FROM true OR p_expected_revision IS NULL OR length(p_expected_revision)<>32
 THEN RAISE EXCEPTION 'Explicit confirmation of a reviewed result is required' USING errcode='22023'; END IF;
 -- Authorize before looking up participant identities or taking their locks.
 preview:=league_v21_private.duel_close_preview_core(p_duel_id,clock_timestamp());
 SELECT * INTO d FROM public.league_duels WHERE id=p_duel_id;
 PERFORM 1 FROM public.profiles WHERE id IN (d.challenger_id,d.opponent_id) ORDER BY id FOR UPDATE;
 SELECT * INTO d FROM public.league_duels WHERE id=p_duel_id FOR UPDATE;
 PERFORM 1 FROM public.training_submissions s
 WHERE s.boxer_id IN (d.challenger_id,d.opponent_id)
  AND s.training_date BETWEEN (d.accepted_at AT TIME ZONE 'Europe/Zurich')::date
    AND (d.ends_at AT TIME ZONE 'Europe/Zurich')::date AND s.created_at<=d.ends_at
 ORDER BY s.id FOR UPDATE;
 preview:=league_v21_private.duel_close_preview_core(p_duel_id,clock_timestamp());
 IF preview->>'revision' IS DISTINCT FROM p_expected_revision THEN
  outcome:='preview_changed';
 ELSIF (preview->>'can_close')::boolean OR (preview->>'can_correct')::boolean THEN
  outcome:=league_v21_private.duel_reconcile_ranked_core(p_duel_id);
  changed:=outcome='settled';
 ELSIF d.status='settled' AND preview->'blockers'='[]'::jsonb THEN
  outcome:='settled';
 ELSIF EXISTS(SELECT 1 FROM pg_catalog.jsonb_array_elements(preview->'blockers') b WHERE b->>'code'='in_progress') THEN
  outcome:='in_progress';
 ELSIF EXISTS(SELECT 1 FROM pg_catalog.jsonb_array_elements(preview->'blockers') b WHERE b->>'code'='pending_reviews') THEN
  outcome:=CASE WHEN d.status='settled' THEN 'pending_correction' ELSE 'awaiting_reviews' END;
 ELSE
  outcome:='blocked';
 END IF;
 after_preview:=league_v21_private.duel_close_preview_core(p_duel_id,clock_timestamp());
 SELECT coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
  'boxer_id',l.boxer_id,'awarded_exp',l.awarded_exp,'transaction_id',l.transaction_id)
  ORDER BY l.boxer_id),'[]'::jsonb) INTO bookings
 FROM public.league_duel_exp_ledger l WHERE l.duel_id=p_duel_id;
 RETURN pg_catalog.jsonb_build_object('outcome',outcome,'preview',after_preview,
  'bookings',bookings,'unchanged',NOT changed);
END $fn$;
REVOKE ALL ON FUNCTION league_v21_private.duel_close_confirm_core(uuid,boolean,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION league_v21_private.duel_close_confirm_core(uuid,boolean,text) TO authenticated;
CREATE OR REPLACE FUNCTION public.duel_v2_close_confirm(
 p_duel_id uuid,p_confirm boolean,p_expected_revision text)
RETURNS jsonb LANGUAGE sql VOLATILE SECURITY INVOKER SET search_path=''
AS $fn$ SELECT league_v21_private.duel_close_confirm_core(p_duel_id,p_confirm,p_expected_revision) $fn$;
REVOKE ALL ON FUNCTION public.duel_v2_close_confirm(uuid,boolean,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.duel_v2_close_confirm(uuid,boolean,text) TO authenticated;

-- Preserve the existing public live/settlement wrapper signatures and grants.
REVOKE ALL ON FUNCTION league_duel_private.duel_v2_live_scores_core(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION league_duel_private.duel_v2_live_scores_core(uuid) TO authenticated;
REVOKE ALL ON FUNCTION league_v21_private.duel_reconcile_ranked_core(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION league_v21_private.duel_reconcile_ranked_core(uuid) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
