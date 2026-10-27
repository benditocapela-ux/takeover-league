\set ON_ERROR_STOP on
-- Disposable-database test for 20261028090000_league_challenges_arena_admin.sql.
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE ROLE anon;
CREATE ROLE authenticated;
CREATE SCHEMA auth;
CREATE SCHEMA league_v21_private;
CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE
AS $$ SELECT NULLIF(current_setting('request.jwt.claim.sub', true),'')::uuid $$;

CREATE TABLE public.profiles(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), auth_user_id uuid UNIQUE, display_name text NOT NULL,
 role text NOT NULL DEFAULT 'boxer', is_active boolean NOT NULL DEFAULT true, is_listed boolean NOT NULL DEFAULT false, archived_at timestamptz);
CREATE TABLE public.league_feature_flags(feature_key text PRIMARY KEY, is_enabled boolean NOT NULL DEFAULT false);
CREATE TABLE public.boxer_notifications(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), recipient_id uuid NOT NULL REFERENCES public.profiles(id),
 notification_type text NOT NULL CHECK (notification_type = ANY (ARRAY['training_approved','training_rejected','coach_feedback','coach_goal',
  'league_challenge','boxer_duel','achievement','season','general','level_up'])),
 title text NOT NULL CHECK (char_length(btrim(title)) BETWEEN 1 AND 160), message text NOT NULL DEFAULT '',
 target_path text CHECK (target_path IS NULL OR (target_path LIKE '/%' AND target_path NOT LIKE '//%')), created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.point_transactions(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), boxer_id uuid NOT NULL, points integer NOT NULL DEFAULT 0,
 exp integer NOT NULL DEFAULT 0, category text NOT NULL, description text);
CREATE TABLE public.league_global_challenges_v21(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), title text NOT NULL, description text NOT NULL DEFAULT '',
 metric text NOT NULL CHECK (metric IN ('training_sessions','jogging_km','technique_minutes')), target_value numeric NOT NULL,
 starts_at timestamptz NOT NULL, ends_at timestamptz NOT NULL, status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','active','closed')),
 created_by uuid NOT NULL, completion_exp integer NOT NULL DEFAULT 0, winner_exp integer NOT NULL DEFAULT 0, CHECK (ends_at>starts_at));
CREATE TABLE public.league_global_entries_v21(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), challenge_id uuid NOT NULL REFERENCES public.league_global_challenges_v21(id),
 boxer_id uuid NOT NULL, joined_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.league_global_results_v21(challenge_id uuid NOT NULL, boxer_id uuid NOT NULL, PRIMARY KEY(challenge_id,boxer_id));
CREATE TABLE public.league_global_exp_ledger_v21(challenge_id uuid NOT NULL, boxer_id uuid NOT NULL, PRIMARY KEY(challenge_id,boxer_id));
CREATE TABLE public.league_arena_duels_v21(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), title text NOT NULL, duration_days integer NOT NULL CHECK (duration_days IN (7,14)),
 status text NOT NULL DEFAULT 'invited' CHECK (status IN ('invited','active','awaiting_reviews','settled','cancelled')),
 starts_at timestamptz, ends_at timestamptz, settled_at timestamptz, created_by uuid NOT NULL, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.league_arena_members_v21(arena_id uuid NOT NULL REFERENCES public.league_arena_duels_v21(id), boxer_id uuid NOT NULL,
 status text NOT NULL DEFAULT 'invited' CHECK (status IN ('invited','accepted','declined')), responded_at timestamptz, PRIMARY KEY(arena_id,boxer_id));
CREATE TABLE public.league_arena_results_v21(arena_id uuid NOT NULL, boxer_id uuid NOT NULL, boxer_name text NOT NULL, score integer NOT NULL, rank_position integer NOT NULL);

-- From 20261027120000 (already in production).
CREATE OR REPLACE FUNCTION league_v21_private.notifications_enabled() RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=''
AS $fn$ SELECT EXISTS(SELECT 1 FROM public.league_feature_flags f WHERE f.feature_key='notifications' AND f.is_enabled IS TRUE) $fn$;

\ir ../supabase/migrations/20261028090000_league_challenges_arena_admin.sql
-- Existing production wrapper (unchanged by the migration).
CREATE FUNCTION public.league_v21_arena_create(p_title text, p_duration integer, p_boxers uuid[]) RETURNS uuid LANGUAGE sql SET search_path=''
AS $fn$ select league_v21_private.arena_create_core(p_title,p_duration,p_boxers) $fn$;

INSERT INTO public.league_feature_flags VALUES ('notifications',true);
INSERT INTO public.profiles(id,auth_user_id,display_name,role,is_active,is_listed,archived_at) VALUES
 ('00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','Admin','admin',true,true,null),
 ('00000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000002','Anna','boxer',true,true,null),
 ('00000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000003','Ben','boxer',true,true,null),
 ('00000000-0000-0000-0000-000000000004','10000000-0000-0000-0000-000000000004','Cleo','boxer',true,true,null),
 ('00000000-0000-0000-0000-000000000005','10000000-0000-0000-0000-000000000005','Privat','boxer',true,false,null),
 ('00000000-0000-0000-0000-000000000006',null,'Archiviert','boxer',false,false,now());

-- Boxer cannot use any admin function.
SELECT set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000002',false);
INSERT INTO public.league_global_challenges_v21(id,title,metric,target_value,starts_at,ends_at,status,created_by) VALUES
 ('20000000-0000-0000-0000-000000000001','Jab Master','technique_minutes',100,now()-interval '10 days',now()-interval '3 days','draft','00000000-0000-0000-0000-000000000001');
DO $t$ BEGIN
 BEGIN PERFORM public.league_v21_admin_publish_global_challenge('20000000-0000-0000-0000-000000000001'); RAISE EXCEPTION 'boxer publish ok';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.league_v21_admin_delete_global_draft('20000000-0000-0000-0000-000000000001'); RAISE EXCEPTION 'boxer delete ok';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.league_v21_arena_cancel(gen_random_uuid()); RAISE EXCEPTION 'boxer cancel ok';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $t$;

SELECT set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',false);
-- Expired draft cannot be published; after re-dating it can; publishing twice is idempotent.
DO $t$ BEGIN
 BEGIN PERFORM public.league_v21_admin_publish_global_challenge('20000000-0000-0000-0000-000000000001'); RAISE EXCEPTION 'expired publish ok';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.league_v21_admin_update_global_draft('20000000-0000-0000-0000-000000000001','Jab Master','',
   'technique_minutes',100,now(),now()+interval '91 days'); RAISE EXCEPTION 'too long ok';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
END $t$;
SELECT public.league_v21_admin_update_global_draft('20000000-0000-0000-0000-000000000001','Jab Master 2','Neu',
 'technique_minutes',120,now()+interval '1 day',now()+interval '8 days');
SELECT public.league_v21_admin_publish_global_challenge('20000000-0000-0000-0000-000000000001');
DO $t$ BEGIN
 IF (SELECT status||'/'||title||'/'||target_value FROM public.league_global_challenges_v21 WHERE id='20000000-0000-0000-0000-000000000001')<>'active/Jab Master 2/120' THEN
  RAISE EXCEPTION 'draft update/publish failed'; END IF;
 IF (public.league_v21_admin_publish_global_challenge('20000000-0000-0000-0000-000000000001')->>'unchanged')<>'true' THEN RAISE EXCEPTION 'publish not idempotent'; END IF;
 -- Published challenge is history: no full edit, no delete.
 BEGIN PERFORM public.league_v21_admin_update_global_draft('20000000-0000-0000-0000-000000000001','X Y Z','','training_sessions',1,now()+interval '1 day',now()+interval '2 days');
  RAISE EXCEPTION 'active full edit ok'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.league_v21_admin_delete_global_draft('20000000-0000-0000-0000-000000000001'); RAISE EXCEPTION 'active delete ok';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
END $t$;

-- Draft with any trace is kept; unused draft is deleted.
INSERT INTO public.league_global_challenges_v21(id,title,metric,target_value,starts_at,ends_at,status,created_by) VALUES
 ('20000000-0000-0000-0000-000000000002','Unbenutzt','training_sessions',5,now()+interval '1 day',now()+interval '5 days','draft','00000000-0000-0000-0000-000000000001'),
 ('20000000-0000-0000-0000-000000000003','Mit Spur','training_sessions',5,now()+interval '1 day',now()+interval '5 days','draft','00000000-0000-0000-0000-000000000001');
INSERT INTO public.point_transactions(boxer_id,exp,category,description) VALUES
 ('00000000-0000-0000-0000-000000000002',10,'challenge_exp','Global challenge reward: 20000000-0000-0000-0000-000000000003');
SELECT public.league_v21_admin_delete_global_draft('20000000-0000-0000-0000-000000000002');
DO $t$ BEGIN
 IF EXISTS(SELECT 1 FROM public.league_global_challenges_v21 WHERE id='20000000-0000-0000-0000-000000000002') THEN RAISE EXCEPTION 'unused draft not deleted'; END IF;
 BEGIN PERFORM public.league_v21_admin_delete_global_draft('20000000-0000-0000-0000-000000000003'); RAISE EXCEPTION 'traced draft deleted';
 EXCEPTION WHEN foreign_key_violation THEN NULL; END;
 IF (SELECT count(*) FROM public.point_transactions)<>1 THEN RAISE EXCEPTION 'ledger changed'; END IF;
END $t$;

-- Arena: non-public boxers cannot be invited; invitations notify; cancel is idempotent and keeps settled history.
DO $t$ BEGIN
 BEGIN PERFORM public.league_v21_arena_create('Arena privat',7,ARRAY['00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000005']::uuid[]);
  RAISE EXCEPTION 'unlisted invite ok'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.league_v21_arena_create('Arena archiv',7,ARRAY['00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000006']::uuid[]);
  RAISE EXCEPTION 'archived invite ok'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
END $t$;
SELECT set_config('test.arena',public.league_v21_arena_create('Arena Oktober',7,ARRAY['00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000004']::uuid[])::text,false);
DO $t$ BEGIN
 IF (SELECT count(*) FROM public.boxer_notifications WHERE target_path='/arena.html' AND title LIKE 'Einladung zur Arena%')<>3 THEN RAISE EXCEPTION 'invite notifications missing'; END IF;
END $t$;
UPDATE public.league_arena_members_v21 SET status='declined' WHERE boxer_id='00000000-0000-0000-0000-000000000004';
SELECT public.league_v21_arena_cancel(current_setting('test.arena')::uuid);
DO $t$ BEGIN
 IF (SELECT status FROM public.league_arena_duels_v21 WHERE id=current_setting('test.arena')::uuid)<>'cancelled' THEN RAISE EXCEPTION 'arena not cancelled'; END IF;
 IF (SELECT count(*) FROM public.boxer_notifications WHERE title LIKE 'Arena «Arena Oktober» abgesagt')<>2 THEN RAISE EXCEPTION 'cancel notifications must reach invited/accepted only'; END IF;
 IF (public.league_v21_arena_cancel(current_setting('test.arena')::uuid)->>'unchanged')<>'true' THEN RAISE EXCEPTION 'cancel not idempotent'; END IF;
END $t$;
INSERT INTO public.league_arena_duels_v21(id,title,duration_days,status,created_by) VALUES
 ('30000000-0000-0000-0000-000000000001','Gewertet',7,'settled','00000000-0000-0000-0000-000000000001'),
 ('30000000-0000-0000-0000-000000000002','Mit Ergebnis',7,'awaiting_reviews','00000000-0000-0000-0000-000000000001');
INSERT INTO public.league_arena_results_v21 VALUES ('30000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000002','Anna',10,1);
DO $t$ BEGIN
 BEGIN PERFORM public.league_v21_arena_cancel('30000000-0000-0000-0000-000000000001'); RAISE EXCEPTION 'settled cancel ok';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.league_v21_arena_cancel('30000000-0000-0000-0000-000000000002'); RAISE EXCEPTION 'cancel with results ok';
 EXCEPTION WHEN check_violation THEN NULL; END;
 IF (SELECT count(*) FROM public.league_arena_results_v21)<>1 THEN RAISE EXCEPTION 'results changed'; END IF;
END $t$;

-- Grants.
DO $t$ BEGIN
 IF has_function_privilege('anon','public.league_v21_arena_cancel(uuid)','execute')
    OR has_function_privilege('anon','public.league_v21_admin_publish_global_challenge(uuid)','execute')
    OR NOT has_function_privilege('authenticated','public.league_v21_admin_delete_global_draft(uuid)','execute') THEN
  RAISE EXCEPTION 'Unexpected grants'; END IF;
END $t$;

\ir ../supabase/migrations/20261028090000_league_challenges_arena_admin.sql
SELECT 'PASS: drafts can be edited, published (not when expired) and deleted only without traces; arena only with public boxers, invitations and cancellations notify, cancel keeps settled history; admin-only' AS result;
