\set ON_ERROR_STOP on
-- Disposable-database test for 20261028200000_weekly_quests.sql (+ rollback). Fixture from training-groups-gym-schema.sql
-- (production review_training, required-details trigger 20261028150000, Etappen 1 und 2).
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
CREATE TABLE public.league_duels(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), challenger_id uuid NOT NULL REFERENCES public.profiles(id),
 opponent_id uuid NOT NULL REFERENCES public.profiles(id), status text NOT NULL, accepted_at timestamptz);
\ir ../supabase/migrations/20261028200000_weekly_quests.sql
\ir ../supabase/migrations/20261028200000_weekly_quests.sql
CREATE FUNCTION pg_temp.act(p text) RETURNS void LANGUAGE plpgsql AS $fn$ BEGIN
 PERFORM set_config('role','postgres',true);
 IF p IS NULL THEN PERFORM set_config('request.jwt.claim.sub','',true); PERFORM set_config('role','anon',true);
 ELSE PERFORM set_config('request.jwt.claim.sub',p,true); PERFORM set_config('role','authenticated',true); END IF;
END $fn$;
GRANT EXECUTE ON FUNCTION pg_temp.act(text) TO authenticated, anon;

DO $t$ DECLARE r jsonb; q jsonb; today date := (now() AT TIME ZONE 'Europe/Zurich')::date; dow integer; ws date;
 reg bigint; tech bigint; jog bigint; sand bigint; mob bigint; mobsub uuid;
 owner text := '10000000-0000-0000-0000-00000000000a'; coach text := '10000000-0000-0000-0000-00000000000c';
 anna text := '10000000-0000-0000-0000-000000000001'; ben text := '10000000-0000-0000-0000-000000000002';
 annaP uuid := '00000000-0000-0000-0000-000000000001'; benP uuid := '00000000-0000-0000-0000-000000000002';
BEGIN
 dow := extract(isodow FROM today)::integer - 1; ws := today - dow;
 SELECT id INTO reg FROM public.training_types WHERE name='Reguläres Boxtraining';
 SELECT id INTO tech FROM public.training_types WHERE name='Techniktraining';
 SELECT id INTO jog FROM public.training_types WHERE name='Joggen';
 SELECT id INTO sand FROM public.training_types WHERE name='Sandsack / Rundenarbeit';
 SELECT id INTO mob FROM public.training_types WHERE name='Mobilität / Regeneration';
 IF sand IS NULL OR mob IS NULL THEN RAISE EXCEPTION 'fixture types'; END IF;
 -- Rechte und Seeds
 IF has_function_privilege('anon','public.get_my_quests(date)','EXECUTE') OR has_function_privilege('anon','public.claim_quest(text,date)','EXECUTE') THEN RAISE EXCEPTION 'anon may execute'; END IF;
 IF has_table_privilege('authenticated','public.quest_claims','SELECT') OR has_table_privilege('authenticated','public.quest_definitions','UPDATE') THEN RAISE EXCEPTION 'table grant'; END IF;
 IF has_function_privilege('authenticated','league_private.quest_progress(uuid,text,date,date)','EXECUTE') THEN RAISE EXCEPTION 'helper grant'; END IF;
 IF (SELECT count(*) FROM public.quest_definitions)<>10 THEN RAISE EXCEPTION 'seeds'; END IF;
 IF (SELECT sum(exp) FILTER (WHERE kind IN ('weekly','chest')) + 7*max(exp) FILTER (WHERE kind='daily') FROM public.quest_definitions)<>175 THEN RAISE EXCEPTION 'max exp'; END IF;
 IF (SELECT count(DISTINCT league_private.daily_quest_key(today+i)) FROM generate_series(0,3) i)<>4 THEN RAISE EXCEPTION 'rotation'; END IF;
 IF league_private.daily_quest_key(today)<>league_private.daily_quest_key(today+4) THEN RAISE EXCEPTION 'rotation period'; END IF;

 -- Flag aus
 PERFORM pg_temp.act(anna);
 IF (public.get_my_quests()->>'enabled')::boolean THEN RAISE EXCEPTION 'visible with flag off'; END IF;
 BEGIN PERFORM public.claim_quest('box_sessions',today); RAISE EXCEPTION 'claim flag off'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM pg_temp.act(owner);
 r := public.get_my_quests();
 IF NOT (r->>'preview')::boolean OR (r->>'can_claim')::boolean OR jsonb_array_length(r->'weekly')<>5 OR jsonb_array_length(r->'daily')<>dow+1 THEN RAISE EXCEPTION 'admin preview %', r; END IF;
 BEGIN PERFORM public.get_my_quests(today+7); RAISE EXCEPTION 'future week'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.get_my_quests(today-70); RAISE EXCEPTION 'old week'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;

 -- Admin-Einstellungen
 PERFORM pg_temp.act(coach);
 BEGIN PERFORM public.admin_update_quest('box_sessions',3,20,60,true,'{}'); RAISE EXCEPTION 'coach edits'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.admin_list_quests(); RAISE EXCEPTION 'coach lists'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM pg_temp.act(owner);
 BEGIN PERFORM public.admin_update_quest('box_sessions',3,150,60,true,'{}'); RAISE EXCEPTION 'exp 150'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.admin_update_quest('box_sessions',3,20,60,true,'{"profis":3}'); RAISE EXCEPTION 'unknown group'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.admin_update_quest('box_sessions',3,20,60,true,'{"newcomer":2.5}'); RAISE EXCEPTION 'fraction'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.admin_update_quest('plan',120,30,80,true,'{}'); RAISE EXCEPTION 'plan 120'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM public.admin_update_quest('d_home',20,5,25,false,'{}');
 PERFORM public.admin_update_quest('d_run',3,5,25,false,'{}');
 PERFORM public.admin_update_quest('d_mob',15,5,25,false,'{}');
 BEGIN PERFORM public.admin_update_quest('d_any',1,5,25,false,'{}'); RAISE EXCEPTION 'last daily'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 IF public.admin_list_quests()->>'today_daily'<>'d_any' THEN RAISE EXCEPTION 'today daily'; END IF;

 -- Gruppe, Plan, Trainings
 PERFORM pg_temp.act(coach);
 PERFORM public.staff_set_training_group(annaP,'wettkampf');
 PERFORM public.staff_save_training_plan('wettkampf',today,'Konter',jsonb_build_array(
   jsonb_build_object('day',0,'type_id',reg,'minutes',90),jsonb_build_object('day',1,'type_id',tech,'minutes',60)),true);
 PERFORM set_config('role','postgres',true);
 UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key IN ('weekly_quests','gym_training');
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes,jogging_km) VALUES
  (annaP,reg,ws,'Montag','approved',90,NULL),(annaP,tech,ws+1,'Technik','approved',60,NULL),(annaP,tech,ws+2,'Technik','approved',60,NULL),
  (annaP,sand,ws+3,'Sandsack','approved',45,NULL),(annaP,jog,today,'Lauf','approved',30,5),
  (annaP,reg,ws-7,'Vorwoche','rejected',90,NULL);
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes) VALUES (annaP,mob,ws+4,'Dehnen','pending',20)
 RETURNING id INTO mobsub;

 PERFORM pg_temp.act(anna);
 r := public.get_my_quests();
 IF NOT (r->>'can_claim')::boolean OR (r->>'preview')::boolean OR r->'group'->>'key'<>'wettkampf' THEN RAISE EXCEPTION 'state %', r; END IF;
 SELECT x INTO q FROM jsonb_array_elements(r->'weekly') x WHERE x->>'key'='box_sessions';
 IF (q->>'target')::int<>4 OR q->>'title'<>'4 Boxeinheiten' OR (q->>'progress')::int<>4 OR NOT (q->>'done')::boolean THEN RAISE EXCEPTION 'box %', q; END IF;
 SELECT x INTO q FROM jsonb_array_elements(r->'weekly') x WHERE x->>'key'='technique';
 IF (q->>'target')::int<>120 OR (q->>'progress')::int<>120 OR NOT (q->>'done')::boolean THEN RAISE EXCEPTION 'tech %', q; END IF;
 SELECT x INTO q FROM jsonb_array_elements(r->'weekly') x WHERE x->>'key'='plan';
 IF NOT (q->>'available')::boolean OR (q->>'progress')::int<>100 THEN RAISE EXCEPTION 'plan %', q; END IF;
 SELECT x INTO q FROM jsonb_array_elements(r->'weekly') x WHERE x->>'key'='recovery';
 IF (q->>'done')::boolean OR (q->>'progress')::int<>0 THEN RAISE EXCEPTION 'pending counted %', q; END IF;
 SELECT x INTO q FROM jsonb_array_elements(r->'weekly') x WHERE x->>'key'='duel';
 IF (q->>'available')::boolean THEN RAISE EXCEPTION 'duel without flag'; END IF;
 IF (r->'chest'->>'target')::int<>4 OR (r->'chest'->>'done')::boolean THEN RAISE EXCEPTION 'chest %', r->'chest'; END IF;
 q := r->'daily'->dow;
 IF q->>'key'<>'d_any' OR NOT (q->>'done')::boolean OR (q->>'period_start')::date<>today THEN RAISE EXCEPTION 'daily %', r->'daily'; END IF;

 -- Abholen
 BEGIN PERFORM public.claim_quest('recovery',today); RAISE EXCEPTION 'claimed undone'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.claim_quest('chest',today); RAISE EXCEPTION 'chest early'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.claim_quest('duel',today); RAISE EXCEPTION 'duel unavailable'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.claim_quest('box_sessions',ws-14); RAISE EXCEPTION 'expired'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.claim_quest('box_sessions',ws-7); RAISE EXCEPTION 'last week undone'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.claim_quest('d_any',today+1); RAISE EXCEPTION 'future day'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.claim_quest('nope',today); RAISE EXCEPTION 'unknown'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 r := public.claim_quest('box_sessions',today);
 IF (r->>'exp')::int<>20 OR (r->>'coins')::int<>60 OR (r->>'period_start')::date<>ws OR r->>'title'<>'4 Boxeinheiten' THEN RAISE EXCEPTION 'claim %', r; END IF;
 BEGIN PERFORM public.claim_quest('box_sessions',ws+2); RAISE EXCEPTION 'claim twice'; EXCEPTION WHEN unique_violation THEN NULL; END;
 PERFORM public.claim_quest('technique',ws);
 PERFORM public.claim_quest('plan',ws);
 PERFORM public.claim_quest('d_any',today);
 BEGIN PERFORM public.claim_quest('d_any',today); RAISE EXCEPTION 'daily twice'; EXCEPTION WHEN unique_violation THEN NULL; END;
 PERFORM set_config('role','postgres',true);
 UPDATE public.training_submissions SET status='approved' WHERE id=mobsub;
 PERFORM pg_temp.act(anna);
 PERFORM public.claim_quest('recovery',today);
 r := public.claim_quest('chest',today);
 IF (r->>'exp')::int<>40 OR (r->>'coins')::int<>200 THEN RAISE EXCEPTION 'chest claim %', r; END IF;
 r := public.get_my_quests();
 IF (r->>'exp_week')::int<>125 OR (r->>'coins_pending')::int<>445 OR NOT (r->'chest'->>'claimed')::boolean THEN RAISE EXCEPTION 'totals %', r; END IF;
 PERFORM set_config('role','postgres',true);
 IF (SELECT count(*) FROM public.point_transactions WHERE description LIKE 'Quest-Belohnung:%' AND points=0 AND category='challenge_exp' AND boxer_id=annaP)<>6
    OR (SELECT sum(exp) FROM public.point_transactions WHERE description LIKE 'Quest-Belohnung:%')<>125
    OR (SELECT count(*) FROM public.quest_claims c JOIN public.point_transactions t ON t.id=c.transaction_id AND t.exp=c.exp)<>6 THEN RAISE EXCEPTION 'ledger'; END IF;
 IF (SELECT sum(points) FROM public.point_transactions WHERE description LIKE 'Quest-Belohnung:%')<>0 THEN RAISE EXCEPTION 'quest points'; END IF;

 -- Duell (Flag duels an, diese Woche angenommen) → Quest verfügbar und abholbar
 INSERT INTO public.league_feature_flags(feature_key,display_name,is_enabled) VALUES ('duels','Duelle',true);
 INSERT INTO public.league_duels(challenger_id,opponent_id,status,accepted_at) VALUES (benP,annaP,'active',now()),(annaP,benP,'pending',NULL);
 PERFORM pg_temp.act(anna);
 IF (public.claim_quest('duel',today)->>'exp')::int<>20 THEN RAISE EXCEPTION 'duel claim'; END IF;
 PERFORM pg_temp.act(ben);
 r := public.get_my_quests();
 SELECT x INTO q FROM jsonb_array_elements(r->'weekly') x WHERE x->>'key'='box_sessions';
 IF (q->>'target')::int<>3 OR r->'group'<>'null'::jsonb THEN RAISE EXCEPTION 'ben default target %', q; END IF;
 SELECT x INTO q FROM jsonb_array_elements(r->'weekly') x WHERE x->>'key'='plan';
 IF (q->>'available')::boolean THEN RAISE EXCEPTION 'ben plan available'; END IF;
 SELECT x INTO q FROM jsonb_array_elements(r->'weekly') x WHERE x->>'key'='duel';
 IF NOT (q->>'done')::boolean THEN RAISE EXCEPTION 'ben duel %', q; END IF;
 IF (SELECT x->>'done' FROM jsonb_array_elements(r->'daily') x WHERE (x->>'period_start')::date=today)::boolean THEN RAISE EXCEPTION 'ben daily'; END IF;

 -- Admin kann nicht abholen; spätere Änderungen verändern bereits abgeholte Belohnungen nicht
 PERFORM pg_temp.act(owner);
 BEGIN PERFORM public.claim_quest('box_sessions',today); RAISE EXCEPTION 'admin claimed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM public.admin_update_quest('box_sessions',5,50,99,false,'{}');
 SELECT x INTO q FROM jsonb_array_elements(public.admin_list_quests()->'quests') x WHERE x->>'key'='box_sessions';
 IF (q->>'claims')::int<>1 OR (q->>'is_active')::boolean THEN RAISE EXCEPTION 'admin list %', q; END IF;
 PERFORM pg_temp.act(anna);
 r := public.get_my_quests();
 SELECT x INTO q FROM jsonb_array_elements(r->'weekly') x WHERE x->>'key'='box_sessions';
 IF q IS NULL OR (q->>'exp')::int<>20 OR NOT (q->>'claimed')::boolean THEN RAISE EXCEPTION 'claimed inactive quest %', q; END IF;
 PERFORM pg_temp.act(ben);
 IF EXISTS (SELECT 1 FROM jsonb_array_elements(public.get_my_quests()->'weekly') x WHERE x->>'key'='box_sessions') THEN RAISE EXCEPTION 'inactive shown'; END IF;
 BEGIN PERFORM public.claim_quest('box_sessions',today); RAISE EXCEPTION 'inactive claimed'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;

 -- Trainerübersicht
 PERFORM pg_temp.act(anna);
 BEGIN PERFORM public.staff_quest_overview(); RAISE EXCEPTION 'boxer overview'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM pg_temp.act(coach);
 r := public.staff_quest_overview();
 IF jsonb_array_length(r)<>4 THEN RAISE EXCEPTION 'overview %', r; END IF;
 SELECT x INTO q FROM jsonb_array_elements(r) x WHERE x->>'display_name'='Anna';
 IF (q->>'claimed')::int<>5 OR NOT (q->>'chest')::boolean OR (q->>'exp_week')::int<>145 THEN RAISE EXCEPTION 'anna overview %', q; END IF;
 PERFORM set_config('role','postgres',true);
END $t$;

SELECT set_config('role','postgres',false);
\ir ../supabase/production-prep/rollback_20261028200000_weekly_quests.sql
DO $t$ BEGIN
 IF to_regprocedure('public.claim_quest(text,date)') IS NOT NULL OR to_regprocedure('league_private.quest_progress(uuid,text,date,date)') IS NOT NULL THEN RAISE EXCEPTION 'rollback left functions'; END IF;
 IF to_regprocedure('league_private.group_of(uuid)') IS NULL OR to_regprocedure('public.get_my_week_plan(date)') IS NULL THEN RAISE EXCEPTION 'rollback removed earlier functions'; END IF;
 IF (SELECT count(*) FROM public.quest_claims)<>7 OR (SELECT count(*) FROM public.quest_definitions)<>10
    OR (SELECT count(*) FROM public.point_transactions WHERE description LIKE 'Quest-Belohnung:%')<>7 THEN RAISE EXCEPTION 'rollback lost data'; END IF;
END $t$;
\ir ../supabase/migrations/20261028200000_weekly_quests.sql
DO $t$ BEGIN
 IF (SELECT is_active FROM public.quest_definitions WHERE key='box_sessions') OR (SELECT exp FROM public.quest_definitions WHERE key='box_sessions')<>50 THEN RAISE EXCEPTION 'reapply reset admin settings'; END IF;
END $t$;
SELECT 'PASS: Wochen-/Tagesquests – Fortschritt nur aus bestätigten Trainings, Gruppenziele, Plan- und Duellquest nur wenn verfügbar, Truhe, keine Doppelabholung, EXP ohne Punkte, Coins gespeichert, Admin-Grenzen, Flag, Rollback behält Daten' AS result;
