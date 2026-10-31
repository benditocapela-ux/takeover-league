-- Club Training Quick Request · complements Training 2.0 (PR #84).
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
 new_id uuid;
BEGIN
 IF me.id IS NULL OR NOT me.is_active OR me.role <> 'boxer' OR me.auth_user_id IS DISTINCT FROM auth.uid() THEN
  RAISE EXCEPTION 'Nur aktive Boxer dürfen eigene Trainings beantragen' USING ERRCODE='42501';
 END IF;
 IF NOT league_private.flag_on('training_v2') THEN
  RETURN pg_catalog.jsonb_build_object('status','disabled');
 END IF;
 -- Check-in-only clubs must use the existing supervised Gym flow; do not bypass it.
 IF league_private.flag_on('gym_training') AND league_private.flag_on('club_checkin_only') THEN
  RETURN pg_catalog.jsonb_build_object('status','checkin_required');
 END IF;
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
 -- Do not double-register someone already checked into an open/confirmed Gym session.
 IF EXISTS (
  SELECT 1 FROM public.gym_attendance a
  JOIN public.gym_sessions g ON g.id=a.session_id
  WHERE a.profile_id=me.id AND g.session_date=day_ AND g.status<>'cancelled'
 ) THEN
  RETURN pg_catalog.jsonb_build_object('status','gym_registered','label',sl.label);
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
