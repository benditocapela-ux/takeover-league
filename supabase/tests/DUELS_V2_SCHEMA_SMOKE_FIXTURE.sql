-- Disposable PostgreSQL only. Synthetic minimal dependencies for migration 007.
-- NEVER execute on production or an existing Supabase project.
BEGIN;
CREATE SCHEMA IF NOT EXISTS public;
-- Supabase API roles referenced by the migrations, not real credentials.
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
-- Minimal test-only auth.uid() shim, never a production authentication model.
CREATE SCHEMA auth;
CREATE FUNCTION auth.uid() RETURNS uuid
LANGUAGE sql STABLE AS $auth_test$
 SELECT nullif(current_setting('test.auth_uid',true),'')::uuid
$auth_test$;
CREATE TABLE public.profiles (
 id uuid PRIMARY KEY,
 auth_user_id uuid,
 display_name text,
 role text,
 is_active boolean DEFAULT true
);
CREATE TABLE public.point_transactions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 boxer_id uuid REFERENCES public.profiles(id),
 points integer NOT NULL DEFAULT 0,
 exp integer NOT NULL DEFAULT 0,
 category text NOT NULL,
 description text,
 effective_date date,
 created_by uuid REFERENCES public.profiles(id),
 submission_id uuid,
 created_at timestamptz DEFAULT now(),
 CONSTRAINT point_transactions_category_check CHECK(category IN
 ('training','trainer_bonus','adjustment','legacy_import','automatic_bonus','achievement_exp'))
);
CREATE TABLE public.training_submissions (
 id uuid PRIMARY KEY,
 boxer_id uuid NOT NULL REFERENCES public.profiles(id),
 training_date date NOT NULL,
 jogging_km numeric,
 technique_minutes integer,
 status text NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.league_feature_flags (
 feature_key text PRIMARY KEY,
 is_enabled boolean NOT NULL DEFAULT false
);
COMMIT;
