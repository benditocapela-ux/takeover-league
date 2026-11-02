\set ON_ERROR_STOP on
BEGIN;
DO $$ BEGIN
 IF current_database() NOT LIKE 'league21_replay_%' THEN RAISE EXCEPTION 'Disposable database required'; END IF;
END $$;
CREATE FUNCTION pg_temp.check_ok(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERT: %',label; END IF; END $$;
INSERT INTO public.profiles(id,auth_user_id,display_name,role,is_active,archived_at) VALUES
 ('44444444-4444-4444-8444-444444444444','dddddddd-dddd-4ddd-8ddd-dddddddddddd','Fixture Coach','coach',true,NULL),
 ('55555555-5555-4555-8555-555555555555','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','Fixture Other','boxer',true,NULL),
 ('66666666-6666-4666-8666-666666666666','ffffffff-ffff-4fff-8fff-ffffffffffff','Fixture Inactive Coach','coach',false,NULL),
 ('77777777-7777-4777-8777-777777777777','99999999-9999-4999-8999-999999999999','Fixture Archived Coach','coach',true,now());
INSERT INTO public.league_duels(id,challenger_id,opponent_id,status,duration_days,accepted_at,ends_at)
VALUES('10000000-0000-4000-8000-000000000001','11111111-1111-4111-8111-111111111111',
 '22222222-2222-4222-8222-222222222222','active',7,now()-interval '8 days',now()-interval '1 day');
INSERT INTO public.league_duel_rank_snapshots_v21(duel_id,boxer_id,rank_index,exp_at_start) VALUES
 ('10000000-0000-4000-8000-000000000001','11111111-1111-4111-8111-111111111111',1,0),
 ('10000000-0000-4000-8000-000000000001','22222222-2222-4222-8222-222222222222',3,5000);
INSERT INTO public.training_submissions(id,boxer_id,training_type_id,training_date,status,created_at) VALUES
 ('20000000-0000-4000-8000-000000000001','11111111-1111-4111-8111-111111111111',1,current_date-4,'approved',now()-interval '4 days'),
 ('20000000-0000-4000-8000-000000000002','22222222-2222-4222-8222-222222222222',1,current_date-3,'approved',now()-interval '3 days'),
 ('20000000-0000-4000-8000-000000000003','22222222-2222-4222-8222-222222222222',1,current_date-2,'pending',now()-interval '2 days'),
 -- A late submission must not block or score, even with a date inside the duel.
 ('20000000-0000-4000-8000-000000000004','22222222-2222-4222-8222-222222222222',1,current_date-3,'pending',now()),
 ('20000000-0000-4000-8000-000000000005','22222222-2222-4222-8222-222222222222',1,current_date-20,'pending',now()-interval '20 days');
SELECT set_config('request.jwt.claim.sub','dddddddd-dddd-4ddd-8ddd-dddddddddddd',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE p jsonb; BEGIN
 p:=public.duel_v2_close_preview('10000000-0000-4000-8000-000000000001');
 PERFORM pg_temp.check_ok(p#>>'{scores,challenger_score}' IS NULL,'invalid ledger never returns fake score');
 PERFORM pg_temp.check_ok((p#>>'{scores,pending}')::int=1,'only timely relevant pending included');
 PERFORM pg_temp.check_ok(NOT (p->>'can_close')::boolean,'broken ledger blocks preview');
 BEGIN PERFORM public.duel_v2_live_scores('10000000-0000-4000-8000-000000000001');
  RAISE EXCEPTION 'Missing ledger accepted by live'; EXCEPTION WHEN check_violation THEN NULL; END;
END $$;
RESET ROLE;
UPDATE public.training_submissions SET status='rejected' WHERE id='20000000-0000-4000-8000-000000000003';
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 BEGIN PERFORM public.duel_v2_reconcile('10000000-0000-4000-8000-000000000001');
  RAISE EXCEPTION 'Missing ledger accepted by settlement'; EXCEPTION WHEN check_violation THEN NULL; END;
END $$;
RESET ROLE;
SELECT pg_temp.check_ok(NOT EXISTS(SELECT 1 FROM public.league_duel_exp_ledger),'failed settlement has no payout');
INSERT INTO public.point_transactions(id,boxer_id,submission_id,points,exp,category,description,effective_date) VALUES
 ('30000000-0000-4000-8000-000000000001','11111111-1111-4111-8111-111111111111','20000000-0000-4000-8000-000000000001',50,50,'training','Fixture A',current_date-4),
 ('30000000-0000-4000-8000-000000000002','22222222-2222-4222-8222-222222222222','20000000-0000-4000-8000-000000000002',20,20,'training','Fixture B',current_date-3);
-- Read-only is checked against all affected result/ledger/event/inbox tables, including duel updated_at.
SELECT set_config('fixture.before',jsonb_build_object('duels',(SELECT jsonb_agg(to_jsonb(d)) FROM public.league_duels d),
 'tx',(SELECT jsonb_agg(to_jsonb(t)) FROM public.point_transactions t),
 'events',(SELECT count(*) FROM public.league_duel_events),'ledger',(SELECT count(*) FROM public.league_duel_exp_ledger),
 'inbox',(SELECT count(*) FROM public.boxer_notifications))::text,true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE p jsonb; BEGIN
 p:=public.duel_v2_close_preview('10000000-0000-4000-8000-000000000001');
 PERFORM pg_temp.check_ok((p->>'can_close')::boolean,'valid due duel ready');
 PERFORM pg_temp.check_ok(p#>>'{rule,reward_rule}'='rank_snapshot_v21','rank rule exposed');
 PERFORM pg_temp.check_ok((p#>>'{scores,challenger_score}')::int=50 AND (p#>>'{scores,opponent_score}')::int=20,'same shared points');
 PERFORM pg_temp.check_ok((p#>>'{rewards,0,planned_exp}')::int=150 AND (p#>>'{rewards,1,planned_exp}')::int=-50,'underdog reward preserved');
 PERFORM pg_temp.check_ok((p#>>'{rewards,0,booked_exp}')::int=0 AND (p#>>'{rewards,0,delta_exp}')::int=150,'unpaid plan uses zero booked');
 PERFORM set_config('fixture.revision',p->>'revision',true);
 BEGIN PERFORM public.duel_v2_close_confirm('10000000-0000-4000-8000-000000000001',false,p->>'revision');
  RAISE EXCEPTION 'Implicit close accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
END $$;
RESET ROLE;
SELECT pg_temp.check_ok(current_setting('fixture.before')::jsonb=jsonb_build_object(
 'duels',(SELECT jsonb_agg(to_jsonb(d)) FROM public.league_duels d),
 'tx',(SELECT jsonb_agg(to_jsonb(t)) FROM public.point_transactions t),
 'events',(SELECT count(*) FROM public.league_duel_events),'ledger',(SELECT count(*) FROM public.league_duel_exp_ledger),
 'inbox',(SELECT count(*) FROM public.boxer_notifications)),'preview and rejected confirm are read-only');
-- Duplicate scoring ledger, with exact ID cleanup confined to this transaction fixture.
INSERT INTO public.point_transactions(id,boxer_id,submission_id,points,category,description)
VALUES('30000000-0000-4000-8000-000000000003','11111111-1111-4111-8111-111111111111','20000000-0000-4000-8000-000000000001',10,'training','Fixture duplicate');
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 BEGIN PERFORM public.duel_v2_live_scores('10000000-0000-4000-8000-000000000001'); RAISE EXCEPTION 'Duplicate live accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
 BEGIN PERFORM public.duel_v2_reconcile('10000000-0000-4000-8000-000000000001'); RAISE EXCEPTION 'Duplicate settle accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
END $$;
RESET ROLE;
DELETE FROM public.point_transactions WHERE id='30000000-0000-4000-8000-000000000003';
-- A reviewed score changes before confirmation: refresh, do not pay a different plan.
UPDATE public.point_transactions SET points=60 WHERE id='30000000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;
DO $$ DECLARE r jsonb; BEGIN
 r:=public.duel_v2_close_confirm('10000000-0000-4000-8000-000000000001',true,current_setting('fixture.revision'));
 PERFORM pg_temp.check_ok(r->>'outcome'='preview_changed' AND (r->>'unchanged')::boolean,'stale preview does not settle');
 PERFORM set_config('fixture.revision',r#>>'{preview,revision}',true);
END $$;
RESET ROLE;
SELECT pg_temp.check_ok(NOT EXISTS(SELECT 1 FROM public.league_duel_exp_ledger),'stale preview pays nothing');
SET LOCAL ROLE authenticated;
DO $$ DECLARE r jsonb; BEGIN
 r:=public.duel_v2_close_confirm('10000000-0000-4000-8000-000000000001',true,current_setting('fixture.revision'));
 PERFORM pg_temp.check_ok(r->>'outcome'='settled' AND r#>>'{preview,status}'='settled','close returns persisted result');
 PERFORM pg_temp.check_ok(jsonb_array_length(r->'bookings')=2,'two actual bookings returned');
 -- Retry after lost response has no second financial effect, even with old revision.
 r:=public.duel_v2_close_confirm('10000000-0000-4000-8000-000000000001',true,current_setting('fixture.revision'));
 PERFORM pg_temp.check_ok((r->>'unchanged')::boolean AND r#>>'{preview,status}'='settled','lost response retry safe');
 r:=public.duel_v2_close_confirm('10000000-0000-4000-8000-000000000001',true,r#>>'{preview,revision}');
 PERFORM pg_temp.check_ok(r->>'outcome'='settled' AND (r->>'unchanged')::boolean,'fresh settled retry unchanged');
END $$;
RESET ROLE;
SELECT pg_temp.check_ok((SELECT count(*) FROM public.point_transactions WHERE category='duel_exp')=2,'no double payout');
SELECT pg_temp.check_ok((SELECT count(*) FROM public.league_duel_events WHERE event_type='settled')=1,'one settlement event');
SELECT pg_temp.check_ok((SELECT count(*) FROM public.boxer_notifications WHERE notification_type='boxer_duel')=2,'one settlement notice per recipient');
-- Existing explicit correction path updates the original payout transactions; no implicit recalc.
UPDATE public.point_transactions SET points=10 WHERE id='30000000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;
DO $$ DECLARE p jsonb; r jsonb; BEGIN
 p:=public.duel_v2_close_preview('10000000-0000-4000-8000-000000000001');
 PERFORM pg_temp.check_ok((p->>'can_correct')::boolean AND NOT (p->>'can_close')::boolean,'correction explicit');
 r:=public.duel_v2_close_confirm('10000000-0000-4000-8000-000000000001',true,p->>'revision');
 PERFORM pg_temp.check_ok(r->>'outcome'='settled','correction settles');
END $$;
RESET ROLE;
SELECT pg_temp.check_ok((SELECT count(*) FROM public.point_transactions WHERE category='duel_exp')=2,'correction reuses payout tx');
SELECT pg_temp.check_ok((SELECT awarded_exp FROM public.league_duel_exp_ledger WHERE boxer_id='11111111-1111-4111-8111-111111111111')=25,'underdog loss 25');
SELECT pg_temp.check_ok((SELECT awarded_exp FROM public.league_duel_exp_ledger WHERE boxer_id='22222222-2222-4222-8222-222222222222')=50,'favourite win 50');
-- No new role/table exposure. Participant live remains authorized; staff-only preview is not.
SELECT pg_temp.check_ok(NOT has_function_privilege('anon','public.duel_v2_close_preview(uuid)','EXECUTE'),'guest no preview execute');
SELECT pg_temp.check_ok(NOT has_function_privilege('authenticated','league_v21_private.duel_points_snapshot(public.league_duels,timestamptz)','EXECUTE'),'scorer inaccessible directly');
SET LOCAL ROLE authenticated;
DO $$ DECLARE sub text; BEGIN
 FOREACH sub IN ARRAY ARRAY['aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','ffffffff-ffff-4fff-8fff-ffffffffffff',
 '99999999-9999-4999-8999-999999999999',''] LOOP
  PERFORM set_config('request.jwt.claim.sub',sub,true);
  BEGIN PERFORM public.duel_v2_close_preview('10000000-0000-4000-8000-000000000001');
   RAISE EXCEPTION 'Unauthorized preview allowed: %',sub; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN PERFORM public.duel_v2_close_confirm('10000000-0000-4000-8000-000000000001',true,repeat('a',32));
   RAISE EXCEPTION 'Unauthorized close allowed: %',sub; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 END LOOP;
END $$;
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','cccccccc-cccc-4ccc-8ccc-cccccccccccc',true);
SET LOCAL ROLE authenticated;
SELECT pg_temp.check_ok(public.duel_v2_close_preview('10000000-0000-4000-8000-000000000001')->>'status'='settled','admin preview authorized');
RESET ROLE;
ROLLBACK;
\echo Duel points preview: ledger integrity, read-only, rewards, stale preview, retries, correction and roles passed.
