-- Disposable PostgreSQL fixture only. NEVER run against a Supabase project.
\set ON_ERROR_STOP on
DO $roles$ BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname='anon') THEN CREATE ROLE anon NOLOGIN; END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname='authenticated') THEN CREATE ROLE authenticated NOLOGIN; END IF;
END $roles$;
CREATE SCHEMA auth;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $auth$
 SELECT NULLIF(current_setting('request.jwt.claim.sub',true),'')::uuid;
$auth$;

CREATE TABLE public.profiles(
 id uuid PRIMARY KEY,
 auth_user_id uuid UNIQUE,
 display_name text NOT NULL,
 role text NOT NULL CHECK(role IN ('boxer','admin','coach')),
 is_active boolean NOT NULL DEFAULT true
);
CREATE TABLE public.training_types(id bigint PRIMARY KEY,name text NOT NULL);
CREATE TABLE public.training_submissions(
 id uuid PRIMARY KEY,
 boxer_id uuid NOT NULL REFERENCES public.profiles(id),
 training_type_id bigint NOT NULL REFERENCES public.training_types(id),
 training_date date NOT NULL,
 notes text NOT NULL DEFAULT '',
 status text NOT NULL CHECK(status IN ('pending','approved','rejected')),
 jogging_km numeric,
 technique_minutes integer,
 created_at timestamptz NOT NULL DEFAULT now(),
 reviewed_at timestamptz,
 reviewed_by uuid
);
CREATE TABLE public.point_transactions(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),points integer NOT NULL DEFAULT 0,exp integer NOT NULL DEFAULT 0);
CREATE TABLE public.league_feature_flags(feature_key text PRIMARY KEY,is_enabled boolean NOT NULL DEFAULT false);

INSERT INTO public.profiles(id,auth_user_id,display_name,role) VALUES
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','11111111-1111-4111-8111-111111111111','Test Boxer','boxer'),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','22222222-2222-4222-8222-222222222222','Test Coach','coach');
INSERT INTO public.training_types(id,name) VALUES(1,'Boxtraining');
INSERT INTO public.training_submissions(id,boxer_id,training_type_id,training_date,notes,status,created_at)
SELECT ('00000000-0000-4000-8000-'||lpad(g::text,12,'0'))::uuid,
       'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',1,current_date-g,
       'history row '||g,CASE WHEN g=12 THEN 'pending' ELSE 'approved' END,
       now()-g*interval '1 minute'
FROM generate_series(1,12) AS series(g);

\i supabase/migrations/20261022210000_coach_training_history_pagination.sql

SELECT set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',false);
DO $test$
DECLARE
 page1 jsonb;
 page2 jsonb;
 filtered jsonb;
BEGIN
 page1:=public.coach_list_training_history(p_limit=>10,p_offset=>0);
 IF jsonb_array_length(page1->'items')<>10 OR (page1->>'total_count')::integer<>12 THEN
  RAISE EXCEPTION 'First page must contain 10 of 12 matching trainings';
 END IF;
 IF page1->'items'->0->>'id'<>'00000000-0000-4000-8000-000000000001' THEN
  RAISE EXCEPTION 'History ordering is not newest training date first';
 END IF;
 page2:=public.coach_list_training_history(p_limit=>10,p_offset=>10);
 IF jsonb_array_length(page2->'items')<>2 OR (page2->>'total_count')::integer<>12 THEN
  RAISE EXCEPTION 'Second page must contain remaining 2 trainings';
 END IF;
 IF page1->'items'->0->>'id'=page2->'items'->0->>'id' THEN
  RAISE EXCEPTION 'Pages overlap';
 END IF;
 filtered:=public.coach_list_training_history(p_search=>'history row 12',p_status=>'pending',p_limit=>10,p_offset=>0);
 IF (filtered->>'total_count')::integer<>1 OR filtered->'items'->0->>'notes'<>'history row 12' THEN
  RAISE EXCEPTION 'Server-side text/status filter failed';
 END IF;
 filtered:=public.coach_list_training_history(p_status=>'approved',p_boxer_id=>'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',p_limit=>5,p_offset=>0);
 IF (filtered->>'total_count')::integer<>11 OR jsonb_array_length(filtered->'items')<>5 THEN
  RAISE EXCEPTION 'Server-side boxer/status filter or page limit failed';
 END IF;
 BEGIN
  PERFORM public.coach_list_training_history(p_status=>'all');
  RAISE EXCEPTION 'Invalid status should be rejected';
 EXCEPTION WHEN SQLSTATE '22023' THEN NULL; END;
END
$test$;

SELECT set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',false);
DO $authz$
BEGIN
 BEGIN
  PERFORM public.coach_list_training_history(p_limit=>10,p_offset=>0);
  RAISE EXCEPTION 'Boxer must not read coach history RPC';
 EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END;
 IF has_function_privilege('anon','public.coach_list_training_history(text,uuid,bigint,date,date,text,integer,integer)','EXECUTE') THEN
  RAISE EXCEPTION 'anon unexpectedly has execute privilege';
 END IF;
 IF NOT has_function_privilege('authenticated','public.coach_list_training_history(text,uuid,bigint,date,date,text,integer,integer)','EXECUTE') THEN
  RAISE EXCEPTION 'authenticated execute grant is missing';
 END IF;
END
$authz$;

\i supabase/production-prep/rollback_20261022210000_coach_training_history_pagination.sql
DO $rollback$
BEGIN
 IF to_regprocedure('public.coach_list_training_history(text,uuid,bigint,date,date,text,integer,integer)') IS NOT NULL THEN
  RAISE EXCEPTION 'Rollback did not remove the RPC';
 END IF;
 IF (SELECT count(*) FROM public.training_submissions)<>12 OR (SELECT count(*) FROM public.point_transactions)<>0 THEN
  RAISE EXCEPTION 'History rollback changed training or points data';
 END IF;
END
$rollback$;
SELECT 'Coach training history pagination schema checks passed' AS result;
