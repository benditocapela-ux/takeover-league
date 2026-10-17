-- Takeover League 2.0 — duel invitation RPCs (REVIEW ONLY; do not run on live).
-- Requires 007. Settlement/payouts will be a separate reviewed migration.
BEGIN;

CREATE OR REPLACE FUNCTION public.duel_v2_invite(
 p_challenger uuid, p_opponent uuid, p_duration_days integer DEFAULT 7
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $$
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
END $$;

CREATE OR REPLACE FUNCTION public.duel_v2_respond(
 p_duel_id uuid, p_accept boolean
) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $$
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
END $$;

-- PostgreSQL grants EXECUTE to PUBLIC by default: revoke before commit.
REVOKE ALL ON FUNCTION public.duel_v2_invite(uuid,uuid,integer) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.duel_v2_respond(uuid,boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.duel_v2_invite(uuid,uuid,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.duel_v2_respond(uuid,boolean) TO authenticated;
COMMIT;

-- RELEASE BLOCKERS (current):
-- 1. Verify profile-first locking against the existing training review/edit RPCs
--    and test concurrent invitation, acceptance and reconciliation.
-- 2. Confirm coach-created duel semantics and opponent acceptance in isolation.
-- 3. Verify live role values ('admin','coach') and auth_user_id mapping.
-- 4. Test authorization, 48-hour expiry, rematches and active-duel caps.
-- 5. No production rollout until settlement and UI integration tests pass.
