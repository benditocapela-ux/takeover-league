\set ON_ERROR_STOP on
-- Disposable-database test for 20261028220000_kampfgeist_etappe5.sql (+ rollback). Fixture wie kampfgeist-shop-schema.sql
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

DO $t$ DECLARE r jsonb; q jsonb; today date := (now() AT TIME ZONE 'Europe/Zurich')::date; m0 date; pm date; reg bigint; d1 uuid; d2 uuid; ev bigint; pt0 bigint; n int;
 owner text := '10000000-0000-0000-0000-00000000000a'; coach text := '10000000-0000-0000-0000-00000000000c';
 anna text := '10000000-0000-0000-0000-000000000001'; ben text := '10000000-0000-0000-0000-000000000002'; bob text := '10000000-0000-0000-0000-000000000003';
 annaP uuid := '00000000-0000-0000-0000-000000000001'; benP uuid := '00000000-0000-0000-0000-000000000002'; bobP uuid := '00000000-0000-0000-0000-000000000003';
BEGIN
 m0 := date_trunc('month',today)::date; pm := (m0 - interval '1 month')::date;
 SELECT id INTO reg FROM public.training_types WHERE name='Reguläres Boxtraining';
 -- Rechte, Katalog
 IF has_function_privilege('anon','public.send_duel_emote(uuid,text)','EXECUTE') OR has_function_privilege('anon','public.get_my_kampfpfad(date)','EXECUTE') THEN RAISE EXCEPTION 'anon'; END IF;
 IF has_table_privilege('authenticated','public.kg_emote_events','SELECT') OR has_table_privilege('authenticated','public.kg_pass_claims','INSERT') THEN RAISE EXCEPTION 'table grant'; END IF;
 IF has_function_privilege('authenticated','league_private.kg_pass_points(uuid,date)','EXECUTE') THEN RAISE EXCEPTION 'helper'; END IF;
 IF (SELECT count(*) FROM public.kg_items)<>145 OR (SELECT count(*) FROM public.kg_items WHERE category='emote')<>18 OR (SELECT count(*) FROM public.kg_items WHERE category='einlauf')<>10
    OR (SELECT count(*) FROM public.kg_items WHERE unlock='pass')<>5 OR (SELECT count(*) FROM public.kg_pass_tiers)<>30 THEN RAISE EXCEPTION 'catalog'; END IF;

 -- Testdaten (als postgres): Anna 3 Trainings, 3 Quests, 1 gewonnenes Duell gegen Ben; Monatspunkte für Podium
 PERFORM set_config('role','postgres',true);
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes)
 SELECT annaP,reg,m0+(i%3),'Test '||i,'approved',60 FROM generate_series(1,3) i;
 INSERT INTO public.quest_claims(profile_id,quest_key,period_start,progress,target,exp,coins,claimed_at) VALUES
  (annaP,'box_sessions',m0,3,3,0,0,now()),(annaP,'d_any',today,1,1,0,0,now()),(annaP,'chest',m0,5,5,0,0,now());
 INSERT INTO public.league_duels(challenger_id,opponent_id,status,accepted_at,settled_at,winner_id) VALUES (annaP,benP,'settled',now(),now(),annaP) RETURNING id INTO d1;
 INSERT INTO public.league_duels(challenger_id,opponent_id,status,accepted_at,settled_at,winner_id) VALUES (benP,bobP,'settled',now()-interval '40 days',now()-interval '30 days',bobP) RETURNING id INTO d2;
 INSERT INTO public.point_transactions(boxer_id,points,exp,category,description,effective_date) VALUES
  (annaP,300,0,'adjustment','Podium',today),(benP,200,0,'adjustment','Podium',today),(bobP,100,0,'adjustment','Podium',today);
 SELECT count(*) INTO pt0 FROM public.point_transactions;

 -- Flag aus
 PERFORM pg_temp.act(anna);
 IF (public.get_my_kampfpfad()->>'enabled')::boolean OR (public.get_duel_kampfgeist(ARRAY[d1])->>'enabled')::boolean OR (public.get_podium_kampfgeist()->>'enabled')::boolean THEN RAISE EXCEPTION 'visible flag off'; END IF;
 BEGIN PERFORM public.claim_kampfpfad(today); RAISE EXCEPTION 'claim off'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.send_duel_emote(d1,'m_respekt'); RAISE EXCEPTION 'send off'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM pg_temp.act(owner);
 r := public.get_my_kampfpfad();
 IF NOT (r->>'preview')::boolean OR (r->>'can_claim')::boolean OR jsonb_array_length(r->'tiers')<>30 THEN RAISE EXCEPTION 'admin preview'; END IF;
 IF NOT (public.get_podium_kampfgeist()->>'preview')::boolean THEN RAISE EXCEPTION 'podium preview'; END IF;
 PERFORM set_config('role','postgres',true);
 UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key IN ('kampfgeist_shop','duels');

 -- Kampfpfad: 30 + 35 + 25 = 90 Punkte → Stufe 4
 PERFORM pg_temp.act(anna);
 r := public.get_my_kampfpfad();
 q := r->'points';
 IF (q->>'trainings')::int<>3 OR (q->>'points_quests')::int<>35 OR (q->>'duels_played')::int<>1 OR (q->>'duels_won')::int<>1 OR (q->>'total')::int<>90 OR (q->>'tier')::int<>4 THEN RAISE EXCEPTION 'points %', q; END IF;
 IF NOT (r->'tiers'->3->>'reached')::boolean OR (r->'tiers'->4->>'reached')::boolean OR r->'tiers'->9->'reward'->'item'->>'key'<>'m_pass_feuer' THEN RAISE EXCEPTION 'tiers'; END IF;
 BEGIN PERFORM public.claim_kampfpfad(today,5); RAISE EXCEPTION 'claim unreached'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.claim_kampfpfad((m0 - interval '2 months')::date); RAISE EXCEPTION 'claim old'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 r := public.claim_kampfpfad(today);
 IF (r->>'claimed')::int<>4 OR (r->>'coins')::int<>60 THEN RAISE EXCEPTION 'claim all %', r; END IF;
 BEGIN PERFORM public.claim_kampfpfad(today); RAISE EXCEPTION 'claim nothing'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.claim_kampfpfad(today,2); RAISE EXCEPTION 'claim twice'; EXCEPTION WHEN unique_violation THEN NULL; END;
 PERFORM set_config('role','postgres',true);
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes)
 SELECT annaP,reg,m0+(i%5),'Test mehr '||i,'approved',60 FROM generate_series(1,11) i;
 PERFORM pg_temp.act(anna);
 r := public.claim_kampfpfad(today,10);
 IF (r->>'coins')::int<>0 OR r->'items'->0->>'key'<>'m_pass_feuer' THEN RAISE EXCEPTION 'tier 10 %', r; END IF;
 r := public.claim_kampfpfad(today);
 IF (r->>'claimed')::int<>5 OR (r->>'coins')::int<>160 THEN RAISE EXCEPTION 'tiers 5-9 %', r; END IF;
 -- Vormonat: Stufe 10 → Item schon vorhanden → 150 Ersatz-Coins
 PERFORM set_config('role','postgres',true);
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes)
 SELECT annaP,reg,pm+(i%7),'Vormonat '||i,'approved',60 FROM generate_series(1,20) i;
 PERFORM pg_temp.act(anna);
 r := public.get_my_kampfpfad();
 IF (r->>'previous_open')::int<>10 THEN RAISE EXCEPTION 'previous open %', r->>'previous_open'; END IF;
 r := public.get_my_kampfpfad(pm);
 IF NOT (r->'tiers'->9->'reward'->>'substitute')::boolean OR (r->'tiers'->9->'reward'->>'coins')::int<>150 OR r->'tiers'->9->'reward'->'item'<>'null'::jsonb THEN RAISE EXCEPTION 'substitute %', r->'tiers'->9; END IF;
 r := public.claim_kampfpfad(pm,10);
 IF (r->>'coins')::int<>150 OR jsonb_array_length(r->'items')<>0 THEN RAISE EXCEPTION 'prev month %', r; END IF;
 PERFORM set_config('role','postgres',true);
 IF (SELECT count(*) FROM public.kg_ledger WHERE profile_id=annaP AND reason='pass')<>10 OR (SELECT sum(amount) FROM public.kg_ledger WHERE profile_id=annaP AND reason='pass')<>370
    OR NOT EXISTS (SELECT 1 FROM public.kg_inventory WHERE profile_id=annaP AND item_key='m_pass_feuer') THEN RAISE EXCEPTION 'ledger pass'; END IF;

 -- Ausrüsten: Sieger-Emote und Einlauf; Kampfpfad-Items nicht käuflich
 PERFORM pg_temp.act(anna);
 r := public.equip_kg_item('emote','m_pass_feuer');
 IF r->'look'->'emote'->>'key'<>'m_pass_feuer' OR r->'look'->'einlauf'->>'key'<>'e_slam' THEN RAISE EXCEPTION 'equip emote %', r->'look'; END IF;
 BEGIN PERFORM public.equip_kg_item('einlauf','m_gg'); RAISE EXCEPTION 'wrong slot'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.buy_kg_item('t_pass'); RAISE EXCEPTION 'buy pass item'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 r := public.buy_kg_item('m_stark');
 IF r->>'key'<>'m_stark' THEN RAISE EXCEPTION 'buy emote'; END IF;

 -- Emotes im Duell
 r := public.send_duel_emote(d1,'m_respekt');
 IF r->'emote'->>'key'<>'m_respekt' OR r->>'sender'<>'Anna' THEN RAISE EXCEPTION 'send %', r; END IF;
 BEGIN PERFORM public.send_duel_emote(d1,'m_gg'); RAISE EXCEPTION 'rate'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.send_duel_emote(d1,'m_legende'); RAISE EXCEPTION 'not owned'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.send_duel_emote(d2,'m_gg'); RAISE EXCEPTION 'foreign duel'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM set_config('role','postgres',true);
 UPDATE public.kg_emote_events SET created_at=now()-interval '20 seconds';
 PERFORM pg_temp.act(anna);
 PERFORM public.send_duel_emote(d1,'m_stark');
 PERFORM pg_temp.act(bob);
 BEGIN PERFORM public.send_duel_emote(d2,'m_gg'); RAISE EXCEPTION 'old duel'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 r := public.get_duel_kampfgeist(ARRAY[d1,d2]);
 IF jsonb_array_length(r->'duels')<>1 OR (r->'duels'->0->>'id')::uuid<>d2 OR (r->'duels'->0->>'can_send')::boolean THEN RAISE EXCEPTION 'bob sees %', r->'duels'; END IF;
 PERFORM pg_temp.act(ben);
 r := public.get_duel_kampfgeist(ARRAY[d1]);
 q := r->'duels'->0;
 IF jsonb_array_length(q->'events')<>2 OR NOT (q->>'can_send')::boolean OR q->'challenger'->>'name'<>'Anna' OR q->'challenger'->'emote'->>'key'<>'m_pass_feuer'
    OR (r->>'can_moderate')::boolean OR jsonb_array_length(r->'my_emotes')<>4 THEN RAISE EXCEPTION 'ben sees %', r; END IF;
 BEGIN PERFORM public.hide_kg_emote((q->'events'->0->>'id')::bigint); RAISE EXCEPTION 'boxer hides'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM pg_temp.act(coach);
 r := public.get_duel_kampfgeist(ARRAY[d1,d2]);
 IF jsonb_array_length(r->'duels')<>2 OR NOT (r->>'can_moderate')::boolean THEN RAISE EXCEPTION 'coach sees'; END IF;
 ev := (q->'events'->0->>'id')::bigint;
 PERFORM public.hide_kg_emote(ev);
 PERFORM pg_temp.act(ben);
 IF jsonb_array_length(public.get_duel_kampfgeist(ARRAY[d1])->'duels'->0->'events')<>1 THEN RAISE EXCEPTION 'hidden still visible'; END IF;
 PERFORM pg_temp.act(coach);
 IF NOT (SELECT bool_or((x->>'hidden')::boolean) FROM jsonb_array_elements(public.get_duel_kampfgeist(ARRAY[d1])->'duels'->0->'events') x) THEN RAISE EXCEPTION 'coach sees hidden flag'; END IF;
 BEGIN PERFORM public.admin_set_emote_mute(annaP,true); RAISE EXCEPTION 'coach mutes'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM pg_temp.act(owner);
 PERFORM public.admin_set_emote_mute(annaP,true);
 PERFORM set_config('role','postgres',true);
 UPDATE public.kg_emote_events SET created_at=now()-interval '20 seconds';
 PERFORM pg_temp.act(anna);
 BEGIN PERFORM public.send_duel_emote(d1,'m_gg'); RAISE EXCEPTION 'muted send'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 IF NOT (public.get_duel_kampfgeist(ARRAY[d1])->>'muted')::boolean THEN RAISE EXCEPTION 'muted flag'; END IF;
 PERFORM pg_temp.act(owner);
 PERFORM public.admin_set_emote_mute(annaP,false);

 -- Podium: Anna 1., Ben 2., Bob 3.
 PERFORM pg_temp.act(ben);
 r := public.get_podium_kampfgeist();
 IF jsonb_array_length(r->'places')<>3 OR r->'places'->0->>'name'<>'Anna' OR r->'places'->0->'look'->'emote'->>'key'<>'m_pass_feuer'
    OR NOT (r->'places'->0->>'can_react')::boolean OR (r->'places'->1->>'can_react')::boolean THEN RAISE EXCEPTION 'podium %', r->'places'; END IF;
 PERFORM public.react_podium('anna','m_gg');
 BEGIN PERFORM public.react_podium('Anna','m_respekt'); RAISE EXCEPTION 'react twice'; EXCEPTION WHEN unique_violation THEN NULL; END;
 BEGIN PERFORM public.react_podium('Ben','m_gg'); RAISE EXCEPTION 'react self'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.react_podium('Owner','m_gg'); RAISE EXCEPTION 'react non podium'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.react_podium('Bob','m_legende'); RAISE EXCEPTION 'react not owned'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM pg_temp.act(coach);
 PERFORM public.react_podium('Anna','m_gg');
 PERFORM pg_temp.act(bob);
 PERFORM public.react_podium('Anna','m_respekt');
 r := public.get_podium_kampfgeist();
 q := r->'places'->0;
 IF (q->'reactions'->0->>'count')::int<>2 OR q->'reactions'->0->'emote'->>'key'<>'m_gg' OR NOT (q->>'reacted_today')::boolean OR (q->>'can_react')::boolean THEN RAISE EXCEPTION 'reactions %', q; END IF;
 IF q::text LIKE '%Marco%' OR q::text LIKE '%Ben%' THEN RAISE EXCEPTION 'podium reveals senders'; END IF;

 -- Admin-Übersicht und Einstellungen
 PERFORM pg_temp.act(coach);
 BEGIN PERFORM public.admin_kg_social(); RAISE EXCEPTION 'coach social'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.admin_update_kg_pass(10,10,5,20,10,15,20); RAISE EXCEPTION 'coach pass'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM pg_temp.act(owner);
 r := public.admin_kg_social();
 IF jsonb_array_length(r->'events')<>5 OR (r->'pass'->>'kp_per_tier')::int<>20 OR jsonb_array_length(r->'profiles')<>4 THEN RAISE EXCEPTION 'social %', r; END IF;
 BEGIN PERFORM public.admin_update_kg_pass(10,10,5,20,10,150,20); RAISE EXCEPTION 'pass bounds'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.admin_update_kg_pass(10,10,5,20,10,15,1); RAISE EXCEPTION 'tier bounds'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM public.admin_update_kg_pass(10,10,5,20,10,15,25);

 -- Keine Änderung an Punkten/EXP
 PERFORM set_config('role','postgres',true);
 IF (SELECT count(*) FROM public.point_transactions)<>pt0 THEN RAISE EXCEPTION 'point_transactions touched'; END IF;
END $t$;

SELECT set_config('role','postgres',false);
\ir ../supabase/production-prep/rollback_20261028220000_kampfgeist_etappe5.sql
DO $t$ BEGIN
 IF to_regprocedure('public.claim_kampfpfad(date,integer)') IS NOT NULL OR to_regprocedure('league_private.kg_pass_points(uuid,date)') IS NOT NULL THEN RAISE EXCEPTION 'rollback left functions'; END IF;
 IF to_regprocedure('public.buy_kg_item(text)') IS NULL OR to_regprocedure('public.equip_kg_item(text,text)') IS NULL OR league_private.kg_look('00000000-0000-0000-0000-000000000001') ? 'emote' THEN RAISE EXCEPTION 'rollback did not restore Etappe 4'; END IF;
 IF (SELECT count(*) FROM public.kg_pass_claims)<>11 OR (SELECT count(*) FROM public.kg_emote_events)<>5 OR (SELECT count(*) FROM public.kg_items)<>145 THEN RAISE EXCEPTION 'rollback lost data'; END IF;
END $t$;
\ir ../supabase/migrations/20261028220000_kampfgeist_etappe5.sql
DO $t$ BEGIN
 IF (SELECT kp_per_tier FROM public.kg_pass_settings)<>25 OR NOT (league_private.kg_look('00000000-0000-0000-0000-000000000001') ? 'emote') THEN RAISE EXCEPTION 'reapply'; END IF;
END $t$;
SELECT 'PASS: Etappe 5 – Kampfpfad pro Monat (Trainings, Quests, Duelle; 30 Stufen, Items/Ersatz-Coins, Vormonat), Emotes im eigenen Duell (Takt, Besitz, Pause, Ausblenden), Podium-Reaktionen (1 pro Tag, ohne Namen), Sieger-Emote/Einlauf, Admin-Grenzen, Flag, Rollback stellt Etappe 4 wieder her und behält Daten' AS result;
