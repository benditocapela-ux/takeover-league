\set ON_ERROR_STOP on
BEGIN;
DO $$ BEGIN IF current_database() NOT LIKE 'league21_replay_%' THEN RAISE EXCEPTION 'Disposable database required'; END IF; END $$;
CREATE FUNCTION pg_temp.check_queue(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERT: %',label; END IF; END $$;
INSERT INTO public.profiles(id,auth_user_id,display_name,role,is_active,archived_at) VALUES
 ('44444444-4444-4444-8444-444444444444','dddddddd-dddd-4ddd-8ddd-dddddddddddd','Queue Coach','coach',true,NULL),
 ('55555555-5555-4555-8555-555555555555','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','Queue Inactive','coach',false,NULL),
 ('66666666-6666-4666-8666-666666666666','ffffffff-ffff-4fff-8fff-ffffffffffff','Queue Archived','coach',true,now());
-- A same-timestamp page boundary requires both timestamp and UUID cursor components.
INSERT INTO public.league_duels(id,challenger_id,opponent_id,status,duration_days,invited_at,accepted_at,ends_at,settled_at)
SELECT ('90000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
 '11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222',
 'settled',7,now()-interval '1 day',now()-interval '9 days',now()-interval '2 days',now()-interval '2 days'
FROM generate_series(1,120) i;
INSERT INTO public.league_duels(id,challenger_id,opponent_id,status,duration_days,invited_at,accepted_at,ends_at) VALUES
 ('80000000-0000-4000-8000-000000000001','11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222','active',7,now()-interval '121 days',now()-interval '120 days',now()-interval '113 days'),
 ('80000000-0000-4000-8000-000000000002','11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222','awaiting_reviews',7,now()-interval '21 days',now()-interval '20 days',now()-interval '13 days'),
 ('80000000-0000-4000-8000-000000000003','11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222','active',7,now()-interval '41 days',now()-interval '40 days',now()-interval '33 days'),
 ('80000000-0000-4000-8000-000000000004','11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222','active',7,now()-interval '2 days',now()-interval '1 day',now()+interval '6 days');
INSERT INTO public.league_duels(id,challenger_id,opponent_id,status,duration_days,invited_at,expires_at) VALUES
 ('80000000-0000-4000-8000-000000000005','11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222','pending',7,now(),now()+interval '1 day'),
 ('80000000-0000-4000-8000-000000000006','11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222','pending',7,now()-interval '4 days',now()-interval '1 day'),
 ('80000000-0000-4000-8000-000000000007','11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222','declined',7,now()-interval '5 days',now()-interval '3 days');
INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,status,created_at) VALUES
 ('11111111-1111-4111-8111-111111111111',1,current_date-17,'pending',now()-interval '17 days'),
 ('11111111-1111-4111-8111-111111111111',1,current_date-37,'approved',now()-interval '37 days');
SELECT set_config('request.jwt.claim.sub','dddddddd-dddd-4ddd-8ddd-dddddddddddd',true);
DO $snapshot$ BEGIN PERFORM set_config('queue.before',jsonb_build_object('duels',(SELECT jsonb_agg(to_jsonb(d) ORDER BY id) FROM public.league_duels d),
 'tx',(SELECT count(*) FROM public.point_transactions),'ledger',(SELECT count(*) FROM public.league_duel_exp_ledger),
 'events',(SELECT count(*) FROM public.league_duel_events),'notifications',(SELECT count(*) FROM public.boxer_notifications))::text,true); END $snapshot$;
SET LOCAL ROLE authenticated;
EXPLAIN (ANALYZE,BUFFERS) SELECT public.duel_v2_staff_queue();
DO $$ DECLARE p jsonb; cursor jsonb; ids uuid[]:='{}'; item jsonb; pages integer:=0; BEGIN
 p:=public.duel_v2_staff_queue();
 PERFORM pg_temp.check_queue(jsonb_array_length(p->'items')=3,'old due rows reachable before >100 newer settled');
 PERFORM pg_temp.check_queue(p->'counts'='{"all":127,"open":2,"due":3,"ready":1,"closed":120}'::jsonb,'all scope counts exact and ready excludes blocked');
 PERFORM pg_temp.check_queue(p->'next_cursor'='null'::jsonb,'three due rows need no next page');
 p:=public.duel_v2_staff_queue('ready');
 PERFORM pg_temp.check_queue(jsonb_array_length(p->'items')=1 AND p#>>'{items,0,id}'='80000000-0000-4000-8000-000000000001','only actual preview-ready duel');
 p:=public.duel_v2_staff_queue('open');PERFORM pg_temp.check_queue(jsonb_array_length(p->'items')=2,'expired pending and due are not open');
 p:=public.duel_v2_staff_queue('closed');PERFORM pg_temp.check_queue(jsonb_array_length(p->'items')=20,'bounded closed page');
 LOOP
  p:=public.duel_v2_staff_queue('all',20,(cursor->>'before')::timestamptz,(cursor->>'before_id')::uuid);
  pages:=pages+1;
  PERFORM pg_temp.check_queue(jsonb_array_length(p->'items')<=20,'every page bounded20');
  FOR item IN SELECT value FROM jsonb_array_elements(p->'items') LOOP
   PERFORM pg_temp.check_queue(NOT ((item->>'id')::uuid=ANY(ids)),'cursor never duplicates a same-timestamp ID');
   ids:=array_append(ids,(item->>'id')::uuid);
  END LOOP;
  cursor:=p->'next_cursor';EXIT WHEN cursor='null'::jsonb;
  PERFORM pg_temp.check_queue(pages<10,'pagination terminates');
 END LOOP;
 PERFORM pg_temp.check_queue(cardinality(ids)=127 AND pages=7,'pagination reaches all127 with old due included');
 p:=public.duel_v2_staff_queue(p_state=>'all',p_search=>'FIXTURE BOXER ALPHA');PERFORM pg_temp.check_queue((p#>>'{counts,all}')::int=127,'case-insensitive names');
 p:=public.duel_v2_staff_queue(p_state=>'all',p_search=>'%');PERFORM pg_temp.check_queue((p#>>'{counts,all}')::int=0,'percent is literal, never wildcard');
 p:=public.duel_v2_staff_queue(p_state=>'all',p_search=>'_');PERFORM pg_temp.check_queue((p#>>'{counts,all}')::int=0,'underscore is literal');
 p:=public.duel_v2_staff_queue(p_state=>'all',p_duel_id=>'80000000-0000-4000-8000-000000000001');PERFORM pg_temp.check_queue(jsonb_array_length(p->'items')=1 AND p#>>'{items,0,id}'='80000000-0000-4000-8000-000000000001','old precise staff deep link');
 p:=public.duel_v2_staff_queue(p_state=>'all',p_limit=>500);PERFORM pg_temp.check_queue(jsonb_array_length(p->'items')=20,'caller cannot increase limit');
 BEGIN PERFORM public.duel_v2_staff_queue(p_before=>now());RAISE EXCEPTION 'Invalid cursor accepted';EXCEPTION WHEN invalid_parameter_value THEN NULL;END;
 BEGIN PERFORM public.duel_v2_staff_queue(p_state=>'unknown');RAISE EXCEPTION 'Invalid state accepted';EXCEPTION WHEN invalid_parameter_value THEN NULL;END;
 BEGIN PERFORM public.duel_v2_staff_queue(p_search=>repeat('x',81));RAISE EXCEPTION 'Long search accepted';EXCEPTION WHEN invalid_parameter_value THEN NULL;END;
END $$;
RESET ROLE;
SELECT pg_temp.check_queue(current_setting('queue.before')::jsonb=jsonb_build_object('duels',(SELECT jsonb_agg(to_jsonb(d) ORDER BY id) FROM public.league_duels d),
 'tx',(SELECT count(*) FROM public.point_transactions),'ledger',(SELECT count(*) FROM public.league_duel_exp_ledger),
 'events',(SELECT count(*) FROM public.league_duel_events),'notifications',(SELECT count(*) FROM public.boxer_notifications)),'queue reads change no game state or notifications');
-- Later metric routing column must exclude non-points without replacing this queue function.
ALTER TABLE public.league_duels ADD COLUMN IF NOT EXISTS scoring_metric text NOT NULL DEFAULT 'points';
UPDATE public.league_duels SET scoring_metric='jogging_km' WHERE id='80000000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;
SELECT pg_temp.check_queue((public.duel_v2_staff_queue()#>>'{counts,ready}')::int=0 AND (public.duel_v2_staff_queue()#>>'{counts,due}')::int=2,'future non-points excluded before any legacy preview');
RESET ROLE;
UPDATE public.league_duels SET scoring_metric='points' WHERE id='80000000-0000-4000-8000-000000000001';
-- Anonymous, boxer, inactive and archived identities cannot read staff queue metadata/counts.
SELECT set_config('request.jwt.claim.sub','',true);SET LOCAL ROLE anon;
DO $$ BEGIN BEGIN PERFORM public.duel_v2_staff_queue();RAISE EXCEPTION 'Anon queue granted';EXCEPTION WHEN insufficient_privilege THEN NULL;END;END $$;RESET ROLE;
DO $$ DECLARE subject text; BEGIN
 FOREACH subject IN ARRAY ARRAY['aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','ffffffff-ffff-4fff-8fff-ffffffffffff','99999999-9999-4999-8999-999999999999'] LOOP
  PERFORM set_config('request.jwt.claim.sub',subject,true);SET LOCAL ROLE authenticated;
  BEGIN PERFORM public.duel_v2_staff_queue();RAISE EXCEPTION 'Unauthorized queue granted';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
  RESET ROLE;
 END LOOP;
END $$;
SELECT set_config('request.jwt.claim.sub','cccccccc-cccc-4ccc-8ccc-cccccccccccc',true);SET LOCAL ROLE authenticated;
SELECT pg_temp.check_queue((public.duel_v2_staff_queue()#>>'{counts,due}')::int=3,'admin authorized');RESET ROLE;
UPDATE public.league_feature_flags SET is_enabled=false WHERE feature_key='duels';SET LOCAL ROLE authenticated;
DO $$ BEGIN BEGIN PERFORM public.duel_v2_staff_queue();RAISE EXCEPTION 'Disabled flag bypassed';EXCEPTION WHEN insufficient_privilege THEN NULL;END;END $$;RESET ROLE;
SELECT pg_temp.check_queue(NOT has_function_privilege('anon','public.duel_v2_staff_queue(text,integer,timestamptz,uuid,text,uuid)','EXECUTE'),'no anonymous execution grant');
ROLLBACK;
\echo Staff queue: exact scopes, all127 rows, old due/deep links, literal search, role barriers, future metric exclusion and read-only state passed.
