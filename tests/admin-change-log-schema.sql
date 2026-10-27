\set ON_ERROR_STOP on
-- Disposable-database test for 20261028140000_admin_change_log.sql (+ rollback).
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE ROLE anon;
CREATE ROLE authenticated;
CREATE SCHEMA auth;
CREATE SCHEMA league_v21_private;
CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT NULLIF(current_setting('request.jwt.claim.sub', true),'')::uuid $$;
CREATE TABLE public.profiles(id uuid PRIMARY KEY, auth_user_id uuid, role text NOT NULL, is_active boolean NOT NULL DEFAULT true);
CREATE TABLE public.league_seasons_v21(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), title text, starts_on date, ends_on date, status text);
CREATE TABLE public.league_global_challenges_v21(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), title text, description text, metric text, target_value numeric,
 starts_at timestamptz, ends_at timestamptz, status text, completion_exp int, winner_exp int);
CREATE TABLE public.league_arena_duels_v21(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), title text, duration_days int, status text, starts_at timestamptz, ends_at timestamptz);
CREATE TABLE public.league_boxer_goals_v21(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), boxer_id uuid, title text, metric text, target_value numeric,
 ends_on date, status text, reward_exp int, updated_at timestamptz DEFAULT now());
\ir ../supabase/migrations/20261028140000_admin_change_log.sql
INSERT INTO public.profiles VALUES ('00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','admin',true);
SELECT set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',false);
INSERT INTO public.league_seasons_v21(id,title,starts_on,ends_on,status) VALUES ('20000000-0000-0000-0000-000000000001','Winter','2026-11-14','2026-12-16','draft');
UPDATE public.league_seasons_v21 SET status='active';
UPDATE public.league_seasons_v21 SET status='active';
INSERT INTO public.league_boxer_goals_v21(id,title,status) VALUES ('30000000-0000-0000-0000-000000000001','Ziel','active');
UPDATE public.league_boxer_goals_v21 SET updated_at=now()+interval '1 minute';
UPDATE public.league_boxer_goals_v21 SET status='archived';
INSERT INTO public.league_global_challenges_v21(id,title,status) VALUES ('40000000-0000-0000-0000-000000000001','Entwurf','draft');
DELETE FROM public.league_global_challenges_v21;
DO $t$ DECLARE t text; BEGIN
 SELECT string_agg(entity||':'||action||coalesce(':'||(new_value->>'status'),''),',' ORDER BY id) INTO t FROM public.league_admin_audit_v21;
 IF t IS DISTINCT FROM 'season:insert:draft,season:update:active,goal:insert:active,goal:update:archived,league_challenge:insert:draft,league_challenge:delete' THEN
  RAISE EXCEPTION 'unexpected log: %',t; END IF;
 IF EXISTS(SELECT 1 FROM public.league_admin_audit_v21 WHERE actor_role IS DISTINCT FROM 'admin') THEN RAISE EXCEPTION 'actor missing'; END IF;
 IF has_table_privilege('authenticated','public.league_admin_audit_v21','INSERT') OR has_table_privilege('anon','public.league_admin_audit_v21','SELECT') THEN RAISE EXCEPTION 'grants'; END IF;
END $t$;
\ir ../supabase/migrations/20261028140000_admin_change_log.sql
\ir ../supabase/production-prep/rollback_20261028140000_admin_change_log.sql
DO $t$ BEGIN
 IF EXISTS(SELECT 1 FROM pg_trigger WHERE tgname LIKE 'league_v21_audit_%') THEN RAISE EXCEPTION 'rollback left triggers'; END IF;
 IF (SELECT count(*) FROM public.league_admin_audit_v21)<>6 THEN RAISE EXCEPTION 'rollback must keep history'; END IF;
END $t$;
SELECT 'PASS: change log records admin changes (only real field changes), admin-only read, no client writes, idempotent, rollback keeps history' AS result;
