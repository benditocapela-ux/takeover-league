\set ON_ERROR_STOP on
DO $$BEGIN IF current_database() NOT LIKE 'league21_replay_%' THEN RAISE EXCEPTION 'Disposable database required'; END IF; END$$;
DO $$BEGIN IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='anon') THEN CREATE ROLE anon; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='authenticated') THEN CREATE ROLE authenticated; END IF; END$$;
CREATE SCHEMA auth;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
GRANT USAGE ON SCHEMA auth TO anon,authenticated;
CREATE TABLE public.profiles(id uuid PRIMARY KEY,auth_user_id uuid UNIQUE,role text,is_active boolean,archived_at timestamptz);
CREATE TABLE public.training_types(id bigint PRIMARY KEY,name text,is_active boolean);
CREATE TABLE public.training_submissions(id uuid PRIMARY KEY,boxer_id uuid REFERENCES public.profiles(id),training_type_id bigint REFERENCES public.training_types(id),
 training_date date NOT NULL,created_at timestamptz NOT NULL,status text NOT NULL,notes text,jogging_km numeric,technique_minutes integer,
 duration_minutes integer,club_tier text,training_location text,recorded_by uuid);
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.training_submissions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.profiles,public.training_submissions,public.training_types FROM PUBLIC,anon,authenticated;
INSERT INTO public.profiles VALUES
 ('11111111-1111-4111-8111-111111111111','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','boxer',true,null),
 ('22222222-2222-4222-8222-222222222222','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','boxer',true,null),
 ('33333333-3333-4333-8333-333333333333','cccccccc-cccc-4ccc-8ccc-cccccccccccc','coach',true,now()),
 ('44444444-4444-4444-8444-444444444444','dddddddd-dddd-4ddd-8ddd-dddddddddddd','boxer',false,null);
INSERT INTO public.training_types VALUES(1,'Reguläres Boxtraining',true),(2,'Sparring',true),(3,'Techniktraining',true),
 (4,'Krafttraining',false),(5,'Sprint-Intervalle',true),(6,'Joggen',true);
INSERT INTO public.training_submissions(id,boxer_id,training_type_id,training_date,created_at,status,notes,jogging_km,technique_minutes)
SELECT md5(i::text)::uuid,'11111111-1111-4111-8111-111111111111',1+(i%6),
 (now() AT TIME ZONE 'Europe/Zurich')::date-(i%80),now(),'approved','Own note '||i,
 CASE WHEN i%6=5 THEN 0.3 END,CASE WHEN i%6=2 THEN 30 END FROM generate_series(0,1199) i;
INSERT INTO public.training_submissions(id,boxer_id,training_type_id,training_date,created_at,status,notes) VALUES
 ('00000000-0000-4000-8000-000000000001','11111111-1111-4111-8111-111111111111',1,current_date,now(),'pending','Own pending'),
 ('00000000-0000-4000-8000-000000000002','11111111-1111-4111-8111-111111111111',1,current_date,now(),'rejected','Own rejected'),
 ('00000000-0000-4000-8000-000000000003','22222222-2222-4222-8222-222222222222',1,current_date,now(),'approved','FOREIGN SECRET');
\ir ../supabase/migrations/20261102103929_studio_training_history_summary.sql
BEGIN READ ONLY;
SET LOCAL ROLE anon;
DO $$BEGIN BEGIN PERFORM public.get_my_studio_training_summary();RAISE EXCEPTION 'Anon allowed';EXCEPTION WHEN insufficient_privilege THEN NULL;END;END$$;
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',true);
SET LOCAL ROLE authenticated;
DO $$DECLARE s jsonb; p jsonb; cursor jsonb; seen uuid[]:='{}'; item jsonb; n integer:=0; BEGIN
 s:=public.get_my_studio_training_summary();
 IF (s#>>'{totals,total}')::int<>1202 OR (s#>>'{progress,training}')::int<>1200
 OR (s#>>'{progress,consistent}')::int<>80 OR (s#>>'{progress,complete}')::int<>200
 OR (s#>>'{progress,road}')::numeric<>60 OR (s#>>'{progress,technician}')::int<>6000
 OR (s->>'day_streak')::int<>80 OR (s->>'last7')::int<>105 OR (s->>'last30')::int<>450
 OR jsonb_array_length(s->'days')<>42 OR jsonb_array_length(s->'types')<>6 THEN RAISE EXCEPTION 'Full aggregate mismatch: %',s;END IF;
 IF s::text LIKE '%note%' OR s::text LIKE '%SECRET%' THEN RAISE EXCEPTION 'Raw notes leaked into summary';END IF;
 LOOP
  p:=public.get_my_studio_training_history('all',(cursor->>'before')::timestamptz,(cursor->>'before_id')::uuid);
  IF jsonb_array_length(p->'items')>20 THEN RAISE EXCEPTION 'Page limit';END IF;
  FOR item IN SELECT * FROM jsonb_array_elements(p->'items') LOOP
   IF (item->>'id')::uuid=ANY(seen) OR item->>'notes'='FOREIGN SECRET' THEN RAISE EXCEPTION 'Duplicate/private row';END IF;
   seen:=array_append(seen,(item->>'id')::uuid);n:=n+1;
  END LOOP;
  cursor:=p->'next_cursor';EXIT WHEN cursor='null'::jsonb;
 END LOOP;
 IF n<>1202 THEN RAISE EXCEPTION 'Missing history beyond 1000: %',n;END IF;
 IF public.get_my_studio_training_summary()<>s THEN RAISE EXCEPTION 'Paging changed stats';END IF;
 IF jsonb_array_length(public.get_my_studio_training_history('pending')->'items')<>1 THEN RAISE EXCEPTION 'Filter';END IF;
 BEGIN PERFORM public.get_my_studio_training_history('bogus');RAISE EXCEPTION 'Badfilter';EXCEPTION WHEN invalid_parameter_value THEN NULL;END;
 BEGIN PERFORM public.get_my_studio_training_history('all',now(),NULL);RAISE EXCEPTION 'Badcursor';EXCEPTION WHEN invalid_parameter_value THEN NULL;END;
 BEGIN PERFORM public.get_my_studio_training_history('all','infinity','00000000-0000-4000-8000-000000000001');RAISE EXCEPTION 'Badtime';EXCEPTION WHEN invalid_parameter_value THEN NULL;END;
 BEGIN PERFORM * FROM public.training_submissions;RAISE EXCEPTION 'Raw access';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
END$$;
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',true);
SET LOCAL ROLE authenticated;
DO $$BEGIN IF public.get_my_studio_training_summary()#>>'{totals,total}'<>'1' THEN RAISE EXCEPTION 'Own-only failed';END IF;END$$;
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','cccccccc-cccc-4ccc-8ccc-cccccccccccc',true);
SET LOCAL ROLE authenticated;
DO $$BEGIN BEGIN PERFORM public.get_my_studio_training_summary();RAISE EXCEPTION 'Archived allowed';EXCEPTION WHEN insufficient_privilege THEN NULL;END;END$$;
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','dddddddd-dddd-4ddd-8ddd-dddddddddddd',true);
SET LOCAL ROLE authenticated;
DO $$BEGIN BEGIN PERFORM public.get_my_studio_training_history();RAISE EXCEPTION 'Inactive allowed';EXCEPTION WHEN insufficient_privilege THEN NULL;END;END$$;
ROLLBACK;
BEGIN;
INSERT INTO public.profiles VALUES('55555555-5555-4555-8555-555555555555','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','boxer',true,null);
SELECT set_config('request.jwt.claim.sub','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',true);
SET LOCAL ROLE authenticated;
DO $$DECLARE s jsonb;BEGIN s:=public.get_my_studio_training_summary();
 IF s#>>'{totals,total}'<>'0' OR s#>>'{progress,complete}'<>'0' OR s->>'day_streak'<>'0' OR s#>>'{weekly,streak}'<>'0'
 OR jsonb_array_length(s->'days')<>0 OR jsonb_array_length(public.get_my_studio_training_history()->'items')<>0 THEN RAISE EXCEPTION 'Empty profile mismatch';END IF;END$$;
RESET ROLE;
-- A gap breaks a daily sequence; an unfinished current week must preserve the last full weeks.
DELETE FROM public.training_submissions WHERE boxer_id='22222222-2222-4222-8222-222222222222';
INSERT INTO public.training_submissions(id,boxer_id,training_type_id,training_date,created_at,status,notes)
SELECT gen_random_uuid(),'22222222-2222-4222-8222-222222222222',1,
 date_trunc('week',now() AT TIME ZONE 'Europe/Zurich')::date-7*w,now(),'approved','Streak fixture'
FROM generate_series(1,3) w CROSS JOIN generate_series(1,2) n;
SELECT set_config('request.jwt.claim.sub','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',true);
SET LOCAL ROLE authenticated;
DO $$BEGIN IF public.get_my_studio_training_summary()#>>'{weekly,streak}'<>'3' THEN RAISE EXCEPTION 'Unfinished current week lost streak';END IF;END$$;
RESET ROLE;
DELETE FROM public.training_submissions WHERE boxer_id='22222222-2222-4222-8222-222222222222'
 AND training_date=date_trunc('week',now() AT TIME ZONE 'Europe/Zurich')::date-7;
SET LOCAL ROLE authenticated;
DO $$BEGIN IF public.get_my_studio_training_summary()#>>'{weekly,streak}'<>'0' THEN RAISE EXCEPTION 'Week gap ignored';END IF;END$$;
ROLLBACK;
\echo PASS own Studio history: 1202 rows across tied cursors, exact aggregates, inactive type, auth boundaries and READ ONLY.
