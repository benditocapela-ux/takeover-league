\set ON_ERROR_STOP on
-- Requires duel-points-preview-schema.sql in this disposable database.
DO $$ BEGIN
 IF current_database() NOT LIKE 'league21_replay_%' THEN RAISE EXCEPTION 'Disposable database required'; END IF;
END $$;
CREATE TEMP TABLE notice_legacy_witness AS SELECT to_jsonb(n) row FROM public.boxer_notifications n;
\i supabase/migrations/20261102093606_duel_notification_event_identity.sql
DO $$ BEGIN
 IF EXISTS(SELECT row FROM notice_legacy_witness EXCEPT SELECT to_jsonb(n)-'event_key' FROM public.boxer_notifications n)
 OR EXISTS(SELECT 1 FROM public.boxer_notifications WHERE event_key IS NOT NULL)
 THEN RAISE EXCEPTION 'Event migration rewrote historical inbox rows'; END IF;
END $$;
\i supabase/migrations/20261018230000_notification_mark_read.sql
BEGIN;
CREATE FUNCTION pg_temp.notice_assert(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERT: %',label; END IF; END $$;
-- Dedicated synthetic participants avoid earlier fixture notifications influencing assertions.
INSERT INTO public.profiles(id,auth_user_id,display_name,role) VALUES
 ('81111111-1111-4111-8111-111111111111','8aaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Notice Alpha','boxer'),
 ('82222222-2222-4222-8222-222222222222','8bbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','Notice Beta','boxer');
INSERT INTO public.league_duels(id,challenger_id,opponent_id,status,duration_days,accepted_at,ends_at)
VALUES('80000000-0000-4000-8000-000000000001','81111111-1111-4111-8111-111111111111',
 '82222222-2222-4222-8222-222222222222','active',7,now()-interval '8 days',now()-interval '1 day');
SELECT set_config('request.jwt.claim.sub','cccccccc-cccc-4ccc-8ccc-cccccccccccc',true);
SET LOCAL ROLE authenticated;
SELECT public.duel_v2_reconcile('80000000-0000-4000-8000-000000000001');
RESET ROLE;
SELECT set_config('fixture.notice',(SELECT id::text FROM public.boxer_notifications
 WHERE recipient_id='81111111-1111-4111-8111-111111111111' AND event_key='duel:80000000-0000-4000-8000-000000000001:settled'),true);
SELECT set_config('request.jwt.claim.sub','8aaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',true);
SET LOCAL ROLE authenticated;
SELECT pg_temp.notice_assert(public.mark_my_notification_read(current_setting('fixture.notice')::uuid),'own notice read acknowledgement works');
RESET ROLE;
-- A second identical result in the same transaction/minute must produce its own two notices.
INSERT INTO public.league_duels(id,challenger_id,opponent_id,status,duration_days,accepted_at,ends_at)
VALUES('80000000-0000-4000-8000-000000000002','81111111-1111-4111-8111-111111111111',
 '82222222-2222-4222-8222-222222222222','active',7,now()-interval '8 days',now()-interval '1 day');
SELECT set_config('request.jwt.claim.sub','cccccccc-cccc-4ccc-8ccc-cccccccccccc',true);
SET LOCAL ROLE authenticated;
SELECT public.duel_v2_reconcile('80000000-0000-4000-8000-000000000002');
SELECT public.duel_v2_reconcile('80000000-0000-4000-8000-000000000002');
SELECT public.duel_v2_reconcile('80000000-0000-4000-8000-000000000001');
RESET ROLE;
SELECT pg_temp.notice_assert((SELECT count(*) FROM public.boxer_notifications WHERE event_key IN (
 'duel:80000000-0000-4000-8000-000000000001:settled','duel:80000000-0000-4000-8000-000000000002:settled'))=4,'two distinct duels each notify both recipients');
SELECT pg_temp.notice_assert((SELECT read_at IS NOT NULL FROM public.boxer_notifications WHERE id=current_setting('fixture.notice')::uuid),'replay preserves read state');
SELECT pg_temp.notice_assert((SELECT count(*) FROM public.boxer_notifications WHERE event_key='duel:80000000-0000-4000-8000-000000000002:settled' AND read_at IS NULL)=2,'new event remains unread');
SELECT pg_temp.notice_assert(NOT EXISTS(SELECT 1 FROM public.boxer_notifications
 WHERE event_key LIKE 'duel:80000000-%' AND target_path NOT IN (
 '/duels.html?duel=80000000-0000-4000-8000-000000000001','/duels.html?duel=80000000-0000-4000-8000-000000000002')),'exact duel links');
-- Existing correction updates result/ledger but does not duplicate the initial settlement alert.
INSERT INTO public.training_submissions(id,boxer_id,training_type_id,training_date,status,created_at)
VALUES('82000000-0000-4000-8000-000000000001','81111111-1111-4111-8111-111111111111',1,current_date-4,'approved',now()-interval '4 days');
INSERT INTO public.point_transactions(boxer_id,submission_id,points,exp,category,description,effective_date)
VALUES('81111111-1111-4111-8111-111111111111','82000000-0000-4000-8000-000000000001',30,30,'training','Synthetic correction',current_date-4);
SET LOCAL ROLE authenticated;
SELECT public.duel_v2_reconcile('80000000-0000-4000-8000-000000000001');
SELECT public.duel_v2_reconcile('80000000-0000-4000-8000-000000000001');
RESET ROLE;
SELECT pg_temp.notice_assert((SELECT count(*) FROM public.boxer_notifications WHERE event_key='duel:80000000-0000-4000-8000-000000000001:settled')=2,'correction does not repeat settlement alert');
DO $$ BEGIN
 BEGIN
  INSERT INTO public.boxer_notifications(recipient_id,notification_type,title,message,event_key)
  VALUES('81111111-1111-4111-8111-111111111111','boxer_duel','Duplicate','Should fail','duel:80000000-0000-4000-8000-000000000001:settled');
  RAISE EXCEPTION 'Event uniqueness missing';
 EXCEPTION WHEN unique_violation THEN NULL; END;
END $$;
-- Invitation/acceptance/decline get separate event keys and preserve existing German text.
INSERT INTO public.league_duels(id,challenger_id,opponent_id,duration_days)
VALUES('80000000-0000-4000-8000-000000000003','81111111-1111-4111-8111-111111111111','82222222-2222-4222-8222-222222222222',7);
UPDATE public.league_duels SET status='declined' WHERE id='80000000-0000-4000-8000-000000000003';
SELECT pg_temp.notice_assert((SELECT count(*) FROM public.boxer_notifications WHERE event_key IN (
 'duel:80000000-0000-4000-8000-000000000003:invited','duel:80000000-0000-4000-8000-000000000003:declined'))=2,'invitation and decline are distinct events');
INSERT INTO public.league_duels(id,challenger_id,opponent_id,duration_days)
VALUES('80000000-0000-4000-8000-000000000004','81111111-1111-4111-8111-111111111111','82222222-2222-4222-8222-222222222222',7);
UPDATE public.league_duels SET status='active',accepted_at=now(),ends_at=now()+interval '7 days' WHERE id='80000000-0000-4000-8000-000000000004';
SELECT pg_temp.notice_assert((SELECT count(*) FROM public.boxer_notifications WHERE event_key='duel:80000000-0000-4000-8000-000000000004:accepted')=1,'acceptance event identity');
ROLLBACK;
DROP TABLE notice_legacy_witness;
\echo Duel notification identity: separate simultaneous results, repeat/correction dedup, read state and deep links passed.
