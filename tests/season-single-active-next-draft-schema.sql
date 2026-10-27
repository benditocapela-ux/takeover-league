\set ON_ERROR_STOP on
-- Disposable-database test for 20261028110000_season_single_active_next_draft.sql.
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
CREATE TABLE public.boxer_notifications(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), recipient_id uuid NOT NULL, notification_type text NOT NULL,
 title text NOT NULL, message text NOT NULL DEFAULT '', target_path text);
CREATE TABLE public.training_submissions(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), boxer_id uuid NOT NULL, training_date date NOT NULL, status text NOT NULL);
CREATE TABLE public.point_transactions(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), boxer_id uuid NOT NULL, points integer NOT NULL DEFAULT 0,
 exp integer NOT NULL DEFAULT 0, effective_date date NOT NULL);
CREATE TABLE public.league_seasons_v21(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), title text NOT NULL, starts_on date NOT NULL, ends_on date NOT NULL,
 status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','active','closed')), CHECK (ends_on>=starts_on));
CREATE TABLE public.league_season_results_v21(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), season_id uuid NOT NULL, boxer_id uuid NOT NULL,
 boxer_name text NOT NULL, rank_position integer NOT NULL, points integer NOT NULL, exp integer NOT NULL, UNIQUE(season_id,boxer_id));
CREATE TABLE public.league_hall_of_fame_v21(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), boxer_id uuid NOT NULL, season_id uuid, title text NOT NULL,
 description text, boxer_name text NOT NULL, UNIQUE(boxer_id,season_id,title));
CREATE OR REPLACE FUNCTION league_v21_private.notifications_enabled() RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=''
AS $fn$ SELECT EXISTS(SELECT 1 FROM public.league_feature_flags f WHERE f.feature_key='notifications' AND f.is_enabled IS TRUE) $fn$;

\ir ../supabase/migrations/20261028110000_season_single_active_next_draft.sql

INSERT INTO public.league_feature_flags VALUES ('notifications',true);
INSERT INTO public.profiles(id,auth_user_id,display_name,role) VALUES
 ('00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','Admin','admin'),
 ('00000000-0000-0000-0000-000000000002',null,'Anna','boxer');
INSERT INTO public.point_transactions(boxer_id,points,exp,effective_date) VALUES ('00000000-0000-0000-0000-000000000002',100,10,'2026-09-10');
INSERT INTO public.league_seasons_v21(id,title,starts_on,ends_on,status) VALUES
 ('20000000-0000-0000-0000-000000000001','Herbst Test','2026-08-12','2026-09-13','active'),
 ('20000000-0000-0000-0000-000000000002','Parallel','2027-01-01','2027-01-31','draft');
SELECT set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',false);

-- A second season cannot be activated while one is active.
DO $t$ BEGIN
 BEGIN PERFORM league_v21_private.season_transition_core('20000000-0000-0000-0000-000000000002','activate'); RAISE EXCEPTION 'two active seasons';
 EXCEPTION WHEN unique_violation THEN NULL; END;
END $t$;
DELETE FROM public.league_seasons_v21 WHERE id='20000000-0000-0000-0000-000000000002';

-- Close prepares the next draft with the same length right after; repeated close changes nothing.
SELECT league_v21_private.season_transition_core('20000000-0000-0000-0000-000000000001','close') AS r \gset
DO $t$ DECLARE s record; BEGIN
 SELECT * INTO s FROM public.league_seasons_v21 WHERE status='draft';
 IF s.starts_on<>'2026-09-14' OR s.ends_on<>'2026-10-16' OR s.title<>'Herbst 2026' THEN RAISE EXCEPTION 'next draft wrong: % % %',s.title,s.starts_on,s.ends_on; END IF;
 IF (SELECT count(*) FROM public.league_season_results_v21)<>1 OR (SELECT count(*) FROM public.league_hall_of_fame_v21)<>1 THEN RAISE EXCEPTION 'snapshot missing'; END IF;
 IF (league_v21_private.season_transition_core('20000000-0000-0000-0000-000000000001','close')->>'unchanged')<>'true'
    OR (SELECT count(*) FROM public.league_seasons_v21)<>2 OR (SELECT count(*) FROM public.league_season_results_v21)<>1 THEN RAISE EXCEPTION 'repeat close changed data'; END IF;
END $t$;
-- Activating the draft now works (no other active season).
SELECT league_v21_private.season_transition_core((SELECT id FROM public.league_seasons_v21 WHERE status='draft'),'activate');
-- When a later season already exists, no extra draft is created; title collisions get a suffix.
UPDATE public.league_seasons_v21 SET starts_on='2026-08-01', ends_on='2026-08-31', title='Sommer A' WHERE status='active';
INSERT INTO public.league_seasons_v21(title,starts_on,ends_on,status) VALUES ('Später','2026-11-01','2026-11-30','draft');
SELECT league_v21_private.season_transition_core((SELECT id FROM public.league_seasons_v21 WHERE status='active'),'close');
DO $t$ BEGIN
 IF (SELECT count(*) FROM public.league_seasons_v21 WHERE status='draft')<>1 THEN RAISE EXCEPTION 'draft created although a later season exists'; END IF;
END $t$;
DELETE FROM public.league_seasons_v21 WHERE title='Später';
INSERT INTO public.league_seasons_v21(title,starts_on,ends_on,status) VALUES ('Herbst 2026','2025-12-01','2025-12-02','closed'),('X','2026-09-20','2026-10-20','active');
SELECT league_v21_private.season_transition_core((SELECT id FROM public.league_seasons_v21 WHERE title='X'),'close');
DO $t$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.league_seasons_v21 WHERE title='Herbst 2026 (2)' AND status='draft' AND starts_on='2026-10-21' AND ends_on='2026-11-20') THEN RAISE EXCEPTION 'title collision not handled'; END IF;
END $t$;
\ir ../supabase/migrations/20261028110000_season_single_active_next_draft.sql
SELECT 'PASS: never two active seasons, close prepares next draft (same length, unique title) once, repeated close unchanged' AS result;
