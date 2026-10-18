-- Disposable PostgreSQL test fixtures only. NEVER run against any Supabase project.
\set ON_ERROR_STOP on
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE TABLE public.profiles (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 role text NOT NULL DEFAULT 'boxer',
 CONSTRAINT profiles_role_check CHECK (role IN ('boxer','admin'))
);
CREATE TABLE public.point_transactions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
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
INSERT INTO public.point_transactions(category) VALUES ('training');
INSERT INTO public.league_feature_flags(feature_key,display_name,is_enabled)
 VALUES ('boxer_duels','Legacy Duels',false),('league_challenges','Legacy Challenges',false);
\i supabase/production-prep/20261018_allow_coach_role.sql
\i supabase/production-prep/20261018_extend_transaction_categories.sql
\i supabase/production-prep/20261018_v2_feature_flags_disabled.sql
\i supabase/production-prep/20261018_coach_challenges_v2_schema.sql
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
INSERT INTO public.profiles(id,role) VALUES('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','coach');
INSERT INTO public.point_transactions(category) VALUES ('duel_exp'),('challenge_exp');
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
