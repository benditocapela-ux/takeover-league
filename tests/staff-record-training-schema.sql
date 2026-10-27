\set ON_ERROR_STOP on
-- Disposable-database test for 20261028170000_staff_record_training.sql (+ rollback).
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
INSERT INTO public.profiles(id,auth_user_id,display_name,role,is_active,archived_at) VALUES
 ('00000000-0000-0000-0000-00000000000a','10000000-0000-0000-0000-00000000000a','Owner','admin',true,null),
 ('00000000-0000-0000-0000-00000000000c','10000000-0000-0000-0000-00000000000c','Coach','coach',true,null),
 ('00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','Anna','boxer',true,null),
 ('00000000-0000-0000-0000-000000000002',null,'Archiviert','boxer',false,now()),
 ('00000000-0000-0000-0000-000000000003',null,'Inaktiv','boxer',false,null);
INSERT INTO public.league_seasons_v21(title,starts_on,ends_on,status) VALUES ('Alt','2026-01-01','2026-03-31','closed');

\ir ../supabase/migrations/20261028170000_staff_record_training.sql
\ir ../supabase/migrations/20261028170000_staff_record_training.sql

DO $t$ DECLARE j jsonb; box bigint; jog bigint; tech bigint; rid uuid := gen_random_uuid(); n int; BEGIN
 SELECT id INTO box FROM public.training_types WHERE name='Reguläres Boxtraining';
 SELECT id INTO jog FROM public.training_types WHERE name='Joggen';
 SELECT id INTO tech FROM public.training_types WHERE name='Techniktraining';
 IF has_function_privilege('anon','public.staff_record_training(uuid,bigint,date,integer,text,numeric,uuid)','EXECUTE') THEN RAISE EXCEPTION 'anon may execute'; END IF;
 -- Boxer darf nicht
 PERFORM set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true); PERFORM set_config('role','authenticated',true);
 BEGIN PERFORM public.staff_record_training('00000000-0000-0000-0000-000000000001',box,current_date,60,'Selbst bestätigt');
  RAISE EXCEPTION 'boxer recorded'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM set_config('role','postgres',true);
 -- Coach trägt für Anna ein → sofort bestätigt, Punkte gebucht, Mitteilung
 PERFORM set_config('request.jwt.claim.sub','10000000-0000-0000-0000-00000000000c',true); PERFORM set_config('role','authenticated',true);
 j := public.staff_record_training('00000000-0000-0000-0000-000000000001',box,current_date,90,'  Pratzen und Runden  ',NULL,rid);
 IF j->>'status'<>'approved' OR (j->>'points_awarded')::int<>50 THEN RAISE EXCEPTION 'coach entry: %', j; END IF;
 -- gleiche Anfrage nochmals → keine Doppelbuchung
 j := public.staff_record_training('00000000-0000-0000-0000-000000000001',box,current_date,90,'Pratzen und Runden',NULL,rid);
 IF j->>'duplicate'<>'true' THEN RAISE EXCEPTION 'duplicate not detected: %', j; END IF;
 -- Coach darf sich nicht selbst eintragen
 BEGIN PERFORM public.staff_record_training('00000000-0000-0000-0000-00000000000c',box,current_date,60,'Eigenes Training');
  RAISE EXCEPTION 'coach self entry'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 -- Pflichtangaben
 BEGIN PERFORM public.staff_record_training('00000000-0000-0000-0000-000000000001',box,current_date,60,'');
  RAISE EXCEPTION 'missing notes accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
 BEGIN PERFORM public.staff_record_training('00000000-0000-0000-0000-000000000001',box,current_date,NULL,'Ohne Dauer');
  RAISE EXCEPTION 'missing duration accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
 BEGIN PERFORM public.staff_record_training('00000000-0000-0000-0000-000000000001',jog,current_date,30,'Lauf ohne km');
  RAISE EXCEPTION 'jogging without km accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 -- Datum
 BEGIN PERFORM public.staff_record_training('00000000-0000-0000-0000-000000000001',box,current_date+2,60,'Zukunft');
  RAISE EXCEPTION 'future accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.staff_record_training('00000000-0000-0000-0000-000000000001',box,'2026-02-10',60,'Alte Saison');
  RAISE EXCEPTION 'closed season accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 -- Zielprofil
 BEGIN PERFORM public.staff_record_training('00000000-0000-0000-0000-000000000002',box,current_date,60,'Archiviert');
  RAISE EXCEPTION 'archived accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.staff_record_training('00000000-0000-0000-0000-000000000003',box,current_date,60,'Inaktiv');
  RAISE EXCEPTION 'inactive accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM set_config('role','postgres',true);
 -- Admin trägt Joggen und Technik ein
 PERFORM set_config('request.jwt.claim.sub','10000000-0000-0000-0000-00000000000a',true); PERFORM set_config('role','authenticated',true);
 j := public.staff_record_training('00000000-0000-0000-0000-000000000001',jog,current_date-1,35,'Lockerer Lauf',6.5);
 j := public.staff_record_training('00000000-0000-0000-0000-000000000001',tech,current_date-1,45,'Jab-Technik',99);
 PERFORM set_config('role','postgres',true);
 SELECT count(*) INTO n FROM public.training_submissions WHERE boxer_id='00000000-0000-0000-0000-000000000001' AND status='approved';
 IF n<>3 THEN RAISE EXCEPTION 'expected 3 approved, got %', n; END IF;
 IF (SELECT sum(points) FROM public.point_transactions)<>110 OR (SELECT count(*) FROM public.point_transactions)<>3 THEN RAISE EXCEPTION 'points wrong'; END IF;
 IF (SELECT count(*) FROM public.boxer_notifications WHERE title='Training bestätigt')<>3 THEN RAISE EXCEPTION 'notifications'; END IF;
 IF EXISTS (SELECT 1 FROM public.training_submissions WHERE recorded_by IS NULL OR reviewed_by IS DISTINCT FROM recorded_by) THEN RAISE EXCEPTION 'recorded_by/reviewed_by'; END IF;
 IF (SELECT notes FROM public.training_submissions WHERE client_request_id=rid)<>'Pratzen und Runden' THEN RAISE EXCEPTION 'notes trimmed'; END IF;
 IF (SELECT jogging_km FROM public.training_submissions WHERE training_type_id=jog)<>6.5 THEN RAISE EXCEPTION 'km'; END IF;
 IF (SELECT jogging_km FROM public.training_submissions WHERE training_type_id=tech) IS NOT NULL THEN RAISE EXCEPTION 'km on technique'; END IF;
 IF (SELECT technique_minutes FROM public.training_submissions WHERE training_type_id=tech)<>45 THEN RAISE EXCEPTION 'technique minutes'; END IF;
END $t$;

\ir ../supabase/production-prep/rollback_20261028170000_staff_record_training.sql
DO $t$ BEGIN
 IF to_regprocedure('public.staff_record_training(uuid,bigint,date,integer,text,numeric,uuid)') IS NOT NULL THEN RAISE EXCEPTION 'rollback left rpc'; END IF;
 IF (SELECT count(*) FROM public.training_submissions)<>3 OR (SELECT count(*) FROM public.point_transactions)<>3 THEN RAISE EXCEPTION 'rollback lost data'; END IF;
END $t$;
\ir ../supabase/migrations/20261028170000_staff_record_training.sql
SELECT 'PASS: Trainer/Admin tragen ein und bestätigen sofort (Punkte, Mitteilung), keine Selbstbestätigung, Pflichtangaben, Datum, Doppelklick, Rollback behält Daten' AS result;
