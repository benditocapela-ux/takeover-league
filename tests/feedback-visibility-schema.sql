\set ON_ERROR_STOP on
-- Disposable-database test for 20261028240000_feedback_visibility.sql (+ rollback). Fixture: Etappen 1–3 (active_viewer, require_staff, zurich_today) plus Feedback wie Produktion.
-- (Etappen 1 bis 4); league_duels um settled_at/winner_id ergänzt, get_public_leaderboard wie Produktion (Monatspunkte).
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
CREATE FUNCTION pg_temp.act(p text) RETURNS void LANGUAGE plpgsql AS $fn$ BEGIN
 PERFORM set_config('role','postgres',true);
 IF p IS NULL THEN PERFORM set_config('request.jwt.claim.sub','',true); PERFORM set_config('role','anon',true);
 ELSE PERFORM set_config('request.jwt.claim.sub',p,true); PERFORM set_config('role','authenticated',true); END IF;
END $fn$;
GRANT EXECUTE ON FUNCTION pg_temp.act(text) TO authenticated, anon;
-- Feedback wie Produktion (Tabelle, Policies, Benachrichtigung)
CREATE FUNCTION public.is_league_admin() RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO '' AS $function$
 select exists (select 1 from public.profiles p where p.auth_user_id = (select auth.uid()) and p.role = 'admin' and p.is_active); $function$;
CREATE FUNCTION public.is_league_coach() RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO '' AS $function$
 SELECT EXISTS (SELECT 1 FROM public.profiles p WHERE p.auth_user_id=(SELECT auth.uid()) AND p.role IN ('admin','coach') AND p.is_active IS TRUE); $function$;
GRANT EXECUTE ON FUNCTION public.is_league_admin(), public.is_league_coach() TO authenticated;
CREATE TABLE public.boxer_coach_feedback(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), boxer_id uuid NOT NULL REFERENCES public.profiles(id),
 coach_id uuid NOT NULL REFERENCES public.profiles(id), title text NOT NULL CHECK (char_length(btrim(title)) BETWEEN 1 AND 120),
 message text NOT NULL CHECK (char_length(btrim(message)) BETWEEN 1 AND 4000), created_at timestamptz NOT NULL DEFAULT now());
ALTER TABLE public.boxer_coach_feedback ENABLE ROW LEVEL SECURITY;
GRANT INSERT, SELECT ON public.boxer_coach_feedback TO authenticated;
CREATE POLICY feedback_select_enabled ON public.boxer_coach_feedback FOR SELECT TO authenticated USING (
 (EXISTS (SELECT 1 FROM public.league_feature_flags f WHERE f.feature_key='coach_feedback' AND f.is_enabled))
 AND (public.is_league_admin() OR (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=boxer_coach_feedback.boxer_id AND p.auth_user_id=(SELECT auth.uid())))));
CREATE POLICY coach_v3_feedback_select_enabled ON public.boxer_coach_feedback FOR SELECT TO authenticated USING (public.is_league_coach()
 AND EXISTS (SELECT 1 FROM public.league_feature_flags f WHERE f.feature_key='coach_feedback' AND f.is_enabled));
CREATE POLICY coach_v3_feedback_insert_admin_enabled ON public.boxer_coach_feedback FOR INSERT TO authenticated WITH CHECK (public.is_league_coach()
 AND EXISTS (SELECT 1 FROM public.league_feature_flags f WHERE f.feature_key='coach_feedback' AND f.is_enabled)
 AND EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=boxer_coach_feedback.coach_id AND p.auth_user_id=(SELECT auth.uid()) AND p.role IN ('admin','coach') AND p.is_active)
 AND EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=boxer_coach_feedback.boxer_id AND p.role='boxer' AND p.is_active));
GRANT SELECT ON public.profiles TO authenticated;
-- Wie Produktion: Profile liest man nur selbst (Admin alle) – Coaches sehen fremde Boxer nicht
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "profiles own or admin read" ON public.profiles FOR SELECT TO authenticated USING (((auth_user_id = (SELECT auth.uid())) AND is_active) OR (SELECT public.is_league_admin()));
INSERT INTO public.league_feature_flags(feature_key,display_name,is_enabled) VALUES ('coach_feedback','Coach-Feedback',true) ON CONFLICT (feature_key) DO UPDATE SET is_enabled=true;
-- Bestehende Feedbacks: eines vom 18.10. (älter als 7 Tage), eines von heute
INSERT INTO public.boxer_coach_feedback(boxer_id,coach_id,title,message,created_at) VALUES
 ('00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-00000000000a','Alt','Deckung hoch','2026-10-18 18:00+02'),
 ('00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-00000000000c','Neu','Gute Beinarbeit',now());
CREATE TEMP TABLE fb_before AS SELECT id,title,message,boxer_id,coach_id,created_at FROM public.boxer_coach_feedback;
GRANT SELECT ON fb_before TO authenticated;
\ir ../supabase/migrations/20261028240000_feedback_visibility.sql
\ir ../supabase/migrations/20261028240000_feedback_visibility.sql

DO $t$ DECLARE r jsonb; today date := (now() AT TIME ZONE 'Europe/Zurich')::date; f1 uuid; f2 uuid; f3 uuid; n int;
 owner text := '10000000-0000-0000-0000-00000000000a'; coach text := '10000000-0000-0000-0000-00000000000c';
 anna text := '10000000-0000-0000-0000-000000000001'; ben text := '10000000-0000-0000-0000-000000000002';
 ownerP uuid := '00000000-0000-0000-0000-00000000000a'; coachP uuid := '00000000-0000-0000-0000-00000000000c';
 annaP uuid := '00000000-0000-0000-0000-000000000001'; benP uuid := '00000000-0000-0000-0000-000000000002';
BEGIN
 PERFORM set_config('role','postgres',true);
 -- Bestehende Inhalte unverändert, sichtbar bis = Versand + 7
 IF EXISTS (SELECT 1 FROM fb_before b JOIN public.boxer_coach_feedback f USING (id) WHERE (b.title,b.message,b.boxer_id,b.coach_id,b.created_at) IS DISTINCT FROM (f.title,f.message,f.boxer_id,f.coach_id,f.created_at)) THEN RAISE EXCEPTION 'content changed'; END IF;
 IF (SELECT visible_until FROM public.boxer_coach_feedback WHERE title='Alt')<>DATE '2026-10-25' THEN RAISE EXCEPTION 'old visible_until'; END IF;
 IF has_function_privilege('anon','public.get_my_feedback()','EXECUTE') OR has_function_privilege('anon','public.staff_send_feedback(uuid,text,text,date)','EXECUTE') OR has_function_privilege('authenticated','league_private.feedback_json(public.boxer_coach_feedback,date)','EXECUTE') THEN RAISE EXCEPTION 'rights'; END IF;

 -- Boxerin Anna: altes Feedback liegt im Archiv
 PERFORM pg_temp.act(anna);
 r := public.get_my_feedback();
 IF jsonb_array_length(r->'active')<>0 OR jsonb_array_length(r->'archived')<>1 OR r->'archived'->0->>'status'<>'archived' THEN RAISE EXCEPTION 'anna old %', r; END IF;

 -- Coach sendet mit Vorgabe (heute+7) und mit eigenem Datum; ungültige Daten werden abgelehnt; Zurückziehen nicht beim Senden
 PERFORM pg_temp.act(coach);
 -- Direkt über die Tabelle scheitert es für Coaches (Profile-RLS wie Produktion) → Senden über staff_send_feedback
 BEGIN INSERT INTO public.boxer_coach_feedback(boxer_id,coach_id,title,message) VALUES (annaP,coachP,'x','y'); RAISE EXCEPTION 'coach direct insert should fail (prod RLS)'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 r := public.staff_send_feedback(annaP,' Woche ','Jab doppeln'); f1 := (r->>'id')::uuid;
 IF r->>'status'<>'active' OR r->>'title'<>'Woche' OR r->>'coach'<>'Marco' THEN RAISE EXCEPTION 'send %', r; END IF;
 r := public.staff_send_feedback(annaP,'Monat','Kondition',today+30); f2 := (r->>'id')::uuid;
 BEGIN PERFORM public.staff_send_feedback(annaP,'x','y',today-1); RAISE EXCEPTION 'past'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.staff_send_feedback(annaP,'x','y',today+91); RAISE EXCEPTION 'far'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.staff_send_feedback(annaP,'  ','y'); RAISE EXCEPTION 'empty title'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.staff_send_feedback(coachP,'x','y'); RAISE EXCEPTION 'not a boxer'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM set_config('role','postgres',true);
 IF (SELECT coach_id FROM public.boxer_coach_feedback WHERE id=f1)<>coachP THEN RAISE EXCEPTION 'author = caller'; END IF;
 -- Admin kann weiterhin direkt einfügen (bisheriger Weg); Zurückziehen beim Einfügen wird ignoriert
 PERFORM pg_temp.act(owner);
 INSERT INTO public.boxer_coach_feedback(boxer_id,coach_id,title,message,withdrawn_at) VALUES (benP,ownerP,'Admin','Direkt',now()) RETURNING id INTO f3;
 PERFORM set_config('role','postgres',true);
 IF (SELECT withdrawn_at FROM public.boxer_coach_feedback WHERE id=f3) IS NOT NULL THEN RAISE EXCEPTION 'withdrawn on insert'; END IF;
 DELETE FROM public.boxer_coach_feedback WHERE id=f3;
 IF (SELECT visible_until FROM public.boxer_coach_feedback WHERE id=f1)<>today+7 OR (SELECT withdrawn_at FROM public.boxer_coach_feedback WHERE id=f2) IS NOT NULL THEN RAISE EXCEPTION 'insert defaults'; END IF;
 PERFORM pg_temp.act(anna);
 r := public.get_my_feedback();
 IF jsonb_array_length(r->'active')<>2 OR r->'active'->0->>'coach'<>'Marco' THEN RAISE EXCEPTION 'anna active %', r; END IF;

 -- Archivieren (gestern), Datum verlängern, Zurückziehen: Boxer sieht es nirgends mehr – auch nicht direkt über die Tabelle
 PERFORM pg_temp.act(coach);
 r := public.staff_update_feedback(f1, today-1, NULL);
 IF r->>'status'<>'archived' THEN RAISE EXCEPTION 'archive now'; END IF;
 r := public.staff_update_feedback(f2, NULL, true);
 IF r->>'status'<>'withdrawn' THEN RAISE EXCEPTION 'withdraw'; END IF;
 BEGIN PERFORM public.staff_update_feedback(f1, today-2, NULL); RAISE EXCEPTION 'too early'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.staff_update_feedback(f1, NULL, NULL); RAISE EXCEPTION 'nothing'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM pg_temp.act(anna);
 r := public.get_my_feedback();
 IF jsonb_array_length(r->'active')<>0 OR jsonb_array_length(r->'archived')<>2 OR r::text LIKE '%Kondition%' THEN RAISE EXCEPTION 'anna after %', r; END IF;
 IF EXISTS (SELECT 1 FROM public.boxer_coach_feedback WHERE id=f2) THEN RAISE EXCEPTION 'withdrawn visible via table'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.boxer_coach_feedback WHERE id=f1) THEN RAISE EXCEPTION 'archived must stay readable'; END IF;
 BEGIN PERFORM public.staff_update_feedback(f1, today+3, NULL); RAISE EXCEPTION 'boxer edits'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM pg_temp.act(ben);
 IF jsonb_array_length(public.get_my_feedback()->'active')<>1 OR EXISTS (SELECT 1 FROM public.boxer_coach_feedback WHERE boxer_id=annaP) THEN RAISE EXCEPTION 'ben sees only own'; END IF;

 -- Coach-Liste mit Status; nur Verfasser oder Admin dürfen ändern
 PERFORM pg_temp.act(coach);
 r := public.staff_list_feedback(NULL, 20);
 IF (SELECT count(*) FROM jsonb_array_elements(r) x WHERE x->>'status'='withdrawn')<>1 OR (SELECT (x->>'can_edit')::boolean FROM jsonb_array_elements(r) x WHERE x->>'title'='Alt') THEN RAISE EXCEPTION 'staff list %', r; END IF;
 IF jsonb_array_length(public.staff_list_feedback(annaP, 5))<>3 THEN RAISE EXCEPTION 'staff list boxer'; END IF;
 SELECT id INTO f1 FROM public.boxer_coach_feedback WHERE title='Alt';
 BEGIN PERFORM public.staff_update_feedback(f1, today+5, NULL); RAISE EXCEPTION 'not author'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM pg_temp.act(owner);
 IF public.staff_update_feedback(f1, today+5, NULL)->>'status'<>'active' THEN RAISE EXCEPTION 'admin reactivates'; END IF;
 IF public.staff_update_feedback(f2, NULL, false)->>'status'<>'active' THEN RAISE EXCEPTION 'restore withdrawn'; END IF;
 PERFORM pg_temp.act(anna);
 IF jsonb_array_length(public.get_my_feedback()->'active')<>2 THEN RAISE EXCEPTION 'anna restored'; END IF;
 -- Flag aus
 PERFORM set_config('role','postgres',true);
 UPDATE public.league_feature_flags SET is_enabled=false WHERE feature_key='coach_feedback';
 PERFORM pg_temp.act(anna);
 IF (public.get_my_feedback()->>'enabled')::boolean THEN RAISE EXCEPTION 'flag off'; END IF;
 PERFORM pg_temp.act(coach);
 BEGIN PERFORM public.staff_update_feedback(f2, NULL, true); RAISE EXCEPTION 'flag off edit'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM set_config('role','postgres',true);
 UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='coach_feedback';
 RAISE NOTICE 'PASS: Etappe 6b Feedback – sichtbar bis (7 Tage Vorgabe, max. 90), Archiv, sofort archivieren, Zurückziehen (auch über die Tabelle unsichtbar), Wiederherstellen, nur Verfasser/Admin, bestehende Inhalte unverändert';
END $t$;

\ir ../supabase/production-prep/rollback_20261028240000_feedback_visibility.sql
DO $r$ BEGIN
 IF to_regprocedure('public.get_my_feedback()') IS NOT NULL OR to_regprocedure('public.staff_send_feedback(uuid,text,text,date)') IS NOT NULL OR EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='league_feedback_insert_guard') THEN RAISE EXCEPTION 'rollback left objects'; END IF;
 IF (SELECT count(*) FROM public.boxer_coach_feedback)<>4 THEN RAISE EXCEPTION 'rollback kept data'; END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname='feedback_select_enabled' AND qual NOT LIKE '%withdrawn%') THEN RAISE EXCEPTION 'policy restored'; END IF;
 RAISE NOTICE 'PASS: Rollback 6b Feedback stellt Policy her und behält Daten';
END $r$;
\ir ../supabase/migrations/20261028240000_feedback_visibility.sql
DO $a$ BEGIN IF to_regprocedure('public.get_my_feedback()') IS NULL THEN RAISE EXCEPTION 'reapply'; END IF; RAISE NOTICE 'PASS: Migration 6b nach Rollback erneut anwendbar'; END $a$;
