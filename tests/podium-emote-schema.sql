\set ON_ERROR_STOP on
-- Disposable-database test for 20261029130000_podium_emote.sql (Etappe 8) inkl. Rollback. Fixture wie card-designs-schema.sql (Etappen 1 bis 5).
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
\ir ../supabase/migrations/20261028200000_weekly_quests.sql
CREATE FUNCTION pg_temp.act(p text) RETURNS void LANGUAGE plpgsql AS $fn$ BEGIN
 PERFORM set_config('role','postgres',true);
 IF p IS NULL THEN PERFORM set_config('request.jwt.claim.sub','',true); PERFORM set_config('role','anon',true);
 ELSE PERFORM set_config('request.jwt.claim.sub',p,true); PERFORM set_config('role','authenticated',true); END IF;
END $fn$;
GRANT EXECUTE ON FUNCTION pg_temp.act(text) TO authenticated, anon;
\ir ../supabase/migrations/20261028210000_kampfgeist_shop.sql
\ir ../supabase/migrations/20261028210000_kampfgeist_shop.sql
ALTER TABLE public.league_duels ADD COLUMN settled_at timestamptz, ADD COLUMN winner_id uuid;
CREATE FUNCTION public.get_public_leaderboard() RETURNS TABLE(rank_position bigint, boxer_name text, monthly_points bigint, lifetime_exp bigint)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT row_number() OVER (ORDER BY coalesce(sum(t.points) FILTER (WHERE t.effective_date>=date_trunc('month',current_date)),0) DESC, p.display_name),
  p.display_name, coalesce(sum(t.points) FILTER (WHERE t.effective_date>=date_trunc('month',current_date)),0)::bigint, coalesce(sum(t.exp),0)::bigint
 FROM public.profiles p LEFT JOIN public.point_transactions t ON t.boxer_id=p.id
 WHERE p.role IN ('boxer','coach') AND p.is_active AND p.is_listed AND p.archived_at IS NULL GROUP BY p.id, p.display_name $fn$;
GRANT EXECUTE ON FUNCTION public.get_public_leaderboard() TO anon, authenticated;
\ir ../supabase/migrations/20261028220000_kampfgeist_etappe5.sql
\ir ../supabase/migrations/20261028220000_kampfgeist_etappe5.sql
\ir ../supabase/migrations/20261029130000_podium_emote.sql
\ir ../supabase/migrations/20261029130000_podium_emote.sql

DO $t$ DECLARE r jsonb; today date := (now() AT TIME ZONE 'Europe/Zurich')::date; ev bigint; eq0 text;
 owner text := '10000000-0000-0000-0000-00000000000a'; anna text := '10000000-0000-0000-0000-000000000001';
 ben text := '10000000-0000-0000-0000-000000000002'; bob text := '10000000-0000-0000-0000-000000000003';
 annaP uuid := '00000000-0000-0000-0000-000000000001'; benP uuid := '00000000-0000-0000-0000-000000000002'; bobP uuid := '00000000-0000-0000-0000-000000000003';
BEGIN
 -- Rechte
 IF has_function_privilege('anon','public.set_podium_emote(boolean,text)','EXECUTE') OR has_function_privilege('anon','public.get_podium_kampfgeist()','EXECUTE') THEN RAISE EXCEPTION 'anon'; END IF;
 IF NOT has_function_privilege('authenticated','public.set_podium_emote(boolean,text)','EXECUTE') THEN RAISE EXCEPTION 'grant'; END IF;
 IF has_table_privilege('authenticated','public.kg_equipped','UPDATE') THEN RAISE EXCEPTION 'table grant'; END IF;
 -- Podium-Daten: Anna 300, Ben 200, Bob 100 Monatspunkte; Ben hat schon ein ausgewähltes Emote (bleibt erhalten, aber aus)
 PERFORM set_config('role','postgres',true);
 INSERT INTO public.point_transactions(boxer_id,points,exp,category,description,effective_date) VALUES
  (annaP,300,0,'adjustment','Podium',today),(benP,200,0,'adjustment','Podium',today),(bobP,100,0,'adjustment','Podium',today);
 INSERT INTO public.kg_equipped(profile_id,emote) VALUES (benP,'m_gg');
 INSERT INTO public.kg_emote_events(sender_id,context,target_id,month,emote_key) VALUES (bobP,'podium',annaP,date_trunc('month',today)::date,'m_gg') RETURNING id INTO ev;
 SELECT string_agg(x::text,'|' ORDER BY profile_id) INTO eq0 FROM (SELECT profile_id,emote FROM public.kg_equipped) x;

 -- Flag aus: Boxer sieht nichts und kann nichts einstellen; Admin hat Vorschau
 PERFORM pg_temp.act(anna);
 IF (public.get_podium_kampfgeist()->>'enabled')::boolean THEN RAISE EXCEPTION 'visible flag off'; END IF;
 BEGIN PERFORM public.set_podium_emote(true,NULL); RAISE EXCEPTION 'set off'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM pg_temp.act(owner);
 IF NOT (public.get_podium_kampfgeist()->>'preview')::boolean THEN RAISE EXCEPTION 'admin preview'; END IF;
 PERFORM set_config('role','postgres',true);
 UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='kampfgeist_shop';

 -- Standard: niemand zeigt ein Emote, keine Reaktionen/Look mehr in der Antwort
 PERFORM pg_temp.act(anna);
 r := public.get_podium_kampfgeist();
 IF jsonb_array_length(r->'places')<>3 OR r->'places'->0->>'name'<>'Anna' OR NOT (r->'places'->0->>'is_me')::boolean THEN RAISE EXCEPTION 'places %', r; END IF;
 IF (r->>'my_show')::boolean OR EXISTS (SELECT 1 FROM jsonb_array_elements(r->'places') p WHERE (p->>'show_emote')::boolean OR jsonb_typeof(p->'emote')<>'null') THEN RAISE EXCEPTION 'default off %', r; END IF;
 IF r::text LIKE '%reactions%' OR r::text LIKE '%"look"%' OR r::text LIKE '%Marco%' THEN RAISE EXCEPTION 'no reactions/look %', r; END IF;
 IF jsonb_array_length(r->'my_emotes')<1 OR r->'my_emote'->>'key'<>'m_respekt' THEN RAISE EXCEPTION 'my emotes %', r; END IF;

 -- Anna schaltet ein (Standard-Emote), dann mit eigenem Emote; fremdes/nicht eigenes/falsche Kategorie geht nicht
 r := public.set_podium_emote(true,NULL);
 IF NOT (r->>'show')::boolean OR r->'emote'->>'key'<>'m_respekt' THEN RAISE EXCEPTION 'on default %', r; END IF;
 r := public.set_podium_emote(true,'m_gg');
 IF r->'emote'->>'key'<>'m_gg' THEN RAISE EXCEPTION 'on gg %', r; END IF;
 BEGIN PERFORM public.set_podium_emote(true,'m_legende'); RAISE EXCEPTION 'not owned'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.set_podium_emote(true,'a_kenji'); RAISE EXCEPTION 'not emote'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.set_podium_emote(true,'gibts_nicht'); RAISE EXCEPTION 'unknown'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.set_podium_emote(NULL,NULL); RAISE EXCEPTION 'null'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;

 -- Ben sieht Annas Emote, sein eigenes (ausgewählt, aber aus) nicht
 PERFORM pg_temp.act(ben);
 r := public.get_podium_kampfgeist();
 IF NOT (r->'places'->0->>'show_emote')::boolean OR r->'places'->0->'emote'->>'key'<>'m_gg' THEN RAISE EXCEPTION 'ben sees anna %', r; END IF;
 IF (r->'places'->1->>'show_emote')::boolean OR jsonb_typeof(r->'places'->1->'emote')<>'null' OR NOT (r->'places'->1->>'is_me')::boolean THEN RAISE EXCEPTION 'ben own off %', r; END IF;

 -- Anna schaltet aus: Emote verschwindet, Auswahl bleibt gespeichert
 PERFORM pg_temp.act(anna);
 r := public.set_podium_emote(false,NULL);
 IF (r->>'show')::boolean OR r->'emote'->>'key'<>'m_gg' THEN RAISE EXCEPTION 'off %', r; END IF;
 PERFORM pg_temp.act(bob);
 r := public.get_podium_kampfgeist();
 IF (r->'places'->0->>'show_emote')::boolean OR jsonb_typeof(r->'places'->0->'emote')<>'null' THEN RAISE EXCEPTION 'hidden %', r; END IF;

 -- Bestehende Daten: Bens Auswahl und die alte Reaktion unverändert
 PERFORM set_config('role','postgres',true);
 IF (SELECT emote FROM public.kg_equipped WHERE profile_id=benP)<>'m_gg' OR NOT EXISTS (SELECT 1 FROM public.kg_emote_events WHERE id=ev AND hidden_at IS NULL) THEN RAISE EXCEPTION 'data changed'; END IF;
 RAISE NOTICE 'PASS: Podium-Emote (Etappe 8) – Standard aus, eigenes Emote wählen, nur eigene Emotes, aus = unsichtbar, keine Reaktionen/Looks, Flag aus nur Admin-Vorschau';
END $t$;

-- Rollback: alte Podium-Funktion (mit Reaktionen) zurück, Spalte und neue Funktion weg, Daten bleiben
\ir ../supabase/production-prep/rollback_20261029130000_podium_emote.sql
DO $r$ BEGIN
 IF to_regprocedure('public.set_podium_emote(boolean,text)') IS NOT NULL
    OR EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='kg_equipped' AND column_name='podium_emote') THEN RAISE EXCEPTION 'rollback incomplete'; END IF;
 IF pg_get_functiondef('public.get_podium_kampfgeist()'::regprocedure) NOT LIKE '%reactions%' THEN RAISE EXCEPTION 'old podium not restored'; END IF;
 IF (SELECT count(*) FROM public.kg_emote_events WHERE context='podium')<>1 OR (SELECT count(*) FROM public.kg_equipped)<2 THEN RAISE EXCEPTION 'rollback lost data'; END IF;
 RAISE NOTICE 'PASS: Rollback Podium-Emote';
END $r$;
-- Erneut einspielen (idempotent nach Rollback)
\ir ../supabase/migrations/20261029130000_podium_emote.sql
