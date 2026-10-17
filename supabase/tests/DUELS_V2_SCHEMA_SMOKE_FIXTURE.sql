-- Disposable PostgreSQL only. Synthetic minimal dependencies for migration 007.
-- NEVER execute on production or an existing Supabase project.
BEGIN;
CREATE SCHEMA IF NOT EXISTS public;
CREATE TABLE public.profiles (
 id uuid PRIMARY KEY,
 auth_user_id uuid,
 display_name text,
 role text,
 is_active boolean DEFAULT true
);
CREATE TABLE public.point_transactions (
 id uuid PRIMARY KEY,
 boxer_id uuid REFERENCES public.profiles(id),
 points integer NOT NULL DEFAULT 0,
 exp integer NOT NULL DEFAULT 0,
 category text NOT NULL,
 description text,
 effective_date date,
 created_by uuid REFERENCES public.profiles(id)
);
CREATE TABLE public.league_feature_flags (
 feature_key text PRIMARY KEY,
 is_enabled boolean NOT NULL DEFAULT false
);
COMMIT;
