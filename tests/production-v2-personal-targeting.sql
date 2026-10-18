-- Isolated integration test database only. No production SQL is executed.
\set ON_ERROR_STOP on
CREATE SCHEMA auth;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $auth$
 SELECT NULLIF(current_setting('request.jwt.claim.sub',true),'')::uuid;
$auth$;
CREATE TABLE public.profiles (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 auth_user_id uuid UNIQUE,
 display_name text NOT NULL DEFAULT 'Boxer',
 is_active boolean NOT NULL DEFAULT true,
 role text NOT NULL DEFAULT 'boxer',
 CONSTRAINT profiles_role_check CHECK (role IN ('boxer','admin'))
);
CREATE TABLE public.point_transactions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 boxer_id uuid,
 submission_id uuid,
 points integer NOT NULL DEFAULT 0,
 exp integer NOT NULL DEFAULT 0,
 description text NOT NULL DEFAULT '',
 effective_date date NOT NULL DEFAULT CURRENT_DATE,
 created_by uuid,
 category text NOT NULL,
 CONSTRAINT point_transactions_category_check
 CHECK (category IN ('training','trainer_bonus','adjustment','legacy_import','automatic_bonus','achievement_exp'))
);
CREATE TABLE public.training_submissions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 boxer_id uuid NOT NULL REFERENCES public.profiles(id),
 training_date date NOT NULL,
 status text NOT NULL CHECK (status IN ('pending','approved','rejected')),
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.league_feature_flags (
 feature_key text PRIMARY KEY,
 display_name text NOT NULL,
 is_enabled boolean NOT NULL DEFAULT false,
 updated_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO public.profiles(id,auth_user_id,display_name,role)
VALUES
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','11111111-1111-4111-8111-111111111111','Boxer Alpha','boxer'),
 ('cccccccc-cccc-4ccc-8ccc-cccccccccccc','33333333-3333-4333-8333-333333333333','League Admin','admin'),
 ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','55555555-5555-4555-8555-555555555555','Boxer Beta','boxer');
-- Old V2 migration itself extends role and category CHECKs.
\i supabase/migrations/20261018131000_coach_challenges_v2.sql
INSERT INTO public.profiles(id,auth_user_id,display_name,role)
VALUES
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','22222222-2222-4222-8222-222222222222','Coach Alpha','coach'),
 ('dddddddd-dddd-4ddd-8ddd-dddddddddddd','44444444-4444-4444-8444-444444444444','Other Coach','coach');
UPDATE public.league_feature_flags SET is_enabled=true
 WHERE feature_key='coach_challenges';
\i supabase/migrations/20261018170000_private_boxer_challenge_assignment.sql

-- Defensive grants; unauthorized users must not access private tables or functions.
DO $permissions$
DECLARE p text;
BEGIN
 FOR p IN SELECT unnest(ARRAY['SELECT','INSERT','UPDATE','DELETE']) LOOP
 IF has_table_privilege('anon','public.league_coach_challenge_targets',p)
 OR has_table_privilege('authenticated','public.league_coach_challenge_targets',p)
 THEN RAISE EXCEPTION 'Target mapping exposed through %',p; END IF;
 END LOOP;
 IF has_function_privilege('anon','public.league_assign_personal_challenge(uuid,text,text,text,integer,integer)','EXECUTE')
 OR has_function_privilege('anon','public.league_personal_challenge_roster()','EXECUTE')
 OR has_function_privilege('anon','public.league_cancel_personal_challenge(uuid)','EXECUTE')
 THEN RAISE EXCEPTION 'Direct assignment functions are public'; END IF;
END
$permissions$;

SET ROLE anon;
DO $anonymous$
BEGIN
 BEGIN
  PERFORM public.league_personal_challenge_roster();
  RAISE EXCEPTION 'Anonymous roster permitted';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END
$anonymous$;
RESET ROLE;

SET ROLE authenticated;
SET request.jwt.claim.sub='11111111-1111-4111-8111-111111111111';
DO $boxerCannotAssign$
BEGIN
 BEGIN
  PERFORM public.league_assign_personal_challenge('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
  'Forged challenge','', 'Forge EXP reward',7,200);
  RAISE EXCEPTION 'Boxer assigned another boxer a challenge';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN
  PERFORM public.league_personal_challenge_roster();
  RAISE EXCEPTION 'Boxer obtained coach-only private roster';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END
$boxerCannotAssign$;
RESET ROLE;

SET ROLE authenticated;
SET request.jwt.claim.sub='22222222-2222-4222-8222-222222222222';
DO $coachCreate$
DECLARE v_id uuid; data jsonb;
BEGIN
 BEGIN
  PERFORM public.league_assign_personal_challenge('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','Bad target','','Trainer is not boxer',7,50);
  RAISE EXCEPTION 'Coach assigned other coach an athlete-only challenge';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN
  PERFORM public.league_assign_personal_challenge('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Sparring focus','','Accurate punches',7,75);
  RAISE EXCEPTION 'Invalid EXP accepted';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 data:=public.league_assign_personal_challenge('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'Sparring focus','Improve movement','Three defensive sparring rounds',7,50);
 v_id:=(data->>'challenge_id')::uuid;
 IF data->>'status'<>'active' OR data->>'boxer_id'<>'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
 THEN RAISE EXCEPTION 'Incorrect assignment response'; END IF;
 PERFORM pg_catalog.set_config('test.direct_id',v_id::text,false);
 IF (SELECT count(*) FROM public.league_coach_challenge_entries
     WHERE challenge_id=v_id AND boxer_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' AND status='joined')<>1
 THEN RAISE EXCEPTION 'Direct challenge did not auto-enroll target'; END IF;
 IF (SELECT status FROM public.league_coach_challenges WHERE id=v_id)<>'active'
 THEN RAISE EXCEPTION 'Direct challenge was not activated'; END IF;
 IF (SELECT count(*) FROM public.point_transactions)<>0
 THEN RAISE EXCEPTION 'Assignment incorrectly awarded EXP'; END IF;
 data:=public.coach_challenge_v2_list();
 IF pg_catalog.jsonb_array_length(data)<>1
 OR data->0->>'target_boxer_name'<>'Boxer Alpha'
 OR data->0->>'is_personal_assignment'<>'true'
 THEN RAISE EXCEPTION 'Creator cannot find assigned challenge'; END IF;
 IF (SELECT count(*) FROM public.league_personal_challenge_roster())<>2
 THEN RAISE EXCEPTION 'Coach roster included non-boxer'; END IF;
END
$coachCreate$;
RESET ROLE;

-- Only the selected boxer and coach/admin are entitled to see this challenge.
SET ROLE authenticated;
SET request.jwt.claim.sub='55555555-5555-4555-8555-555555555555';
DO $wrongBoxer$
DECLARE data jsonb;
BEGIN
 data:=public.coach_challenge_v2_list();
 IF pg_catalog.jsonb_array_length(data)<>0
 THEN RAISE EXCEPTION 'Other boxer can view private challenge'; END IF;
 BEGIN
  PERFORM public.coach_challenge_v2_goal_details(current_setting('test.direct_id')::uuid);
  RAISE EXCEPTION 'Other boxer can read private goal';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN
  PERFORM public.coach_challenge_v2_progress(current_setting('test.direct_id')::uuid);
  RAISE EXCEPTION 'Other boxer can read private progress';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 -- Even if a trainer accidentally re-opens a direct goal for joining,
 -- a different boxer must still not be able to join.
END
$wrongBoxer$;
RESET ROLE;

UPDATE public.league_coach_challenges SET status='open' WHERE id=current_setting('test.direct_id')::uuid;
SET ROLE authenticated;
SET request.jwt.claim.sub='55555555-5555-4555-8555-555555555555';
DO $unauthorizedJoin$
BEGIN
 BEGIN
  PERFORM public.coach_challenge_v2_join(current_setting('test.direct_id')::uuid);
  RAISE EXCEPTION 'Wrong boxer joined directly targeted challenge';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END
$unauthorizedJoin$;
RESET ROLE;
UPDATE public.league_coach_challenges SET status='active' WHERE id=current_setting('test.direct_id')::uuid;

SET ROLE authenticated;
SET request.jwt.claim.sub='44444444-4444-4444-8444-444444444444';
DO $otherCoach$
BEGIN
 IF pg_catalog.jsonb_array_length(public.coach_challenge_v2_list())<>0
 THEN RAISE EXCEPTION 'Unrelated trainer can view assigned goal'; END IF;
 BEGIN
  PERFORM public.league_cancel_personal_challenge(current_setting('test.direct_id')::uuid);
  RAISE EXCEPTION 'Unrelated trainer cancelled assigned goal';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END
$otherCoach$;
RESET ROLE;

SET ROLE authenticated;
SET request.jwt.claim.sub='11111111-1111-4111-8111-111111111111';
DO $chosenBoxer$
DECLARE data jsonb;
BEGIN
 data:=public.coach_challenge_v2_list();
 IF pg_catalog.jsonb_array_length(data)<>1 OR data->0->>'my_enrollment_status'<>'joined'
 THEN RAISE EXCEPTION 'Chosen boxer did not see the assigned challenge'; END IF;
 BEGIN
  PERFORM public.league_cancel_personal_challenge(current_setting('test.direct_id')::uuid);
  RAISE EXCEPTION 'Boxer cancelled coach assignment';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END
$chosenBoxer$;
RESET ROLE;

SET ROLE authenticated;
SET request.jwt.claim.sub='33333333-3333-4333-8333-333333333333';
DO $admin$
BEGIN
 IF pg_catalog.jsonb_array_length(public.coach_challenge_v2_list())<>1
 THEN RAISE EXCEPTION 'Admin lost moderation visibility'; END IF;
END
$admin$;
RESET ROLE;

-- Trainer can cancel only an unpaid active goal. No EXP must be touched.
SET ROLE authenticated;
SET request.jwt.claim.sub='22222222-2222-4222-8222-222222222222';
DO $coachCancel$
DECLARE result jsonb;
BEGIN
 result:=public.league_cancel_personal_challenge(current_setting('test.direct_id')::uuid);
 IF result->>'status'<>'cancelled' THEN RAISE EXCEPTION 'Cancellation failed'; END IF;
 IF (SELECT status FROM public.league_coach_challenge_entries
 WHERE challenge_id=current_setting('test.direct_id')::uuid)<>'withdrawn'
 THEN RAISE EXCEPTION 'Cancellation left athlete enrolled'; END IF;
 IF (SELECT count(*) FROM public.point_transactions)<>0
 THEN RAISE EXCEPTION 'Cancellation created or deleted points'; END IF;
 BEGIN
  PERFORM public.league_cancel_personal_challenge(current_setting('test.direct_id')::uuid);
  RAISE EXCEPTION 'Repeat cancellation unexpectedly permitted';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
END
$coachCancel$;
RESET ROLE;

-- A second assigned challenge exercises the existing human review and
-- idempotent EXP-ledger settlement without creating fake prod points.
SET ROLE authenticated;
SET request.jwt.claim.sub='22222222-2222-4222-8222-222222222222';
DO $second$
DECLARE id uuid;
BEGIN
 id:=(public.league_assign_personal_challenge('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
 'Fitness focus','','Complete five boxing sessions',7,25)->>'challenge_id')::uuid;
 PERFORM pg_catalog.set_config('test.completed_id',id::text,false);
END
$second$;
RESET ROLE;
UPDATE public.league_coach_challenges SET ends_at=now()-interval '1 second'
 WHERE id=current_setting('test.completed_id')::uuid;
SET ROLE authenticated;
SET request.jwt.claim.sub='22222222-2222-4222-8222-222222222222';
DO $award$
DECLARE id uuid:=current_setting('test.completed_id')::uuid; firstResult jsonb; secondResult jsonb;
BEGIN
 PERFORM public.coach_challenge_v2_begin_reviews(id);
 PERFORM public.coach_challenge_v2_review_manual(id,
 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',true,'Verified target progress');
 firstResult:=public.coach_challenge_v2_settle_manual(id);
 secondResult:=public.coach_challenge_v2_settle_manual(id);
 IF firstResult->>'awards'<>'1' OR secondResult->>'already_settled'<>'true'
 THEN RAISE EXCEPTION 'Direct challenge paid twice or not at all'; END IF;
 IF (SELECT count(*) FROM public.point_transactions
  WHERE category='challenge_exp' AND points=0 AND exp=25)<>1
 THEN RAISE EXCEPTION 'Wrong personal challenge EXP payout'; END IF;
 IF (SELECT count(*) FROM public.league_coach_challenge_exp_ledger
  WHERE challenge_id=id AND awarded_exp=25)<>1
 THEN RAISE EXCEPTION 'Missing settlement ledger'; END IF;
 BEGIN
  PERFORM public.league_cancel_personal_challenge(id);
  RAISE EXCEPTION 'Paid challenge can be cancelled';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
END
$award$;
RESET ROLE;

SELECT 'PASS private assignment, role guards, visibility, cancellation and EXP idempotency' AS result;
