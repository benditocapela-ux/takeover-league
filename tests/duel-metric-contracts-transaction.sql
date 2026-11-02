\set ON_ERROR_STOP on
BEGIN;
DO $$ BEGIN IF current_database() NOT LIKE 'league21_replay_%' THEN RAISE EXCEPTION 'Disposable database required'; END IF; END $$;
SET LOCAL TIME ZONE 'UTC';
CREATE FUNCTION pg_temp.metric_assert(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERT: %',label; END IF; END $$;
CREATE FUNCTION pg_temp.metric_error(command text,state text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
 BEGIN EXECUTE command; EXCEPTION WHEN OTHERS THEN
  IF SQLSTATE=state THEN RETURN; ELSE RAISE; END IF;
 END;
 RAISE EXCEPTION 'Expected error % from %',state,command;
END $$;
CREATE FUNCTION pg_temp.metric_rule(metric text,type_id bigint DEFAULT NULL) RETURNS jsonb LANGUAGE sql STABLE AS $$
 SELECT jsonb_build_object('metric_revision',(SELECT m->>'revision' FROM jsonb_array_elements(public.duel_v3_options()->'metrics') m WHERE m->>'key'=metric),
  'training_type_revision',CASE WHEN metric='training_count' THEN (SELECT t->>'revision' FROM jsonb_array_elements(public.duel_v3_options()->'training_types') t WHERE (t->>'id')::bigint=type_id) END)
$$;
-- Only fixture owner may seed past authoritative receipts. This helper is not an app API.
CREATE FUNCTION pg_temp.seed_metric_receipts() RETURNS void LANGUAGE plpgsql AS $$ BEGIN
 IF current_user<>'postgres' OR current_database() NOT LIKE 'league21_replay_%' THEN RAISE EXCEPTION 'Fixture owner required' USING errcode='42501'; END IF;
 ALTER TABLE public.training_submissions DISABLE TRIGGER zz_league_training_receipt_guard;
 UPDATE public.training_submissions SET server_received_at=created_at WHERE id::text LIKE '72000000-%';
 ALTER TABLE public.training_submissions ENABLE TRIGGER zz_league_training_receipt_guard;
END $$;
REVOKE ALL ON FUNCTION pg_temp.seed_metric_receipts() FROM PUBLIC,anon,authenticated;
SELECT pg_temp.metric_assert((SELECT count(*) FROM league_v21_private.duel_metric_config WHERE NOT enabled AND reward_rule IS NULL)=2,'migration leaves both metrics disabled/unconfigured');
INSERT INTO public.profiles(id,auth_user_id,display_name,role,is_active,is_listed) VALUES
 ('71111111-1111-4111-8111-111111111111','7aaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Metric Alpha','boxer',true,true),
 ('72222222-2222-4222-8222-222222222222','7bbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','Metric Beta','boxer',true,true),
 ('73333333-3333-4333-8333-333333333333','7ccccccc-cccc-4ccc-8ccc-cccccccccccc','Metric Spectator','boxer',true,true),
 ('74444444-4444-4444-8444-444444444444','7ddddddd-dddd-4ddd-8ddd-dddddddddddd','Metric Coach','coach',true,false);
INSERT INTO public.training_types(id,name,points,is_active) VALUES
 (101,'Fixture Joggen',10,true),(102,'Fixture Boxen',20,true),(103,'Fixture Inactive',20,false),(104,'Fixture Other',10,true);
SELECT set_config('request.jwt.claim.sub','7aaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE o jsonb; BEGIN
 o:=public.duel_v3_options();
 PERFORM pg_temp.metric_assert((SELECT count(*) FROM jsonb_array_elements(o->'metrics') m WHERE NOT (m->>'enabled')::boolean)=2,'new options visibly disabled');
 PERFORM pg_temp.metric_error($q$select public.duel_v3_invite('71111111-1111-4111-8111-111111111111','72222222-2222-4222-8222-222222222222',7,'jogging_km',NULL,'participants',pg_temp.metric_rule('jogging_km'))$q$,'42501');
 PERFORM pg_temp.metric_error($q$select public.duel_v3_invite('71111111-1111-4111-8111-111111111111','72222222-2222-4222-8222-222222222222',7,NULL)$q$,'22023');
 PERFORM pg_temp.metric_error($q$select public.duel_v3_invite('71111111-1111-4111-8111-111111111111','72222222-2222-4222-8222-222222222222',7,'points',NULL,'public')$q$,'22023');
END $$;
RESET ROLE;
UPDATE league_v21_private.duel_metric_config SET enabled=true;
SET LOCAL ROLE authenticated;
SELECT pg_temp.metric_error($q$select public.duel_v3_invite('71111111-1111-4111-8111-111111111111','72222222-2222-4222-8222-222222222222',7,'training_count',102,'participants',pg_temp.metric_rule('training_count',102))$q$,'42501');
RESET ROLE;
-- This explicit no-reward selection exists ONLY inside the isolated rollback fixture.
UPDATE league_v21_private.duel_metric_config SET reward_rule='none',jogging_training_type_id=CASE WHEN metric='jogging_km' THEN 101 END;
SELECT set_config('metric.reviewed_jog',pg_temp.metric_rule('jogging_km')::text,true);
SELECT set_config('metric.reviewed_count',pg_temp.metric_rule('training_count',102)::text,true);
UPDATE league_v21_private.duel_metric_config SET reward_rule='ranked_v21' WHERE metric='jogging_km';
SET LOCAL ROLE authenticated;
SELECT pg_temp.metric_error(format('select public.duel_v3_invite(%L,%L,7,''jogging_km'',NULL,''participants'',%L::jsonb)',
 '71111111-1111-4111-8111-111111111111','72222222-2222-4222-8222-222222222222',current_setting('metric.reviewed_jog')),'40001');
RESET ROLE;
UPDATE league_v21_private.duel_metric_config SET reward_rule='none' WHERE metric='jogging_km';
UPDATE public.training_types SET name='Changed after review' WHERE id=102;
SET LOCAL ROLE authenticated;
SELECT pg_temp.metric_error(format('select public.duel_v3_invite(%L,%L,7,''training_count'',102,''participants'',%L::jsonb)',
 '71111111-1111-4111-8111-111111111111','72222222-2222-4222-8222-222222222222',current_setting('metric.reviewed_count')),'40001');
SELECT pg_temp.metric_error($q$select public.duel_v3_invite('71111111-1111-4111-8111-111111111111','72222222-2222-4222-8222-222222222222',7,'points')$q$,'22023');
RESET ROLE;
UPDATE public.training_types SET name='Fixture Boxen' WHERE id=102;
SELECT pg_temp.metric_assert(NOT EXISTS(SELECT 1 FROM public.league_duels WHERE challenger_id='71111111-1111-4111-8111-111111111111'),'stale/unreviewed rule created no invitation');
SET LOCAL ROLE authenticated;
SELECT pg_temp.metric_error($q$select public.duel_v3_invite('71111111-1111-4111-8111-111111111111','72222222-2222-4222-8222-222222222222',7,'training_count')$q$,'22023');
SELECT pg_temp.metric_error($q$select public.duel_v3_invite('71111111-1111-4111-8111-111111111111','72222222-2222-4222-8222-222222222222',7,'training_count',103)$q$,'22023');
SELECT pg_temp.metric_error($q$select public.duel_v3_invite('71111111-1111-4111-8111-111111111111','72222222-2222-4222-8222-222222222222',7,'jogging_km',104)$q$,'22023');
SELECT set_config('metric.actual',public.duel_v3_invite('71111111-1111-4111-8111-111111111111','72222222-2222-4222-8222-222222222222',7,'jogging_km',NULL,'participants',pg_temp.metric_rule('jogging_km'))::text,true);
SELECT pg_temp.metric_assert(public.duel_v3_list('mine','all',20,NULL,NULL,NULL,current_setting('metric.actual')::uuid)#>>'{items,0,id}'=current_setting('metric.actual'),'exact pending deep link remains authorized');
SELECT pg_temp.metric_error($q$select public.duel_v3_invite('71111111-1111-4111-8111-111111111111','72222222-2222-4222-8222-222222222222',7,'training_count',102,'participants',pg_temp.metric_rule('training_count',102))$q$,'P0001');
SELECT pg_temp.metric_error(format('select public.duel_v2_respond(%L,true)',current_setting('metric.actual')),'P0001');
SELECT set_config('request.jwt.claim.sub','7bbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',true);
SELECT pg_temp.metric_assert(public.duel_v2_respond(current_setting('metric.actual')::uuid,true)='active','actual opponent accepts metric through existing guarded path');
RESET ROLE;
SELECT pg_temp.metric_assert((SELECT scoring_starts_at=(((accepted_at AT TIME ZONE 'Europe/Zurich')::date+1)::timestamp AT TIME ZONE 'Europe/Zurich')
 AND (ends_at AT TIME ZONE 'Europe/Zurich')::date-(scoring_starts_at AT TIME ZONE 'Europe/Zurich')::date=7
 FROM public.league_duels WHERE id=current_setting('metric.actual')::uuid),'actual acceptance starts next local midnight for seven days');
SELECT pg_temp.metric_error(format('update public.league_duels set ends_at=ends_at+interval ''1 day'' where id=%L',current_setting('metric.actual')),'23514');
SELECT pg_temp.metric_error(format('update public.league_duels set scoring_contract=jsonb_set(scoring_contract,''{reward_rule}'',''"ranked_v21"'') where id=%L',current_setting('metric.actual')),'23514');
SELECT pg_temp.metric_error(format('update public.league_duels set scoring_training_type_id=104 where id=%L',current_setting('metric.actual')),'23514');
-- Fixture-only cancellation frees the pair; historic acceptance below exercises DST without changing an accepted contract.
UPDATE public.league_duels SET status='cancelled' WHERE id=current_setting('metric.actual')::uuid;
SELECT set_config('request.jwt.claim.sub','7aaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',true);
SET LOCAL ROLE authenticated;
SELECT set_config('metric.jog',public.duel_v3_invite('71111111-1111-4111-8111-111111111111','72222222-2222-4222-8222-222222222222',7,'jogging_km',NULL,'participants',pg_temp.metric_rule('jogging_km'))::text,true);
RESET ROLE;
UPDATE public.league_duels SET status='active',accepted_at='2026-10-23 14:30Z',ends_at='2026-10-30 14:30Z'
 WHERE id=current_setting('metric.jog')::uuid;
SELECT pg_temp.metric_assert((SELECT scoring_starts_at='2026-10-23 22:00Z'::timestamptz AND ends_at='2026-10-30 23:00Z'::timestamptz
 AND extract(epoch FROM ends_at-scoring_starts_at)/3600=169 FROM public.league_duels WHERE id=current_setting('metric.jog')::uuid),'seven full local days span winter DST in 169 hours');
-- Changes to release configuration never change the invitation's agreed reward contract.
UPDATE league_v21_private.duel_metric_config SET reward_rule='ranked_v21',enabled=false WHERE metric='jogging_km';
INSERT INTO public.training_submissions(id,boxer_id,training_type_id,training_date,status,created_at,jogging_km) VALUES
 ('72000000-0000-4000-8000-000000000001','71111111-1111-4111-8111-111111111111',101,'2026-10-24','approved','2026-10-23 22:00Z',1.25),
 ('72000000-0000-4000-8000-000000000002','71111111-1111-4111-8111-111111111111',101,'2026-10-25','approved','2026-10-25 12:00Z',2.10),
 ('72000000-0000-4000-8000-000000000003','72222222-2222-4222-8222-222222222222',101,'2026-10-26','approved','2026-10-26 12:00Z',3.30),
 ('72000000-0000-4000-8000-000000000004','71111111-1111-4111-8111-111111111111',102,'2026-10-26','approved','2026-10-26 12:00Z',999),
 ('72000000-0000-4000-8000-000000000005','71111111-1111-4111-8111-111111111111',101,'2026-10-27','rejected','2026-10-27 12:00Z',50),
 ('72000000-0000-4000-8000-000000000006','72222222-2222-4222-8222-222222222222',101,'2026-10-28','pending','2026-10-28 12:00Z',5),
 ('72000000-0000-4000-8000-000000000007','72222222-2222-4222-8222-222222222222',101,'2026-10-29','pending','2026-10-30 23:00Z',50),
 ('72000000-0000-4000-8000-000000000008','71111111-1111-4111-8111-111111111111',101,'2026-10-31','approved','2026-10-30 22:59Z',999),
 ('72000000-0000-4000-8000-000000000009','71111111-1111-4111-8111-111111111111',101,'2026-10-27','approved','2026-10-27 12:00Z',NULL);
INSERT INTO public.point_transactions(boxer_id,submission_id,points,exp,category,description,effective_date)
SELECT boxer_id,id,10,10,'training','Synthetic metric ledger',training_date FROM public.training_submissions
 WHERE id IN ('72000000-0000-4000-8000-000000000001','72000000-0000-4000-8000-000000000002',
 '72000000-0000-4000-8000-000000000003','72000000-0000-4000-8000-000000000004','72000000-0000-4000-8000-000000000009');
SELECT pg_temp.seed_metric_receipts();
SET LOCAL ROLE authenticated;
SELECT pg_temp.metric_error(format('select public.duel_v3_live_scores(%L)',current_setting('metric.jog')),'23514');
SELECT pg_temp.metric_error(format('select public.duel_v2_live_scores(%L)',current_setting('metric.jog')),'22023');
RESET ROLE;
UPDATE public.training_submissions SET jogging_km=0 WHERE id='72000000-0000-4000-8000-000000000009';
ALTER TABLE public.training_submissions DISABLE TRIGGER zz_league_training_receipt_guard;
UPDATE public.training_submissions SET server_received_at=NULL WHERE id='72000000-0000-4000-8000-000000000001';
ALTER TABLE public.training_submissions ENABLE TRIGGER zz_league_training_receipt_guard;
SET LOCAL ROLE authenticated;
SELECT pg_temp.metric_error(format('select public.duel_v3_live_scores(%L)',current_setting('metric.jog')),'23514');
RESET ROLE;
SELECT pg_temp.seed_metric_receipts();
UPDATE public.training_submissions SET jogging_km='NaN'::numeric WHERE id='72000000-0000-4000-8000-000000000009';
SET LOCAL ROLE authenticated;
SELECT pg_temp.metric_error(format('select public.duel_v3_live_scores(%L)',current_setting('metric.jog')),'23514');
RESET ROLE;
UPDATE public.training_submissions SET jogging_km=0 WHERE id='72000000-0000-4000-8000-000000000009';
SET LOCAL ROLE authenticated;
DO $$ DECLARE s jsonb; BEGIN
 s:=public.duel_v3_live_scores(current_setting('metric.jog')::uuid);
 PERFORM pg_temp.metric_assert((s->>'challenger_score')::numeric=3.35 AND (s->>'opponent_score')::numeric=3.30,'exact numeric km, type/date/rejection filtering');
 PERFORM pg_temp.metric_assert((s->>'pending')::int=1,'exclusive end excludes late pending');
END $$;
SELECT set_config('request.jwt.claim.sub','7ccccccc-cccc-4ccc-8ccc-cccccccccccc',true);
SELECT pg_temp.metric_error(format('select public.duel_v3_live_scores(%L)',current_setting('metric.jog')),'42501');
SELECT set_config('request.jwt.claim.sub','7ddddddd-dddd-4ddd-8ddd-dddddddddddd',true);
SELECT pg_temp.metric_error(format('select public.duel_v2_reconcile(%L)',current_setting('metric.jog')),'22023');
SELECT pg_temp.metric_error(format('select public.duel_v2_close_preview(%L)',current_setting('metric.jog')),'22023');
DO $$ DECLARE p jsonb; r jsonb; BEGIN
 p:=public.duel_v3_close_preview(current_setting('metric.jog')::uuid);
 PERFORM pg_temp.metric_assert(NOT (p->>'can_close')::boolean,'timely pending blocks metric close');
 r:=public.duel_v3_close_confirm(current_setting('metric.jog')::uuid,true,p->>'revision');
 PERFORM pg_temp.metric_assert(r->>'outcome'='awaiting_reviews' AND (r->>'unchanged')::boolean,'pending confirmation pays nothing');
END $$;
RESET ROLE;
UPDATE public.training_submissions SET status='rejected' WHERE id='72000000-0000-4000-8000-000000000006';
-- Duplicate matching points ledgers are rejected even though distances/counts are not joined into duplicate scores.
INSERT INTO public.point_transactions(id,boxer_id,submission_id,points,category,description)
VALUES('73000000-0000-4000-8000-000000000001','71111111-1111-4111-8111-111111111111','72000000-0000-4000-8000-000000000001',10,'training','Synthetic duplicate');
SET LOCAL ROLE authenticated;
SELECT pg_temp.metric_error(format('select public.duel_v3_live_scores(%L)',current_setting('metric.jog')),'23514');
RESET ROLE;
DELETE FROM public.point_transactions WHERE id='73000000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;
DO $$ DECLARE p jsonb; r jsonb; BEGIN
 p:=public.duel_v3_close_preview(current_setting('metric.jog')::uuid);
 PERFORM pg_temp.metric_assert((p->>'can_close')::boolean AND p#>>'{rule,reward_rule}'='none','snapshotted no-reward agreement survives config change');
 PERFORM pg_temp.metric_assert((p#>>'{rewards,0,planned_exp}')::int=0 AND (p#>>'{rewards,1,planned_exp}')::int=0,'no invented reward');
 r:=public.duel_v3_close_confirm(current_setting('metric.jog')::uuid,true,p->>'revision');
 PERFORM pg_temp.metric_assert(r->>'outcome'='settled' AND jsonb_array_length(r->'bookings')=0,'metric settlement without payout ledger');
 PERFORM pg_temp.metric_assert((r#>>'{preview,scores,challenger_score}')::numeric=3.35,'numeric score retained in final read');
 r:=public.duel_v3_close_confirm(current_setting('metric.jog')::uuid,true,r#>>'{preview,revision}');
 PERFORM pg_temp.metric_assert((r->>'unchanged')::boolean,'metric retry idempotent');
END $$;
RESET ROLE;
SELECT pg_temp.metric_assert(NOT EXISTS(SELECT 1 FROM public.league_public_duel_history_v21 WHERE duel_id=current_setting('metric.jog')::uuid),'no zero-integer metric result published through legacy history');
SELECT pg_temp.metric_assert(NOT EXISTS(SELECT 1 FROM public.league_duel_exp_ledger WHERE duel_id=current_setting('metric.jog')::uuid),'no-reward contract has no financial ledger');
SELECT pg_temp.metric_assert((SELECT count(*) FROM public.boxer_notifications WHERE event_key='duel:'||current_setting('metric.jog')||':settled' AND message LIKE '%3.35%km.%')=2,'notifications use same numeric score/unit');
-- The stored official score stays fixed until an explicit correction is reviewed and confirmed.
UPDATE public.training_submissions SET jogging_km=2.25 WHERE id='72000000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;
DO $$ DECLARE p jsonb; r jsonb; BEGIN
 PERFORM pg_temp.metric_assert((public.duel_v3_live_scores(current_setting('metric.jog')::uuid)->>'challenger_score')::numeric=3.35,'settled read never silently recomputes');
 p:=public.duel_v3_close_preview(current_setting('metric.jog')::uuid);
 PERFORM pg_temp.metric_assert((p->>'can_correct')::boolean AND (p#>>'{scores,challenger_score}')::numeric=4.35,'explicit correction preview reflects edited training');
 r:=public.duel_v3_close_confirm(current_setting('metric.jog')::uuid,true,p->>'revision');
 PERFORM pg_temp.metric_assert(r->>'outcome'='settled' AND (r#>>'{preview,scores,challenger_score}')::numeric=4.35,'explicit correction persists precise new score');
END $$;
RESET ROLE;
-- Exact-type training count across a month boundary, explicitly club-visible.
SELECT set_config('request.jwt.claim.sub','7aaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',true);
SET LOCAL ROLE authenticated;
SELECT set_config('metric.count',public.duel_v3_invite('71111111-1111-4111-8111-111111111111','72222222-2222-4222-8222-222222222222',14,'training_count',102,'club',pg_temp.metric_rule('training_count',102))::text,true);
RESET ROLE;
UPDATE public.league_duels SET status='active',accepted_at='2026-09-20 14:30Z',ends_at='2026-10-04 14:30Z'
 WHERE id=current_setting('metric.count')::uuid;
SELECT pg_temp.metric_assert((SELECT scoring_starts_at='2026-09-20 22:00Z'::timestamptz AND ends_at='2026-10-04 22:00Z'::timestamptz
 FROM public.league_duels WHERE id=current_setting('metric.count')::uuid),'14 full days cross month correctly');
INSERT INTO public.training_submissions(id,boxer_id,training_type_id,training_date,status,created_at) VALUES
 ('72000000-0000-4000-8000-000000000011','71111111-1111-4111-8111-111111111111',102,'2026-09-22','approved','2026-09-22 12:00Z'),
 ('72000000-0000-4000-8000-000000000012','71111111-1111-4111-8111-111111111111',102,'2026-09-23','approved','2026-09-23 12:00Z'),
 ('72000000-0000-4000-8000-000000000013','72222222-2222-4222-8222-222222222222',102,'2026-09-24','approved','2026-09-24 12:00Z'),
 ('72000000-0000-4000-8000-000000000014','71111111-1111-4111-8111-111111111111',101,'2026-09-25','pending','2026-09-25 12:00Z'),
 ('72000000-0000-4000-8000-000000000015','71111111-1111-4111-8111-111111111111',102,'2026-09-26','rejected','2026-09-26 12:00Z');
INSERT INTO public.point_transactions(boxer_id,submission_id,points,exp,category,description,effective_date)
SELECT boxer_id,id,20,20,'training','Synthetic count ledger',training_date FROM public.training_submissions
 WHERE id IN ('72000000-0000-4000-8000-000000000011','72000000-0000-4000-8000-000000000012','72000000-0000-4000-8000-000000000013');
SELECT pg_temp.seed_metric_receipts();
SELECT set_config('request.jwt.claim.sub','7ccccccc-cccc-4ccc-8ccc-cccccccccccc',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE s jsonb; l jsonb; BEGIN
 s:=public.duel_v3_live_scores(current_setting('metric.count')::uuid);
 PERFORM pg_temp.metric_assert((s->>'challenger_score')::numeric=2 AND (s->>'opponent_score')::numeric=1 AND (s->>'pending')::int=0,'distinct approved IDs of exact type only');
 l:=public.duel_v3_list('club','all',1);
 PERFORM pg_temp.metric_assert(jsonb_array_length(l->'items')=1 AND l#>>'{items,0,id}'=current_setting('metric.count'),'club viewer sees only explicitly visible result');
 PERFORM pg_temp.metric_error(format('select public.duel_v3_close_preview(%L)',current_setting('metric.count')),'42501');
END $$;
RESET ROLE;
UPDATE public.profiles SET is_listed=false WHERE id='71111111-1111-4111-8111-111111111111';
SET LOCAL ROLE authenticated;
SELECT pg_temp.metric_error(format('select public.duel_v3_live_scores(%L)',current_setting('metric.count')),'42501');
SELECT pg_temp.metric_assert(jsonb_array_length(public.duel_v3_list('club')->'items')=0,'current unlisted profile hidden from club');
RESET ROLE;
UPDATE public.profiles SET is_listed=true WHERE id='71111111-1111-4111-8111-111111111111';
SELECT set_config('request.jwt.claim.sub','7ddddddd-dddd-4ddd-8ddd-dddddddddddd',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE p jsonb; r jsonb; BEGIN
 p:=public.duel_v3_close_preview(current_setting('metric.count')::uuid);
 r:=public.duel_v3_close_confirm(current_setting('metric.count')::uuid,true,p->>'revision');
 PERFORM pg_temp.metric_assert(r->>'outcome'='settled' AND (r#>>'{preview,scores,challenger_score}')::numeric=2,'count settlement uses shared exact-type result');
 PERFORM pg_temp.metric_assert(NOT EXISTS(SELECT 1 FROM public.duel_v2_list_mine() WHERE id IN(current_setting('metric.count')::uuid,current_setting('metric.jog')::uuid)),'old points list excludes metric generation');
END $$;
SELECT set_config('request.jwt.claim.sub','7aaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',true);
DO $$ DECLARE a jsonb; b jsonb; BEGIN
 a:=public.duel_v3_list('mine','all',1);
 b:=public.duel_v3_list('mine','all',1,(a#>>'{next_cursor,before}')::timestamptz,(a#>>'{next_cursor,before_id}')::uuid);
 PERFORM pg_temp.metric_assert(a#>>'{items,0,id}' IS DISTINCT FROM b#>>'{items,0,id}','keyset cursor does not repeat first invitation');
 PERFORM pg_temp.metric_error('select public.duel_v3_list(''staff'')','42501');
 PERFORM pg_temp.metric_error('select public.duel_v3_list(''mine'',''all'',0)','22023');
 PERFORM pg_temp.metric_error('select public.duel_v3_list(''mine'',''all'',20,now(),null)','22023');
END $$;
SELECT set_config('request.jwt.claim.sub','',true);
SELECT pg_temp.metric_error('select public.duel_v3_options()','42501');
SELECT pg_temp.metric_error('select public.duel_v3_list()','42501');
RESET ROLE;
UPDATE public.profiles SET is_active=false WHERE id='74444444-4444-4444-8444-444444444444';
SELECT set_config('request.jwt.claim.sub','7ddddddd-dddd-4ddd-8ddd-dddddddddddd',true);
SET LOCAL ROLE authenticated;
SELECT pg_temp.metric_error('select public.duel_v3_options()','42501');
SELECT pg_temp.metric_error(format('select public.duel_v3_close_preview(%L)',current_setting('metric.count')),'42501');
SELECT pg_temp.metric_error(format('select public.duel_v3_close_confirm(%L,true,%L)',current_setting('metric.count'),repeat('a',32)),'42501');
RESET ROLE;
UPDATE public.profiles SET is_active=true,archived_at=now() WHERE id='74444444-4444-4444-8444-444444444444';
SET LOCAL ROLE authenticated;
SELECT pg_temp.metric_error('select public.duel_v3_list(''staff'')','42501');
SELECT pg_temp.metric_error(format('select public.duel_v3_close_preview(%L)',current_setting('metric.count')),'42501');
RESET ROLE;
SELECT pg_temp.metric_assert(NOT has_function_privilege('anon','public.duel_v3_invite(uuid,uuid,integer,text,bigint,text,jsonb)','EXECUTE'),'anonymous invite unavailable');
SELECT pg_temp.metric_assert(NOT has_table_privilege('authenticated','league_v21_private.duel_metric_config','UPDATE'),'no client metric activation');
ROLLBACK;
SELECT CASE WHEN count(*)=2 THEN 'Metric configuration remains disabled/unconfigured after rollback.' ELSE 'FAILED' END
 FROM league_v21_private.duel_metric_config WHERE NOT enabled AND reward_rule IS NULL;
\echo Metric contracts: disabled gates, actual invite/acceptance, immutable terms, decimal km, distinct type counts, boundaries, visibility, closure and legacy isolation passed.
