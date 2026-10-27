\set ON_ERROR_STOP on
-- Disposable-database test for 20261028210000_kampfgeist_shop.sql (+ rollback). Fixture wie weekly-quests-schema.sql
-- (production review_training, Etappen 1 bis 3).
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

DO $t$ DECLARE r jsonb; q jsonb; today date := (now() AT TIME ZONE 'Europe/Zurich')::date; reg bigint; tech bigint; s1 uuid; n0 bigint; pt0 bigint;
 owner text := '10000000-0000-0000-0000-00000000000a'; coach text := '10000000-0000-0000-0000-00000000000c';
 anna text := '10000000-0000-0000-0000-000000000001'; ben text := '10000000-0000-0000-0000-000000000002';
 annaP uuid := '00000000-0000-0000-0000-000000000001'; benP uuid := '00000000-0000-0000-0000-000000000002';
 ownerP uuid := '00000000-0000-0000-0000-00000000000a';
BEGIN
 SELECT id INTO reg FROM public.training_types WHERE name='Reguläres Boxtraining';
 SELECT id INTO tech FROM public.training_types WHERE name='Techniktraining';
 -- Rechte, Katalog, Formeln
 IF has_function_privilege('anon','public.get_my_kampfgeist(boolean)','EXECUTE') OR has_function_privilege('anon','public.buy_kg_item(text)','EXECUTE') THEN RAISE EXCEPTION 'anon may execute'; END IF;
 IF has_table_privilege('authenticated','public.kg_ledger','SELECT') OR has_table_privilege('authenticated','public.kg_ledger','INSERT')
    OR has_table_privilege('authenticated','public.kg_inventory','INSERT') THEN RAISE EXCEPTION 'table grant'; END IF;
 IF has_function_privilege('authenticated','league_private.kg_sync(uuid)','EXECUTE') THEN RAISE EXCEPTION 'helper grant'; END IF;
 IF (SELECT count(*) FROM public.kg_items)<>114 OR (SELECT count(*) FROM public.kg_items WHERE unlock='shop')<>93
    OR (SELECT count(*) FROM public.kg_items WHERE unlock='start')<>9 OR (SELECT count(*) FROM public.kg_items WHERE unlock='rank')<>12 THEN RAISE EXCEPTION 'catalog'; END IF;
 IF (SELECT count(*) FROM public.kg_items WHERE unlock='shop' AND min_rank='F')<19 THEN RAISE EXCEPTION 'too few F items'; END IF;
 IF EXISTS (SELECT 1 FROM (SELECT min_rank, max(price) mx, min(price) mn FROM public.kg_items WHERE unlock='shop' GROUP BY 1) x
   JOIN (SELECT min_rank, max(price) mx, min(price) mn FROM public.kg_items WHERE unlock='shop' GROUP BY 1) y
   ON league_private.kg_rank_of(y.min_rank)=league_private.kg_rank_of(x.min_rank)+2 WHERE y.mn<=x.mx) THEN RAISE EXCEPTION 'prices not staged by rank'; END IF;
 IF league_private.kg_level(0)<>1 OR league_private.kg_level(2124)<>10 OR league_private.kg_level(2125)<>11 OR league_private.kg_level(6750)<>21
    OR league_private.kg_level(50250)<>61 OR league_private.kg_level(128625)<>99 OR league_private.kg_level(10000000)<>99 OR league_private.kg_level(-5)<>1 THEN RAISE EXCEPTION 'levels'; END IF;
 IF league_private.kg_rank_idx(10)<>0 OR league_private.kg_rank_idx(11)<>1 OR league_private.kg_rank_idx(61)<>6 OR league_private.kg_rank_idx(99)<>6 THEN RAISE EXCEPTION 'ranks'; END IF;

 -- Testdaten: Anna 3 bestätigte, 1 offenes, 1 abgelehntes Training; eine abgeholte Quest mit 60 Coins
 PERFORM set_config('role','postgres',true);
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes) VALUES
  (annaP,reg,today-3,'Test a','approved',90),(annaP,tech,today-2,'Test b','approved',60),(annaP,reg,today-1,'Test c','approved',90),
  (annaP,reg,today,'Test d','pending',90),(annaP,reg,today-4,'Test e','rejected',90);
 SELECT id INTO s1 FROM public.training_submissions WHERE boxer_id=annaP AND notes='Test a';
 INSERT INTO public.quest_claims(profile_id,quest_key,period_start,progress,target,exp,coins) VALUES (annaP,'recovery',today-(extract(isodow FROM today)::int-1),1,1,0,60);
 SELECT count(*) INTO pt0 FROM public.point_transactions;

 -- Flag aus
 PERFORM pg_temp.act(anna);
 IF (public.get_my_kampfgeist()->>'enabled')::boolean THEN RAISE EXCEPTION 'visible with flag off'; END IF;
 BEGIN PERFORM public.buy_kg_item('t_frueh'); RAISE EXCEPTION 'buy flag off'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.equip_kg_item('titel','t_rookie'); RAISE EXCEPTION 'equip flag off'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 IF public.get_kg_look('Anna') IS NOT NULL THEN RAISE EXCEPTION 'look flag off'; END IF;
 PERFORM pg_temp.act(owner);
 r := public.get_my_kampfgeist();
 IF NOT (r->>'preview')::boolean OR (r->>'can_buy')::boolean OR jsonb_array_length(r->'items')<>114 THEN RAISE EXCEPTION 'admin preview %', r->>'preview'; END IF;
 r := public.admin_kg_overview();
 SELECT x INTO q FROM jsonb_array_elements(r->'wallets') x WHERE x->>'display_name'='Anna';
 IF (q->>'preview_coins')::int<>190 OR (q->>'balance')::int<>0 THEN RAISE EXCEPTION 'preview coins %', q; END IF;
 BEGIN PERFORM public.admin_adjust_coins(annaP,50,'Test'); RAISE EXCEPTION 'adjust flag off'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM set_config('role','postgres',true);
 IF EXISTS (SELECT 1 FROM public.kg_ledger) OR EXISTS (SELECT 1 FROM public.quest_claims WHERE coins_credited_at IS NOT NULL) THEN RAISE EXCEPTION 'writes with flag off'; END IF;

 -- Flag an: Gutschriften
 UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='kampfgeist_shop';
 PERFORM pg_temp.act(anna);
 r := public.get_my_kampfgeist();
 IF (r->'wallet'->>'balance')::int<>190 OR (r->'wallet'->>'quest_pending')::int<>0 OR r->'level'->>'rank'<>'F' OR NOT (r->>'can_buy')::boolean THEN RAISE EXCEPTION 'wallet %', r->'wallet'; END IF;
 IF r->'look'->'avatar'->>'key'<>'a_kenji' OR r->'look'->'titel'->>'key'<>'t_rookie' THEN RAISE EXCEPTION 'default look %', r->'look'; END IF;
 SELECT x INTO q FROM jsonb_array_elements(r->'items') x WHERE x->>'key'='a_tomas';
 IF (q->>'owned')::boolean OR (q->>'rank_ok')::boolean THEN RAISE EXCEPTION 'E item state %', q; END IF;
 SELECT x INTO q FROM jsonb_array_elements(r->'items') x WHERE x->>'key'='a_zara';
 IF NOT (q->>'owned')::boolean THEN RAISE EXCEPTION 'start item not owned'; END IF;
 r := public.get_my_kampfgeist(false);
 IF r ? 'items' OR r ? 'history' OR (r->'wallet'->>'balance')::int<>190 OR r->'look'->'avatar' IS NULL THEN RAISE EXCEPTION 'light %', r; END IF;
 PERFORM set_config('role','postgres',true);
 SELECT count(*) INTO n0 FROM public.kg_ledger WHERE profile_id=annaP;
 IF n0<>5 THEN RAISE EXCEPTION 'ledger rows % (start + 3 trainings + quest)', n0; END IF;
 PERFORM pg_temp.act(anna);

 -- Kaufen
 BEGIN PERFORM public.buy_kg_item('a_lina'); RAISE EXCEPTION 'bought too expensive'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.buy_kg_item('a_tomas'); RAISE EXCEPTION 'bought above rank'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.buy_kg_item('a_kenji'); RAISE EXCEPTION 'bought start item'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.buy_kg_item('t_prospect'); RAISE EXCEPTION 'bought rank item'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 r := public.buy_kg_item('t_frueh');
 IF (r->>'balance')::int<>90 OR (r->>'price')::int<>100 THEN RAISE EXCEPTION 'buy %', r; END IF;
 BEGIN PERFORM public.buy_kg_item('t_frueh'); RAISE EXCEPTION 'bought twice'; EXCEPTION WHEN unique_violation THEN NULL; END;
 -- Ausrüsten
 BEGIN PERFORM public.equip_kg_item('avatar','a_lina'); RAISE EXCEPTION 'equip not owned'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.equip_kg_item('aura','t_frueh'); RAISE EXCEPTION 'equip wrong slot'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.equip_kg_item('rahmen','f_rang_e'); RAISE EXCEPTION 'equip rank item early'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.equip_kg_item('hut','t_frueh'); RAISE EXCEPTION 'unknown slot'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 r := public.equip_kg_item('titel','t_frueh');
 IF r->'look'->'titel'->>'name'<>'Frühaufsteher' THEN RAISE EXCEPTION 'equip %', r; END IF;
 PERFORM public.equip_kg_item('avatar','a_zara');
 -- Aussehen für andere
 PERFORM pg_temp.act(ben);
 r := public.get_kg_look('anna');
 IF r->'titel'->>'key'<>'t_frueh' OR r->'avatar'->>'key'<>'a_zara' OR r->>'rank'<>'F' OR r->>'name'<>'Anna' THEN RAISE EXCEPTION 'look %', r; END IF;
 IF public.get_kg_look('Niemand') IS NOT NULL THEN RAISE EXCEPTION 'unknown look'; END IF;

 -- Rang E erreicht → Rang-Belohnungen gehören dir, E-Items kaufbar
 PERFORM set_config('role','postgres',true);
 INSERT INTO public.point_transactions(boxer_id,points,exp,category,description,effective_date) VALUES (annaP,0,2125,'adjustment','Test',today);
 PERFORM pg_temp.act(owner);
 BEGIN PERFORM public.admin_adjust_coins(ownerP,500,'Selbst'); RAISE EXCEPTION 'self adjust'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.admin_adjust_coins(annaP,0,'Null'); RAISE EXCEPTION 'zero adjust'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.admin_adjust_coins(annaP,9000,'Zu viel'); RAISE EXCEPTION 'big adjust'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.admin_adjust_coins(annaP,50,''); RAISE EXCEPTION 'no note'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 r := public.admin_adjust_coins(annaP,500,'Turnier-Helferin');
 IF (r->>'balance')::int<>590 THEN RAISE EXCEPTION 'adjust %', r; END IF;
 PERFORM pg_temp.act(coach);
 BEGIN PERFORM public.admin_adjust_coins(annaP,50,'Coach'); RAISE EXCEPTION 'coach adjust'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.admin_kg_overview(); RAISE EXCEPTION 'coach overview'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM pg_temp.act(anna);
 r := public.get_my_kampfgeist();
 IF r->'level'->>'rank'<>'E' OR (r->'level'->>'level')::int<>11 THEN RAISE EXCEPTION 'rank E %', r->'level'; END IF;
 SELECT x INTO q FROM jsonb_array_elements(r->'items') x WHERE x->>'key'='f_rang_e';
 IF NOT (q->>'owned')::boolean THEN RAISE EXCEPTION 'rank reward not owned'; END IF;
 PERFORM public.equip_kg_item('rahmen','f_rang_e');
 r := public.buy_kg_item('a_tomas');
 IF (r->>'balance')::int<>140 THEN RAISE EXCEPTION 'buy E %', r; END IF;

 -- Training nicht mehr bestätigt → -10, wieder bestätigt → +10
 PERFORM set_config('role','postgres',true);
 UPDATE public.training_submissions SET status='rejected' WHERE id=s1;
 PERFORM pg_temp.act(anna);
 IF (public.get_my_kampfgeist()->'wallet'->>'balance')::int<>130 THEN RAISE EXCEPTION 'reversal'; END IF;
 IF (public.get_my_kampfgeist()->'wallet'->>'balance')::int<>130 THEN RAISE EXCEPTION 'reversal twice'; END IF;
 PERFORM set_config('role','postgres',true);
 UPDATE public.training_submissions SET status='approved' WHERE id=s1;
 UPDATE public.training_submissions SET status='approved' WHERE boxer_id=annaP AND notes='Test d';
 PERFORM pg_temp.act(anna);
 IF (public.get_my_kampfgeist()->'wallet'->>'balance')::int<>150 THEN RAISE EXCEPTION 're-approval'; END IF;
 PERFORM set_config('role','postgres',true);
 IF (SELECT count(*) FROM public.kg_ledger WHERE reason='training_fix' AND profile_id=annaP)<>2 THEN RAISE EXCEPTION 'fix rows'; END IF;

 -- Admin: Einstellungen und Items
 PERFORM pg_temp.act(owner);
 BEGIN PERFORM public.admin_update_kg_item('a_kenji',NULL,'F',false); RAISE EXCEPTION 'start inactive'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.admin_update_kg_item('f_rang_e',100,'E',true); RAISE EXCEPTION 'rank priced'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.admin_update_kg_item('a_lina',5,'F',true); RAISE EXCEPTION 'price low'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.admin_update_kg_item('a_lina',200,'X',true); RAISE EXCEPTION 'bad rank'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 r := public.admin_update_kg_item('a_lina',180,'F',false);
 IF (r->>'price')::int<>180 OR (r->>'is_active')::boolean THEN RAISE EXCEPTION 'item update %', r; END IF;
 BEGIN PERFORM public.admin_update_kg_settings(100,900); RAISE EXCEPTION 'settings bounds'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM public.admin_update_kg_settings(100,15);
 PERFORM set_config('role','postgres',true);
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,notes,status,duration_minutes) VALUES (annaP,tech,today,'Test f','approved',45);
 PERFORM pg_temp.act(owner);
 r := public.admin_kg_overview();
 SELECT x INTO q FROM jsonb_array_elements(r->'wallets') x WHERE x->>'display_name'='Anna';
 IF (q->>'balance')::int<>165 OR (q->>'spent')::int<>550 OR (q->>'items')::int<>2 THEN RAISE EXCEPTION 'overview anna % (neues Training mit 15)', q; END IF;
 SELECT x INTO q FROM jsonb_array_elements(r->'wallets') x WHERE x->>'display_name'='Owner';
 IF (q->>'balance')::int<>100 THEN RAISE EXCEPTION 'admin wallet %', q; END IF;
 PERFORM pg_temp.act(ben);
 BEGIN PERFORM public.buy_kg_item('a_lina'); RAISE EXCEPTION 'inactive bought'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.admin_update_kg_item('a_sora',1,'F',true); RAISE EXCEPTION 'boxer edits'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 -- Anna sieht deaktiviertes, aber gekauftes Item weiterhin
 PERFORM set_config('role','postgres',true);
 UPDATE public.kg_items SET is_active=false WHERE key='t_frueh';
 PERFORM pg_temp.act(anna);
 IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(public.get_my_kampfgeist()->'items') x WHERE x->>'key'='t_frueh' AND (x->>'owned')::boolean) THEN RAISE EXCEPTION 'owned inactive hidden'; END IF;

 -- Shop verändert keine Punkte/EXP
 PERFORM set_config('role','postgres',true);
 IF (SELECT count(*) FROM public.point_transactions)<>pt0+1 THEN RAISE EXCEPTION 'point_transactions touched'; END IF;
 IF EXISTS (SELECT 1 FROM public.kg_ledger GROUP BY profile_id HAVING sum(amount)<0) THEN RAISE EXCEPTION 'negative balance'; END IF;
END $t$;

SELECT set_config('role','postgres',false);
\ir ../supabase/production-prep/rollback_20261028210000_kampfgeist_shop.sql
DO $t$ BEGIN
 IF to_regprocedure('public.buy_kg_item(text)') IS NOT NULL OR to_regprocedure('league_private.kg_sync(uuid)') IS NOT NULL THEN RAISE EXCEPTION 'rollback left functions'; END IF;
 IF to_regprocedure('public.claim_quest(text,date)') IS NULL OR to_regprocedure('public.get_my_week_plan(date)') IS NULL THEN RAISE EXCEPTION 'rollback removed earlier functions'; END IF;
 IF (SELECT count(*) FROM public.kg_inventory)<>2 OR (SELECT count(*) FROM public.kg_items)<>114 OR NOT EXISTS (SELECT 1 FROM public.kg_equipped) THEN RAISE EXCEPTION 'rollback lost data'; END IF;
END $t$;
\ir ../supabase/migrations/20261028210000_kampfgeist_shop.sql
DO $t$ BEGIN
 IF (SELECT price FROM public.kg_items WHERE key='a_lina')<>180 OR (SELECT coins_per_training FROM public.kg_settings)<>15 THEN RAISE EXCEPTION 'reapply reset admin settings'; END IF;
END $t$;
SELECT 'PASS: Kampfgeist-Shop – 114 Items nach Rang gestaffelt, Coins aus Start/Trainings (rückwirkend)/Quests idempotent, Korrekturen bei Ablehnung, Kauf mit Rang-/Guthabenprüfung, Rang-Belohnungen, Ausrüsten, Admin-Grenzen, Flag, Level 99, Rollback behält Daten' AS result;
