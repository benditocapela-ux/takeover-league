-- Training 2.0 · Tages-Lock auch für die Gym-Bestätigung (PR #84, Integrationsprüfung 31.10.2026).
-- staff_confirm_gym_session prüft pro Anwesendem, ob er dieses Training schon eingereicht hat. Ohne gemeinsamen Lock konnte ein
-- gleichzeitig laufender Ein-Klick-Antrag (submit_scheduled_club_training_today) oder eine Trainerfreigabe (staff_review_training)
-- die Prüfung verpassen. Jetzt nehmen alle drei Wege denselben Tages-Lock pro Boxer. Zusätzlich gilt ein offener oder bestätigter
-- Pflicht-Antrag des Tages bei einer Pflicht-Einheit als «schon eingereicht», auch wenn die Trainingsart abweicht.
-- Sonst unverändert gegenüber 20261028230000_club_schedule_tiers.sql. Ändert keine Daten.
BEGIN;
DO $$ BEGIN
 IF to_regprocedure('public.submit_scheduled_club_training_today(integer)') IS NULL THEN
  RAISE EXCEPTION 'Voraussetzung fehlt: 20261031100000_scheduled_club_training_quick_request.sql';
 END IF;
END $$;
CREATE OR REPLACE FUNCTION public.staff_confirm_gym_session(p_session_id bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE me public.profiles := league_private.require_staff(); s public.gym_sessions; a record; r jsonb; sid uuid;
 n integer := 0; pts integer := 0; skipped jsonb := '[]'::jsonb; reason text;
BEGIN
 SELECT * INTO s FROM public.gym_sessions x WHERE x.id=p_session_id FOR UPDATE;
 IF NOT FOUND OR s.status<>'open' THEN RAISE EXCEPTION 'Diese Einheit ist schon abgeschlossen' USING ERRCODE='55000'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.gym_attendance x WHERE x.session_id=s.id) THEN RAISE EXCEPTION 'Noch niemand als anwesend markiert' USING ERRCODE='22023'; END IF;
 FOR a IN SELECT x.profile_id, p.display_name, p.role, p.is_active, p.archived_at FROM public.gym_attendance x JOIN public.profiles p ON p.id=x.profile_id
          WHERE x.session_id=s.id AND x.submission_id IS NULL ORDER BY pg_catalog.lower(p.display_name) LOOP
  reason := NULL;
  -- Training 2.0: gleicher Tages-Lock wie staff_review_training und submit_scheduled_club_training_today
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('training_day:'||a.profile_id::text||':'||s.session_date::text));
  IF a.profile_id=me.id THEN reason := 'eigenes Training – bitte normal einreichen';
  ELSIF a.role NOT IN ('boxer','coach') OR NOT a.is_active OR a.archived_at IS NOT NULL THEN reason := 'Profil nicht aktiv';
  ELSIF EXISTS (SELECT 1 FROM public.training_submissions t WHERE t.boxer_id=a.profile_id AND t.training_date=s.session_date
                AND t.status IN ('pending','approved')
                AND (t.training_type_id=s.training_type_id OR (s.club_tier='pflicht' AND (t.requested_tier='pflicht' OR t.club_tier='pflicht')))) THEN reason := 'hat dieses Training schon eingereicht';
  END IF;
  IF reason IS NOT NULL THEN
   UPDATE public.gym_attendance x SET skipped_reason=reason WHERE x.session_id=s.id AND x.profile_id=a.profile_id;
   skipped := skipped || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object('name',a.display_name,'reason',reason));
   CONTINUE;
  END IF;
  r := public.staff_record_training(a.profile_id, s.training_type_id, s.session_date, s.duration_minutes, s.note, NULL,
        pg_catalog.md5('gym:'||s.id::text||':'||a.profile_id::text)::uuid);
  sid := (r->>'submission_id')::uuid;
  IF s.club_tier IS NOT NULL AND league_private.flag_on('gym_training') THEN
   UPDATE public.training_submissions x SET club_tier=s.club_tier WHERE x.id=sid;
   PERFORM league_private.apply_training_value(sid, me.id, 'Bestätigtes Training ('||league_private.tier_label(s.club_tier)||')', NULL);
  END IF;
  UPDATE public.gym_attendance x SET submission_id=sid, skipped_reason=NULL WHERE x.session_id=s.id AND x.profile_id=a.profile_id;
  n := n+1; pts := pts+coalesce((SELECT x.points FROM public.point_transactions x WHERE x.submission_id=sid),0);
 END LOOP;
 UPDATE public.gym_sessions x SET status='confirmed', confirmed_at=now(), confirmed_by=me.id WHERE x.id=s.id;
 RETURN pg_catalog.jsonb_build_object('confirmed',n,'points_awarded',pts,'skipped',skipped,'club_tier',CASE WHEN league_private.flag_on('gym_training') THEN s.club_tier END);
END;
$fn$;
REVOKE ALL ON FUNCTION public.staff_confirm_gym_session(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.staff_confirm_gym_session(bigint) TO authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
