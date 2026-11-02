\set ON_ERROR_STOP on
BEGIN;
DO $$ BEGIN IF current_database() NOT LIKE 'league21_replay_%' THEN RAISE EXCEPTION 'Disposable database required'; END IF; END $$;
SET LOCAL TIME ZONE 'UTC';
CREATE FUNCTION pg_temp.ranked_assert(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERT: %',label; END IF; END $$;
CREATE FUNCTION pg_temp.ranked_rule() RETURNS jsonb LANGUAGE sql STABLE AS $$
 SELECT jsonb_build_object('metric_revision',(SELECT m->>'revision' FROM jsonb_array_elements(public.duel_v3_options()->'metrics') m WHERE m->>'key'='training_count'),
 'training_type_revision',(SELECT t->>'revision' FROM jsonb_array_elements(public.duel_v3_options()->'training_types') t WHERE (t->>'id')::bigint=106)) $$;
INSERT INTO public.profiles(id,auth_user_id,display_name,role,is_listed) VALUES
 ('61111111-1111-4111-8111-111111111111','6aaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Rank Metric Alpha','boxer',true),
 ('62222222-2222-4222-8222-222222222222','6bbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','Rank Metric Beta','boxer',true);
INSERT INTO public.training_types(id,name,points,is_active) VALUES(106,'Rank Metric Training',20,true);
INSERT INTO public.point_transactions(boxer_id,points,exp,category,description,effective_date)
VALUES('62222222-2222-4222-8222-222222222222',0,5000,'trainer_bonus','Synthetic rank configuration','2026-01-01');
UPDATE league_v21_private.duel_metric_config SET enabled=true,reward_rule='ranked_v21' WHERE metric='training_count';
SELECT set_config('request.jwt.claim.sub','6aaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',true);
SET LOCAL ROLE authenticated;
SELECT set_config('rankmetric.duel',public.duel_v3_invite('61111111-1111-4111-8111-111111111111','62222222-2222-4222-8222-222222222222',7,'training_count',106,'participants',pg_temp.ranked_rule())::text,true);
RESET ROLE;
UPDATE public.league_duels SET status='active',accepted_at='2026-03-27 14:30Z',ends_at='2026-04-03 14:30Z'
 WHERE id=current_setting('rankmetric.duel')::uuid;
SELECT pg_temp.ranked_assert((SELECT scoring_starts_at='2026-03-27 23:00Z'::timestamptz AND ends_at='2026-04-03 22:00Z'::timestamptz
 AND extract(epoch FROM ends_at-scoring_starts_at)/3600=167 FROM public.league_duels WHERE id=current_setting('rankmetric.duel')::uuid),'spring DST seven full local days are167hours');
SELECT set_config('request.jwt.claim.sub','cccccccc-cccc-4ccc-8ccc-cccccccccccc',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE p jsonb; BEGIN
 p:=public.duel_v3_close_preview(current_setting('rankmetric.duel')::uuid);
 PERFORM pg_temp.ranked_assert((p->>'tie')::boolean AND (p#>>'{scores,challenger_score}')::numeric=0,'zero performance is a real tie');
 PERFORM pg_temp.ranked_assert((p#>>'{rewards,0,planned_exp}')::integer=50 AND (p#>>'{rewards,1,planned_exp}')::integer=50,'existing ranked tie reward');
 PERFORM set_config('rankmetric.zero_revision',p->>'revision',true);
END $$;
RESET ROLE;
INSERT INTO public.training_submissions(id,boxer_id,training_type_id,training_date,status,created_at)
VALUES('62000000-0000-4000-8000-000000000001','61111111-1111-4111-8111-111111111111',106,'2026-03-29','approved','2026-03-29 10:00Z');
-- Historical authoritative receipt fixture; client tampering is tested separately with the guard active.
ALTER TABLE public.training_submissions DISABLE TRIGGER zz_league_training_receipt_guard;
UPDATE public.training_submissions SET server_received_at=created_at WHERE id='62000000-0000-4000-8000-000000000001';
ALTER TABLE public.training_submissions ENABLE TRIGGER zz_league_training_receipt_guard;
SET LOCAL ROLE authenticated;
DO $$ DECLARE p jsonb; BEGIN
 p:=public.duel_v3_close_preview(current_setting('rankmetric.duel')::uuid);
 PERFORM pg_temp.ranked_assert(NOT (p->>'can_close')::boolean AND p#>>'{scores,challenger_score}' IS NULL,'count missing ledger fails closed');
END $$;
RESET ROLE;
INSERT INTO public.point_transactions(boxer_id,submission_id,points,exp,category,description,effective_date)
VALUES('61111111-1111-4111-8111-111111111111','62000000-0000-4000-8000-000000000001',20,20,'training','Synthetic ranked count','2026-03-29');
SET LOCAL ROLE authenticated;
DO $$ DECLARE p jsonb; r jsonb; BEGIN
 p:=public.duel_v3_close_preview(current_setting('rankmetric.duel')::uuid);
 PERFORM pg_temp.ranked_assert((p#>>'{rewards,0,planned_exp}')::integer=150 AND (p#>>'{rewards,1,planned_exp}')::integer=-50,'explicit configured ranked mapping preserves underdog amounts');
 r:=public.duel_v3_close_confirm(current_setting('rankmetric.duel')::uuid,true,current_setting('rankmetric.zero_revision'));
 PERFORM pg_temp.ranked_assert(r->>'outcome'='preview_changed' AND (r->>'unchanged')::boolean,'changed count cannot pay stale tie plan');
 r:=public.duel_v3_close_confirm(current_setting('rankmetric.duel')::uuid,true,r#>>'{preview,revision}');
 PERFORM pg_temp.ranked_assert(r->>'outcome'='settled' AND jsonb_array_length(r->'bookings')=2,'ranked metric has two real payout references');
 r:=public.duel_v3_close_confirm(current_setting('rankmetric.duel')::uuid,true,r#>>'{preview,revision}');
 PERFORM pg_temp.ranked_assert((r->>'unchanged')::boolean,'ranked metric repeat unchanged');
END $$;
RESET ROLE;
SELECT pg_temp.ranked_assert((SELECT count(*) FROM public.league_duel_exp_ledger WHERE duel_id=current_setting('rankmetric.duel')::uuid)=2,'exactly two ranked metric ledgers');
SELECT pg_temp.ranked_assert((SELECT count(*) FROM public.point_transactions WHERE category='duel_exp' AND description='Duel reward: '||current_setting('rankmetric.duel'))=2,'no duplicate ranked metric payout');
SELECT pg_temp.ranked_assert((SELECT awarded_exp FROM public.league_duel_exp_ledger WHERE duel_id=current_setting('rankmetric.duel')::uuid AND boxer_id='61111111-1111-4111-8111-111111111111')=150,'underdog actual payout150');
SELECT pg_temp.ranked_assert((SELECT awarded_exp FROM public.league_duel_exp_ledger WHERE duel_id=current_setting('rankmetric.duel')::uuid AND boxer_id='62222222-2222-4222-8222-222222222222')=-50,'favourite actual payout-50');
ROLLBACK;
\echo Ranked metrics: explicit mapping, spring DST, zero/tie, missing ledger, stale preview and idempotent actual payouts passed.
