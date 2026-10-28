\set ON_ERROR_STOP on
-- Disposable-database test for 20261029120000_card_designs_awards.sql (Etappe 7d) inkl. Rollback. Fixture wie kampfgeist-etappe5-schema.sql
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
ALTER TABLE public.boxer_notifications ADD COLUMN notification_type text, ADD COLUMN message text, ADD COLUMN target_path text;
-- Bestätigte Trainings: letzte Woche Anna 120 EXP, Ben 90; diesen Monat/Jahr ebenso. Ben hat dazu viele alte EXP (Rang D).
DO $s$ DECLARE today date := (now() AT TIME ZONE 'Europe/Zurich')::date; lw date; s uuid; t bigint := (SELECT id FROM public.training_types WHERE name='Reguläres Boxtraining');
 b record;
BEGIN
 lw := today - (extract(isodow FROM today)::integer-1) - 7;  -- Montag letzte Woche
 FOR b IN SELECT * FROM (VALUES ('00000000-0000-0000-0000-000000000001'::uuid,lw,60),('00000000-0000-0000-0000-000000000001'::uuid,lw+2,60),
   ('00000000-0000-0000-0000-000000000002'::uuid,lw+1,90),('00000000-0000-0000-0000-000000000004'::uuid,lw+1,500)) v(p,d,x) LOOP
  INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes) VALUES (b.p,t,b.d,'Sparring im Gym','approved',90) RETURNING id INTO s;
  INSERT INTO public.point_transactions(boxer_id,submission_id,points,exp,category,effective_date) VALUES (b.p,s,b.x,b.x,'training',b.d);
 END LOOP;
 INSERT INTO public.point_transactions(boxer_id,points,exp,category,effective_date) VALUES ('00000000-0000-0000-0000-000000000002',0,9000,'bonus','2025-06-01');
END $s$;
CREATE TEMP TABLE ref AS SELECT (SELECT count(*)||'/'||coalesce(sum(exp),0) FROM public.point_transactions) pt, (SELECT count(*) FROM public.training_submissions) ts;
GRANT SELECT ON ref TO authenticated;
\ir ../supabase/production-prep/preflight_20261029120000_card_designs_awards.sql
\ir ../supabase/migrations/20261029120000_card_designs_awards.sql
\ir ../supabase/migrations/20261029120000_card_designs_awards.sql

DO $t$ DECLARE r jsonb; today date := (now() AT TIME ZONE 'Europe/Zurich')::date; lw date; cw date; lm date; aw bigint; n int;
 owner text := '10000000-0000-0000-0000-00000000000a'; coach text := '10000000-0000-0000-0000-00000000000c';
 anna text := '10000000-0000-0000-0000-000000000001'; ben text := '10000000-0000-0000-0000-000000000002'; bob text := '10000000-0000-0000-0000-000000000003';
 annaP uuid := '00000000-0000-0000-0000-000000000001'; benP uuid := '00000000-0000-0000-0000-000000000002'; bobP uuid := '00000000-0000-0000-0000-000000000003';
 coachP uuid := '00000000-0000-0000-0000-00000000000c';
BEGIN
 cw := today - (extract(isodow FROM today)::integer-1); lw := cw-7; lm := (date_trunc('month',today)-interval '1 month')::date;
 IF (SELECT count(*) FROM public.card_designs)<>13 THEN RAISE EXCEPTION 'designs'; END IF;
 IF has_table_privilege('authenticated','public.card_awards','SELECT') OR has_function_privilege('anon','public.get_my_card_designs()','EXECUTE')
  OR has_function_privilege('authenticated','league_private.card_look(uuid)','EXECUTE') THEN RAISE EXCEPTION 'rights'; END IF;
 IF league_private.card_period('cotw',DATE '2026-10-28')<>daterange('2026-10-26','2026-11-01','[]') OR league_private.card_period('cotm',DATE '2026-02-10')<>daterange('2026-02-01','2026-02-28','[]')
  OR league_private.card_period('poty',DATE '2026-10-28')<>daterange('2026-01-01','2026-12-31','[]') THEN RAISE EXCEPTION 'periods'; END IF;

 -- Flag aus: Boxer sieht nichts, Trainer/Admin Vorschau
 PERFORM pg_temp.act(anna);
 IF (public.get_my_card_designs()->>'enabled')::boolean OR (public.get_card_awards()->>'enabled')::boolean OR public.get_card_looks(ARRAY['Anna'])<>'{}'::jsonb THEN RAISE EXCEPTION 'flag off visible'; END IF;
 BEGIN PERFORM public.equip_card_design('classic'); RAISE EXCEPTION 'equip flag off'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM set_config('role','postgres',true);
 UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='card_designs';

 -- Designs: Rang-Freischaltung (Anna F, Ben D), Shop nur mit Shop-Flag und Coins
 PERFORM pg_temp.act(anna);
 r := public.get_my_card_designs();
 IF r->>'rank'<>'F' OR (SELECT count(*) FROM jsonb_array_elements(r->'designs') d WHERE (d->>'available')::boolean)<>1 OR r->'look'->>'key'<>'classic' OR (r->>'shop')::boolean THEN RAISE EXCEPTION 'anna designs %', r; END IF;
 BEGIN PERFORM public.equip_card_design('ocean'); RAISE EXCEPTION 'locked equip'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.equip_card_design('cotw'); RAISE EXCEPTION 'award equip'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.buy_card_design('neon'); RAISE EXCEPTION 'buy without shop'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM pg_temp.act(ben);
 r := public.get_my_card_designs();
 IF r->>'rank'<>'D' OR (SELECT string_agg(d->>'key',',' ORDER BY d->>'key') FROM jsonb_array_elements(r->'designs') d WHERE (d->>'available')::boolean)<>'carbon,classic,ocean' THEN RAISE EXCEPTION 'ben designs %', r; END IF;
 r := public.equip_card_design('ocean');IF r->>'key'<>'ocean' THEN RAISE EXCEPTION 'equip ocean'; END IF;
 BEGIN PERFORM public.equip_card_design('ember'); RAISE EXCEPTION 'rank C locked'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM set_config('role','postgres',true);
 UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='kampfgeist_shop';
 PERFORM pg_temp.act(ben);
 r := public.get_my_card_designs(); -- kg_sync not run yet: balance from ledger
 BEGIN PERFORM public.buy_card_design('ocean'); RAISE EXCEPTION 'buy rank design'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM set_config('role','postgres',true);
 INSERT INTO public.kg_ledger(profile_id,amount,reason,ref,note) VALUES (benP,450,'admin','test-450','Test');
 PERFORM pg_temp.act(ben);
 BEGIN PERFORM public.buy_card_design('thunder'); RAISE EXCEPTION 'too expensive'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 r := public.buy_card_design('neon');
 IF (r->>'price')::int<>400 THEN RAISE EXCEPTION 'buy %', r; END IF;
 BEGIN PERFORM public.buy_card_design('neon'); RAISE EXCEPTION 'buy twice'; EXCEPTION WHEN unique_violation THEN NULL; END;
 IF (public.equip_card_design('neon')->>'key')<>'neon' THEN RAISE EXCEPTION 'equip bought'; END IF;
 PERFORM set_config('role','postgres',true);
 IF NOT EXISTS (SELECT 1 FROM public.kg_ledger WHERE profile_id=benP AND reason='purchase' AND ref='card:neon' AND amount=-400) THEN RAISE EXCEPTION 'ledger'; END IF;

 -- Looks für andere: nur sichtbare Profile
 PERFORM set_config('role','postgres',true);
 UPDATE public.profiles SET is_listed=false WHERE id=bobP;
 PERFORM pg_temp.act(anna);
 r := public.get_card_looks(ARRAY['Ben','bob',' anna ','Niemand']);
 IF r->'Ben'->>'key'<>'neon' OR r ? 'Bob' OR r->'Anna'->>'key'<>'classic' THEN RAISE EXCEPTION 'looks %', r; END IF;

 -- Auszeichnungen: Vorschlag + Bestätigung
 PERFORM pg_temp.act(anna);
 BEGIN PERFORM public.staff_card_award_overview(); RAISE EXCEPTION 'boxer overview'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.staff_confirm_card_award('cotw',lw,annaP); RAISE EXCEPTION 'boxer awards'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM pg_temp.act(coach);
 r := public.staff_card_award_overview();
 IF (SELECT p->'candidates'->0->>'display_name' FROM jsonb_array_elements(r->'kinds') k, jsonb_array_elements(k->'periods') p WHERE k->>'kind'='cotw' AND (p->>'completed')::boolean)<>'Anna'
  OR (SELECT (p->'candidates'->0->>'exp')::int FROM jsonb_array_elements(r->'kinds') k, jsonb_array_elements(k->'periods') p WHERE k->>'kind'='cotw' AND (p->>'completed')::boolean)<>120
  OR (SELECT jsonb_array_length(p->'candidates') FROM jsonb_array_elements(r->'kinds') k, jsonb_array_elements(k->'periods') p WHERE k->>'kind'='cotw' AND (p->>'completed')::boolean)<>2
  THEN RAISE EXCEPTION 'suggestion (archived Alt excluded) %', r; END IF;
 BEGIN PERFORM public.staff_confirm_card_award('cotw',cw,annaP); RAISE EXCEPTION 'running week'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.staff_confirm_card_award('cotw',lw+1,annaP); RAISE EXCEPTION 'not monday'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.staff_confirm_card_award('cotw',lw-77,annaP); RAISE EXCEPTION 'too old'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.staff_confirm_card_award('cotw',lw,coachP); RAISE EXCEPTION 'self'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.staff_confirm_card_award('cotw',lw,'00000000-0000-0000-0000-000000000004'); RAISE EXCEPTION 'archived'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 r := public.staff_confirm_card_award('cotw',lw,annaP,'Zwei starke Sparrings');aw := (r->>'id')::bigint;
 IF r->>'display_name'<>'Anna' OR (r->>'exp')::int<>120 OR (r->>'period_end')::date<>lw+6 THEN RAISE EXCEPTION 'award %', r; END IF;
 BEGIN PERFORM public.staff_confirm_card_award('cotw',lw,benP); RAISE EXCEPTION 'two per week'; EXCEPTION WHEN unique_violation THEN NULL; END;
 PERFORM set_config('role','postgres',true);
 IF NOT EXISTS (SELECT 1 FROM public.boxer_notifications WHERE recipient_id=annaP AND notification_type='achievement' AND title='Card of the Week!' AND target_path='/karten.html') THEN RAISE EXCEPTION 'notification'; END IF;
 -- Anna kann das Design nutzen, alle sehen die Auszeichnung
 PERFORM pg_temp.act(anna);
 IF (public.equip_card_design('cotw')->>'key')<>'cotw' THEN RAISE EXCEPTION 'anna equips cotw'; END IF;
 PERFORM pg_temp.act(ben);
 r := public.get_card_awards();
 IF r->'latest'->'cotw'->>'display_name'<>'Anna' OR r->'latest'->'cotw'->'look'->>'key'<>'cotw' OR jsonb_array_length(r->'history')<>1 OR r->'latest'->'cotm'<>'null'::jsonb THEN RAISE EXCEPTION 'awards %', r; END IF;
 -- Zurücknehmen: nur Verfasser/Admin, mit Grund; Design fällt auf Klassisch zurück
 PERFORM pg_temp.act(owner);
 BEGIN PERFORM public.staff_revoke_card_award(aw,'  '); RAISE EXCEPTION 'no reason'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 r := public.staff_revoke_card_award(aw,'Falsche Woche');IF NOT (r->>'revoked')::boolean THEN RAISE EXCEPTION 'revoke'; END IF;
 PERFORM pg_temp.act(anna);
 IF (public.get_my_card_designs()->'look'->>'key')<>'classic' THEN RAISE EXCEPTION 'falls back to classic'; END IF;
 IF jsonb_array_length(public.get_card_awards()->'history')<>0 THEN RAISE EXCEPTION 'revoked hidden'; END IF;
 PERFORM pg_temp.act(owner);
 r := public.staff_confirm_card_award('cotw',lw,benP);  -- nach Rücknahme neu vergeben
 r := public.staff_confirm_card_award('cotm',lm,annaP);
 PERFORM set_config('role','postgres',true);
 IF (SELECT count(*) FROM public.card_awards)<>3 OR (SELECT count(*) FROM public.card_awards WHERE revoked_at IS NULL)<>2 THEN RAISE EXCEPTION 'award rows'; END IF;
 IF (SELECT pt FROM ref)<>(SELECT count(*)||'/'||coalesce(sum(exp),0) FROM public.point_transactions) THEN RAISE EXCEPTION 'points changed'; END IF;
 RAISE NOTICE 'PASS: Etappe 7d – 13 Designs (Rang, Shop mit Coins, Auszeichnung), Flag, Looks nur sichtbarer Profile, Vorschlag aus bestätigten EXP (Archivierte ausgenommen), Bestätigen nur nach Ende, nicht sich selbst, eine pro Zeitraum, Benachrichtigung, Zurücknehmen mit Grund, Punkte unverändert';
END $t$;
\ir ../supabase/production-prep/postflight_20261029120000_card_designs_awards.sql
\ir ../supabase/production-prep/rollback_20261029120000_card_designs_awards.sql
DO $r$ BEGIN
 IF to_regprocedure('public.get_my_card_designs()') IS NOT NULL OR (SELECT count(*) FROM public.card_awards)<>3 OR (SELECT count(*) FROM public.card_design_purchases)<>1 THEN RAISE EXCEPTION 'rollback'; END IF;
 RAISE NOTICE 'PASS: Rollback 7d entfernt RPCs, Designs, Käufe und Auszeichnungen bleiben';
END $r$;
\ir ../supabase/migrations/20261029120000_card_designs_awards.sql
DO $a$ BEGIN IF to_regprocedure('public.get_my_card_designs()') IS NULL OR (SELECT count(*) FROM public.card_designs)<>13 THEN RAISE EXCEPTION 'reapply'; END IF; RAISE NOTICE 'PASS: Migration 7d nach Rollback erneut anwendbar'; END $a$;
