-- Takeover League 2.0 — duel settlement and correction engine (REVIEW ONLY).
-- Requires 007 and 008, with lock-order review before production.
-- The scoring rule uses awarded training transaction points, not current type prices.
-- Do not execute on live Supabase until isolated integration tests pass.
BEGIN;

ALTER TABLE public.point_transactions DROP CONSTRAINT point_transactions_category_check;
ALTER TABLE public.point_transactions ADD CONSTRAINT point_transactions_category_check
 CHECK(category=ANY(ARRAY[
 'training','trainer_bonus','adjustment','legacy_import','automatic_bonus',
 'achievement_exp','duel_exp']::text[]));

CREATE OR REPLACE FUNCTION public.duel_v2_reconcile(p_duel_id uuid)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $$
DECLARE
 d public.league_duels%ROWTYPE;
 actor public.profiles%ROWTYPE;
 current_time timestamptz := clock_timestamp();
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
 IF NOT FOUND OR actor.role NOT IN ('admin','coach') THEN
  RAISE EXCEPTION 'Only a coach may reconcile duels';
 END IF;
 -- Lock boxer profiles before the duel row, matching invite/respond.
 SELECT * INTO d FROM public.league_duels WHERE id=p_duel_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Duel not found'; END IF;
 PERFORM 1 FROM public.profiles
 WHERE id IN (d.challenger_id,d.opponent_id) ORDER BY id FOR UPDATE;
 SELECT * INTO d FROM public.league_duels WHERE id=p_duel_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Duel not found'; END IF;
 IF d.status NOT IN ('active','awaiting_reviews','settled') THEN
  RAISE EXCEPTION 'Duel not active or completed';
 END IF;
 IF d.ends_at>current_time THEN RETURN 'in_progress'; END IF;

 -- Only timely submitted, not-yet-reviewed entries delay settlement.
 SELECT count(*) INTO pending_count
 FROM public.training_submissions s
 WHERE s.boxer_id IN (d.challenger_id,d.opponent_id)
   AND s.status='pending'
   AND s.training_date >= (d.accepted_at AT TIME ZONE 'Europe/Zurich')::date
   AND s.training_date <= (d.ends_at AT TIME ZONE 'Europe/Zurich')::date
   AND s.created_at<=d.ends_at;
 IF pending_count>0 THEN
  IF d.status<>'awaiting_reviews' THEN
   UPDATE public.league_duels SET status='awaiting_reviews',updated_at=current_time
   WHERE id=d.id;
   INSERT INTO public.league_duel_events(duel_id,event_type,payload)
   VALUES(d.id,'awaiting_reviews',pg_catalog.jsonb_build_object('pending',pending_count));
  END IF;
  RETURN 'awaiting_reviews';
 END IF;

 -- Training date is date-only. Both boundary dates are included. This is
 -- a deliberate calendar-day approximation to acceptance's exact timestamp.
 SELECT COALESCE(sum(t.points) FILTER(WHERE s.boxer_id=d.challenger_id),0)::integer,
        COALESCE(sum(t.points) FILTER(WHERE s.boxer_id=d.opponent_id),0)::integer
 INTO p1,p2
 FROM public.training_submissions s
 JOIN public.point_transactions t ON t.submission_id=s.id
 WHERE s.boxer_id IN(d.challenger_id,d.opponent_id)
   AND s.status='approved'
   AND s.created_at<=d.ends_at
   AND s.training_date >= (d.accepted_at AT TIME ZONE 'Europe/Zurich')::date
   AND s.training_date <= (d.ends_at AT TIME ZONE 'Europe/Zurich')::date
   AND t.category IN('training','legacy_import');

 IF p1<0 OR p2<0 THEN RAISE EXCEPTION 'Negative duel scores are not supported'; END IF;

 existing_status:=d.status;
 UPDATE public.league_duels
 SET status='settled',settled_at=COALESCE(settled_at,current_time),
     challenger_score=p1,opponent_score=p2,
     winner_id=CASE WHEN p1=p2 THEN NULL WHEN p1>p2 THEN d.challenger_id ELSE d.opponent_id END,
     updated_at=current_time
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
   INSERT INTO public.point_transactions
    (boxer_id,points,exp,category,description,effective_date,created_by)
   VALUES(boxer,0,target_exp,'duel_exp',
          'Duel reward: '||d.id::text,
          (d.ends_at AT TIME ZONE 'Europe/Zurich')::date,actor.id)
   RETURNING id INTO new_tx;
   UPDATE public.league_duel_exp_ledger
   SET transaction_id=new_tx,awarded_exp=target_exp,updated_at=current_time
   WHERE duel_id=d.id AND boxer_id=boxer;
  ELSIF old_exp<>target_exp THEN
   UPDATE public.point_transactions SET exp=target_exp WHERE id=old_tx;
   UPDATE public.league_duel_exp_ledger
   SET awarded_exp=target_exp,updated_at=current_time
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
END $$;

REVOKE ALL ON FUNCTION public.duel_v2_reconcile(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.duel_v2_reconcile(uuid) TO authenticated;
COMMIT;

-- REVIEW BLOCKERS:
-- A. Date-only training_date cannot represent exact accepted_at / ends_at times.
-- B. Scoring policy for late-created but backdated approved submissions needs owner approval.
-- C. Existing training transaction may use 'adjustment' instead of 'training' for edits.
-- D. Reconciliation is coach-triggered; scheduling/automatic re-evaluation not yet wired.
-- E. Lock ordering, grants, and settlement transaction integrity need isolated DB tests.
-- F. Check point_transactions.created_by FK and category constraint on target database.
