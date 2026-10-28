\set ON_ERROR_STOP on
-- Disposable-database test for 20261028230000_club_schedule_tiers.sql (+ Aktivierung, Rücknahme, Rollback). Fixture wie kampfgeist-etappe5-schema.sql (Etappen 1 bis 5)
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
-- Produktionsnähe: genau eine Punktebuchung pro Training, created_at, Änderungshistorie und admin_edit_training wie Produktion.
ALTER TABLE public.point_transactions ADD COLUMN created_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE public.point_transactions ADD CONSTRAINT point_transactions_submission_id_key UNIQUE (submission_id);
CREATE TABLE public.training_audit(id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, submission_id uuid NOT NULL, changed_by uuid NOT NULL,
 changed_at timestamptz NOT NULL DEFAULT now(), old_submission jsonb NOT NULL, new_submission jsonb NOT NULL, old_transaction jsonb, new_transaction jsonb);
GRANT INSERT, SELECT ON public.training_submissions TO authenticated;
CREATE OR REPLACE FUNCTION public.admin_edit_training(p_submission_id uuid, p_boxer_id uuid, p_training_type_id bigint, p_training_date date, p_notes text, p_status text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $function$
DECLARE
 v_admin public.profiles%rowtype;
 v_old public.training_submissions%rowtype;
 v_new public.training_submissions%rowtype;
 v_old_tx jsonb;
 v_new_tx jsonb;
 v_points integer;
 v_tx_id uuid;
BEGIN
 SELECT * INTO v_admin FROM public.profiles
 WHERE auth_user_id=(SELECT auth.uid()) AND role IN ('admin','coach') AND is_active=true;
 IF NOT FOUND THEN RAISE EXCEPTION 'Nur aktive Trainer dürfen Trainings bearbeiten'; END IF;
 IF p_status NOT IN ('pending','approved','rejected') OR p_status IS NULL THEN
  RAISE EXCEPTION 'Ungültiger Status';
 END IF;
 IF p_boxer_id IS NULL OR p_training_type_id IS NULL OR p_training_date IS NULL THEN
  RAISE EXCEPTION 'Boxer, Trainingsart und Datum sind erforderlich';
 END IF;
 PERFORM 1 FROM public.profiles WHERE id=p_boxer_id AND role IN ('boxer','coach');
 IF NOT FOUND THEN RAISE EXCEPTION 'Boxer nicht gefunden'; END IF;
 SELECT points INTO v_points FROM public.training_types
 WHERE id=p_training_type_id AND is_active=true;
 IF NOT FOUND OR v_points IS NULL OR v_points<0 THEN
  RAISE EXCEPTION 'Trainingsart ungültig oder inaktiv';
 END IF;

 SELECT * INTO v_old FROM public.training_submissions
 WHERE id=p_submission_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Training nicht gefunden'; END IF;

 SELECT id INTO v_tx_id FROM public.point_transactions
 WHERE submission_id=p_submission_id ORDER BY created_at LIMIT 1 FOR UPDATE;
 SELECT to_jsonb(t) INTO v_old_tx FROM public.point_transactions t WHERE id=v_tx_id;
 IF (SELECT count(*) FROM public.point_transactions WHERE submission_id=p_submission_id)>1 THEN
  RAISE EXCEPTION 'Mehrere Punktebuchungen vorhanden: manuelle Prüfung erforderlich';
 END IF;

 UPDATE public.training_submissions SET
 boxer_id=p_boxer_id, training_type_id=p_training_type_id,
 training_date=p_training_date, notes=p_notes,
 status=p_status,
 reviewed_by=CASE WHEN p_status='pending' THEN null ELSE v_admin.id END,
 reviewed_at=CASE WHEN p_status='pending' THEN null ELSE now() END
 WHERE id=p_submission_id RETURNING * INTO v_new;

 IF v_tx_id IS NOT NULL THEN
  UPDATE public.point_transactions SET
   boxer_id=p_boxer_id,
   points=CASE WHEN p_status='approved' THEN v_points ELSE 0 END,
   exp=CASE WHEN p_status='approved' THEN v_points ELSE 0 END,
   effective_date=p_training_date,
   created_by=v_admin.id,
   description=CASE WHEN p_status='approved' THEN 'Training (admin-korrigiert)' ELSE 'Training (widerrufen)' END
  WHERE id=v_tx_id;
 ELSIF p_status='approved' THEN
  INSERT INTO public.point_transactions
  (boxer_id,submission_id,points,exp,category,description,effective_date,created_by)
  VALUES (p_boxer_id,p_submission_id,v_points,v_points,'training',
          'Training (admin-korrigiert)',p_training_date,v_admin.id)
  RETURNING id INTO v_tx_id;
 END IF;
 SELECT to_jsonb(t) INTO v_new_tx FROM public.point_transactions t WHERE id=v_tx_id;
 INSERT INTO public.training_audit
 (submission_id,changed_by,old_submission,new_submission,old_transaction,new_transaction)
 VALUES (p_submission_id,v_admin.id,to_jsonb(v_old),to_jsonb(v_new),v_old_tx,v_new_tx);

 -- Recalculate both sides of a transfer, and the affected dates/streaks.
 IF v_admin.role='coach' THEN
  PERFORM league_private.coach_training_bonus_refresh(v_old.boxer_id);
 ELSE
  PERFORM public.recalculate_boxer_bonuses(v_old.boxer_id);
 END IF;
 IF v_old.boxer_id IS DISTINCT FROM p_boxer_id THEN
  IF v_admin.role='coach' THEN
   PERFORM league_private.coach_training_bonus_refresh(p_boxer_id);
  ELSE
   PERFORM public.recalculate_boxer_bonuses(p_boxer_id);
  END IF;
 END IF;

 RETURN jsonb_build_object('status',p_status,
  'points',CASE WHEN p_status='approved' THEN v_points ELSE 0 END);
END;
$function$;
GRANT EXECUTE ON FUNCTION public.admin_edit_training(uuid,uuid,bigint,date,text,text) TO authenticated;
\ir ../supabase/migrations/20261028230000_club_schedule_tiers.sql
\ir ../supabase/migrations/20261028230000_club_schedule_tiers.sql

DO $t$ DECLARE r jsonb; q jsonb; today date := (now() AT TIME ZONE 'Europe/Zurich')::date; ws date; n int; sid bigint; slot int; sub uuid; mk uuid;
 h1 uuid; h2 uuid; h3 uuid; h4 uuid; h5 uuid; h6 uuid; h7 uuid; h8 uuid;
 reg bigint; tech bigint; kraft bigint; sprint bigint; jog bigint; spar bigint; pratzen bigint; tsp bigint; schatten bigint;
 owner text := '10000000-0000-0000-0000-00000000000a'; coach text := '10000000-0000-0000-0000-00000000000c';
 anna text := '10000000-0000-0000-0000-000000000001'; ben text := '10000000-0000-0000-0000-000000000002'; bob text := '10000000-0000-0000-0000-000000000003';
 ownerP uuid := '00000000-0000-0000-0000-00000000000a'; coachP uuid := '00000000-0000-0000-0000-00000000000c';
 annaP uuid := '00000000-0000-0000-0000-000000000001'; benP uuid := '00000000-0000-0000-0000-000000000002'; bobP uuid := '00000000-0000-0000-0000-000000000003';
BEGIN
 ws := today - (extract(isodow FROM today)::int - 1) - 7;   -- Montag der Vorwoche
 SELECT id INTO reg FROM public.training_types WHERE name='Reguläres Boxtraining';
 SELECT id INTO tech FROM public.training_types WHERE name='Techniktraining';
 SELECT id INTO kraft FROM public.training_types WHERE name='Krafttraining';
 SELECT id INTO sprint FROM public.training_types WHERE name='Sprint-Intervalle';
 SELECT id INTO jog FROM public.training_types WHERE name='Joggen';
 SELECT id INTO spar FROM public.training_types WHERE name='Wettkampfsparring';
 SELECT id INTO pratzen FROM public.training_types WHERE name='Pratzentraining';
 SELECT id INTO tsp FROM public.training_types WHERE name='Technisches Sparring';
 SELECT id INTO schatten FROM public.training_types WHERE name='Schattenboxen / Heimtraining';

 -- Struktur und Rechte
 IF (SELECT string_agg(dow::text||coalesce(tier,'-'),',' ORDER BY dow) FROM public.club_schedule)<>'1pflicht,2ergaenzung,3pflicht,4ergaenzung,6pflicht' THEN RAISE EXCEPTION 'schedule seed'; END IF;
 IF (SELECT count(*) FROM public.club_schedule)<>5 THEN RAISE EXCEPTION 'schedule idempotent'; END IF;
 IF (SELECT count(*) FROM public.training_types WHERE club_only)<>5 OR (SELECT is_active FROM public.training_types WHERE id=tsp) THEN RAISE EXCEPTION 'types'; END IF;
 IF (SELECT points FROM public.training_types WHERE id=reg)<>50 THEN RAISE EXCEPTION 'points unchanged by migration'; END IF;
 IF has_function_privilege('anon','public.get_club_schedule()','EXECUTE') OR has_function_privilege('anon','public.staff_update_gym_session(bigint,bigint,text)','EXECUTE') THEN RAISE EXCEPTION 'anon'; END IF;
 IF has_function_privilege('authenticated','league_private.activate_club_tiers(uuid)','EXECUTE') OR has_function_privilege('authenticated','league_private.apply_training_value(uuid,uuid,text,jsonb)','EXECUTE') THEN RAISE EXCEPTION 'helpers'; END IF;
 IF has_table_privilege('authenticated','public.club_schedule','SELECT') OR has_table_privilege('authenticated','public.club_tiers','SELECT') THEN RAISE EXCEPTION 'table grant'; END IF;

 -- Historische Trainings von Anna (vom Coach bestätigt, Punkte wie bisher)
 PERFORM set_config('role','postgres',true); PERFORM set_config('request.jwt.claim.sub','',true);
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes,jogging_km) VALUES
  (annaP,reg,ws,'Training Mo','pending',90,NULL) RETURNING id INTO h1;
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes) VALUES (annaP,reg,ws+1,'Training Di','pending',90) RETURNING id INTO h2;
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes) VALUES (annaP,tech,ws+4,'Training Fr','pending',60) RETURNING id INTO h3;
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes) VALUES (annaP,kraft,ws+3,'Kraft Do','pending',60) RETURNING id INTO h4;
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes) VALUES (annaP,sprint,ws+2,'Sprints','pending',30) RETURNING id INTO h5;
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes,jogging_km) VALUES (annaP,jog,ws+5,'Joggen','pending',30,5) RETURNING id INTO h6;
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes) VALUES (annaP,spar,ws,'Sparring','pending',60) RETURNING id INTO h7;
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes) VALUES (annaP,reg,DATE '2026-02-02','Alte Saison','pending',90) RETURNING id INTO h8;
 PERFORM pg_temp.act(coach);
 PERFORM public.review_training(x,'approved') FROM unnest(ARRAY[h1,h2,h3,h4,h5,h6,h7,h8]) x;
 PERFORM set_config('role','postgres',true);
 IF (SELECT string_agg(t.points::text,',' ORDER BY u.o) FROM unnest(ARRAY[h1,h2,h3,h4,h5,h6,h7,h8]) WITH ORDINALITY u(x,o) JOIN public.point_transactions t ON t.submission_id=u.x)
    <>'50,50,40,30,40,20,70,50' THEN RAISE EXCEPTION 'base points'; END IF;

 -- Flag aus: Boxer reichen Vereinsarten wie bisher ein; Stufe und «eingetragen von» lassen sich nicht selbst setzen
 PERFORM pg_temp.act(anna);
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes,club_tier,recorded_by)
 VALUES (annaP,reg,today,'Selbst gemeldet','pending',60,'pflicht',coachP) RETURNING id INTO sub;
 PERFORM set_config('role','postgres',true);
 IF (SELECT club_tier IS NOT NULL OR recorded_by IS NOT NULL FROM public.training_submissions WHERE id=sub) THEN RAISE EXCEPTION 'guard tier/recorded_by'; END IF;
 DELETE FROM public.training_submissions WHERE id=sub;

 -- Aktivierung (wie Produktionsskript)
 PERFORM set_config('request.jwt.claim.sub','',true);
 r := league_private.activate_club_tiers(ownerP);
 IF (r->>'changed')::int<>5 OR (r->>'up')::int<>2 OR (r->>'down')::int<>3 OR (r->>'delta')::int<>-10 OR (r->>'tiered')::int<>3 THEN RAISE EXCEPTION 'activate %', r; END IF;
 IF (SELECT string_agg(t.points::text||'/'||t.exp::text,',' ORDER BY u.o) FROM unnest(ARRAY[h1,h2,h3,h4,h5,h6,h7,h8]) WITH ORDINALITY u(x,o) JOIN public.point_transactions t ON t.submission_id=u.x)
    <>'60/60,40/40,30/30,40/40,30/30,20/20,70/70,50/50' THEN RAISE EXCEPTION 'revalued points'; END IF;
 IF (SELECT string_agg(coalesce(s.club_tier,'-'),',' ORDER BY u.o) FROM unnest(ARRAY[h1,h2,h3,h4,h7,h8]) WITH ORDINALITY u(x,o) JOIN public.training_submissions s ON s.id=u.x)
    <>'pflicht,ergaenzung,-,ergaenzung,-,-' THEN RAISE EXCEPTION 'retro tiers'; END IF;
 IF (SELECT count(*) FROM public.training_audit WHERE new_transaction->>'description'='Training (umgewertet nach Stundenplan)')<>5 THEN RAISE EXCEPTION 'audit marker'; END IF;
 IF (SELECT count(*) FROM public.training_types WHERE points=30 AND name IN ('Reguläres Boxtraining','Techniktraining','Pratzentraining','Sprint-Intervalle','Technisches Sparring'))<>5
    OR NOT (SELECT is_active FROM public.training_types WHERE id=tsp) THEN RAISE EXCEPTION 'type points'; END IF;
 BEGIN PERFORM league_private.activate_club_tiers(ownerP); RAISE EXCEPTION 'twice'; EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'Bereits aktiviert' THEN RAISE; END IF; END;

 -- Coins: Grundbetrag 10, Pflicht 15, Ergänzung 12 (Korrekturbuchung «Vereinstraining»)
 PERFORM league_private.kg_sync(annaP);
 IF (SELECT string_agg(x.s::text,',' ORDER BY u.o) FROM unnest(ARRAY[h1,h2,h3,h4,h5,h6,h7,h8]) WITH ORDINALITY u(id,o)
      JOIN LATERAL (SELECT sum(l.amount) s FROM public.kg_ledger l WHERE l.profile_id=annaP AND l.reason IN ('training','training_fix') AND split_part(l.ref,':',1)=u.id::text) x ON true)
    <>'15,12,10,12,10,10,10,10' THEN RAISE EXCEPTION 'coins'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.kg_ledger WHERE profile_id=annaP AND reason='training_fix' AND note='Vereinstraining: Pflichttraining' AND amount=5) THEN RAISE EXCEPTION 'coin note'; END IF;
 -- Kampfpfad: Trainings nach Stufe
 q := league_private.kg_pass_points(annaP, ws);
 IF (q->>'trainings_pflicht')::int<1 OR (q->>'points_trainings')::int <> (SELECT sum(CASE s.club_tier WHEN 'pflicht' THEN 15 WHEN 'ergaenzung' THEN 12 ELSE 10 END)
      FROM public.training_submissions s WHERE s.boxer_id=annaP AND s.status='approved' AND date_trunc('month',s.training_date)=date_trunc('month',ws)) THEN RAISE EXCEPTION 'pass points %', q; END IF;

 -- Flag aus: Einstufen gesperrt
 PERFORM pg_temp.act(coach);
 BEGIN PERFORM public.staff_set_training_tier(h3,'ergaenzung'); RAISE EXCEPTION 'tier while flag off'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM set_config('role','postgres',true);
 -- Flags an: Vereinsarten nur noch über das Gym
 UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key IN ('gym_training','weekly_quests','kampfgeist_shop');
 PERFORM pg_temp.act(anna);
 BEGIN
  INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes) VALUES (annaP,reg,today,'Selbst','pending',60);
  RAISE EXCEPTION 'club type self-submitted';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes) VALUES (annaP,schatten,today,'Zuhause','pending',30);

 -- Gruppen, Gym-Einheit mit Stufe, Bestätigung
 PERFORM pg_temp.act(coach);
 PERFORM public.staff_set_training_group(annaP,'wettkampf'); PERFORM public.staff_set_training_group(bobP,'newcomer');
 r := public.staff_open_gym_session(tsp, 90, 'Technisches Sparring', NULL); sid := (r->>'id')::bigint;
 r := public.staff_update_gym_session(sid, tsp, 'pflicht');
 IF r->>'club_tier'<>'pflicht' OR (r->>'updated_trainings')::int<>0 THEN RAISE EXCEPTION 'open edit %', r; END IF;
 PERFORM public.staff_set_gym_attendance(sid, annaP, true); PERFORM public.staff_set_gym_attendance(sid, bobP, true); PERFORM public.staff_set_gym_attendance(sid, benP, true);
 r := public.staff_confirm_gym_session(sid);
 IF (r->>'confirmed')::int<>3 OR (r->>'points_awarded')::int<>180 OR r->>'club_tier'<>'pflicht' THEN RAISE EXCEPTION 'confirm %', r; END IF;
 PERFORM set_config('role','postgres',true);
 IF (SELECT count(*) FROM public.gym_attendance a JOIN public.training_submissions s ON s.id=a.submission_id WHERE a.session_id=sid AND s.club_tier='pflicht')<>3 THEN RAISE EXCEPTION 'tier on trainings'; END IF;
 PERFORM pg_temp.act(coach);
 IF (public.staff_get_gym_session(sid)->'people'->0->>'points') IS NULL THEN RAISE EXCEPTION 'session points'; END IF;

 -- Nachträglich ändern: andere Trainingsart + Ergänzung → 40; Stufe weg → 30; zurück auf Pflicht → 60
 PERFORM set_config('role','postgres',true); n := (SELECT count(*) FROM public.training_audit); PERFORM pg_temp.act(coach);
 r := public.staff_update_gym_session(sid, pratzen, 'ergaenzung');
 IF (r->>'updated_trainings')::int<>3 OR (r->>'points_before')::int<>180 OR (r->>'points_after')::int<>120 THEN RAISE EXCEPTION 'edit type %', r; END IF;
 PERFORM set_config('role','postgres',true);
 IF (SELECT count(*) FROM public.gym_attendance a JOIN public.training_submissions s ON s.id=a.submission_id WHERE a.session_id=sid AND s.training_type_id=pratzen AND s.club_tier='ergaenzung')<>3 THEN RAISE EXCEPTION 'edit applied'; END IF;
 PERFORM pg_temp.act(coach);
 r := public.staff_update_gym_session(sid, pratzen, 'none');
 IF (r->>'points_after')::int<>90 THEN RAISE EXCEPTION 'edit none %', r; END IF;
 r := public.staff_update_gym_session(sid, pratzen, 'pflicht');
 IF (r->>'points_after')::int<>180 THEN RAISE EXCEPTION 'edit back %', r; END IF;
 PERFORM set_config('role','postgres',true);
 IF (SELECT count(*) FROM public.training_audit)<>n+9 THEN RAISE EXCEPTION 'audit for edits %', (SELECT count(*) FROM public.training_audit)-n; END IF;
 PERFORM pg_temp.act(coach);
 BEGIN PERFORM public.staff_update_gym_session(sid, pratzen, 'gold'); RAISE EXCEPTION 'bad tier'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.staff_update_gym_session(sid, jog, 'pflicht'); RAISE EXCEPTION 'jog'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 -- Coins und Kampfpfad folgen der Stufe
 PERFORM set_config('role','postgres',true); SELECT a.submission_id INTO sub FROM public.gym_attendance a WHERE a.session_id=sid AND a.profile_id=annaP;
 PERFORM league_private.kg_sync(annaP);
 IF (SELECT sum(l.amount) FROM public.kg_ledger l WHERE l.profile_id=annaP AND l.reason IN ('training','training_fix') AND split_part(l.ref,':',1)=sub::text)<>15 THEN RAISE EXCEPTION 'gym coins'; END IF;

 -- Einzelnes Training einstufen
 PERFORM pg_temp.act(coach);
 r := public.staff_set_training_tier(h3,'ergaenzung');
 IF (r->>'points')::int<>40 OR NOT (r->>'changed')::boolean THEN RAISE EXCEPTION 'set tier %', r; END IF;
 IF (public.staff_set_training_tier(h3,'ergaenzung')->>'changed')::boolean THEN RAISE EXCEPTION 'set tier idempotent'; END IF;
 BEGIN PERFORM public.staff_set_training_tier(h8,'pflicht'); RAISE EXCEPTION 'closed season'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 q := public.staff_training_tiers(ARRAY[h1,h3,h8]);
 IF jsonb_array_length(q)<>3 OR (SELECT x->>'club_tier' FROM jsonb_array_elements(q) x WHERE (x->>'id')::uuid=h1)<>'pflicht'
    OR (SELECT (x->>'points')::int FROM jsonb_array_elements(q) x WHERE (x->>'id')::uuid=h3)<>40
    OR (SELECT (x->>'editable')::boolean FROM jsonb_array_elements(q) x WHERE (x->>'id')::uuid=h8) THEN RAISE EXCEPTION 'tiers list %', q; END IF;
 PERFORM pg_temp.act(owner);
 r := public.staff_record_training(coachP, reg, today, 60, 'Coach trainiert', NULL, NULL); mk := (r->>'submission_id')::uuid;
 PERFORM pg_temp.act(coach);
 BEGIN PERFORM public.staff_set_training_tier(mk,'pflicht'); RAISE EXCEPTION 'own tier'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM pg_temp.act(anna);
 BEGIN PERFORM public.staff_set_training_tier(h1,'pflicht'); RAISE EXCEPTION 'boxer tier'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.staff_update_gym_session(sid, tsp, 'pflicht'); RAISE EXCEPTION 'boxer edit'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;

 -- Admin-Korrektur behält die Stufe: Wettkampfsparring (70) am Pflichttag → 70, zurück → 60
 PERFORM pg_temp.act(owner);
 IF (public.admin_edit_training(h1, annaP, spar, ws, 'Training Mo', 'approved')->>'points')::int<>70 THEN RAISE EXCEPTION 'edit keeps max'; END IF;
 IF (public.admin_edit_training(h1, annaP, reg, ws, 'Training Mo', 'approved')->>'points')::int<>60 THEN RAISE EXCEPTION 'edit keeps tier'; END IF;
 IF (public.admin_edit_training(h1, annaP, reg, ws, 'Training Mo', 'rejected')->>'points')::int<>0 THEN RAISE EXCEPTION 'reject'; END IF;
 IF (public.admin_edit_training(h1, annaP, reg, ws, 'Training Mo', 'approved')->>'points')::int<>60 THEN RAISE EXCEPTION 're-approve'; END IF;

 -- Quests: Pflicht-Quest nur für Wettkämpfer
 PERFORM pg_temp.act(anna);
 q := (SELECT x FROM jsonb_array_elements(public.get_my_quests()->'weekly') x WHERE x->>'key'='pflicht');
 IF q IS NULL OR NOT (q->>'available')::boolean OR (q->>'target')::int<>3 OR (q->>'progress')::int<>1 OR q->>'title'<>'Alle 3 Pflichttrainings' THEN RAISE EXCEPTION 'pflicht quest anna %', q; END IF;
 PERFORM pg_temp.act(bob);
 q := (SELECT x FROM jsonb_array_elements(public.get_my_quests()->'weekly') x WHERE x->>'key'='pflicht');
 IF (q->>'available')::boolean THEN RAISE EXCEPTION 'pflicht quest bob'; END IF;
 BEGIN PERFORM public.claim_quest('pflicht', today); RAISE EXCEPTION 'bob claims'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;

 -- Wochenplan automatisch aus dem Stundenplan; Präsenz mit Pflichtquote
 PERFORM pg_temp.act(anna);
 r := public.get_my_week_plan();
 IF NOT (r->'plan'->>'auto')::boolean OR jsonb_array_length(r->'plan'->'items')<>5 OR (r->'plan'->>'need')::int<>5 OR r->'plan'->'items'->0->>'tier_label'<>'Pflichttraining' THEN RAISE EXCEPTION 'auto plan %', r->'plan'; END IF;
 IF NOT (r->'pflicht'->>'required')::boolean OR (r->'pflicht'->>'target')::int<>3 OR (r->'pflicht'->>'week')::int<>1 THEN RAISE EXCEPTION 'plan pflicht %', r->'pflicht'; END IF;
 r := public.get_my_presence();
 IF NOT (r->'pflicht'->>'required')::boolean OR jsonb_array_length(r->'pflicht'->'weeks')<>5 OR (r->'pflicht'->'weeks'->1->>'days')::int<>1 THEN RAISE EXCEPTION 'presence pflicht %', r->'pflicht'; END IF;
 PERFORM pg_temp.act(bob);
 IF (public.get_my_presence()->'pflicht'->>'required')::boolean THEN RAISE EXCEPTION 'bob required'; END IF;
 IF (public.get_my_week_plan()->'plan'->>'need')::int<>2 THEN RAISE EXCEPTION 'newcomer need'; END IF;
 PERFORM set_config('role','postgres',true);
 IF league_private.plan_pct(bobP, today) IS NULL THEN RAISE EXCEPTION 'plan pct'; END IF;
 PERFORM pg_temp.act(coach);
 IF (SELECT count(*) FROM jsonb_array_elements(public.staff_presence_overview()) x WHERE x ? 'pflicht')<4 THEN RAISE EXCEPTION 'overview pflicht'; END IF;
 IF jsonb_array_length(public.staff_get_training_plan('wettkampf', today)->'auto_items')<>5 THEN RAISE EXCEPTION 'staff auto items'; END IF;

 -- Stundenplan lesen und pflegen; Einheit mit einem Tippen öffnen
 PERFORM pg_temp.act(anna);
 r := public.get_club_schedule();
 IF NOT (r->>'enabled')::boolean OR (r->>'can_edit')::boolean OR jsonb_array_length(r->'slots')<>5 OR jsonb_array_length(r->'tiers')<>2 THEN RAISE EXCEPTION 'schedule anna'; END IF;
 PERFORM pg_temp.act(coach);
 BEGIN PERFORM public.admin_save_club_slot(NULL, 5, reg, 'pflicht', 'Freitag', 90, true); RAISE EXCEPTION 'coach edits'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM set_config('role','postgres',true);
 SELECT x.id INTO slot FROM public.club_schedule x WHERE x.is_active AND x.dow=extract(isodow FROM today)::int ORDER BY x.id LIMIT 1;
 PERFORM pg_temp.act(owner);
 IF slot IS NULL THEN slot := (public.admin_save_club_slot(NULL, extract(isodow FROM today)::int, tech, 'ergaenzung', 'Testeinheit', 60, true)->>'id')::int; END IF;
 IF (public.get_club_schedule()->>'can_edit')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'owner edit'; END IF;
 BEGIN PERFORM public.admin_save_club_slot(slot, 8, reg, NULL, 'x', 90, true); RAISE EXCEPTION 'bad dow'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM pg_temp.act(coach);
 r := public.staff_open_club_session(slot);
 PERFORM set_config('role','postgres',true);
 -- Die Einheit von vorhin (sid) hängt am heutigen Stundenplan-Platz, falls es einen gibt → wird wiederverwendet.
 IF (SELECT slot_id FROM public.gym_sessions WHERE id=sid) IS NOT DISTINCT FROM slot THEN
  IF NOT (r->>'existing')::boolean OR (r->>'id')::bigint<>sid THEN RAISE EXCEPTION 'open club existing %', r; END IF;
 ELSIF (r->>'existing')::boolean OR (SELECT club_tier FROM public.gym_sessions WHERE id=(r->>'id')::bigint) IS DISTINCT FROM (SELECT tier FROM public.club_schedule WHERE id=slot) THEN RAISE EXCEPTION 'open club %', r; END IF;
 PERFORM pg_temp.act(coach);
 IF NOT (public.staff_open_club_session(slot)->>'existing')::boolean THEN RAISE EXCEPTION 'open club twice'; END IF;
 IF (SELECT count(*) FROM jsonb_array_elements(public.get_club_schedule()->'slots') x WHERE x->'today_session' IS NOT NULL AND x->'today_session'<>'null'::jsonb)<1 THEN RAISE EXCEPTION 'today session'; END IF;

 -- Rücknahme der Aktivierung: Punkte und Stufen der umgewerteten Trainings zurück, Punktwerte zurück
 PERFORM set_config('role','postgres',true); PERFORM set_config('request.jwt.claim.sub','',true);
 r := league_private.deactivate_club_tiers(ownerP);
 IF (r->>'restored')::int<>5 THEN RAISE EXCEPTION 'deactivate %', r; END IF;
 IF (SELECT string_agg(t.points::text,',' ORDER BY u.o) FROM unnest(ARRAY[h1,h2,h3,h4,h5,h6,h7,h8]) WITH ORDINALITY u(x,o) JOIN public.point_transactions t ON t.submission_id=u.x)
    <>'50,50,40,30,40,20,70,50' THEN RAISE EXCEPTION 'restored points %', (SELECT string_agg(t.points::text,',' ORDER BY u.o) FROM unnest(ARRAY[h1,h2,h3,h4,h5,h6,h7,h8]) WITH ORDINALITY u(x,o) JOIN public.point_transactions t ON t.submission_id=u.x); END IF;
 IF EXISTS (SELECT 1 FROM public.training_submissions WHERE id IN (h1,h2,h3,h4) AND club_tier IS NOT NULL) THEN RAISE EXCEPTION 'restored tiers'; END IF;
 IF (SELECT points FROM public.training_types WHERE id=reg)<>50 OR (SELECT points FROM public.training_types WHERE id=sprint)<>40 THEN RAISE EXCEPTION 'restored type points'; END IF;
 RAISE NOTICE 'PASS: Etappe 6a – Stundenplan, Stufen 60/40, Umwertung inkl. Rücknahme, Coins 15/12/10, Kampfpfad, nachträglich ändern, Pflicht-Quest nur Wettkämpfer, Wochenplan, Präsenz';
END $t$;

\ir ../supabase/production-prep/rollback_20261028230000_club_schedule_tiers.sql
DO $r$ BEGIN
 IF to_regprocedure('public.staff_update_gym_session(bigint,bigint,text)') IS NOT NULL OR to_regprocedure('league_private.training_value(uuid)') IS NOT NULL
    OR EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='league_training_insert_guard') THEN RAISE EXCEPTION 'rollback left objects'; END IF;
 IF position('club_tier' IN pg_get_functiondef('league_private.kg_sync(uuid)'::regprocedure))>0 OR position('training_value' IN pg_get_functiondef('public.admin_edit_training(uuid,uuid,bigint,date,text,text)'::regprocedure))>0 THEN RAISE EXCEPTION 'rollback old versions'; END IF;
 IF (SELECT count(*) FROM public.club_schedule)<5 OR (SELECT count(*) FROM public.training_submissions WHERE club_tier IS NOT NULL)=0 THEN RAISE EXCEPTION 'rollback kept data'; END IF;
 RAISE NOTICE 'PASS: Rollback 6a stellt Funktionen wieder her und behält Daten';
END $r$;
\ir ../supabase/migrations/20261028230000_club_schedule_tiers.sql
DO $a$ BEGIN
 IF to_regprocedure('public.staff_update_gym_session(bigint,bigint,text)') IS NULL OR (SELECT count(*) FROM public.club_schedule)<5 THEN RAISE EXCEPTION 'reapply'; END IF;
 RAISE NOTICE 'PASS: Migration 6a nach Rollback erneut anwendbar';
END $a$;
