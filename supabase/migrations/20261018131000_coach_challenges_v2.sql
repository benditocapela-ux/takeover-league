-- Takeover League 2.0 | Coach Challenges V2 production migration.
-- GENERATED from individually reviewed/tested production-prep SQL modules.
-- SAFE-DEFAULT: two feature flags remain disabled. Does not modify real challenge or boxer point rows.
-- APPLY ONLY AFTER EXPLICIT RELEASE APPROVAL AND DATA BACKUP.
BEGIN;
DO $preflight$
BEGIN
 IF pg_catalog.to_regnamespace('league_private') IS NOT NULL
 THEN RAISE EXCEPTION 'Private league schema already exists; review migration collision'; END IF;
 IF EXISTS (SELECT 1 FROM pg_catalog.pg_proc p
 JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.proname LIKE 'coach_challenge_v2_%')
 THEN RAISE EXCEPTION 'V2 RPC names already exist; review migration collision'; END IF;
 IF pg_catalog.to_regclass('public.league_coach_challenges') IS NOT NULL
 OR pg_catalog.to_regclass('public.league_coach_challenge_entries') IS NOT NULL
 OR pg_catalog.to_regclass('public.league_coach_challenge_reviews') IS NOT NULL
 OR pg_catalog.to_regclass('public.league_coach_challenge_exp_ledger') IS NOT NULL
 THEN RAISE EXCEPTION 'V2 challenge tables already exist; review schema collision'; END IF;
END $preflight$;

-- 1. 20261018_allow_coach_role.sql
-- PREPARED ONLY: allow coach role for V2 challenge administration.
-- Existing profiles and their roles remain unchanged.

DO $$
DECLARE c record;
BEGIN
 SELECT conname,pg_get_constraintdef(oid) AS definition INTO c
 FROM pg_constraint WHERE conrelid='public.profiles'::regclass
 AND contype='c' AND pg_get_constraintdef(oid) LIKE '%role%'
 LIMIT 1;
 IF c.conname IS NULL OR c.definition NOT LIKE '%boxer%'
 OR c.definition NOT LIKE '%admin%' THEN
  RAISE EXCEPTION 'Unexpected profiles role constraint; abort';
 END IF;
 EXECUTE format('ALTER TABLE public.profiles DROP CONSTRAINT %I',c.conname);
END $$;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_role_check
CHECK (role IN ('boxer','admin','coach'));

-- Verification: SELECT role,count(*) FROM public.profiles GROUP BY role;

-- 2. 20261018_extend_transaction_categories.sql
-- Takeover League 2.0: production transaction category compatibility
-- PREPARED ONLY. Do not run until the full V2 migration is reviewed.
-- This preserves existing rows and existing accepted categories.

DO $$
DECLARE actual text; expected text;
BEGIN
 SELECT pg_get_constraintdef(c.oid) INTO actual FROM pg_constraint c
 WHERE c.conrelid='public.point_transactions'::regclass
 AND c.conname='point_transactions_category_check' AND c.contype='c';
 IF actual IS NULL THEN
  RAISE EXCEPTION 'Missing category constraint; abort migration';
 END IF;
 IF actual NOT LIKE '%achievement_exp%' OR actual NOT LIKE '%automatic_bonus%'
    OR actual NOT LIKE '%legacy_import%' THEN
  RAISE EXCEPTION 'Unexpected transaction category constraint: %',actual;
 END IF;
 IF EXISTS (SELECT 1 FROM public.point_transactions WHERE category NOT IN
 ('training','trainer_bonus','adjustment','legacy_import','automatic_bonus','achievement_exp','duel_exp','challenge_exp')) THEN
  RAISE EXCEPTION 'Unknown existing category; abort migration';
 END IF;
END $$;
ALTER TABLE public.point_transactions DROP CONSTRAINT point_transactions_category_check;
ALTER TABLE public.point_transactions ADD CONSTRAINT point_transactions_category_check
CHECK (category IN ('training','trainer_bonus','adjustment','legacy_import','automatic_bonus','achievement_exp','duel_exp','challenge_exp'));

-- Verification: SELECT category,count(*) FROM public.point_transactions GROUP BY category;

-- 3. 20261018_v2_feature_flags_disabled.sql
-- PREPARED ONLY: introduce separate V2 feature gates without enabling them.
-- Preserve legacy boxer_duels and league_challenges keys.

DO $$
BEGIN
 IF to_regclass('public.league_feature_flags') IS NULL THEN
  RAISE EXCEPTION 'Feature flags table missing';
 END IF;
END $$;
INSERT INTO public.league_feature_flags(feature_key,display_name,is_enabled)
VALUES
 ('coach_challenges','Coach Challenges V2',false),
 ('duels','Duels V2',false)
ON CONFLICT(feature_key) DO NOTHING;
DO $$
BEGIN
 IF EXISTS(SELECT 1 FROM public.league_feature_flags
 WHERE feature_key IN ('coach_challenges','duels') AND is_enabled) THEN
  RAISE EXCEPTION 'V2 feature unexpectedly enabled; manual review required';
 END IF;
END $$;

-- 4. 20261018_coach_challenges_v2_schema.sql
-- Coach Challenges V2 schema. PREPARED ONLY; do not apply to production yet.

CREATE TABLE public.league_coach_challenges (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 created_by uuid NOT NULL REFERENCES public.profiles(id),
 title text NOT NULL CHECK (char_length(btrim(title)) BETWEEN 3 AND 120),
 description text NOT NULL DEFAULT '',
 challenge_kind text NOT NULL CHECK (challenge_kind IN ('individual','competition','coach_goal')),
 duration_days integer NOT NULL CHECK (duration_days IN (7,14,30)),
 goal_spec jsonb,
 status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','open','active','awaiting_reviews','settled','cancelled')),
 created_at timestamptz NOT NULL DEFAULT now(),
 starts_at timestamptz,
 ends_at timestamptz,
 settled_at timestamptz,
 updated_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT coach_challenge_dates_valid CHECK (starts_at IS NULL OR ends_at IS NULL OR ends_at > starts_at),
 CONSTRAINT coach_challenge_settlement_dates_valid CHECK (settled_at IS NULL OR ends_at IS NOT NULL)
);
CREATE TABLE public.league_coach_challenge_entries (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 challenge_id uuid NOT NULL REFERENCES public.league_coach_challenges(id),
 boxer_id uuid NOT NULL REFERENCES public.profiles(id),
 joined_at timestamptz NOT NULL DEFAULT now(),
 status text NOT NULL DEFAULT 'joined' CHECK (status IN ('joined','withdrawn','completed')),
 UNIQUE(challenge_id,boxer_id)
);
CREATE TABLE public.league_coach_challenge_reviews (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 challenge_id uuid NOT NULL REFERENCES public.league_coach_challenges(id),
 boxer_id uuid NOT NULL REFERENCES public.profiles(id),
 reviewed_by uuid NOT NULL REFERENCES public.profiles(id),
 approved boolean NOT NULL,
 reason text NOT NULL CHECK (char_length(btrim(reason)) BETWEEN 5 AND 1000),
 reviewed_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(challenge_id,boxer_id)
);
CREATE TABLE public.league_coach_challenge_exp_ledger (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 challenge_id uuid NOT NULL REFERENCES public.league_coach_challenges(id),
 boxer_id uuid NOT NULL REFERENCES public.profiles(id),
 transaction_id uuid UNIQUE REFERENCES public.point_transactions(id),
 awarded_exp integer NOT NULL DEFAULT 0 CHECK (awarded_exp IN (0,25,50,100,150,200)),
 updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(challenge_id,boxer_id)
);
CREATE INDEX league_coach_challenges_creator_status_idx ON public.league_coach_challenges(created_by,status);
CREATE INDEX league_coach_challenges_status_dates_idx ON public.league_coach_challenges(status,ends_at);
CREATE INDEX league_coach_challenge_entries_boxer_idx ON public.league_coach_challenge_entries(boxer_id,status);
CREATE INDEX league_coach_challenge_reviews_reviewer_idx ON public.league_coach_challenge_reviews(reviewed_by);
CREATE INDEX league_coach_challenge_exp_ledger_boxer_idx ON public.league_coach_challenge_exp_ledger(boxer_id);
-- RLS blocks ordinary roles; table owners and BYPASSRLS roles are exempt unless FORCE RLS is enabled.
ALTER TABLE public.league_coach_challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.league_coach_challenge_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.league_coach_challenge_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.league_coach_challenge_exp_ledger ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.league_coach_challenges,public.league_coach_challenge_entries,
 public.league_coach_challenge_reviews,public.league_coach_challenge_exp_ledger FROM PUBLIC,anon,authenticated;

-- No policies: access is through audited SECURITY DEFINER RPCs only.

-- 5. 20261018_coach_challenges_v2_rpc_core.sql
-- Coach Challenges V2: production-oriented RPC implementation (part 1/2).
-- PREPARED ONLY. Requires the four V2 tables and disabled V2 feature flags.
-- All public functions use SECURITY DEFINER with explicit actor/owner checks.
-- Do not deploy to production until integration and role tests pass.

CREATE SCHEMA league_private;
REVOKE ALL ON SCHEMA league_private FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION league_private.coach_v2_actor()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $func$
DECLARE v_actor jsonb;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.league_feature_flags
                WHERE feature_key='coach_challenges' AND is_enabled IS TRUE)
 THEN RAISE EXCEPTION 'Coach Challenges not enabled' USING ERRCODE='42501'; END IF;
 SELECT pg_catalog.jsonb_build_object('id',p.id,'role',p.role) INTO v_actor
 FROM public.profiles p WHERE p.auth_user_id=auth.uid() AND p.is_active IS TRUE;
 IF v_actor IS NULL OR (v_actor->>'role') NOT IN ('boxer','coach','admin')
 THEN RAISE EXCEPTION 'Active league profile required' USING ERRCODE='42501'; END IF;
 RETURN v_actor;
END
$func$;
REVOKE ALL ON FUNCTION league_private.coach_v2_actor() FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.coach_challenge_v2_create_draft(
 p_title text,p_description text,p_kind text,p_duration_days integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $func$
DECLARE a jsonb:=league_private.coach_v2_actor(); v_id uuid;
BEGIN
 IF a->>'role' NOT IN ('coach','admin') THEN RAISE EXCEPTION 'Coach role required' USING ERRCODE='42501'; END IF;
 IF char_length(pg_catalog.btrim(COALESCE(p_title,''))) NOT BETWEEN 3 AND 120 OR
    p_kind NOT IN ('individual','competition','coach_goal') OR p_kind IS NULL OR
    p_duration_days NOT IN (7,14,30) OR p_duration_days IS NULL
 THEN RAISE EXCEPTION 'Invalid challenge title, kind or duration' USING ERRCODE='22023'; END IF;
 INSERT INTO public.league_coach_challenges(created_by,title,description,challenge_kind,duration_days)
 VALUES((a->>'id')::uuid,pg_catalog.btrim(p_title),COALESCE(p_description,''),p_kind,p_duration_days)
 RETURNING id INTO v_id;
 RETURN pg_catalog.jsonb_build_object('id',v_id,'status','draft');
END
$func$;

CREATE OR REPLACE FUNCTION public.coach_challenge_v2_edit_draft(
 p_id uuid,p_title text,p_description text,p_kind text,p_days integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $func$
DECLARE a jsonb:=league_private.coach_v2_actor(); c public.league_coach_challenges%ROWTYPE;
BEGIN
 IF a->>'role' NOT IN ('coach','admin') THEN RAISE EXCEPTION 'Coach role required' USING ERRCODE='42501'; END IF;
 IF char_length(pg_catalog.btrim(COALESCE(p_title,''))) NOT BETWEEN 3 AND 120 OR
    p_kind NOT IN ('individual','competition','coach_goal') OR p_kind IS NULL OR
    p_days NOT IN (7,14,30) OR p_days IS NULL
 THEN RAISE EXCEPTION 'Invalid challenge data' USING ERRCODE='22023'; END IF;
 SELECT * INTO c FROM public.league_coach_challenges WHERE id=p_id FOR UPDATE;
 IF c.id IS NULL THEN RAISE EXCEPTION 'Challenge not found' USING ERRCODE='P0002'; END IF;
 IF (a->>'role') <> 'admin' AND c.created_by <> (a->>'id')::uuid
 THEN RAISE EXCEPTION 'Not challenge owner' USING ERRCODE='42501'; END IF;
 IF c.status <> 'draft' THEN RAISE EXCEPTION 'Only drafts can be edited' USING ERRCODE='22023'; END IF;
 UPDATE public.league_coach_challenges SET title=pg_catalog.btrim(p_title),
 description=COALESCE(p_description,''),challenge_kind=p_kind,duration_days=p_days,updated_at=now()
 WHERE id=c.id;
 RETURN pg_catalog.jsonb_build_object('id',c.id,'status','draft');
END
$func$;

CREATE OR REPLACE FUNCTION public.coach_challenge_v2_save_goal_reward(
 p_challenge_id uuid,p_goal_text text,p_review_mode text,p_reward_exp integer,
 p_target_value numeric,p_metric text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $func$
DECLARE a jsonb:=league_private.coach_v2_actor(); c public.league_coach_challenges%ROWTYPE;
BEGIN
 IF a->>'role' NOT IN ('coach','admin') THEN RAISE EXCEPTION 'Coach role required' USING ERRCODE='42501'; END IF;
 SELECT * INTO c FROM public.league_coach_challenges WHERE id=p_challenge_id FOR UPDATE;
 IF c.id IS NULL THEN RAISE EXCEPTION 'Challenge not found' USING ERRCODE='P0002'; END IF;
 IF a->>'role'<>'admin' AND c.created_by<>(a->>'id')::uuid
 THEN RAISE EXCEPTION 'Not challenge owner' USING ERRCODE='42501'; END IF;
 IF c.status<>'draft' THEN RAISE EXCEPTION 'Goal locked after publication' USING ERRCODE='22023'; END IF;
 IF char_length(pg_catalog.btrim(COALESCE(p_goal_text,''))) NOT BETWEEN 5 AND 1000
 OR p_review_mode IS DISTINCT FROM 'manual'
 OR p_reward_exp NOT IN (25,50,100,150,200) OR p_reward_exp IS NULL
 OR (p_target_value IS NOT NULL AND p_target_value<=0)
 THEN RAISE EXCEPTION 'Invalid manual goal or EXP reward' USING ERRCODE='22023'; END IF;
 UPDATE public.league_coach_challenges SET
 goal_spec=pg_catalog.jsonb_build_object('version',1,
 'goal_text',pg_catalog.btrim(p_goal_text),'review_mode',p_review_mode,
 'reward_exp',p_reward_exp,'target_value',p_target_value,'metric',p_metric),
 updated_at=now() WHERE id=c.id;
 RETURN pg_catalog.jsonb_build_object('id',c.id,'reward_exp',p_reward_exp,'review_mode','manual');
END
$func$;

CREATE OR REPLACE FUNCTION public.coach_challenge_v2_set_goal(
 p_challenge_id uuid,p_goal_text text,p_review_mode text,p_target_value numeric,p_metric text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $func$
DECLARE a jsonb:=league_private.coach_v2_actor(); c public.league_coach_challenges%ROWTYPE;
BEGIN
 IF a->>'role' NOT IN ('coach','admin') THEN RAISE EXCEPTION 'Coach role required' USING ERRCODE='42501'; END IF;
 SELECT * INTO c FROM public.league_coach_challenges WHERE id=p_challenge_id FOR UPDATE;
 IF c.id IS NULL THEN RAISE EXCEPTION 'Challenge not found' USING ERRCODE='P0002'; END IF;
 IF a->>'role'<>'admin' AND c.created_by<>(a->>'id')::uuid
 THEN RAISE EXCEPTION 'Not challenge owner' USING ERRCODE='42501'; END IF;
 IF c.status<>'draft' THEN RAISE EXCEPTION 'Goal locked after publication' USING ERRCODE='22023'; END IF;
 IF char_length(pg_catalog.btrim(COALESCE(p_goal_text,''))) NOT BETWEEN 5 AND 1000
 OR p_review_mode IS DISTINCT FROM 'manual'
 OR (p_target_value IS NOT NULL AND p_target_value<=0)
 THEN RAISE EXCEPTION 'Invalid goal definition' USING ERRCODE='22023'; END IF;
 UPDATE public.league_coach_challenges SET
 goal_spec=COALESCE(goal_spec,'{}'::jsonb) || pg_catalog.jsonb_build_object(
 'version',1,'goal_text',pg_catalog.btrim(p_goal_text),
 'review_mode','manual','target_value',p_target_value,'metric',p_metric),
 updated_at=now() WHERE id=c.id;
 RETURN pg_catalog.jsonb_build_object('id',c.id,'goal_text',pg_catalog.btrim(p_goal_text));
END
$func$;

CREATE OR REPLACE FUNCTION public.coach_challenge_v2_set_reward(
 p_challenge_id uuid,p_reward_exp integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $func$
DECLARE a jsonb:=league_private.coach_v2_actor(); c public.league_coach_challenges%ROWTYPE;
BEGIN
 IF a->>'role' NOT IN ('coach','admin') THEN RAISE EXCEPTION 'Coach role required' USING ERRCODE='42501'; END IF;
 SELECT * INTO c FROM public.league_coach_challenges WHERE id=p_challenge_id FOR UPDATE;
 IF c.id IS NULL THEN RAISE EXCEPTION 'Challenge not found' USING ERRCODE='P0002'; END IF;
 IF a->>'role'<>'admin' AND c.created_by<>(a->>'id')::uuid
 THEN RAISE EXCEPTION 'Not challenge owner' USING ERRCODE='42501'; END IF;
 IF c.status<>'draft' THEN RAISE EXCEPTION 'Reward locked after publication' USING ERRCODE='22023'; END IF;
 IF p_reward_exp IS NULL OR p_reward_exp NOT IN (25,50,100,150,200)
 THEN RAISE EXCEPTION 'Invalid EXP reward' USING ERRCODE='22023'; END IF;
 UPDATE public.league_coach_challenges
 SET goal_spec=COALESCE(goal_spec,'{}'::jsonb)||pg_catalog.jsonb_build_object('reward_exp',p_reward_exp),
 updated_at=now() WHERE id=c.id;
 RETURN pg_catalog.jsonb_build_object('id',c.id,'reward_exp',p_reward_exp);
END
$func$;

CREATE OR REPLACE FUNCTION public.coach_challenge_v2_manage(
 p_challenge_id uuid,p_action text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $func$
DECLARE a jsonb:=league_private.coach_v2_actor(); c public.league_coach_challenges%ROWTYPE; next_status text;
BEGIN
 IF a->>'role' NOT IN ('coach','admin') THEN RAISE EXCEPTION 'Coach role required' USING ERRCODE='42501'; END IF;
 SELECT * INTO c FROM public.league_coach_challenges WHERE id=p_challenge_id FOR UPDATE;
 IF c.id IS NULL THEN RAISE EXCEPTION 'Challenge not found' USING ERRCODE='P0002'; END IF;
 IF a->>'role'<>'admin' AND c.created_by<>(a->>'id')::uuid
 THEN RAISE EXCEPTION 'Not challenge owner' USING ERRCODE='42501'; END IF;
 IF p_action='open' AND c.status='draft' THEN
   IF pg_catalog.char_length(pg_catalog.btrim(COALESCE(c.goal_spec->>'goal_text','')))<5
   OR c.goal_spec->>'review_mode' IS DISTINCT FROM 'manual'
   OR COALESCE((c.goal_spec->>'reward_exp')::integer,0) NOT IN (25,50,100,150,200)
   THEN RAISE EXCEPTION 'Valid manual goal and reward required' USING ERRCODE='22023'; END IF;
   next_status:='open';
 ELSIF p_action='cancel' AND c.status IN ('draft','open') THEN next_status:='cancelled';
 ELSE RAISE EXCEPTION 'Unsupported action or status transition' USING ERRCODE='22023';
 END IF;
 UPDATE public.league_coach_challenges SET status=next_status,updated_at=now() WHERE id=c.id;
 RETURN pg_catalog.jsonb_build_object('id',c.id,'status',next_status);
END
$func$;

CREATE OR REPLACE FUNCTION public.coach_challenge_v2_join(p_challenge_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $func$
DECLARE a jsonb:=league_private.coach_v2_actor(); c public.league_coach_challenges%ROWTYPE; current_status text;
BEGIN
 IF a->>'role'<>'boxer' THEN RAISE EXCEPTION 'Boxer role required' USING ERRCODE='42501'; END IF;
 SELECT * INTO c FROM public.league_coach_challenges WHERE id=p_challenge_id FOR UPDATE;
 IF c.id IS NULL OR c.status<>'open' THEN RAISE EXCEPTION 'Challenge not open' USING ERRCODE='22023'; END IF;
 SELECT status INTO current_status FROM public.league_coach_challenge_entries
 WHERE challenge_id=c.id AND boxer_id=(a->>'id')::uuid FOR UPDATE;
 IF current_status='completed' THEN RAISE EXCEPTION 'Entry already completed' USING ERRCODE='22023'; END IF;
 IF current_status='withdrawn' THEN
 UPDATE public.league_coach_challenge_entries
 SET status='joined',joined_at=now() WHERE challenge_id=c.id AND boxer_id=(a->>'id')::uuid;
 ELSIF current_status IS NULL THEN
 INSERT INTO public.league_coach_challenge_entries(challenge_id,boxer_id)
 VALUES(c.id,(a->>'id')::uuid);
 END IF;
 RETURN pg_catalog.jsonb_build_object('challenge_id',c.id,'status','joined');
END
$func$;

CREATE OR REPLACE FUNCTION public.coach_challenge_v2_withdraw(p_challenge_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $func$
DECLARE a jsonb:=league_private.coach_v2_actor(); c public.league_coach_challenges%ROWTYPE;
BEGIN
 IF a->>'role'<>'boxer' THEN RAISE EXCEPTION 'Boxer role required' USING ERRCODE='42501'; END IF;
 SELECT * INTO c FROM public.league_coach_challenges WHERE id=p_challenge_id FOR UPDATE;
 IF c.id IS NULL OR c.status<>'open' THEN RAISE EXCEPTION 'Withdrawal no longer available' USING ERRCODE='22023'; END IF;
 UPDATE public.league_coach_challenge_entries SET status='withdrawn'
 WHERE challenge_id=c.id AND boxer_id=(a->>'id')::uuid AND status='joined';
 IF NOT FOUND THEN RAISE EXCEPTION 'No active enrollment' USING ERRCODE='22023'; END IF;
 RETURN pg_catalog.jsonb_build_object('challenge_id',c.id,'status','withdrawn');
END
$func$;

CREATE OR REPLACE FUNCTION public.coach_challenge_v2_activate(p_challenge_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $func$
DECLARE a jsonb:=league_private.coach_v2_actor(); c public.league_coach_challenges%ROWTYPE; started timestamptz:=pg_catalog.clock_timestamp();
BEGIN
 IF a->>'role' NOT IN ('coach','admin') THEN RAISE EXCEPTION 'Coach role required' USING ERRCODE='42501'; END IF;
 SELECT * INTO c FROM public.league_coach_challenges WHERE id=p_challenge_id FOR UPDATE;
 IF c.id IS NULL THEN RAISE EXCEPTION 'Challenge not found' USING ERRCODE='P0002'; END IF;
 IF a->>'role'<>'admin' AND c.created_by<>(a->>'id')::uuid
 THEN RAISE EXCEPTION 'Not challenge owner' USING ERRCODE='42501'; END IF;
 IF c.status<>'open' THEN RAISE EXCEPTION 'Challenge must be open' USING ERRCODE='22023'; END IF;
 UPDATE public.league_coach_challenges
 SET status='active',starts_at=started,ends_at=started+pg_catalog.make_interval(days=>c.duration_days),
 updated_at=started WHERE id=c.id;
 RETURN pg_catalog.jsonb_build_object('id',c.id,'status','active');
END
$func$;

-- Lock down all nine public entrypoints before transaction commits.
DO $grant$
DECLARE sig text;
BEGIN
 FOREACH sig IN ARRAY ARRAY[
 'coach_challenge_v2_create_draft(text,text,text,integer)',
 'coach_challenge_v2_edit_draft(uuid,text,text,text,integer)',
 'coach_challenge_v2_save_goal_reward(uuid,text,text,integer,numeric,text)',
 'coach_challenge_v2_set_goal(uuid,text,text,numeric,text)',
 'coach_challenge_v2_set_reward(uuid,integer)',
 'coach_challenge_v2_manage(uuid,text)',
 'coach_challenge_v2_join(uuid)',
 'coach_challenge_v2_withdraw(uuid)',
 'coach_challenge_v2_activate(uuid)'] LOOP
 EXECUTE 'REVOKE ALL ON FUNCTION public.'||sig||' FROM PUBLIC, anon';
 EXECUTE 'GRANT EXECUTE ON FUNCTION public.'||sig||' TO authenticated';
END LOOP;
END
$grant$;

-- 6. 20261018_coach_challenges_v2_rpc_review.sql
-- Coach Challenges V2: read, review, and atomic EXP settlement RPCs (part 2/2).
-- PREPARED ONLY. Apply after _rpc_core; do not activate production feature flag.

CREATE OR REPLACE FUNCTION public.coach_challenge_v2_list()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $func$
DECLARE a jsonb:=league_private.coach_v2_actor(); result jsonb;
BEGIN
 SELECT COALESCE(pg_catalog.jsonb_agg(
 pg_catalog.jsonb_build_object(
 'id',c.id,'title',c.title,'description',c.description,'challenge_kind',c.challenge_kind,
 'duration_days',c.duration_days,'goal_spec',c.goal_spec,'status',c.status,
 'created_by',c.created_by,'created_at',c.created_at,'starts_at',c.starts_at,
 'ends_at',c.ends_at,'settled_at',c.settled_at,
 'is_creator',c.created_by=(a->>'id')::uuid,
 'joined_count',(SELECT count(*) FROM public.league_coach_challenge_entries e
 WHERE e.challenge_id=c.id AND e.status IN ('joined','completed')),
 'my_enrollment_status',(SELECT e.status FROM public.league_coach_challenge_entries e
 WHERE e.challenge_id=c.id AND e.boxer_id=(a->>'id')::uuid),
 'my_review_approved',(SELECT r.approved FROM public.league_coach_challenge_reviews r
 WHERE r.challenge_id=c.id AND r.boxer_id=(a->>'id')::uuid)
 ) ORDER BY c.created_at DESC,c.id), '[]'::jsonb) INTO result
 FROM public.league_coach_challenges c
 WHERE a->>'role'='admin'
 OR (a->>'role'='coach' AND (c.created_by=(a->>'id')::uuid OR c.status IN ('open','active','awaiting_reviews','settled')))
 OR (a->>'role'='boxer' AND c.status IN ('open','active','awaiting_reviews','settled'));
 RETURN result;
END
$func$;

CREATE OR REPLACE FUNCTION public.coach_challenge_v2_goal_details(p_challenge_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $func$
DECLARE a jsonb:=league_private.coach_v2_actor(); c public.league_coach_challenges%ROWTYPE;
BEGIN
 SELECT * INTO c FROM public.league_coach_challenges WHERE id=p_challenge_id;
 IF c.id IS NULL OR
 (a->>'role'<>'admin' AND c.created_by<>(a->>'id')::uuid AND c.status NOT IN ('open','active','awaiting_reviews','settled'))
 THEN RAISE EXCEPTION 'Challenge not visible' USING ERRCODE='42501'; END IF;
 RETURN pg_catalog.jsonb_build_object('challenge_id',c.id,'status',c.status,
 'challenge_kind',c.challenge_kind,'goal_spec',c.goal_spec,
 'starts_at',c.starts_at,'ends_at',c.ends_at);
END
$func$;

CREATE OR REPLACE FUNCTION public.coach_challenge_v2_progress(p_challenge_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $func$
DECLARE a jsonb:=league_private.coach_v2_actor(); c public.league_coach_challenges%ROWTYPE;
DECLARE participants integer; reviews integer; v_enrollment text; v_approved boolean;
BEGIN
 SELECT * INTO c FROM public.league_coach_challenges WHERE id=p_challenge_id;
 IF c.id IS NULL OR
 (a->>'role'<>'admin' AND c.created_by<>(a->>'id')::uuid AND c.status NOT IN ('open','active','awaiting_reviews','settled'))
 THEN RAISE EXCEPTION 'Challenge not visible' USING ERRCODE='42501'; END IF;
 SELECT count(*) INTO participants FROM public.league_coach_challenge_entries
 WHERE challenge_id=c.id AND status IN ('joined','completed');
 SELECT count(*) INTO reviews FROM public.league_coach_challenge_reviews r
 JOIN public.league_coach_challenge_entries e ON e.challenge_id=r.challenge_id
 AND e.boxer_id=r.boxer_id
 WHERE r.challenge_id=c.id AND e.status IN ('joined','completed');
 SELECT status INTO v_enrollment FROM public.league_coach_challenge_entries
 WHERE challenge_id=c.id AND boxer_id=(a->>'id')::uuid;
 SELECT approved INTO v_approved FROM public.league_coach_challenge_reviews
 WHERE challenge_id=c.id AND boxer_id=(a->>'id')::uuid;
 RETURN pg_catalog.jsonb_build_object('challenge_id',c.id,'status',c.status,
 'joined_count',participants,'reviewed_count',reviews,'pending_count',participants-reviews,
 'my_enrollment_status',v_enrollment,'my_review_approved',v_approved,
 'goal_spec',c.goal_spec,'starts_at',c.starts_at,'ends_at',c.ends_at);
END
$func$;

CREATE OR REPLACE FUNCTION public.coach_challenge_v2_review_status(p_challenge_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $func$
DECLARE a jsonb:=league_private.coach_v2_actor(); c public.league_coach_challenges%ROWTYPE;
DECLARE total integer; done integer; success integer;
BEGIN
 SELECT * INTO c FROM public.league_coach_challenges WHERE id=p_challenge_id;
 IF c.id IS NULL THEN RAISE EXCEPTION 'Challenge not found' USING ERRCODE='P0002'; END IF;
 IF a->>'role' NOT IN ('coach','admin') OR
 (a->>'role'<>'admin' AND c.created_by<>(a->>'id')::uuid)
 THEN RAISE EXCEPTION 'Not challenge manager' USING ERRCODE='42501'; END IF;
 SELECT count(*) INTO total FROM public.league_coach_challenge_entries e
 WHERE e.challenge_id=c.id AND e.status IN ('joined','completed');
 SELECT count(*),count(*) FILTER (WHERE r.approved) INTO done,success
 FROM public.league_coach_challenge_reviews r
 JOIN public.league_coach_challenge_entries e ON e.challenge_id=r.challenge_id AND e.boxer_id=r.boxer_id
 WHERE r.challenge_id=c.id AND e.status IN ('joined','completed');
 RETURN pg_catalog.jsonb_build_object('challenge_id',c.id,'status',c.status,
 'joined_count',total,'reviewed_count',done,'pending_count',total-done,
 'approved_count',success,'rejected_count',done-success);
END
$func$;

CREATE OR REPLACE FUNCTION public.coach_challenge_v2_review_candidates(p_challenge_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $func$
DECLARE a jsonb:=league_private.coach_v2_actor(); c public.league_coach_challenges%ROWTYPE; result jsonb;
BEGIN
 SELECT * INTO c FROM public.league_coach_challenges WHERE id=p_challenge_id;
 IF c.id IS NULL THEN RAISE EXCEPTION 'Challenge not found' USING ERRCODE='P0002'; END IF;
 IF a->>'role' NOT IN ('coach','admin') OR
 (a->>'role'<>'admin' AND c.created_by<>(a->>'id')::uuid)
 THEN RAISE EXCEPTION 'Not challenge manager' USING ERRCODE='42501'; END IF;
 IF c.status<>'awaiting_reviews' OR c.ends_at IS NULL OR c.ends_at>now()
 THEN RAISE EXCEPTION 'Reviews unavailable' USING ERRCODE='22023'; END IF;
 SELECT COALESCE(pg_catalog.jsonb_agg(
 pg_catalog.jsonb_build_object('boxer_id',e.boxer_id,'display_name',p.display_name)
 ORDER BY p.display_name,e.boxer_id), '[]'::jsonb) INTO result
 FROM public.league_coach_challenge_entries e
 JOIN public.profiles p ON p.id=e.boxer_id
 WHERE e.challenge_id=c.id AND e.status='joined'
 AND NOT EXISTS (SELECT 1 FROM public.league_coach_challenge_reviews r
 WHERE r.challenge_id=e.challenge_id AND r.boxer_id=e.boxer_id);
 RETURN result;
END
$func$;

CREATE OR REPLACE FUNCTION public.coach_challenge_v2_begin_reviews(p_challenge_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $func$
DECLARE a jsonb:=league_private.coach_v2_actor(); c public.league_coach_challenges%ROWTYPE;
BEGIN
 IF a->>'role' NOT IN ('coach','admin') THEN RAISE EXCEPTION 'Coach role required' USING ERRCODE='42501'; END IF;
 SELECT * INTO c FROM public.league_coach_challenges WHERE id=p_challenge_id FOR UPDATE;
 IF c.id IS NULL THEN RAISE EXCEPTION 'Challenge not found' USING ERRCODE='P0002'; END IF;
 IF a->>'role'<>'admin' AND c.created_by<>(a->>'id')::uuid
 THEN RAISE EXCEPTION 'Not challenge owner' USING ERRCODE='42501'; END IF;
 IF c.status<>'active' OR c.ends_at IS NULL OR c.ends_at>now()
 THEN RAISE EXCEPTION 'Challenge still active' USING ERRCODE='22023'; END IF;
 UPDATE public.league_coach_challenges SET status='awaiting_reviews',updated_at=now() WHERE id=c.id;
 RETURN pg_catalog.jsonb_build_object('id',c.id,'status','awaiting_reviews');
END
$func$;

CREATE OR REPLACE FUNCTION public.coach_challenge_v2_review_manual(
 p_challenge_id uuid,p_boxer_id uuid,p_approved boolean,p_reason text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $func$
DECLARE a jsonb:=league_private.coach_v2_actor(); c public.league_coach_challenges%ROWTYPE;
BEGIN
 IF a->>'role' NOT IN ('coach','admin') THEN RAISE EXCEPTION 'Coach role required' USING ERRCODE='42501'; END IF;
 SELECT * INTO c FROM public.league_coach_challenges WHERE id=p_challenge_id FOR UPDATE;
 IF c.id IS NULL THEN RAISE EXCEPTION 'Challenge not found' USING ERRCODE='P0002'; END IF;
 IF a->>'role'<>'admin' AND c.created_by<>(a->>'id')::uuid
 THEN RAISE EXCEPTION 'Not challenge owner' USING ERRCODE='42501'; END IF;
 IF c.status<>'awaiting_reviews' OR c.ends_at IS NULL OR c.ends_at>now()
 THEN RAISE EXCEPTION 'Manual review unavailable' USING ERRCODE='22023'; END IF;
 IF p_approved IS NULL OR char_length(pg_catalog.btrim(COALESCE(p_reason,''))) NOT BETWEEN 5 AND 1000
 THEN RAISE EXCEPTION 'Valid decision and reason required' USING ERRCODE='22023'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.league_coach_challenge_entries
 WHERE challenge_id=c.id AND boxer_id=p_boxer_id AND status='joined')
 THEN RAISE EXCEPTION 'Boxer not enrolled' USING ERRCODE='42501'; END IF;
 INSERT INTO public.league_coach_challenge_reviews(challenge_id,boxer_id,reviewed_by,approved,reason)
 VALUES(c.id,p_boxer_id,(a->>'id')::uuid,p_approved,pg_catalog.btrim(p_reason))
 ON CONFLICT (challenge_id,boxer_id) DO UPDATE SET
 reviewed_by=excluded.reviewed_by,approved=excluded.approved,reason=excluded.reason,reviewed_at=now();
 RETURN pg_catalog.jsonb_build_object('challenge_id',c.id,'boxer_id',p_boxer_id,'approved',p_approved);
END
$func$;

CREATE OR REPLACE FUNCTION public.coach_challenge_v2_settle_manual(p_challenge_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $func$
DECLARE a jsonb:=league_private.coach_v2_actor(); c public.league_coach_challenges%ROWTYPE;
DECLARE e record; v_reward integer; v_transaction uuid; v_awards integer:=0; v_pending integer;
BEGIN
 IF a->>'role' NOT IN ('coach','admin') THEN RAISE EXCEPTION 'Coach role required' USING ERRCODE='42501'; END IF;
 SELECT * INTO c FROM public.league_coach_challenges WHERE id=p_challenge_id FOR UPDATE;
 IF c.id IS NULL THEN RAISE EXCEPTION 'Challenge not found' USING ERRCODE='P0002'; END IF;
 IF a->>'role'<>'admin' AND c.created_by<>(a->>'id')::uuid
 THEN RAISE EXCEPTION 'Not challenge owner' USING ERRCODE='42501'; END IF;
 IF c.status='settled' THEN
 RETURN pg_catalog.jsonb_build_object('id',c.id,'status','settled','already_settled',true,'awards',0);
 END IF;
 IF c.status<>'awaiting_reviews' OR c.ends_at IS NULL OR c.ends_at>now()
 THEN RAISE EXCEPTION 'Challenge not ready for settlement' USING ERRCODE='22023'; END IF;
 IF c.goal_spec->>'review_mode' IS DISTINCT FROM 'manual'
 THEN RAISE EXCEPTION 'Only manual reviews supported' USING ERRCODE='22023'; END IF;
 v_reward:=(c.goal_spec->>'reward_exp')::integer;
 IF v_reward IS NULL OR v_reward NOT IN (25,50,100,150,200)
 THEN RAISE EXCEPTION 'Invalid configured EXP reward' USING ERRCODE='22023'; END IF;
 SELECT count(*) INTO v_pending FROM public.league_coach_challenge_entries j
 WHERE j.challenge_id=c.id AND j.status='joined'
 AND NOT EXISTS (SELECT 1 FROM public.league_coach_challenge_reviews r
 WHERE r.challenge_id=j.challenge_id AND r.boxer_id=j.boxer_id);
 IF v_pending>0 THEN RAISE EXCEPTION 'Unreviewed enrollments: %',v_pending USING ERRCODE='22023'; END IF;
 FOR e IN SELECT j.boxer_id,r.approved FROM public.league_coach_challenge_entries j
 JOIN public.league_coach_challenge_reviews r ON r.challenge_id=j.challenge_id AND r.boxer_id=j.boxer_id
 WHERE j.challenge_id=c.id AND j.status='joined' ORDER BY j.boxer_id LOOP
  IF e.approved AND NOT EXISTS(SELECT 1 FROM public.league_coach_challenge_exp_ledger l
  WHERE l.challenge_id=c.id AND l.boxer_id=e.boxer_id) THEN
   INSERT INTO public.point_transactions(boxer_id,points,exp,category,description,effective_date,created_by)
   VALUES(e.boxer_id,0,v_reward,'challenge_exp',
   'Coach Challenge: '||c.title,
   (now() AT TIME ZONE 'Europe/Zurich')::date,(a->>'id')::uuid)
   RETURNING id INTO v_transaction;
   INSERT INTO public.league_coach_challenge_exp_ledger(challenge_id,boxer_id,transaction_id,awarded_exp)
   VALUES(c.id,e.boxer_id,v_transaction,v_reward);
   v_awards:=v_awards+1;
  END IF;
 END LOOP;
 UPDATE public.league_coach_challenge_entries SET status='completed'
 WHERE challenge_id=c.id AND status='joined';
 UPDATE public.league_coach_challenges SET status='settled',settled_at=now(),updated_at=now()
 WHERE id=c.id;
 RETURN pg_catalog.jsonb_build_object('id',c.id,'status','settled',
 'already_settled',false,'awards',v_awards);
END
$func$;

DO $grant$
DECLARE sig text;
BEGIN
 FOREACH sig IN ARRAY ARRAY[
 'coach_challenge_v2_list()',
 'coach_challenge_v2_goal_details(uuid)',
 'coach_challenge_v2_progress(uuid)',
 'coach_challenge_v2_review_status(uuid)',
 'coach_challenge_v2_review_candidates(uuid)',
 'coach_challenge_v2_begin_reviews(uuid)',
 'coach_challenge_v2_review_manual(uuid,uuid,boolean,text)',
 'coach_challenge_v2_settle_manual(uuid)'] LOOP
 EXECUTE 'REVOKE ALL ON FUNCTION public.'||sig||' FROM PUBLIC, anon';
 EXECUTE 'GRANT EXECUTE ON FUNCTION public.'||sig||' TO authenticated';
END LOOP;
END
$grant$;
DO $postflight$
DECLARE v_total integer; v_exposed integer; tbl text;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.league_feature_flags
 WHERE feature_key='coach_challenges' AND is_enabled IS FALSE)
 OR NOT EXISTS(SELECT 1 FROM public.league_feature_flags
 WHERE feature_key='duels' AND is_enabled IS FALSE)
 THEN RAISE EXCEPTION 'V2 feature flags must remain disabled'; END IF;
 SELECT count(*),count(*) FILTER (WHERE pg_catalog.has_function_privilege('anon',p.oid,'EXECUTE'))
 INTO v_total,v_exposed
 FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.proname LIKE 'coach_challenge_v2_%';
 IF v_total<>17 OR v_exposed<>0
 THEN RAISE EXCEPTION 'Unexpected V2 function count or anonymous grants: %, %',v_total,v_exposed; END IF;
 FOREACH tbl IN ARRAY ARRAY['league_coach_challenges','league_coach_challenge_entries',
 'league_coach_challenge_reviews','league_coach_challenge_exp_ledger'] LOOP
 IF NOT EXISTS(SELECT 1 FROM pg_catalog.pg_class c WHERE c.oid=('public.'||tbl)::regclass
 AND c.relrowsecurity)
 THEN RAISE EXCEPTION 'RLS absent for %',tbl; END IF;
 IF pg_catalog.has_table_privilege('anon','public.'||tbl,'SELECT')
 OR pg_catalog.has_table_privilege('authenticated','public.'||tbl,'SELECT')
 THEN RAISE EXCEPTION 'Client table permission unexpected: %',tbl; END IF;
 END LOOP;
END $postflight$;
COMMIT;
