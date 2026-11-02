\set ON_ERROR_STOP on
BEGIN;
DO $$ BEGIN IF current_database() NOT LIKE 'league21_replay_%' THEN RAISE EXCEPTION 'Disposable database required'; END IF; END $$;
SET LOCAL TIME ZONE 'UTC';
CREATE FUNCTION pg_temp.points_assert(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERT: %',label; END IF; END $$;
INSERT INTO public.profiles(id,auth_user_id,display_name,role,is_active,archived_at) VALUES
 ('91111111-1111-4111-8111-111111111111','9aaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Boundary Alpha','boxer',true,NULL),
 ('92222222-2222-4222-8222-222222222222','9bbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','Boundary Beta','boxer',true,NULL),
 ('93333333-3333-4333-8333-333333333333','9ccccccc-cccc-4ccc-8ccc-cccccccccccc','Boundary Other','boxer',true,NULL),
 ('94444444-4444-4444-8444-444444444444','9ddddddd-dddd-4ddd-8ddd-dddddddddddd','Boundary Inactive','coach',false,NULL),
 ('95555555-5555-4555-8555-555555555555','9eeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','Boundary Archived','coach',true,now());
-- Seven UTC intervals spanning the Zurich DST transition. Preserve the old inclusive dates,
-- including the end falling on April 5 locally; do not silently apply the new metric time rule.
INSERT INTO public.league_duels(id,challenger_id,opponent_id,status,duration_days,accepted_at,ends_at)
VALUES('90000000-0000-4000-8000-000000000001','91111111-1111-4111-8111-111111111111',
 '92222222-2222-4222-8222-222222222222','active',7,'2026-03-28 22:30Z','2026-04-04 22:30Z');
INSERT INTO public.training_submissions(id,boxer_id,training_type_id,training_date,status,created_at) VALUES
 ('92000000-0000-4000-8000-000000000001','91111111-1111-4111-8111-111111111111',1,'2026-03-28','approved','2026-03-28 10:00Z'),
 ('92000000-0000-4000-8000-000000000002','91111111-1111-4111-8111-111111111111',1,'2026-04-05','approved','2026-04-04 22:30Z'),
 ('92000000-0000-4000-8000-000000000003','91111111-1111-4111-8111-111111111111',1,'2026-04-05','pending','2026-04-04 22:30:01Z'),
 ('92000000-0000-4000-8000-000000000004','91111111-1111-4111-8111-111111111111',1,'2026-03-27','approved','2026-03-27 12:00Z'),
 ('92000000-0000-4000-8000-000000000005','91111111-1111-4111-8111-111111111111',1,'2026-04-06','approved','2026-04-04 12:00Z'),
 ('92000000-0000-4000-8000-000000000006','91111111-1111-4111-8111-111111111111',1,'2026-04-02','rejected','2026-04-02 12:00Z');
INSERT INTO public.point_transactions(boxer_id,submission_id,points,category,description) VALUES
 ('91111111-1111-4111-8111-111111111111','92000000-0000-4000-8000-000000000001',10,'training','Boundary first date'),
 ('91111111-1111-4111-8111-111111111111','92000000-0000-4000-8000-000000000002',20,'training','Boundary exact cutoff'),
 ('92222222-2222-4222-8222-222222222222','92000000-0000-4000-8000-000000000001',999,'training','Wrong-boxer ledger must never count'),
 ('91111111-1111-4111-8111-111111111111','92000000-0000-4000-8000-000000000006',999,'training','Rejected must never count');
-- Optional later metric migration adds trusted receipts. Seed historical fixture receipts as owner only.
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='training_submissions' AND column_name='server_received_at') THEN
  ALTER TABLE public.training_submissions DISABLE TRIGGER zz_league_training_receipt_guard;
  UPDATE public.training_submissions SET server_received_at=created_at WHERE id::text LIKE '92000000-%';
  ALTER TABLE public.training_submissions ENABLE TRIGGER zz_league_training_receipt_guard;
 END IF;
END $$;
DO $$ DECLARE d public.league_duels%ROWTYPE; s jsonb; BEGIN
 SELECT * INTO d FROM public.league_duels WHERE id='90000000-0000-4000-8000-000000000001';
 s:=league_v21_private.duel_points_snapshot(d,d.ends_at);
 PERFORM pg_temp.points_assert((s->>'valid')::boolean AND (s->>'challenger_score')::int=30
  AND (s->>'opponent_score')::int=0 AND (s->>'pending')::int=0,'DST/local boundary, exact cutoff and ownership filtering');
 s:=league_v21_private.duel_points_snapshot(d,'2026-03-29 00:30Z');
 PERFORM pg_temp.points_assert((s->>'challenger_score')::int=10,'live as-of excludes future days/submissions');
END $$;
SET LOCAL ROLE authenticated;
DO $$ DECLARE sub text; s jsonb; BEGIN
 FOREACH sub IN ARRAY ARRAY['9aaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','9bbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'] LOOP
  PERFORM set_config('request.jwt.claim.sub',sub,true);
  s:=public.duel_v2_live_scores('90000000-0000-4000-8000-000000000001');
  PERFORM pg_temp.points_assert((s->>'challenger_score')::int=30,'both participants can read own aggregate');
 END LOOP;
 FOREACH sub IN ARRAY ARRAY['9ccccccc-cccc-4ccc-8ccc-cccccccccccc','9ddddddd-dddd-4ddd-8ddd-dddddddddddd','9eeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',''] LOOP
  PERFORM set_config('request.jwt.claim.sub',sub,true);
  BEGIN PERFORM public.duel_v2_live_scores('90000000-0000-4000-8000-000000000001');
   RAISE EXCEPTION 'Unauthorized live score accepted: %',sub; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 END LOOP;
END $$;
RESET ROLE;
-- A negative total fails live, preview and settlement consistently.
UPDATE public.point_transactions SET points=-100 WHERE submission_id='92000000-0000-4000-8000-000000000002';
SELECT set_config('request.jwt.claim.sub','cccccccc-cccc-4ccc-8ccc-cccccccccccc',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE p jsonb; BEGIN
 BEGIN PERFORM public.duel_v2_live_scores('90000000-0000-4000-8000-000000000001');
  RAISE EXCEPTION 'Negative live score accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
 p:=public.duel_v2_close_preview('90000000-0000-4000-8000-000000000001');
 PERFORM pg_temp.points_assert(NOT (p->>'can_close')::boolean AND p#>>'{scores,challenger_score}' IS NULL,'negative score blocks preview');
 BEGIN PERFORM public.duel_v2_reconcile('90000000-0000-4000-8000-000000000001');
  RAISE EXCEPTION 'Negative settlement accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
END $$;
RESET ROLE;
ROLLBACK;
\echo Legacy points: Zurich DST/date boundaries, late/pending/rejected/foreign ledgers, live roles and negative-score guards passed.
