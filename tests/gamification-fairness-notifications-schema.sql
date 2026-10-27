\set ON_ERROR_STOP on
-- Disposable-database test for 20261027120000_gamification_fairness_and_notifications.sql.
-- Minimal production-shaped fixture; nothing here touches a hosted project.
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE ROLE anon;
CREATE ROLE authenticated;
CREATE SCHEMA auth;
CREATE SCHEMA league_v21_private;
CREATE OR REPLACE FUNCTION auth.uid()
RETURNS uuid LANGUAGE sql STABLE
AS $$ SELECT NULLIF(current_setting('request.jwt.claim.sub', true),'')::uuid $$;

CREATE TABLE public.profiles(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), auth_user_id uuid UNIQUE, display_name text NOT NULL,
 role text NOT NULL DEFAULT 'boxer', is_active boolean NOT NULL DEFAULT true, is_listed boolean NOT NULL DEFAULT false,
 archived_at timestamptz);
CREATE TABLE public.league_feature_flags(feature_key text PRIMARY KEY, display_name text NOT NULL DEFAULT '', is_enabled boolean NOT NULL DEFAULT false);
CREATE TABLE public.training_submissions(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), boxer_id uuid NOT NULL REFERENCES public.profiles(id), training_type_id bigint NOT NULL,
 training_date date NOT NULL, status text NOT NULL DEFAULT 'pending', created_at timestamptz NOT NULL DEFAULT now(),
 jogging_km numeric, technique_minutes integer);
CREATE TABLE public.point_transactions(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), boxer_id uuid NOT NULL REFERENCES public.profiles(id), submission_id uuid,
 points integer NOT NULL DEFAULT 0, exp integer NOT NULL DEFAULT 0, category text NOT NULL, description text,
 effective_date date NOT NULL DEFAULT current_date, created_by uuid, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.league_seasons_v21(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), title text NOT NULL, starts_on date NOT NULL, ends_on date NOT NULL, status text NOT NULL DEFAULT 'draft');
CREATE TABLE public.league_season_results_v21(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), season_id uuid NOT NULL, boxer_id uuid NOT NULL,
 boxer_name text NOT NULL DEFAULT 'Boxer', rank_position integer NOT NULL, points integer NOT NULL, exp integer NOT NULL, UNIQUE(season_id,boxer_id));
CREATE TABLE public.league_hall_of_fame_v21(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), boxer_id uuid NOT NULL, season_id uuid, title text NOT NULL,
 description text, boxer_name text NOT NULL DEFAULT 'Boxer', UNIQUE(boxer_id,season_id,title));
CREATE TABLE public.league_global_challenges_v21(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), title text NOT NULL, description text NOT NULL DEFAULT '',
 metric text NOT NULL, target_value numeric NOT NULL, starts_at timestamptz NOT NULL, ends_at timestamptz NOT NULL, status text NOT NULL DEFAULT 'draft',
 created_by uuid NOT NULL, completion_exp integer NOT NULL DEFAULT 0, winner_exp integer NOT NULL DEFAULT 0);
CREATE TABLE public.league_global_entries_v21(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), challenge_id uuid NOT NULL, boxer_id uuid NOT NULL,
 joined_at timestamptz NOT NULL DEFAULT now(), UNIQUE(challenge_id,boxer_id));
CREATE TABLE public.league_global_results_v21(challenge_id uuid NOT NULL, boxer_id uuid NOT NULL, boxer_name text NOT NULL, progress numeric NOT NULL,
 rank_position integer NOT NULL, completed boolean NOT NULL, PRIMARY KEY(challenge_id,boxer_id));
CREATE TABLE public.league_global_exp_ledger_v21(challenge_id uuid NOT NULL, boxer_id uuid NOT NULL, transaction_id uuid NOT NULL UNIQUE, exp_amount integer NOT NULL,
 PRIMARY KEY(challenge_id,boxer_id));
CREATE TABLE public.league_public_records_v21(boxer_id uuid PRIMARY KEY, boxer_name text NOT NULL, approved_sessions integer NOT NULL, active_days integer NOT NULL,
 max_jogging_km numeric NOT NULL, max_technique_minutes integer NOT NULL, refreshed_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.achievement_definitions(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text NOT NULL, title text NOT NULL, icon_key text, is_active boolean NOT NULL DEFAULT true);
CREATE TABLE public.boxer_achievements(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), boxer_id uuid NOT NULL, achievement_id uuid NOT NULL,
 earned_at timestamptz NOT NULL DEFAULT now(), source_key text, metadata jsonb NOT NULL DEFAULT '{}', UNIQUE(boxer_id,achievement_id));
CREATE TABLE public.league_public_badges_v21(boxer_id uuid NOT NULL, achievement_id uuid NOT NULL, boxer_name text NOT NULL, title text NOT NULL, icon_key text,
 earned_at timestamptz NOT NULL, PRIMARY KEY(boxer_id,achievement_id));
CREATE TABLE public.league_duels(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), challenger_id uuid NOT NULL, opponent_id uuid NOT NULL, status text NOT NULL DEFAULT 'pending',
 settled_at timestamptz, challenger_score integer NOT NULL DEFAULT 0, opponent_score integer NOT NULL DEFAULT 0, winner_id uuid);
CREATE TABLE public.league_public_duel_history_v21(duel_id uuid PRIMARY KEY, challenger_id uuid NOT NULL, opponent_id uuid NOT NULL, challenger_name text NOT NULL,
 opponent_name text NOT NULL, challenger_score integer NOT NULL, opponent_score integer NOT NULL, winner_id uuid, settled_at timestamptz NOT NULL,
 updated_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.boxer_notifications(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), recipient_id uuid NOT NULL REFERENCES public.profiles(id),
 notification_type text NOT NULL, title text NOT NULL, message text NOT NULL DEFAULT '', target_path text, created_at timestamptz NOT NULL DEFAULT now(), read_at timestamptz,
 CONSTRAINT boxer_notifications_notification_type_check CHECK (notification_type = ANY (ARRAY['training_approved','training_rejected','coach_feedback','coach_goal',
  'league_challenge','boxer_duel','achievement','season','general'])),
 CONSTRAINT boxer_notifications_title_check CHECK (char_length(btrim(title)) BETWEEN 1 AND 160),
 CONSTRAINT boxer_notifications_target_path_check CHECK (target_path IS NULL OR (char_length(target_path)<=300 AND target_path LIKE '/%' AND target_path NOT LIKE '//%')));

-- Production definitions of the unchanged level curve.
CREATE FUNCTION public.league_level_from_exp_v2(p_exp numeric) RETURNS bigint LANGUAGE plpgsql IMMUTABLE STRICT SET search_path TO 'public','pg_temp' AS $f$
BEGIN IF p_exp < 0 THEN RETURN NULL; END IF;
 RETURN (floor((sqrt(49::numeric + (8::numeric / 25) * p_exp) - 7) / 2) + 1)::bigint; END $f$;
CREATE FUNCTION public.league_level_start_exp_v2(p_level bigint) RETURNS numeric LANGUAGE sql IMMUTABLE STRICT SET search_path TO 'public','pg_temp' AS $f$
 SELECT CASE WHEN p_level < 1 THEN NULL::numeric ELSE 100::numeric*(p_level-1)::numeric + 25::numeric*(p_level-1)::numeric*(p_level-2)::numeric/2 END $f$;

\ir ../supabase/migrations/20261027120000_gamification_fairness_and_notifications.sql

-- Existing production triggers that use the replaced functions.
CREATE TRIGGER league_v21_badge_projection AFTER INSERT OR UPDATE OR DELETE ON public.boxer_achievements
 FOR EACH ROW EXECUTE FUNCTION league_v21_private.sync_public_badges_core();
CREATE TRIGGER league_v21_public_duel_history AFTER UPDATE ON public.league_duels
 FOR EACH ROW EXECUTE FUNCTION league_v21_private.sync_public_duel_history();
CREATE TRIGGER trg_notify_training_decision AFTER UPDATE OF status ON public.training_submissions
 FOR EACH ROW EXECUTE FUNCTION public._notify_training_decision();

INSERT INTO public.league_feature_flags(feature_key,is_enabled) VALUES ('notifications',true),('performance_dashboard',true),('league_challenges',false);
-- 1 admin; 2,3 public boxers; 4 unlisted; 5 inactive; 6 archived; 7 public boxer with 0 points; 8 coach.
INSERT INTO public.profiles(id,auth_user_id,display_name,role,is_active,is_listed,archived_at) VALUES
 ('00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','Admin','admin',true,true,null),
 ('00000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000002','Anna','boxer',true,true,null),
 ('00000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000003','Ben','boxer',true,true,null),
 ('00000000-0000-0000-0000-000000000004','10000000-0000-0000-0000-000000000004','Unlisted','boxer',true,false,null),
 ('00000000-0000-0000-0000-000000000005',null,'Inaktiv','boxer',false,false,null),
 ('00000000-0000-0000-0000-000000000006',null,'Archiviert','boxer',false,false,now()),
 ('00000000-0000-0000-0000-000000000007',null,'Null','boxer',true,true,null),
 ('00000000-0000-0000-0000-000000000008','10000000-0000-0000-0000-000000000008','Coach','coach',true,true,null);

-- Notifications off while seeding: no level-up rows for the fixture history.
UPDATE public.league_feature_flags SET is_enabled=false WHERE feature_key='notifications';
INSERT INTO public.point_transactions(boxer_id,points,exp,category,effective_date) VALUES
 ('00000000-0000-0000-0000-000000000002',100,50,'adjustment','2026-09-10'),
 ('00000000-0000-0000-0000-000000000003',50,20,'adjustment','2026-09-11'),
 ('00000000-0000-0000-0000-000000000004',300,90,'adjustment','2026-09-12'),
 ('00000000-0000-0000-0000-000000000005',200,80,'adjustment','2026-09-12'),
 ('00000000-0000-0000-0000-000000000006',250,80,'adjustment','2026-09-12'),
 ('00000000-0000-0000-0000-000000000008',400,80,'adjustment','2026-09-12');
UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='notifications';

SELECT set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',false);

-- Season close: only public boxers, no title for 0 points, notifications for ranked boxers.
INSERT INTO public.league_seasons_v21(id,title,starts_on,ends_on,status) VALUES
 ('20000000-0000-0000-0000-000000000001','Sept 2026','2026-09-01','2026-09-30','active');
SELECT league_v21_private.season_transition_core('20000000-0000-0000-0000-000000000001','close');
DO $t$
DECLARE names text; hof text;
BEGIN
 SELECT string_agg(boxer_name||'#'||rank_position,',' ORDER BY rank_position,boxer_name) INTO names
 FROM public.league_season_results_v21 WHERE season_id='20000000-0000-0000-0000-000000000001';
 IF names<>'Anna#1,Ben#2,Null#3' THEN RAISE EXCEPTION 'Season snapshot must only list public boxers, got %',names; END IF;
 SELECT string_agg(boxer_name||'='||title,',' ORDER BY title) INTO hof
 FROM public.league_hall_of_fame_v21 WHERE season_id='20000000-0000-0000-0000-000000000001';
 IF hof IS DISTINCT FROM 'Anna=Saisonmeister,Ben=Vizechampion' THEN
  RAISE EXCEPTION 'Hall of fame must skip 0-point and non-public boxers, got %',hof; END IF;
 IF (SELECT count(*) FROM public.boxer_notifications WHERE notification_type='season')<>3 THEN
  RAISE EXCEPTION 'Season notifications expected for the 3 ranked boxers'; END IF;
END $t$;

-- Zero-point tie: a quiet season must not crown everybody.
INSERT INTO public.league_seasons_v21(id,title,starts_on,ends_on,status) VALUES
 ('20000000-0000-0000-0000-000000000002','Ruhige Saison','2026-08-01','2026-08-31','active');
SELECT league_v21_private.season_transition_core('20000000-0000-0000-0000-000000000002','close');
DO $t$ BEGIN
 IF EXISTS(SELECT 1 FROM public.league_hall_of_fame_v21 WHERE season_id='20000000-0000-0000-0000-000000000002') THEN
  RAISE EXCEPTION 'Season without points must not create hall-of-fame titles'; END IF;
END $t$;

-- League challenge: edit without legacy flag, close pays everybody, non-public shown as "Privates Profil".
INSERT INTO public.league_global_challenges_v21(id,title,metric,target_value,starts_at,ends_at,status,created_by,completion_exp,winner_exp) VALUES
 ('30000000-0000-0000-0000-000000000001','Jab Test','training_sessions',1,now()-interval '3 hours',now()+interval '1 day','active','00000000-0000-0000-0000-000000000001',20,30);
SELECT league_v21_private.global_edit_core('30000000-0000-0000-0000-000000000001','Jab Test neu','Neu',null,null,null,null,false);
INSERT INTO public.league_global_entries_v21(challenge_id,boxer_id,joined_at) VALUES
 ('30000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002',now()-interval '2 hours'),
 ('30000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000004',now()-interval '2 hours');
UPDATE public.league_global_challenges_v21 SET ends_at=now()-interval '1 minute' WHERE id='30000000-0000-0000-0000-000000000001';
INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,status,created_at) VALUES
 ('00000000-0000-0000-0000-000000000002',1,(now() AT TIME ZONE 'Europe/Zurich')::date,'approved',now()-interval '90 minutes'),
 ('00000000-0000-0000-0000-000000000004',1,(now() AT TIME ZONE 'Europe/Zurich')::date,'approved',now()-interval '80 minutes'),
 ('00000000-0000-0000-0000-000000000004',2,(now() AT TIME ZONE 'Europe/Zurich')::date,'approved',now()-interval '70 minutes');
SELECT league_v21_private.global_close_core('30000000-0000-0000-0000-000000000001');
DO $t$
DECLARE names text; paid integer;
BEGIN
 IF (SELECT title FROM public.league_global_challenges_v21 WHERE id='30000000-0000-0000-0000-000000000001')<>'Jab Test neu' THEN
  RAISE EXCEPTION 'Edit without legacy flag failed'; END IF;
 SELECT string_agg(boxer_name||'#'||rank_position,',' ORDER BY rank_position) INTO names
 FROM public.league_global_results_v21 WHERE challenge_id='30000000-0000-0000-0000-000000000001';
 IF names<>'Privates Profil#1,Anna#2' THEN RAISE EXCEPTION 'Challenge results must mask non-public names, got %',names; END IF;
 SELECT sum(exp_amount) INTO paid FROM public.league_global_exp_ledger_v21 WHERE challenge_id='30000000-0000-0000-0000-000000000001';
 IF paid<>70 THEN RAISE EXCEPTION 'Payout changed: expected 70 EXP, got %',paid; END IF;
 IF (SELECT count(*) FROM public.boxer_notifications WHERE notification_type='league_challenge')<>2 THEN
  RAISE EXCEPTION 'Every participant needs a challenge result notification'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.boxer_notifications WHERE notification_type='league_challenge'
   AND recipient_id='00000000-0000-0000-0000-000000000004' AND message LIKE '%+50 EXP%') THEN
  RAISE EXCEPTION 'Winner notification must show the EXP reward'; END IF;
END $t$;

-- Records: only public boxers.
SELECT league_v21_private.refresh_public_records_core(25,null);
DO $t$ BEGIN
 IF EXISTS(SELECT 1 FROM public.league_public_records_v21 r JOIN public.profiles p ON p.id=r.boxer_id WHERE NOT (p.is_active AND p.is_listed AND p.archived_at IS NULL)) THEN
  RAISE EXCEPTION 'Records were written for a non-public boxer'; END IF;
 IF (SELECT count(*) FROM public.league_public_records_v21)<>3 THEN RAISE EXCEPTION 'Expected records for the 3 public boxers'; END IF;
END $t$;

-- Badges: non-public stays private, becomes public on listing; achievement notification once.
INSERT INTO public.achievement_definitions(id,code,title) VALUES ('40000000-0000-0000-0000-000000000001','training_10','Training Warrior – Bronze');
INSERT INTO public.boxer_achievements(boxer_id,achievement_id,metadata) VALUES
 ('00000000-0000-0000-0000-000000000004','40000000-0000-0000-0000-000000000001','{"reward_exp":25}'),
 ('00000000-0000-0000-0000-000000000002','40000000-0000-0000-0000-000000000001','{"reward_exp":25}');
DO $t$ BEGIN
 IF EXISTS(SELECT 1 FROM public.league_public_badges_v21 WHERE boxer_id='00000000-0000-0000-0000-000000000004') THEN
  RAISE EXCEPTION 'Unlisted boxer badge became public'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.league_public_badges_v21 WHERE boxer_id='00000000-0000-0000-0000-000000000002') THEN
  RAISE EXCEPTION 'Public boxer badge missing'; END IF;
END $t$;
UPDATE public.profiles SET is_listed=true WHERE id='00000000-0000-0000-0000-000000000004';
DELETE FROM public.boxer_achievements WHERE boxer_id='00000000-0000-0000-0000-000000000002';
INSERT INTO public.boxer_achievements(boxer_id,achievement_id,metadata) VALUES
 ('00000000-0000-0000-0000-000000000002','40000000-0000-0000-0000-000000000001','{"reward_exp":25}');
DO $t$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.league_public_badges_v21 WHERE boxer_id='00000000-0000-0000-0000-000000000004') THEN
  RAISE EXCEPTION 'Badges must appear once the boxer is public'; END IF;
 IF (SELECT count(*) FROM public.boxer_notifications WHERE notification_type='achievement' AND recipient_id='00000000-0000-0000-0000-000000000002')<>1 THEN
  RAISE EXCEPTION 'Re-earned achievement must not notify twice'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.boxer_notifications WHERE notification_type='achievement' AND message LIKE '+25 EXP.%') THEN
  RAISE EXCEPTION 'Achievement notification must show the reward'; END IF;
END $t$;
UPDATE public.profiles SET is_listed=false WHERE id='00000000-0000-0000-0000-000000000004';

-- Duel history: non-public names masked.
INSERT INTO public.league_duels(id,challenger_id,opponent_id,status) VALUES
 ('50000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000004','active');
UPDATE public.league_duels SET status='settled',settled_at=now(),challenger_score=30,opponent_score=20,
 winner_id='00000000-0000-0000-0000-000000000002' WHERE id='50000000-0000-0000-0000-000000000001';
DO $t$ BEGIN
 IF (SELECT challenger_name||'/'||opponent_name FROM public.league_public_duel_history_v21 WHERE duel_id='50000000-0000-0000-0000-000000000001')<>'Anna/Privates Profil' THEN
  RAISE EXCEPTION 'Duel history must mask non-public names'; END IF;
END $t$;

-- Level-up: crossing levels notifies once per level, rank change named; no notification on EXP decrease or flag off.
DELETE FROM public.boxer_notifications WHERE notification_type='level_up';
-- Ben has 20 EXP (+ achievements none). +300 EXP -> 320 EXP = level 3 (start 225).
INSERT INTO public.point_transactions(boxer_id,points,exp,category) VALUES ('00000000-0000-0000-0000-000000000003',0,300,'adjustment');
DO $t$ DECLARE t text; BEGIN
 SELECT string_agg(title,',' ORDER BY title) INTO t FROM public.boxer_notifications WHERE notification_type='level_up' AND recipient_id='00000000-0000-0000-0000-000000000003';
 IF t<>'Level 2 erreicht,Level 3 erreicht' THEN RAISE EXCEPTION 'Level-up notifications wrong: %',t; END IF;
END $t$;
UPDATE public.point_transactions SET exp=0 WHERE boxer_id='00000000-0000-0000-0000-000000000003' AND exp=300;
UPDATE public.point_transactions SET exp=300 WHERE boxer_id='00000000-0000-0000-0000-000000000003' AND exp=0 AND category='adjustment' AND points=0;
DO $t$ BEGIN
 IF (SELECT count(*) FROM public.boxer_notifications WHERE notification_type='level_up' AND recipient_id='00000000-0000-0000-0000-000000000003')<>2 THEN
  RAISE EXCEPTION 'Re-reaching a level must not notify twice'; END IF;
END $t$;
-- Anna has 50 + 20 (challenge) EXP; +2400 -> 2470 EXP = level 11 (start 2'125), rank E.
INSERT INTO public.point_transactions(boxer_id,points,exp,category) VALUES ('00000000-0000-0000-0000-000000000002',0,2400,'adjustment');
DO $t$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.boxer_notifications WHERE recipient_id='00000000-0000-0000-0000-000000000002'
   AND title='Level 11 erreicht' AND message LIKE 'Neuer Rang: E · Prospect%') THEN
  RAISE EXCEPTION 'Rank change must be announced at level 11'; END IF;
 IF (SELECT count(*) FROM public.boxer_notifications WHERE recipient_id='00000000-0000-0000-0000-000000000002' AND notification_type='level_up')<>5 THEN
  RAISE EXCEPTION 'Large jumps announce the 5 highest levels only'; END IF;
 IF EXISTS(SELECT 1 FROM public.boxer_notifications WHERE recipient_id='00000000-0000-0000-0000-000000000002' AND title='Level 6 erreicht') THEN
  RAISE EXCEPTION 'Lower skipped levels must not be announced'; END IF;
END $t$;
UPDATE public.league_feature_flags SET is_enabled=false WHERE feature_key='notifications';
INSERT INTO public.point_transactions(boxer_id,points,exp,category) VALUES ('00000000-0000-0000-0000-000000000003',0,5000,'adjustment');
DO $t$ BEGIN
 IF (SELECT count(*) FROM public.boxer_notifications WHERE notification_type='level_up' AND recipient_id='00000000-0000-0000-0000-000000000003')<>2 THEN
  RAISE EXCEPTION 'Notifications flag off must suppress level-up notifications'; END IF;
END $t$;
UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='notifications';

-- Training decision text uses umlauts.
INSERT INTO public.training_submissions(id,boxer_id,training_type_id,training_date) VALUES
 ('60000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000003',1,'2026-10-20');
UPDATE public.training_submissions SET status='approved' WHERE id='60000000-0000-0000-0000-000000000001';
DO $t$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.boxer_notifications WHERE title='Training bestätigt' AND message LIKE '%20.10.2026 wurde bestätigt.') THEN
  RAISE EXCEPTION 'Training notification umlauts missing'; END IF;
END $t$;

-- One level curve: RPC level/rank equals league_level_from_exp_v2 and the pages.
SELECT set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000002',false);
DO $t$ DECLARE r record; BEGIN
 SELECT * INTO r FROM public.get_boxer_exp_level_rank('00000000-0000-0000-0000-000000000002');
 -- Anna: 2470 EXP -> level 11 (start 2125, next 2475), rank E.
 IF r.lifetime_exp<>2470 OR r.level_number<>11 OR r.level_start_exp<>2125 OR r.next_level_exp<>2475
    OR r.exp_into_level<>345 OR r.exp_to_next_level<>5 OR r.rank_letter<>'E' THEN
  RAISE EXCEPTION 'Level RPC mismatch: %',row_to_json(r); END IF;
END $t$;

-- Grants: helpers and trigger functions are not callable by clients.
DO $t$ BEGIN
 IF has_function_privilege('anon','league_v21_private.notifications_enabled()','execute')
    OR has_function_privilege('authenticated','league_v21_private.public_display_name(uuid)','execute')
    OR has_function_privilege('authenticated','league_v21_private.notify_level_up()','execute')
    OR has_function_privilege('anon','public.get_boxer_exp_level_rank(uuid)','execute')
    OR NOT has_function_privilege('authenticated','public.get_boxer_exp_level_rank(uuid)','execute') THEN
  RAISE EXCEPTION 'Unexpected function grants'; END IF;
END $t$;

-- Idempotent.
\ir ../supabase/migrations/20261027120000_gamification_fairness_and_notifications.sql

SELECT 'PASS: public snapshots only for public boxers, no 0-point titles, masked challenge/duel names with unchanged payouts, edit without legacy flag, level/achievement/challenge/season notifications, one level curve' AS result;
