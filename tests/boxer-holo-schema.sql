\set ON_ERROR_STOP on
-- Disposable-database test for 20261029140000_boxer_holo.sql (Etappe 9) inkl. Rollback. Fixture wie card-designs-schema.sql (Etappen 1 bis 5) plus Etappe 7d.
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
\ir ../supabase/migrations/20261029120000_card_designs_awards.sql
\ir ../supabase/migrations/20261029140000_boxer_holo.sql
\ir ../supabase/migrations/20261029140000_boxer_holo.sql
CREATE TEMP TABLE ref AS SELECT (SELECT count(*) FROM public.training_submissions) ts;
GRANT SELECT ON ref TO authenticated, anon;

DO $t$ DECLARE r jsonb; q jsonb; n int; bal0 int; bal1 int; e text; benLvl int;
 owner text := '10000000-0000-0000-0000-00000000000a'; coach text := '10000000-0000-0000-0000-00000000000c';
 anna text := '10000000-0000-0000-0000-000000000001'; ben text := '10000000-0000-0000-0000-000000000002'; bob text := '10000000-0000-0000-0000-000000000003';
 annaP uuid := '00000000-0000-0000-0000-000000000001'; benP uuid := '00000000-0000-0000-0000-000000000002'; bobP uuid := '00000000-0000-0000-0000-000000000003';
 ownerP uuid := '00000000-0000-0000-0000-00000000000a';
 good jsonb := '{"tone":6,"hair":"afro","hc":"schwarz","eye":"braun","head":"none","top":"hoodie","hood":true,"topc":"schwarz","bottom":"jogger","bottomc":"grau","hands":"wraps","glove":"rot","feet":"sneaker","feetc":"weiss","coat":"basic","aura":"none","eyefx":"none","scene":"holo","pose_profile":"sieg","pose_card":"jab"}';
BEGIN
 -- Katalog und Rechte
 SELECT count(*) INTO n FROM public.holo_items;
 IF (SELECT count(*) FROM public.holo_items WHERE slot='hair')<>18 OR (SELECT count(*) FROM public.holo_bundles)<>3 THEN RAISE EXCEPTION 'catalog'; END IF;
 IF EXISTS (SELECT 1 FROM public.holo_bundles b, LATERAL unnest(b.items) k WHERE NOT EXISTS (SELECT 1 FROM public.holo_items i WHERE i.key=k AND i.unlock='shop')) THEN RAISE EXCEPTION 'bundle items must be shop items'; END IF;
 IF EXISTS (SELECT 1 FROM public.holo_bundles b WHERE b.price >= (SELECT sum(i.price) FROM public.holo_items i WHERE i.key=ANY(b.items))) THEN RAISE EXCEPTION 'bundle not cheaper'; END IF;
 IF has_function_privilege('anon','public.get_my_holo()','EXECUTE') OR has_function_privilege('anon','public.get_holo_looks(text[])','EXECUTE') OR has_function_privilege('anon','public.buy_holo_bundle(text)','EXECUTE') THEN RAISE EXCEPTION 'anon'; END IF;
 IF has_table_privilege('authenticated','public.holo_config','SELECT') OR has_table_privilege('authenticated','public.holo_owned','INSERT') OR has_table_privilege('authenticated','public.holo_items','SELECT') THEN RAISE EXCEPTION 'table grant'; END IF;
 IF has_function_privilege('authenticated','league_private.holo_clean(uuid,jsonb,boolean)','EXECUTE') THEN RAISE EXCEPTION 'helper'; END IF;

 -- Flag aus: Boxer nichts, Trainer/Admin Vorschau
 PERFORM pg_temp.act(anna);
 IF (public.get_my_holo()->>'enabled')::boolean THEN RAISE EXCEPTION 'visible flag off'; END IF;
 BEGIN PERFORM public.save_my_holo(good); RAISE EXCEPTION 'save off'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 IF public.get_holo_looks(ARRAY['Anna'])<>'{}'::jsonb THEN RAISE EXCEPTION 'looks off'; END IF;
 PERFORM pg_temp.act(coach);
 r := public.get_my_holo();
 IF NOT (r->>'preview')::boolean OR (r->>'shop')::boolean OR r ? 'coins' AND jsonb_typeof(r->'coins')<>'null' THEN RAISE EXCEPTION 'coach preview %', r->>'preview'; END IF;
 PERFORM pg_temp.act(NULL);
 BEGIN PERFORM public.get_my_holo(); RAISE EXCEPTION 'anon call'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM set_config('role','postgres',true);
 UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key IN ('boxer_holo','kampfgeist_shop');

 -- Standard-Holo und Katalog mit Besitz
 PERFORM pg_temp.act(anna);
 r := public.get_my_holo();
 IF NOT (r->>'enabled')::boolean OR (r->>'preview')::boolean OR (r->>'saved')::boolean OR r->'config'->>'hair'<>'kurz_glatt' OR r->'config'->>'bottom'<>'boxer' THEN RAISE EXCEPTION 'default %', r->'config'; END IF;
 IF jsonb_array_length(r->'items')<>n OR jsonb_array_length(r->'bundles')<>3 THEN RAISE EXCEPTION 'catalog json'; END IF;
 IF EXISTS (SELECT 1 FROM jsonb_array_elements(r->'items') x WHERE (x->>'unlock'='start') <> (x->>'owned')::boolean AND x->>'unlock'<>'reward') THEN RAISE EXCEPTION 'owned flags'; END IF;
 IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(r->'items') x WHERE x->>'key'='aura_blitz' AND x->>'reward'='Ab Level 20' AND x->>'value'='blitz') THEN RAISE EXCEPTION 'reward label'; END IF;
 bal0 := (r->>'coins')::int;

 -- Speichern: gültig, gesperrt, unbekannt, falsch
 r := public.save_my_holo(good);
 IF r<>good || '{"headc":"schwarz"}'::jsonb THEN RAISE EXCEPTION 'save good % ', r; END IF;
 BEGIN PERFORM public.save_my_holo(good || '{"coat":"drache"}'); RAISE EXCEPTION 'locked coat'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.save_my_holo(good || '{"pose_card":"flex"}'); RAISE EXCEPTION 'locked pose'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.save_my_holo(good || '{"evil":"x"}'); RAISE EXCEPTION 'unknown field'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.save_my_holo(good || '{"topc":"#ff0000"}'); RAISE EXCEPTION 'raw color'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.save_my_holo(good || '{"tone":9}'); RAISE EXCEPTION 'tone'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.save_my_holo(good || '{"hair":"<script>"}'); RAISE EXCEPTION 'unknown hair'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.save_my_holo(good || '{"hood":"ja"}'); RAISE EXCEPTION 'hood type'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.save_my_holo(good || '{"bottom":"none"}'); RAISE EXCEPTION 'no pants'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.save_my_holo('[]'::jsonb); RAISE EXCEPTION 'array'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM set_config('role','postgres',true);
 IF (SELECT config->>'hair' FROM public.holo_config WHERE profile_id=annaP)<>'afro' THEN RAISE EXCEPTION 'failed saves changed data'; END IF;
 PERFORM pg_temp.act(anna);

 -- Kaufen: zu wenig Coins, Start-/Belohnungs-Item nicht käuflich
 BEGIN PERFORM public.buy_holo_item('coat_drache'); RAISE EXCEPTION 'too poor'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.buy_holo_item('coat_basic'); RAISE EXCEPTION 'buy start'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.buy_holo_item('aura_blitz'); RAISE EXCEPTION 'buy reward'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM set_config('role','postgres',true);
 INSERT INTO public.kg_ledger(profile_id,amount,reason,ref,note) VALUES (annaP,6000,'admin','test-holo','Testguthaben');
 PERFORM pg_temp.act(anna);
 r := public.buy_holo_item('coat_drache');
 IF (r->>'balance')::int<>bal0+6000-1800 THEN RAISE EXCEPTION 'balance after item %', r; END IF;
 BEGIN PERFORM public.buy_holo_item('coat_drache'); RAISE EXCEPTION 'buy twice'; EXCEPTION WHEN unique_violation THEN NULL; END;
 r := public.save_my_holo(good || '{"coat":"drache"}');
 IF r->>'coat'<>'drache' THEN RAISE EXCEPTION 'save bought'; END IF;
 -- Bundle mit einem schon gekauften Teil: übrige 3 Teile, voller Bundle-Preis
 r := public.buy_holo_bundle('drachen_bundle');
 IF (r->>'new_items')::int<>3 OR (r->>'balance')::int<>bal0+6000-1800-3400 THEN RAISE EXCEPTION 'bundle %', r; END IF;
 BEGIN PERFORM public.buy_holo_bundle('drachen_bundle'); RAISE EXCEPTION 'bundle twice'; EXCEPTION WHEN unique_violation THEN NULL; END;
 BEGIN PERFORM public.buy_holo_bundle('neon_bundle'); RAISE EXCEPTION 'bundle too poor'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 r := public.save_my_holo(good || '{"coat":"drache","aura":"flamme","eyefx":"glut","pose_card":"ansage"}');
 IF r->>'eyefx'<>'glut' OR r->>'pose_card'<>'ansage' THEN RAISE EXCEPTION 'save bundle items'; END IF;
 r := public.get_my_holo();
 IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(r->'bundles') b WHERE b->>'key'='drachen_bundle' AND (b->>'owned_all')::boolean AND (b->>'value')::int=4700) THEN RAISE EXCEPTION 'bundle owned_all'; END IF;
 PERFORM set_config('role','postgres',true);
 IF (SELECT count(*) FROM public.kg_ledger WHERE profile_id=annaP AND reason='purchase' AND ref LIKE 'holo%')<>2 THEN RAISE EXCEPTION 'ledger rows'; END IF;

 -- Belohnungen: Level, Duellsieg, Card of the Week; Admin schenkt
 PERFORM set_config('role','postgres',true);
 INSERT INTO public.point_transactions(boxer_id,points,exp,category,description,effective_date) VALUES (benP,0,50000,'bonus','Test-EXP','2025-06-01');
 INSERT INTO public.league_duels(challenger_id,opponent_id,status,accepted_at,settled_at,winner_id) VALUES (bobP,benP,'settled',now(),now(),bobP);
 INSERT INTO public.card_awards(kind,period_start,period_end,profile_id,awarded_by) VALUES ('cotw','2026-10-19','2026-10-25',bobP,ownerP);
 benLvl := league_private.kg_level(league_private.kg_exp(benP));
 PERFORM pg_temp.act(ben);
 r := public.get_my_holo();
 IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(r->'items') x WHERE x->>'key'='pose_flex' AND (x->>'owned')::boolean = (benLvl>=10)) THEN RAISE EXCEPTION 'level reward'; END IF;
 IF (SELECT bool_and((x->>'owned')::boolean) FROM jsonb_array_elements(r->'items') x WHERE x->>'key' IN ('scene_arena','eyefx_stern')) THEN RAISE EXCEPTION 'ben has bob rewards'; END IF;
 PERFORM pg_temp.act(bob);
 r := public.save_my_holo('{"scene":"arena","eyefx":"stern","hair":"locs","hc":"dunkelbraun","eye":"hasel","tone":7}');
 IF r->>'scene'<>'arena' OR r->>'eyefx'<>'stern' OR r->>'hair'<>'locs' THEN RAISE EXCEPTION 'bob rewards %', r; END IF;
 BEGIN PERFORM public.admin_grant_holo_item(benP,'glove_glut','Test'); RAISE EXCEPTION 'grant by boxer'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM pg_temp.act(owner);
 BEGIN PERFORM public.admin_grant_holo_item(benP,'hair_afro','Test'); RAISE EXCEPTION 'grant start'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.admin_grant_holo_item(benP,'glove_glut',''); RAISE EXCEPTION 'grant no note'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 r := public.admin_grant_holo_item(benP,'glove_glut','Kampfabend-Sieger');
 IF NOT (r->>'granted')::boolean OR (public.admin_grant_holo_item(benP,'glove_glut','nochmal')->>'granted')::boolean THEN RAISE EXCEPTION 'grant'; END IF;
 PERFORM pg_temp.act(ben);
 r := public.save_my_holo('{"hands":"gloves","glove":"glut"}');
 IF r->>'glove'<>'glut' THEN RAISE EXCEPTION 'granted glove'; END IF;

 -- Looks anderer: sichtbare Profile, nur gespeicherte Holos, Fallback wenn Besitz fehlt
 r := public.get_holo_looks(ARRAY['anna','Bob','Owner','Marco']);
 IF NOT r ? 'Anna' OR NOT r ? 'Bob' OR r ? 'Owner' OR r ? 'Marco' OR r->'Anna'->>'coat'<>'drache' THEN RAISE EXCEPTION 'looks %', r; END IF;
 PERFORM set_config('role','postgres',true);
 UPDATE public.profiles SET is_listed=false WHERE id=bobP;
 DELETE FROM public.holo_owned WHERE profile_id=annaP AND item_key='coat_drache';
 PERFORM pg_temp.act(ben);
 r := public.get_holo_looks(ARRAY['Anna','Bob']);
 IF r ? 'Bob' OR r->'Anna'->>'coat'<>'none' THEN RAISE EXCEPTION 'hidden/fallback %', r; END IF;
 PERFORM pg_temp.act(coach);
 IF NOT public.get_holo_looks(ARRAY['Bob']) ? 'Bob' THEN RAISE EXCEPTION 'coach sees unlisted'; END IF;
 BEGIN PERFORM public.get_holo_looks(array_fill('x'::text,ARRAY[51])); RAISE EXCEPTION 'cap'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;

 -- Bestehende Daten unverändert
 PERFORM set_config('role','postgres',true);
 IF (SELECT count(*) FROM public.training_submissions)<>(SELECT ts FROM ref) THEN RAISE EXCEPTION 'trainings changed'; END IF;
 RAISE NOTICE 'PASS: Boxer-Holo – Katalog (18 Frisuren, Bundles günstiger), Flag aus nur Vorschau, Speichern streng geprüft, Kauf/Bundle mit Coins, Belohnungen (Level, Duellsieg, COTW, Admin), Looks mit Sichtbarkeit und Fallback';
END $t$;

-- Rollback: verweigert bei Käufen; ohne Käufe sauber
\set ON_ERROR_STOP off
\ir ../supabase/production-prep/rollback_20261029140000_boxer_holo.sql
\set ON_ERROR_STOP on
DO $r$ BEGIN
 IF to_regclass('public.holo_items') IS NULL THEN RAISE EXCEPTION 'rollback ran despite purchases'; END IF;
 RAISE NOTICE 'PASS: Rollback verweigert bei Käufen';
END $r$;
DELETE FROM public.holo_owned; DELETE FROM public.kg_ledger WHERE ref LIKE 'holo%';
\ir ../supabase/production-prep/rollback_20261029140000_boxer_holo.sql
DO $r$ BEGIN
 IF to_regclass('public.holo_items') IS NOT NULL OR to_regprocedure('public.get_my_holo()') IS NOT NULL OR EXISTS (SELECT 1 FROM public.league_feature_flags WHERE feature_key='boxer_holo') THEN RAISE EXCEPTION 'rollback incomplete'; END IF;
 RAISE NOTICE 'PASS: Rollback Boxer-Holo';
END $r$;
\ir ../supabase/migrations/20261029140000_boxer_holo.sql
