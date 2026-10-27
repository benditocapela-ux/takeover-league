\set ON_ERROR_STOP on
-- Disposable-database test for 20261028190000_training_groups_gym.sql (+ rollback). Fixture from staff-record-training-schema.sql.
-- Uses the production definition of public.review_training (md5 5750d619… on 27.10.2026) and the
-- required-details trigger from 20261028150000.
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE ROLE anon;
CREATE ROLE authenticated;
CREATE SCHEMA auth;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $fn$ SELECT nullif(current_setting('request.jwt.claim.sub', true),'')::uuid $fn$;
GRANT USAGE ON SCHEMA auth TO authenticated, anon;
GRANT EXECUTE ON FUNCTION auth.uid() TO authenticated, anon;
CREATE SCHEMA league_v21_private;
CREATE SCHEMA league_private;
CREATE TABLE public.profiles(id uuid PRIMARY KEY, auth_user_id uuid UNIQUE, display_name text NOT NULL, role text NOT NULL DEFAULT 'boxer',
 is_active boolean NOT NULL DEFAULT true, is_listed boolean NOT NULL DEFAULT true, archived_at timestamptz);
CREATE TABLE public.training_types(id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, name text NOT NULL UNIQUE, points integer NOT NULL, is_active boolean NOT NULL DEFAULT true);
CREATE TABLE public.training_submissions(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), boxer_id uuid NOT NULL REFERENCES public.profiles(id),
 training_type_id bigint NOT NULL REFERENCES public.training_types(id), training_date date NOT NULL, notes text NOT NULL DEFAULT '',
 status text NOT NULL DEFAULT 'pending', reviewed_by uuid, reviewed_at timestamptz, created_at timestamptz NOT NULL DEFAULT now(),
 jogging_km numeric, technique_minutes integer, client_request_id uuid);
CREATE UNIQUE INDEX training_submissions_boxer_request_id_uniq ON public.training_submissions(boxer_id, client_request_id) WHERE client_request_id IS NOT NULL;
CREATE TABLE public.training_drafts_v2(boxer_id uuid PRIMARY KEY, training_type_id bigint, training_date date, notes text, jogging_km numeric, technique_minutes integer, updated_at timestamptz);
CREATE TABLE public.point_transactions(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), boxer_id uuid NOT NULL, submission_id uuid, points integer NOT NULL,
 exp integer NOT NULL, category text, description text, effective_date date, created_by uuid);
CREATE TABLE public.league_seasons_v21(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), title text, starts_on date, ends_on date, status text);
CREATE TABLE public.boxer_notifications(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), recipient_id uuid, title text);
CREATE FUNCTION public.recalculate_boxer_bonuses(p_boxer uuid) RETURNS integer LANGUAGE sql SECURITY DEFINER SET search_path=''
AS $fn$ SELECT count(distinct t.name)::integer FROM public.training_submissions s JOIN public.training_types t ON t.id=s.training_type_id
 WHERE s.boxer_id=p_boxer AND s.status='approved' AND t.name in ('Reguläres Boxtraining','Sparring','Krafttraining','Sprint-Intervalle') $fn$;
CREATE FUNCTION league_private.coach_training_bonus_refresh(p_boxer uuid) RETURNS integer LANGUAGE sql SECURITY DEFINER SET search_path=''
AS $fn$ SELECT count(distinct t.name)::integer FROM public.training_submissions s JOIN public.training_types t ON t.id=s.training_type_id
 WHERE s.boxer_id=p_boxer AND s.status='approved' AND t.name in ('Reguläres Boxtraining','Sparring','Krafttraining','Sprint-Intervalle') $fn$;
-- Notification trigger like production (_notify_training_decision, simplified to the recipient/title).
CREATE FUNCTION public._notify_training_decision() RETURNS trigger LANGUAGE plpgsql AS $fn$
BEGIN IF NEW.status='approved' AND OLD.status IS DISTINCT FROM NEW.status THEN
 INSERT INTO public.boxer_notifications(recipient_id,title) VALUES (NEW.boxer_id,'Training bestätigt'); END IF; RETURN NEW; END $fn$;
CREATE TRIGGER trg_notify_training_decision AFTER UPDATE ON public.training_submissions FOR EACH ROW EXECUTE FUNCTION public._notify_training_decision();
-- Production public.review_training (27.10.2026).
CREATE FUNCTION public.review_training(p_submission_id uuid, p_decision text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE v_admin public.profiles%rowtype; v_submission public.training_submissions%rowtype; v_points integer;
BEGIN
  SELECT * INTO v_admin FROM public.profiles WHERE auth_user_id = (SELECT auth.uid()) AND role IN ('admin','coach') AND is_active = true;
  IF NOT FOUND THEN RAISE EXCEPTION 'Nur aktive Trainer dürfen Trainings prüfen.'; END IF;
  IF p_decision IS NULL OR p_decision NOT IN ('approved','rejected') THEN RAISE EXCEPTION 'Ungültige Entscheidung.'; END IF;
  SELECT * INTO v_submission FROM public.training_submissions WHERE id = p_submission_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Training nicht gefunden.'; END IF;
  IF v_submission.status <> 'pending' THEN RAISE EXCEPTION 'Dieses Training wurde bereits bearbeitet.'; END IF;
  IF p_decision = 'approved' THEN
    SELECT points INTO v_points FROM public.training_types WHERE id = v_submission.training_type_id;
    IF v_points IS NULL OR v_points < 0 THEN RAISE EXCEPTION 'Kein gültiger Punktewert für diese Trainingsart.'; END IF;
    INSERT INTO public.point_transactions (boxer_id,submission_id,points,exp,category,description,effective_date,created_by)
    VALUES (v_submission.boxer_id,v_submission.id,v_points,v_points,'training','Bestätigtes Training',v_submission.training_date,v_admin.id);
  END IF;
  UPDATE public.training_submissions SET status = p_decision, reviewed_by = v_admin.id, reviewed_at = now() WHERE id = v_submission.id;
  IF v_admin.role='coach' THEN PERFORM league_private.coach_training_bonus_refresh(v_submission.boxer_id);
  ELSE PERFORM public.recalculate_boxer_bonuses(v_submission.boxer_id); END IF;
  RETURN jsonb_build_object('submission_id',v_submission.id,'status',p_decision,'points_awarded',CASE WHEN p_decision='approved' THEN v_points ELSE 0 END);
END;
$function$;
GRANT EXECUTE ON FUNCTION public.review_training(uuid,text) TO authenticated;
INSERT INTO public.training_types(name,points) VALUES ('Reguläres Boxtraining',50),('Sparring',70),('Techniktraining',40),('Krafttraining',30),('Sprint-Intervalle',40),('Joggen',20);
\ir ../supabase/migrations/20261028150000_training_types_duration_notes.sql
CREATE TABLE public.league_feature_flags(feature_key text PRIMARY KEY, display_name text, is_enabled boolean NOT NULL DEFAULT false);
GRANT SELECT ON public.profiles, public.league_feature_flags, public.training_types TO authenticated, anon;
INSERT INTO public.profiles(id,auth_user_id,display_name,role,is_active,archived_at) VALUES
 ('00000000-0000-0000-0000-00000000000a','10000000-0000-0000-0000-00000000000a','Owner','admin',true,NULL),
 ('00000000-0000-0000-0000-00000000000c','10000000-0000-0000-0000-00000000000c','Marco','coach',true,NULL),
 ('00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','Anna','boxer',true,NULL),
 ('00000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000002','Ben','boxer',true,NULL),
 ('00000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000003','Bob','boxer',true,NULL),
 ('00000000-0000-0000-0000-000000000004','10000000-0000-0000-0000-000000000004','Alt','boxer',true,now());
INSERT INTO public.league_seasons_v21(title,starts_on,ends_on,status) VALUES ('Alt','2026-01-01','2026-03-31','closed');
\ir ../supabase/migrations/20261028170000_staff_record_training.sql
\ir ../supabase/migrations/20261028180000_coach_ratings_style_test.sql
\ir ../supabase/migrations/20261028190000_training_groups_gym.sql
\ir ../supabase/migrations/20261028190000_training_groups_gym.sql

CREATE FUNCTION pg_temp.act(p text) RETURNS void LANGUAGE plpgsql AS $fn$ BEGIN
 PERFORM set_config('role','postgres',true);
 IF p IS NULL THEN PERFORM set_config('request.jwt.claim.sub','',true); PERFORM set_config('role','anon',true);
 ELSE PERFORM set_config('request.jwt.claim.sub',p,true); PERFORM set_config('role','authenticated',true); END IF;
END $fn$;
GRANT EXECUTE ON FUNCTION pg_temp.act(text) TO authenticated, anon;

DO $t$ DECLARE r jsonb; sid bigint; today date := (now() AT TIME ZONE 'Europe/Zurich')::date; dow integer; ws date; reg bigint; tech bigint; jog bigint; n integer;
 owner text := '10000000-0000-0000-0000-00000000000a'; coach text := '10000000-0000-0000-0000-00000000000c';
 anna text := '10000000-0000-0000-0000-000000000001'; ben text := '10000000-0000-0000-0000-000000000002'; bob text := '10000000-0000-0000-0000-000000000003';
 annaP uuid := '00000000-0000-0000-0000-000000000001'; benP uuid := '00000000-0000-0000-0000-000000000002'; bobP uuid := '00000000-0000-0000-0000-000000000003';
 coachP uuid := '00000000-0000-0000-0000-00000000000c'; altP uuid := '00000000-0000-0000-0000-000000000004';
BEGIN
 dow := extract(isodow FROM today)::integer - 1; ws := today - dow;
 SELECT id INTO reg FROM public.training_types WHERE name='Reguläres Boxtraining';
 SELECT id INTO tech FROM public.training_types WHERE name='Techniktraining';
 SELECT id INTO jog FROM public.training_types WHERE name='Joggen';
 -- Rechte
 IF has_function_privilege('anon','public.get_my_presence()','EXECUTE') OR has_function_privilege('anon','public.staff_confirm_gym_session(bigint)','EXECUTE') THEN RAISE EXCEPTION 'anon may execute'; END IF;
 IF has_table_privilege('authenticated','public.gym_sessions','SELECT') OR has_table_privilege('authenticated','public.training_plans','INSERT') THEN RAISE EXCEPTION 'table grant'; END IF;
 IF (SELECT count(*) FROM public.training_groups)<>3 THEN RAISE EXCEPTION 'groups seeded twice?'; END IF;
 PERFORM pg_temp.act(anna);
 BEGIN PERFORM public.staff_set_training_group(annaP,'wettkampf'); RAISE EXCEPTION 'boxer set group'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.staff_open_gym_session(reg,90,'Training'); RAISE EXCEPTION 'boxer opened'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.staff_save_training_plan('wettkampf',today,'x','[]',true); RAISE EXCEPTION 'boxer plan'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 IF jsonb_array_length(public.list_training_groups())<>3 THEN RAISE EXCEPTION 'list groups'; END IF;
 IF (public.get_my_presence()->>'enabled')::boolean OR (public.get_my_week_plan()->>'enabled')::boolean OR public.my_gym_sessions_today()<>'[]'::jsonb THEN RAISE EXCEPTION 'visible with flag off'; END IF;

 -- Gruppen
 PERFORM pg_temp.act(coach);
 BEGIN PERFORM public.admin_set_group_target('wettkampf',6); RAISE EXCEPTION 'coach changed target'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.staff_set_training_group(annaP,'profis'); RAISE EXCEPTION 'unknown group'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.staff_set_training_group(altP,'newcomer'); RAISE EXCEPTION 'archived grouped'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM public.staff_set_training_group(annaP,'newcomer');
 IF public.staff_set_training_group(annaP,'wettkampf')->>'group'<>'wettkampf' THEN RAISE EXCEPTION 'regroup'; END IF;
 PERFORM public.staff_set_training_group(bobP,'fortgeschritten');
 PERFORM public.staff_set_training_group(bobP,NULL);
 PERFORM set_config('role','postgres',true);
 IF (SELECT count(*) FROM public.training_group_members)<>1 THEN RAISE EXCEPTION 'members %', (SELECT count(*) FROM public.training_group_members); END IF;
 PERFORM pg_temp.act(owner);
 IF (public.admin_set_group_target('wettkampf',4)->>'weekly_target')::int<>4 THEN RAISE EXCEPTION 'target'; END IF;
 BEGIN PERFORM public.admin_set_group_target('wettkampf',15); RAISE EXCEPTION 'target 15'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;

 -- Wochenplan
 PERFORM pg_temp.act(coach);
 BEGIN PERFORM public.staff_save_training_plan('wettkampf',today,'x',jsonb_build_array(jsonb_build_object('day',7,'type_id',reg,'minutes',60)),true); RAISE EXCEPTION 'day 7'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.staff_save_training_plan('wettkampf',today,'x',jsonb_build_array(jsonb_build_object('day',1,'type_id',reg,'minutes',3)),true); RAISE EXCEPTION 'minutes 3'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.staff_save_training_plan('wettkampf',today,'x',jsonb_build_array(jsonb_build_object('day',1,'type_id',99999,'minutes',60)),true); RAISE EXCEPTION 'unknown type'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.staff_save_training_plan('wettkampf',today-30,'x','[]',true); RAISE EXCEPTION 'old week'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 r := public.staff_save_training_plan('wettkampf',today,'Konter nach dem Jab',jsonb_build_array(
   jsonb_build_object('day',dow,'type_id',reg,'minutes',90),jsonb_build_object('day',6,'type_id',tech,'minutes',60)),false);
 IF (r->>'published')::boolean THEN RAISE EXCEPTION 'draft published'; END IF;
 PERFORM set_config('role','postgres',true);
 UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='gym_training';
 PERFORM pg_temp.act(anna);
 r := public.get_my_week_plan();
 IF r->'plan'<>'null'::jsonb OR r->'group'->>'key'<>'wettkampf' THEN RAISE EXCEPTION 'draft visible %', r; END IF;
 PERFORM pg_temp.act(coach);
 PERFORM public.staff_save_training_plan('wettkampf',today,'Konter nach dem Jab',jsonb_build_array(
   jsonb_build_object('day',dow,'type_id',reg,'minutes',90),jsonb_build_object('day',6,'type_id',tech,'minutes',60)),true);
 IF (public.staff_get_training_plan('wettkampf',today)->'plan'->>'focus')<>'Konter nach dem Jab' THEN RAISE EXCEPTION 'get plan'; END IF;
 PERFORM pg_temp.act(anna);
 r := public.get_my_week_plan();
 IF r->'plan'->>'focus'<>'Konter nach dem Jab' OR jsonb_array_length(r->'plan'->'items')<>2 OR r->'plan'->'items'->0->>'status'<>'today'
    OR r->'plan'->'items'->0->>'training_type'<>'Reguläres Boxtraining' THEN RAISE EXCEPTION 'plan %', r; END IF;
 PERFORM pg_temp.act(ben);
 IF public.get_my_week_plan()->'plan'<>'null'::jsonb THEN RAISE EXCEPTION 'ungrouped sees plan'; END IF;

 -- Gym-Check-in
 PERFORM pg_temp.act(coach);
 BEGIN PERFORM public.staff_open_gym_session(jog,40,'Lauf'); RAISE EXCEPTION 'joggen'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.staff_open_gym_session(reg,90,'  x '); RAISE EXCEPTION 'short note'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 sid := (public.staff_open_gym_session(reg,90,'Konter nach Jab, 4 Runden Sparring')->>'id')::bigint;
 PERFORM pg_temp.act(anna);
 r := public.my_gym_sessions_today();
 IF jsonb_array_length(r)<>1 OR (r->0->>'checked_in')::boolean THEN RAISE EXCEPTION 'today list %', r; END IF;
 PERFORM public.gym_check_in(sid); PERFORM public.gym_check_in(sid);
 IF (public.my_gym_sessions_today()->0->>'checked_in')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'checked in'; END IF;
 BEGIN PERFORM public.staff_set_gym_attendance(sid,benP,true); RAISE EXCEPTION 'boxer marked other'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 -- Bob hat dasselbe Training heute schon eingereicht
 PERFORM set_config('role','postgres',true);
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes) VALUES (bobP,reg,today,'Selbst eingereicht','pending',60);
 PERFORM pg_temp.act(coach);
 PERFORM public.staff_set_gym_attendance(sid,benP,true);
 PERFORM public.staff_set_gym_attendance(sid,bobP,true);
 PERFORM public.staff_set_gym_attendance(sid,coachP,true);
 PERFORM public.staff_set_gym_attendance(sid,bobP,false);
 PERFORM public.staff_set_gym_attendance(sid,bobP,true);
 BEGIN PERFORM public.staff_set_gym_attendance(sid,altP,true); RAISE EXCEPTION 'archived present'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 r := public.staff_get_gym_session(sid);
 IF (SELECT count(*) FROM jsonb_array_elements(r->'people') x WHERE (x->>'present')::boolean)<>4 THEN RAISE EXCEPTION 'present count %', r; END IF;
 IF (SELECT x->>'source' FROM jsonb_array_elements(r->'people') x WHERE x->>'display_name'='Anna')<>'self' THEN RAISE EXCEPTION 'source'; END IF;
 r := public.staff_confirm_gym_session(sid);
 IF (r->>'confirmed')::int<>2 OR (r->>'points_awarded')::int<>100 OR jsonb_array_length(r->'skipped')<>2 THEN RAISE EXCEPTION 'confirm %', r; END IF;
 BEGIN PERFORM public.staff_confirm_gym_session(sid); RAISE EXCEPTION 'confirm twice'; EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL; END;
 BEGIN PERFORM public.staff_set_gym_attendance(sid,bobP,false); RAISE EXCEPTION 'edit after confirm'; EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL; END;
 PERFORM set_config('role','postgres',true);
 IF (SELECT count(*) FROM public.training_submissions WHERE status='approved' AND recorded_by=coachP AND training_date=today AND training_type_id=reg)<>2 THEN RAISE EXCEPTION 'submissions'; END IF;
 IF (SELECT count(*) FROM public.point_transactions)<>2 THEN RAISE EXCEPTION 'points %', (SELECT count(*) FROM public.point_transactions); END IF;
 IF (SELECT count(*) FROM public.training_submissions WHERE boxer_id=bobP)<>1 THEN RAISE EXCEPTION 'bob doubled'; END IF;
 IF (SELECT count(*) FROM public.gym_attendance WHERE skipped_reason IS NOT NULL)<>2 THEN RAISE EXCEPTION 'skip reasons'; END IF;
 PERFORM pg_temp.act(anna);
 r := public.get_my_week_plan();
 IF r->'plan'->'items'->0->>'status'<>'done' OR (r->>'trainings')::int<>1 THEN RAISE EXCEPTION 'plan done %', r; END IF;
 IF public.my_gym_sessions_today()<>'[]'::jsonb THEN RAISE EXCEPTION 'confirmed still open'; END IF;

 -- Präsenz
 r := public.get_my_presence();
 IF jsonb_array_length(r->'days')<>28 OR jsonb_array_length(r->'weeks')<>4 OR (r->'weeks'->0->>'trainings')::int<>1 OR (r->'weeks'->0->>'target')::int<>4
    OR (r->>'streak_weeks')::int<>0 OR NOT (SELECT bool_or((d->>'gym')::boolean) FROM jsonb_array_elements(r->'days') d) THEN RAISE EXCEPTION 'presence %', r; END IF;
 PERFORM set_config('role','postgres',true);
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes)
 SELECT benP,tech,ws-7+i,'Vorwoche','approved',60 FROM generate_series(0,1) i;
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes)
 SELECT benP,tech,ws+i-dow,'Diese Woche','approved',60 FROM generate_series(0,0) i WHERE dow>0;
 PERFORM pg_temp.act(ben);
 r := public.get_my_presence();
 IF r->'group'<>'null'::jsonb OR (r->'weeks'->1->>'met')::boolean IS NOT TRUE OR (r->>'streak_weeks')::int<1 THEN RAISE EXCEPTION 'ben presence %', r; END IF;
 PERFORM pg_temp.act(coach);
 IF jsonb_array_length(public.staff_presence_overview())<>4 THEN RAISE EXCEPTION 'overview'; END IF;
 IF jsonb_array_length(public.staff_list_gym_sessions(14))<>1 THEN RAISE EXCEPTION 'sessions list'; END IF;
 sid := (public.staff_open_gym_session(tech,60,'Technik am Abend')->>'id')::bigint;
 IF public.staff_cancel_gym_session(sid)->>'status'<>'cancelled' THEN RAISE EXCEPTION 'cancel'; END IF;
 PERFORM pg_temp.act(anna);
 BEGIN PERFORM public.gym_check_in(sid); RAISE EXCEPTION 'check in cancelled'; EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL; END;
 PERFORM set_config('role','postgres',true);
END $t$;

SELECT set_config('role','postgres',false);
\ir ../supabase/production-prep/rollback_20261028190000_training_groups_gym.sql
DO $t$ BEGIN
 IF to_regprocedure('public.staff_confirm_gym_session(bigint)') IS NOT NULL OR to_regprocedure('league_private.presence_streak(uuid)') IS NOT NULL THEN RAISE EXCEPTION 'rollback left functions'; END IF;
 IF to_regprocedure('league_private.active_viewer()') IS NULL OR to_regprocedure('public.staff_record_training(uuid,bigint,date,integer,text,numeric,uuid)') IS NULL THEN RAISE EXCEPTION 'rollback removed earlier functions'; END IF;
 IF (SELECT count(*) FROM public.gym_sessions)<>2 OR (SELECT count(*) FROM public.training_plans)<>1 OR (SELECT count(*) FROM public.training_group_members)<>1 THEN RAISE EXCEPTION 'rollback lost data'; END IF;
END $t$;
\ir ../supabase/migrations/20261028190000_training_groups_gym.sql
SELECT 'PASS: Gruppen nur durch Trainer/Admin, Wochenziel nur Admin, Wochenplan Entwurf/Veröffentlichen mit Status, Check-in (selbst/Trainer), Bestätigen über staff_record_training ohne Doppeltrainings, Präsenz und Serie, Flag, Rollback behält Daten' AS result;
