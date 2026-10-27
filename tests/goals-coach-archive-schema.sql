\set ON_ERROR_STOP on
-- Disposable-database test for 20261028100000_goals_coach_archive.sql.
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE ROLE anon;
CREATE ROLE authenticated;
CREATE SCHEMA auth;
CREATE SCHEMA league_v21_private;
CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE
AS $$ SELECT NULLIF(current_setting('request.jwt.claim.sub', true),'')::uuid $$;

CREATE TABLE public.profiles(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), auth_user_id uuid UNIQUE, display_name text NOT NULL,
 role text NOT NULL DEFAULT 'boxer', is_active boolean NOT NULL DEFAULT true, is_listed boolean NOT NULL DEFAULT true, archived_at timestamptz);
CREATE TABLE public.league_feature_flags(feature_key text PRIMARY KEY, is_enabled boolean NOT NULL DEFAULT false);
CREATE TABLE public.boxer_notifications(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), recipient_id uuid NOT NULL REFERENCES public.profiles(id),
 notification_type text NOT NULL CHECK (notification_type = ANY (ARRAY['training_approved','training_rejected','coach_feedback','coach_goal',
  'league_challenge','boxer_duel','achievement','season','general','level_up'])),
 title text NOT NULL CHECK (char_length(btrim(title)) BETWEEN 1 AND 160), message text NOT NULL DEFAULT '', target_path text, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.training_submissions(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), boxer_id uuid NOT NULL, training_type_id bigint NOT NULL DEFAULT 1,
 training_date date NOT NULL, status text NOT NULL DEFAULT 'pending', jogging_km numeric, technique_minutes integer);
CREATE TABLE public.point_transactions(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), boxer_id uuid NOT NULL, submission_id uuid, points integer NOT NULL DEFAULT 0,
 exp integer NOT NULL DEFAULT 0, category text NOT NULL, description text, effective_date date NOT NULL DEFAULT current_date, created_by uuid);
CREATE TABLE public.league_boxer_goals_v21(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), boxer_id uuid NOT NULL REFERENCES public.profiles(id),
 title text NOT NULL, metric text NOT NULL CHECK (metric IN ('training_sessions','jogging_km','technique_minutes','custom')),
 target_value numeric NOT NULL CHECK (target_value>0), starts_on date NOT NULL DEFAULT current_date, ends_on date NOT NULL,
 status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','completed','archived')), reward_exp integer NOT NULL DEFAULT 0,
 manual_progress numeric NOT NULL DEFAULT 0, created_by uuid NOT NULL, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.league_goal_progress_v21(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), goal_id uuid NOT NULL REFERENCES public.league_boxer_goals_v21(id),
 progress_delta numeric NOT NULL CHECK (progress_delta>0), recorded_by uuid NOT NULL, note text, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.league_goal_exp_ledger_v21(goal_id uuid PRIMARY KEY, boxer_id uuid NOT NULL, transaction_id uuid, exp_amount integer NOT NULL);
ALTER TABLE public.league_boxer_goals_v21 ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION league_v21_private.notifications_enabled() RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=''
AS $fn$ SELECT EXISTS(SELECT 1 FROM public.league_feature_flags f WHERE f.feature_key='notifications' AND f.is_enabled IS TRUE) $fn$;
-- Pre-existing policy (replaced by the migration).
CREATE POLICY "Owner or admin reads goals" ON public.league_boxer_goals_v21 FOR SELECT TO authenticated USING (true);

\ir ../supabase/migrations/20261028100000_goals_coach_archive.sql

-- Existing production wrappers and trigger (unchanged by the migration).
CREATE FUNCTION public.league_v21_save_goal(p_goal_id uuid, p_boxer_id uuid, p_title text, p_metric text, p_target numeric, p_end_date date)
RETURNS uuid LANGUAGE sql SET search_path='' AS $fn$ select league_v21_private.goal_upsert_core(p_goal_id,p_boxer_id,p_title,p_metric,p_target,p_end_date) $fn$;
CREATE FUNCTION public.league_v21_record_goal_progress(p_goal uuid, p_delta numeric, p_note text)
RETURNS uuid LANGUAGE sql SET search_path='' AS $fn$ select league_v21_private.goal_progress_core(p_goal,p_delta,p_note) $fn$;
CREATE FUNCTION public.league_v21_complete_goal(p_goal uuid)
RETURNS jsonb LANGUAGE sql SET search_path='' AS $fn$ select league_v21_private.complete_and_reward_goal_core(p_goal) $fn$;
CREATE TRIGGER league_v21_goal_after_training_review AFTER UPDATE ON public.training_submissions
 FOR EACH ROW EXECUTE FUNCTION league_v21_private.goal_after_training_review();

INSERT INTO public.league_feature_flags VALUES ('notifications',true);
INSERT INTO public.profiles(id,auth_user_id,display_name,role) VALUES
 ('00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','Admin','admin'),
 ('00000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000002','Anna','boxer'),
 ('00000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000003','Ben','boxer'),
 ('00000000-0000-0000-0000-000000000004','10000000-0000-0000-0000-000000000004','Coach','coach');

-- Coach assigns goals (automatic + manual) to Anna.
SELECT set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000004',false);
SELECT set_config('test.auto',public.league_v21_save_goal(null,'00000000-0000-0000-0000-000000000002','2 Trainings','training_sessions',2,current_date+7)::text,false);
SELECT set_config('test.manual',public.league_v21_save_goal(null,'00000000-0000-0000-0000-000000000002','Seilspringen 30 Min','custom',30,current_date+7)::text,false);
-- Anna: own manual goal, cannot rewrite or self-confirm the coach's goal, cannot archive it.
SELECT set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000002',false);
SELECT set_config('test.own',public.league_v21_save_goal(null,'00000000-0000-0000-0000-000000000002','Eigenes Ziel','custom',5,current_date+7)::text,false);
SELECT public.league_v21_record_goal_progress(current_setting('test.own')::uuid,5,'erledigt');
DO $t$ BEGIN
 BEGIN PERFORM public.league_v21_record_goal_progress(current_setting('test.manual')::uuid,30,null); RAISE EXCEPTION 'self-confirm ok';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.league_v21_save_goal(current_setting('test.manual')::uuid,'00000000-0000-0000-0000-000000000002','Umgeschrieben','custom',1,current_date+7);
  RAISE EXCEPTION 'boxer rewrite ok'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.league_v21_archive_goal(current_setting('test.manual')::uuid); RAISE EXCEPTION 'boxer archive assigned ok';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.league_v21_save_goal(null,'00000000-0000-0000-0000-000000000003','Fremd','custom',1,current_date+7); RAISE EXCEPTION 'foreign goal ok';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $t$;
SELECT public.league_v21_complete_goal(current_setting('test.own')::uuid);
DO $t$ BEGIN
 IF (SELECT status FROM public.league_boxer_goals_v21 WHERE id=current_setting('test.own')::uuid)<>'completed' THEN RAISE EXCEPTION 'own goal not completed'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.boxer_notifications WHERE notification_type='coach_goal' AND title='Ziel erreicht: Eigenes Ziel' AND message='Stark, weiter so!') THEN
  RAISE EXCEPTION 'goal notification missing'; END IF;
END $t$;
SELECT public.league_v21_archive_goal(current_setting('test.own')::uuid);

-- Coach confirms manual progress; admin sets EXP on the automatic goal; coach approval completes it with EXP once.
SELECT set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000004',false);
SELECT public.league_v21_record_goal_progress(current_setting('test.manual')::uuid,30,'bestätigt');
SELECT public.league_v21_complete_goal(current_setting('test.manual')::uuid);
SELECT set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',false);
UPDATE public.league_boxer_goals_v21 SET reward_exp=50 WHERE id=current_setting('test.auto')::uuid;
INSERT INTO public.training_submissions(id,boxer_id,training_date,status) VALUES
 ('50000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002',current_date,'pending'),
 ('50000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000002',current_date,'pending');
SELECT set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000004',false);
UPDATE public.training_submissions SET status='approved';
DO $t$ BEGIN
 IF (SELECT status FROM public.league_boxer_goals_v21 WHERE id=current_setting('test.auto')::uuid)<>'completed' THEN RAISE EXCEPTION 'coach approval did not reconcile goal'; END IF;
 IF (SELECT sum(exp) FROM public.point_transactions WHERE description='Personal goal reward: '||current_setting('test.auto'))<>50 THEN RAISE EXCEPTION 'EXP not exactly once'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.boxer_notifications WHERE title='Ziel erreicht: 2 Trainings' AND message LIKE '+50 EXP.%') THEN RAISE EXCEPTION 'reward notification missing'; END IF;
 IF (SELECT status FROM public.league_boxer_goals_v21 WHERE id=current_setting('test.manual')::uuid)<>'completed' THEN RAISE EXCEPTION 'manual goal not completed by coach'; END IF;
END $t$;
-- Re-check is idempotent: no second payout, no second notification.
SELECT public.league_v21_complete_goal(current_setting('test.auto')::uuid);
DO $t$ BEGIN
 IF (SELECT count(*) FROM public.point_transactions)<>1 OR (SELECT count(*) FROM public.boxer_notifications WHERE title='Ziel erreicht: 2 Trainings')<>1 THEN
  RAISE EXCEPTION 'not idempotent'; END IF;
END $t$;
-- Coach archives the completed goal: EXP stays booked.
SELECT public.league_v21_archive_goal(current_setting('test.auto')::uuid);
DO $t$ BEGIN
 IF (SELECT status FROM public.league_boxer_goals_v21 WHERE id=current_setting('test.auto')::uuid)<>'archived' THEN RAISE EXCEPTION 'archive failed'; END IF;
 IF (SELECT sum(exp) FROM public.point_transactions)<>50 THEN RAISE EXCEPTION 'archive changed EXP'; END IF;
 IF (public.league_v21_archive_goal(current_setting('test.auto')::uuid)->>'unchanged')<>'true' THEN RAISE EXCEPTION 'archive not idempotent'; END IF;
 IF has_function_privilege('anon','public.league_v21_archive_goal(uuid)','execute')
    OR has_function_privilege('authenticated','league_v21_private.notify_goal_completed(uuid,integer)','execute') THEN RAISE EXCEPTION 'grants'; END IF;
END $t$;

\ir ../supabase/migrations/20261028100000_goals_coach_archive.sql
SELECT 'PASS: coach assigns/confirms goals, boxers cannot self-confirm or rewrite assigned goals, coach approvals reconcile goals, EXP once, completion notification, archive keeps EXP' AS result;
