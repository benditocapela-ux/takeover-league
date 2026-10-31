-- Unified scheduled club training entry · Training 2.0 (PR #84).
-- Uses existing Gym attendance if the matching scheduled Gym session is open;
-- otherwise submits a pending request ONLY when the club permits self-reports.
-- Apply AFTER 20261031090000_training_v2_classification.sql, with training_v2 initially OFF.
-- No existing entries or point transactions are changed.
BEGIN;
DO $$ BEGIN
 IF to_regprocedure('public.get_training_v2_config()') IS NULL
 OR to_regprocedure('league_private.training_closed_season(date)') IS NULL THEN
  RAISE EXCEPTION 'Training 2.0 migration must be installed first';
 END IF;
END $$;

CREATE OR REPLACE FUNCTION public.submit_scheduled_club_training_today(p_slot_id integer DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE
 me public.profiles := league_private.active_viewer();
 day_ date := league_private.zurich_today();
 sl public.club_schedule;
 matches_ integer;
 previous_ public.training_submissions;
 gym_ public.gym_sessions;
 gym_id bigint;
 gym_count integer;
 new_id uuid;
BEGIN
 IF me.id IS NULL OR NOT me.is_active OR me.role <> 'boxer' OR me.auth_user_id IS DISTINCT FROM auth.uid() THEN
  RAISE EXCEPTION 'Nur aktive Boxer dürfen eigene Trainings beantragen' USING ERRCODE='42501';
 END IF;
 IF NOT league_private.flag_on('training_v2') THEN
  RETURN pg_catalog.jsonb_build_object('status','disabled');
 END IF;
 -- Both self-report and supervised Gym use this same endpoint. The Gym-only
 -- policy is enforced after matching the actual club slot, not by a redirect.
 IF league_private.training_closed_season(day_) THEN
  RAISE EXCEPTION 'In einer abgeschlossenen Saison sind keine neuen Trainings möglich' USING ERRCODE='42501';
 END IF;
 -- The same day lock is also used by staff_review_training; double taps and concurrent requests serialize.
 PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('training_day:'||me.id::text||':'||day_::text));
 SELECT count(*) INTO matches_
 FROM public.club_schedule x
 WHERE x.is_active AND x.tier='pflicht' AND x.dow=extract(isodow FROM day_)::integer;
 IF matches_=0 THEN
  RETURN pg_catalog.jsonb_build_object('status','no_slot');
 END IF;
 IF p_slot_id IS NULL AND matches_>1 THEN
  RETURN pg_catalog.jsonb_build_object('status','choose_slot');
 END IF;
 SELECT * INTO sl FROM public.club_schedule x
 WHERE x.is_active AND x.tier='pflicht' AND x.dow=extract(isodow FROM day_)::integer
   AND (p_slot_id IS NULL OR x.id=p_slot_id)
 ORDER BY x.sort_order,x.id LIMIT 1;
 IF NOT FOUND THEN
  RAISE EXCEPTION 'Diese Vereinseinheit ist heute nicht im aktiven Stundenplan' USING ERRCODE='22023';
 END IF;
 -- Never create a second open/approved scheduled club session for this athlete today.
 SELECT * INTO previous_ FROM public.training_submissions x
 WHERE x.boxer_id=me.id AND x.training_date=day_ AND x.status IN ('pending','approved')
   AND (x.requested_tier='pflicht' OR x.club_tier='pflicht'
        OR x.training_type_id=sl.training_type_id OR x.requested_slot_id=sl.id)
 ORDER BY (x.status='approved') DESC,x.created_at DESC LIMIT 1;
 IF FOUND THEN
  RETURN pg_catalog.jsonb_build_object('status',
   CASE WHEN previous_.status='approved' THEN 'already_approved' ELSE 'already_pending' END,
   'submission_id',previous_.id,'label',sl.label);
 END IF;
 -- Any existing attendance today takes precedence over a second submission,
 -- including Gym sessions already confirmed by the coach.
 IF EXISTS (
  SELECT 1 FROM public.gym_attendance a
  JOIN public.gym_sessions g ON g.id=a.session_id
  WHERE a.profile_id=me.id AND g.session_date=day_ AND g.status<>'cancelled'
 ) THEN
  RETURN pg_catalog.jsonb_build_object('status','already_checked_in','label',sl.label);
 END IF;

 -- If a coach has already opened TODAY'S matching scheduled unit, use the
 -- supervised Gym attendance path instead of inserting an independent request.
 -- Lock its row: staff_confirm_gym_session locks the same session row, so an
 -- athlete cannot join after the coach has closed the session.
 IF league_private.flag_on('gym_training') THEN
  SELECT count(*), min(x.id) INTO gym_count,gym_id
  FROM public.gym_sessions x
  WHERE x.session_date=day_ AND x.status='open'
    AND x.training_type_id=sl.training_type_id AND x.club_tier='pflicht'
    AND (x.slot_id=sl.id OR x.slot_id IS NULL);
  IF gym_count>1 THEN
   RETURN pg_catalog.jsonb_build_object('status','choose_gym_session','label',sl.label);
  END IF;
  IF gym_count=1 THEN
   SELECT * INTO gym_ FROM public.gym_sessions x WHERE x.id=gym_id FOR UPDATE;
   IF FOUND AND gym_.status='open' AND gym_.session_date=day_
      AND gym_.training_type_id=sl.training_type_id AND gym_.club_tier='pflicht'
      AND (gym_.slot_id=sl.id OR gym_.slot_id IS NULL) THEN
    INSERT INTO public.gym_attendance(session_id,profile_id,source)
    VALUES (gym_.id,me.id,'self') ON CONFLICT DO NOTHING;
    RETURN pg_catalog.jsonb_build_object('status','checked_in',
      'session_id',gym_.id,'label',sl.label,'training_date',day_);
   END IF;
  END IF;
 END IF;

 -- Supervised-only clubs must have an opened Gym session. No silent bypass
 -- and no pending self-report if that policy is active.
 IF league_private.flag_on('gym_training') AND league_private.flag_on('club_checkin_only') THEN
  RETURN pg_catalog.jsonb_build_object('status','gym_not_open','label',sl.label);
 END IF;
 -- Request only. The existing training_insert_guard revalidates the slot/day
 -- and explicitly drops club_tier. No transaction, XP or coins is posted here.
 INSERT INTO public.training_submissions(
  boxer_id, training_type_id, training_date, duration_minutes, notes,
  status, training_location, requested_slot_id, requested_tier
 ) VALUES (
  me.id, sl.training_type_id, day_, sl.duration_minutes,
  'Automatisch beantragt: '||sl.label, 'pending','club',sl.id,'pflicht'
 ) RETURNING id INTO new_id;
 RETURN pg_catalog.jsonb_build_object('status','submitted','submission_id',new_id,
  'label',sl.label,'training_date',day_,'duration_minutes',sl.duration_minutes);
END;
$fn$;
REVOKE ALL ON FUNCTION public.submit_scheduled_club_training_today(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_scheduled_club_training_today(integer) TO authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
