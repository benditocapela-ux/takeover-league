-- Disposable PostgreSQL test fixtures only. NEVER run against any Supabase project.
\set ON_ERROR_STOP on
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
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
 points integer NOT NULL DEFAULT 0,
 exp integer NOT NULL DEFAULT 0,
 description text NOT NULL DEFAULT '',
 effective_date date NOT NULL DEFAULT CURRENT_DATE,
 created_by uuid,
 category text NOT NULL,
 CONSTRAINT point_transactions_category_check
 CHECK (category IN ('training','trainer_bonus','adjustment','legacy_import','automatic_bonus','achievement_exp'))
);
CREATE TABLE public.league_feature_flags (
 feature_key text PRIMARY KEY CHECK (feature_key ~ '^[a-z][a-z0-9_]*$'),
 display_name text NOT NULL,
 is_enabled boolean NOT NULL DEFAULT false
);
INSERT INTO public.profiles(id,role)
 VALUES ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','boxer');
UPDATE public.profiles SET auth_user_id='11111111-1111-4111-8111-111111111111', display_name='Test Boxer' WHERE id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
INSERT INTO public.point_transactions(category) VALUES ('training');
INSERT INTO public.league_feature_flags(feature_key,display_name,is_enabled)
 VALUES ('boxer_duels','Legacy Duels',false),('league_challenges','Legacy Challenges',false);
\i supabase/production-prep/20261018_allow_coach_role.sql
\i supabase/production-prep/20261018_extend_transaction_categories.sql
\i supabase/production-prep/20261018_v2_feature_flags_disabled.sql
\i supabase/production-prep/20261018_coach_challenges_v2_schema.sql
\i supabase/production-prep/20261018_coach_challenges_v2_rpc_core.sql
\i supabase/production-prep/20261018_coach_challenges_v2_rpc_review.sql
DO $$
BEGIN
 IF (SELECT count(*) FROM public.profiles) <> 1 OR
 (SELECT count(*) FROM public.point_transactions) <> 1 THEN
 RAISE EXCEPTION 'Existing fixture rows changed';
 END IF;
 IF NOT EXISTS (SELECT 1 FROM public.league_feature_flags WHERE feature_key='coach_challenges' AND NOT is_enabled)
 OR NOT EXISTS (SELECT 1 FROM public.league_feature_flags WHERE feature_key='duels' AND NOT is_enabled)
 THEN RAISE EXCEPTION 'V2 flags missing or unexpectedly enabled'; END IF;
 IF (SELECT count(*) FROM pg_class WHERE relnamespace='public'::regnamespace
 AND relname IN ('league_coach_challenges','league_coach_challenge_entries','league_coach_challenge_reviews','league_coach_challenge_exp_ledger')
 AND relrowsecurity) <> 4 THEN RAISE EXCEPTION 'V2 RLS not enabled'; END IF;
 IF has_table_privilege('authenticated','public.league_coach_challenges','SELECT')
 OR has_table_privilege('anon','public.league_coach_challenges','SELECT')
 THEN RAISE EXCEPTION 'V2 table exposed to clients'; END IF;
END $$;
INSERT INTO public.profiles(id,auth_user_id,display_name,role)
 VALUES('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','22222222-2222-4222-8222-222222222222','Test Coach','coach');
INSERT INTO public.point_transactions(category) VALUES ('duel_exp'),('challenge_exp');
-- Verify all four tables reject direct application-role access.
DO $safety$
DECLARE item text; role_name text; privilege text;
BEGIN
 FOREACH item IN ARRAY ARRAY['league_coach_challenges','league_coach_challenge_entries',
   'league_coach_challenge_reviews','league_coach_challenge_exp_ledger'] LOOP
   FOREACH role_name IN ARRAY ARRAY['anon','authenticated'] LOOP
     FOREACH privilege IN ARRAY ARRAY['SELECT','INSERT','UPDATE','DELETE'] LOOP
       IF has_table_privilege(role_name,'public.'||item,privilege) THEN
         RAISE EXCEPTION 'Unexpected client permission: % % %',role_name,item,privilege;
       END IF;
     END LOOP;
   END LOOP;
 END LOOP;
END $safety$;
-- Database rejects illegal challenge settings and duplicate enrollment/reward rows.
DO $safety$
DECLARE cid uuid; boxer uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
trainer uuid := 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
BEGIN
 BEGIN
   INSERT INTO public.league_coach_challenges(created_by,title,challenge_kind,duration_days)
   VALUES(trainer,'No','individual',7);
   RAISE EXCEPTION 'Expected invalid title rejection';
 EXCEPTION WHEN check_violation THEN NULL; END;
 BEGIN
   INSERT INTO public.league_coach_challenges(created_by,title,challenge_kind,duration_days)
   VALUES(trainer,'Valid title','group',7);
   RAISE EXCEPTION 'Expected invalid kind rejection';
 EXCEPTION WHEN check_violation THEN NULL; END;
 BEGIN
   INSERT INTO public.league_coach_challenges(created_by,title,challenge_kind,duration_days)
   VALUES(trainer,'Valid title','individual',10);
   RAISE EXCEPTION 'Expected invalid duration rejection';
 EXCEPTION WHEN check_violation THEN NULL; END;
 INSERT INTO public.league_coach_challenges(created_by,title,challenge_kind,duration_days)
 VALUES(trainer,'Test Challenge','individual',7) RETURNING id INTO cid;
 INSERT INTO public.league_coach_challenge_entries(challenge_id,boxer_id)
 VALUES(cid,boxer);
 BEGIN
   INSERT INTO public.league_coach_challenge_entries(challenge_id,boxer_id)
   VALUES(cid,boxer);
   RAISE EXCEPTION 'Expected duplicate enrollment rejection';
 EXCEPTION WHEN unique_violation THEN NULL; END;
 INSERT INTO public.league_coach_challenge_exp_ledger(challenge_id,boxer_id,awarded_exp)
 VALUES(cid,boxer,25);
 BEGIN
   INSERT INTO public.league_coach_challenge_exp_ledger(challenge_id,boxer_id,awarded_exp)
   VALUES(cid,boxer,75);
   RAISE EXCEPTION 'Expected reward validation or uniqueness rejection';
 EXCEPTION WHEN check_violation OR unique_violation THEN NULL; END;
 BEGIN
   INSERT INTO public.league_coach_challenge_reviews(challenge_id,boxer_id,reviewed_by,approved,reason)
   VALUES(cid,boxer,trainer,true,'bad');
   RAISE EXCEPTION 'Expected invalid review reason rejection';
 EXCEPTION WHEN check_violation THEN NULL; END;
 DELETE FROM public.league_coach_challenge_exp_ledger WHERE challenge_id=cid;
 DELETE FROM public.league_coach_challenge_entries WHERE challenge_id=cid;
 DELETE FROM public.league_coach_challenges WHERE id=cid;
END $safety$;
\i supabase/production-prep/rollback_coach_challenges_v2_empty_only.sql
DO $$
BEGIN
 IF to_regclass('public.league_coach_challenges') IS NOT NULL THEN
  RAISE EXCEPTION 'Rollback did not remove empty challenge tables';
 END IF;
 IF (SELECT count(*) FROM public.profiles) <> 2 OR
 (SELECT count(*) FROM public.point_transactions) <> 3 THEN
  RAISE EXCEPTION 'Rollback affected existing records';
 END IF;
END $$;
SELECT 'V2 migration fixture checks passed' AS result;
