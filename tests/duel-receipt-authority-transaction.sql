\set ON_ERROR_STOP on
BEGIN;
DO $$ BEGIN IF current_database() NOT LIKE 'league21_replay_%' THEN RAISE EXCEPTION 'Disposable database required'; END IF; END $$;
CREATE FUNCTION pg_temp.receipt_assert(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERT: %',label; END IF; END $$;
SELECT pg_temp.receipt_assert((SELECT server_received_at IS NULL FROM public.training_submissions
 WHERE id='40000000-0000-4000-8000-000000000001'),'historical receipt was not invented/backfilled');
INSERT INTO public.profiles(id,auth_user_id,display_name,role,is_active,is_listed) VALUES
 ('41111111-1111-4111-8111-111111111111','4aaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Receipt Boxer A','boxer',true,true),
 ('42222222-2222-4222-8222-222222222222','4bbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','Receipt Boxer B','boxer',true,true),
 ('43333333-3333-4333-8333-333333333333','4ccccccc-cccc-4ccc-8ccc-cccccccccccc','Receipt Coach','coach',true,false);
-- Model the verified production direct INSERT/own-pending policy; do not grant UPDATE.
ALTER TABLE public.training_submissions ENABLE ROW LEVEL SECURITY;
GRANT SELECT,INSERT ON public.training_submissions TO authenticated;
GRANT SELECT ON public.profiles,public.training_types TO authenticated;
CREATE POLICY receipt_fixture_own_select ON public.training_submissions FOR SELECT TO authenticated USING(
 EXISTS(SELECT 1 FROM public.profiles p WHERE p.id=boxer_id AND p.auth_user_id=(SELECT auth.uid()) AND p.is_active));
CREATE POLICY receipt_fixture_own_pending ON public.training_submissions FOR INSERT TO authenticated WITH CHECK(
 status='pending' AND reviewed_at IS NULL AND reviewed_by IS NULL AND EXISTS(
 SELECT 1 FROM public.profiles p WHERE p.id=boxer_id AND p.auth_user_id=(SELECT auth.uid()) AND p.is_active)
 AND EXISTS(SELECT 1 FROM public.training_types t WHERE t.id=training_type_id AND t.is_active));
SELECT set_config('receipt.before',clock_timestamp()::text,true);
SELECT set_config('request.jwt.claim.sub','4aaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',true);
SET LOCAL ROLE authenticated;
INSERT INTO public.training_submissions(id,boxer_id,training_type_id,training_date,status,created_at,server_received_at)
VALUES('42000000-0000-4000-8000-000000000001','41111111-1111-4111-8111-111111111111',1,current_date-5,'pending',now()-interval '5 days',now()-interval '5 days');
SELECT pg_temp.receipt_assert((SELECT server_received_at>=current_setting('receipt.before')::timestamptz
 AND server_received_at<=clock_timestamp() AND created_at<server_received_at-interval '4 days'
 FROM public.training_submissions WHERE id='42000000-0000-4000-8000-000000000001'),'direct boxer INSERT cannot forge receipt with either timestamp field');
DO $$ BEGIN
 BEGIN UPDATE public.training_submissions SET server_received_at=now()-interval '5 days' WHERE id='42000000-0000-4000-8000-000000000001';
  RAISE EXCEPTION 'Direct authenticated rewrite accepted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
-- A synthetic guarded staff RPC tests the trigger even inside SECURITY DEFINER context.
CREATE FUNCTION pg_temp.receipt_staff_insert(p_boxer uuid,p_forged timestamptz) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$ DECLARE r uuid; BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.profiles WHERE auth_user_id=(SELECT auth.uid()) AND role='coach' AND is_active)
 THEN RAISE EXCEPTION 'Coach required' USING errcode='42501'; END IF;
 INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,status,created_at,server_received_at)
 VALUES(p_boxer,1,current_date-5,'pending',p_forged,p_forged) RETURNING id INTO r; RETURN r;
END $$;
CREATE FUNCTION pg_temp.receipt_staff_rewrite(p_id uuid,p_forged timestamptz) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.profiles WHERE auth_user_id=(SELECT auth.uid()) AND role='coach' AND is_active)
 THEN RAISE EXCEPTION 'Coach required' USING errcode='42501'; END IF;
 UPDATE public.training_submissions SET server_received_at=p_forged WHERE id=p_id;
END $$;
SELECT set_config('request.jwt.claim.sub','4ccccccc-cccc-4ccc-8ccc-cccccccccccc',true);
SET LOCAL ROLE authenticated;
SELECT set_config('receipt.staff',pg_temp.receipt_staff_insert('42222222-2222-4222-8222-222222222222',now()-interval '5 days')::text,true);
DO $$ BEGIN
 BEGIN PERFORM pg_temp.receipt_staff_rewrite(current_setting('receipt.staff')::uuid,now()-interval '5 days');
  RAISE EXCEPTION 'Definer rewrite bypassed receipt guard'; EXCEPTION WHEN check_violation THEN NULL; END;
END $$;
-- Direct coach INSERT is also stamped, not trusted because of the profile's role.
INSERT INTO public.training_submissions(id,boxer_id,training_type_id,training_date,status,created_at,server_received_at)
VALUES('42000000-0000-4000-8000-000000000003','43333333-3333-4333-8333-333333333333',1,current_date-5,'pending',now()-interval '5 days',NULL);
SELECT pg_temp.receipt_assert((SELECT server_received_at>=current_setting('receipt.before')::timestamptz FROM public.training_submissions
 WHERE id='42000000-0000-4000-8000-000000000003'),'direct coach INSERT cannot supply NULL receipt');
RESET ROLE;
SELECT pg_temp.receipt_assert((SELECT server_received_at>=current_setting('receipt.before')::timestamptz FROM public.training_submissions
 WHERE id=current_setting('receipt.staff')::uuid),'definer staff INSERT cannot backdate receipt');
-- Confirm the late rows with complete point ledgers. Their forged created_at must not enter either scoring generation.
UPDATE public.training_submissions SET status='approved' WHERE id IN('42000000-0000-4000-8000-000000000001',current_setting('receipt.staff')::uuid);
INSERT INTO public.point_transactions(boxer_id,submission_id,points,exp,category,description,effective_date)
SELECT boxer_id,id,30,30,'training','Receipt authority fixture',training_date FROM public.training_submissions
 WHERE id IN('42000000-0000-4000-8000-000000000001',current_setting('receipt.staff')::uuid);
INSERT INTO public.league_duels(id,challenger_id,opponent_id,status,duration_days,accepted_at,ends_at)
VALUES('43000000-0000-4000-8000-000000000001','41111111-1111-4111-8111-111111111111',
 '42222222-2222-4222-8222-222222222222','awaiting_reviews',7,now()-interval '8 days',now()-interval '1 day');
INSERT INTO public.league_duels(id,challenger_id,opponent_id,status,duration_days,scoring_metric,scoring_training_type_id,scoring_contract)
VALUES('43000000-0000-4000-8000-000000000002','41111111-1111-4111-8111-111111111111',
 '42222222-2222-4222-8222-222222222222','pending',7,'training_count',1,
 '{"version":3,"metric":"training_count","unit":"Trainings","label":"Receipt fixture","visibility":"participants","reward_rule":"none","reward_label":"Keine zusätzliche Belohnung","timezone":"Europe/Zurich","time_rule":"next_zurich_midnight_full_days"}');
UPDATE public.league_duels SET status='active',accepted_at=now()-interval '8 days',ends_at=now()-interval '1 day'
 WHERE id='43000000-0000-4000-8000-000000000002';
SELECT set_config('request.jwt.claim.sub','4ccccccc-cccc-4ccc-8ccc-cccccccccccc',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE p jsonb; m jsonb; BEGIN
 p:=public.duel_v2_close_preview('43000000-0000-4000-8000-000000000001');
 m:=public.duel_v3_close_preview('43000000-0000-4000-8000-000000000002');
 PERFORM pg_temp.receipt_assert((p#>>'{scores,challenger_score}')::numeric=0 AND (p#>>'{scores,opponent_score}')::numeric=0,'future points submissions use authoritative receipt');
 PERFORM pg_temp.receipt_assert((m#>>'{scores,challenger_score}')::numeric=0 AND (m#>>'{scores,opponent_score}')::numeric=0,'metrics reject forged late submissions after approval');
END $$;
RESET ROLE;
SELECT pg_temp.receipt_assert(NOT has_function_privilege('authenticated','league_v21_private.training_receipt_guard()','EXECUTE'),'receipt trigger is not a callable privileged API');
ROLLBACK;
\echo Server receipt authority: direct boxer/coach and definer inserts stamped, rewrites denied, forged late approved rows excluded from points/metrics, historical rows unbackfilled.
