\set ON_ERROR_STOP on
-- Disposable-database test for 20261028130000_duel_notifications.sql (+ rollback).
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE ROLE anon;
CREATE ROLE authenticated;
CREATE SCHEMA league_v21_private;
CREATE TABLE public.profiles(id uuid PRIMARY KEY, display_name text NOT NULL);
CREATE TABLE public.league_feature_flags(feature_key text PRIMARY KEY, is_enabled boolean NOT NULL DEFAULT false);
CREATE TABLE public.boxer_notifications(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), recipient_id uuid NOT NULL REFERENCES public.profiles(id),
 notification_type text NOT NULL, title text NOT NULL CHECK (char_length(btrim(title)) BETWEEN 1 AND 160), message text NOT NULL DEFAULT '',
 target_path text, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.league_duels(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), challenger_id uuid NOT NULL, opponent_id uuid NOT NULL,
 status text NOT NULL DEFAULT 'pending', duration_days integer NOT NULL DEFAULT 7, challenger_score integer NOT NULL DEFAULT 0,
 opponent_score integer NOT NULL DEFAULT 0, winner_id uuid, settled_at timestamptz);
CREATE OR REPLACE FUNCTION league_v21_private.notifications_enabled() RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=''
AS $fn$ SELECT EXISTS(SELECT 1 FROM public.league_feature_flags f WHERE f.feature_key='notifications' AND f.is_enabled IS TRUE) $fn$;
\ir ../supabase/migrations/20261028130000_duel_notifications.sql
INSERT INTO public.league_feature_flags VALUES ('notifications',true);
INSERT INTO public.profiles VALUES ('00000000-0000-0000-0000-000000000001','Anna'),('00000000-0000-0000-0000-000000000002','Ben');
INSERT INTO public.league_duels(id,challenger_id,opponent_id) VALUES ('d0000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002');
UPDATE public.league_duels SET status='active';
UPDATE public.league_duels SET status='awaiting_reviews';
UPDATE public.league_duels SET status='settled',challenger_score=30,opponent_score=20,winner_id='00000000-0000-0000-0000-000000000001',settled_at=now();
UPDATE public.league_duels SET status='settled';
DO $t$ DECLARE t text; BEGIN
 SELECT string_agg(p.display_name||': '||n.title,' | ' ORDER BY n.created_at,p.display_name) INTO t FROM public.boxer_notifications n JOIN public.profiles p ON p.id=n.recipient_id;
 IF t IS DISTINCT FROM 'Ben: Duell-Einladung von Anna | Anna: Ben hat dein Duell angenommen | Anna: Duell gegen Ben gewonnen | Ben: Duell gegen Anna verloren' THEN
  RAISE EXCEPTION 'unexpected notifications: %',t; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.boxer_notifications WHERE title='Duell gegen Anna verloren' AND message LIKE '%Revanche?%') THEN RAISE EXCEPTION 'revenge hint missing'; END IF;
END $t$;
UPDATE public.league_feature_flags SET is_enabled=false;
INSERT INTO public.league_duels(challenger_id,opponent_id) VALUES ('00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001');
DO $t$ BEGIN IF (SELECT count(*) FROM public.boxer_notifications)<>4 THEN RAISE EXCEPTION 'flag off must suppress'; END IF; END $t$;
\ir ../supabase/migrations/20261028130000_duel_notifications.sql
\ir ../supabase/production-prep/rollback_20261028130000_duel_notifications.sql
DO $t$ BEGIN IF EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='league_v21_notify_duel_events') THEN RAISE EXCEPTION 'rollback left trigger'; END IF; END $t$;
SELECT 'PASS: duel invite/accept/settle notify the right boxers once, flag off suppresses, idempotent, rollback removes trigger' AS result;
