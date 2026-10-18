-- Rank-based duels. Snapshot rank when an invitation is ACCEPTED, not when scored.
-- The original reconciler body is preserved, except rank payout logic and private core placement.
-- Historical duels without a snapshot retain their original EXP rules.
create table if not exists public.league_duel_rank_snapshots_v21(
 duel_id uuid not null references public.league_duels(id) on delete restrict,
 boxer_id uuid not null references public.profiles(id) on delete restrict,
 rank_index integer not null check(rank_index between 1 and 7),
 exp_at_start integer not null,
 captured_at timestamptz not null default now(),
 primary key(duel_id,boxer_id)
);
alter table public.league_duel_rank_snapshots_v21 enable row level security;
revoke all on public.league_duel_rank_snapshots_v21 from public,anon,authenticated;
create or replace function league_v21_private.capture_duel_ranks()
returns trigger language plpgsql security definer set search_path='' as $f$
declare boxer uuid; xp integer; level_index integer; rank_index integer;
begin
 if NEW.status<>'active' or OLD.status='active' then return NEW;end if;
 if NEW.accepted_at is null or NEW.ends_at is null then raise exception 'Duel start must have a date' using errcode='23514';end if;
 foreach boxer in array array[NEW.challenger_id,NEW.opponent_id] loop
  select coalesce(sum(t.exp),0)::integer into xp from public.point_transactions t where t.boxer_id=boxer;
  level_index:=greatest(0,floor((sqrt(49+0.32*greatest(xp,0))-7)/2)::integer);
  rank_index:=least(7,1+(level_index/10));
  insert into public.league_duel_rank_snapshots_v21(duel_id,boxer_id,rank_index,exp_at_start)
  values(NEW.id,boxer,rank_index,xp)
  on conflict(duel_id,boxer_id) do nothing;
 end loop;
 return NEW;
end$f$;
revoke all on function league_v21_private.capture_duel_ranks() from public,anon,authenticated;
drop trigger if exists league_v21_capture_duel_rank on public.league_duels;
create trigger league_v21_capture_duel_rank after update of status on public.league_duels
for each row when (NEW.status='active' and OLD.status is distinct from NEW.status)
execute function league_v21_private.capture_duel_ranks();
-- The original check supports 0/25/50/100 only; extend to the agreed +150/-50.
alter table public.league_duel_exp_ledger drop constraint if exists league_duel_exp_ledger_awarded_exp_check;
alter table public.league_duel_exp_ledger add constraint league_duel_exp_ledger_awarded_exp_check
check (awarded_exp in (-50,0,25,50,100,150));

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
 target_exp integer;
 boxer uuid;
 old_exp integer;
 old_tx uuid;
 new_tx uuid;
 existing_status text;
 challenger_rank integer; opponent_rank integer; winner_rank integer; loser_rank integer; snapshots integer;
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
  IF snapshots=0 THEN
   -- Historical duels retain original payout semantics; no retroactive rank inference.
   target_exp:=CASE WHEN p1=p2 THEN 50
     WHEN (p1>p2 AND boxer=d.challenger_id)
       OR (p2>p1 AND boxer=d.opponent_id) THEN 100 ELSE 25 END;
  ELSIF p1=p2 THEN
   target_exp:=50;
  ELSIF (p1>p2 AND boxer=d.challenger_id) OR (p2>p1 AND boxer=d.opponent_id) THEN
   target_exp:=CASE WHEN winner_rank=loser_rank THEN 100
                    WHEN winner_rank<loser_rank THEN 150 ELSE 50 END;
  ELSE
   target_exp:=CASE WHEN loser_rank>winner_rank THEN -50 ELSE 25 END;
  END IF;

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


revoke all on function league_v21_private.duel_reconcile_ranked_core(uuid) from public,anon,authenticated;
grant execute on function league_v21_private.duel_reconcile_ranked_core(uuid) to authenticated;
create or replace function public.duel_v2_reconcile(p_duel_id uuid)
returns text language sql volatile security invoker set search_path=''
as $f$ select league_v21_private.duel_reconcile_ranked_core(p_duel_id) $f$;
revoke all on function public.duel_v2_reconcile(uuid) from public,anon,authenticated;
grant execute on function public.duel_v2_reconcile(uuid) to authenticated;
