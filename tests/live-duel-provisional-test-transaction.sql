-- ISOLATED SUPABASE TEST ONLY. Every inserted fixture rolls back.
-- Validates live-score API owner control, pending training, date window,
-- and intermediate awaiting_reviews state without awarding EXP.
BEGIN;
UPDATE public.league_feature_flags SET is_enabled=true WHERE feature_key='duels';
SELECT set_config('test.a',(SELECT id::text FROM public.profiles WHERE role='boxer' AND auth_user_id IS NOT NULL AND is_active ORDER BY id LIMIT 1),true);
SELECT set_config('test.b',(SELECT id::text FROM public.profiles WHERE role='boxer' AND auth_user_id IS NOT NULL AND is_active ORDER BY id DESC LIMIT 1),true);
SELECT set_config('test.a_auth',(SELECT auth_user_id::text FROM public.profiles WHERE id=current_setting('test.a')::uuid),true);
SELECT set_config('test.fake_auth',gen_random_uuid()::text,true);
SELECT set_config('test.type',(SELECT id::text FROM public.training_types WHERE is_active ORDER BY id LIMIT 1),true);
DO $fixture$ BEGIN
 IF current_setting('test.a')=current_setting('test.b') THEN RAISE EXCEPTION 'Require two distinct boxer profiles'; END IF;
END $fixture$;
WITH duel AS (
 INSERT INTO public.league_duels(challenger_id,opponent_id,status,duration_days,accepted_at,ends_at)
 VALUES(current_setting('test.a')::uuid,current_setting('test.b')::uuid,'active',7,now()-INTERVAL '2 days',now()+INTERVAL '5 days')
 RETURNING id
) SELECT set_config('test.duel',id::text,true) FROM duel;
INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,status,created_at)
VALUES(current_setting('test.a')::uuid,current_setting('test.type')::bigint,current_date,'approved',now()-INTERVAL '1 hour')
RETURNING set_config('test.entry_a',id::text,true);
INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,status,created_at)
VALUES(current_setting('test.b')::uuid,current_setting('test.type')::bigint,current_date,'approved',now()-INTERVAL '1 hour')
RETURNING set_config('test.entry_b',id::text,true);
INSERT INTO public.training_submissions(boxer_id,training_type_id,training_date,status,created_at)
VALUES(current_setting('test.a')::uuid,current_setting('test.type')::bigint,current_date,'pending',now()-INTERVAL '30 minutes')
RETURNING set_config('test.entry_pending',id::text,true);
INSERT INTO public.point_transactions(boxer_id,submission_id,points,exp,category,description,effective_date)
VALUES
(current_setting('test.a')::uuid,current_setting('test.entry_a')::uuid,50,50,'training','TEST duel-score A',current_date),
(current_setting('test.b')::uuid,current_setting('test.entry_b')::uuid,70,70,'training','TEST duel-score B',current_date);
SELECT set_config('request.jwt.claim.sub',current_setting('test.a_auth'),true);
SET LOCAL ROLE authenticated;
DO $active$
DECLARE result jsonb;
BEGIN
 SELECT public.duel_v2_live_scores(current_setting('test.duel')::uuid) INTO result;
 IF (result->>'challenger_score')::integer<>50
  OR (result->>'opponent_score')::integer<>70
  OR (result->>'pending')::integer<>1
  OR result->>'status'<>'active' OR result->>'provisional'<>'true'
 THEN RAISE EXCEPTION 'Active duel score mismatch: %',result; END IF;
 PERFORM set_config('request.jwt.claim.sub',current_setting('test.fake_auth'),true);
 BEGIN
  PERFORM public.duel_v2_live_scores(current_setting('test.duel')::uuid);
  RAISE EXCEPTION 'Unknown/non-participant actor could access duel';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $active$;
RESET ROLE;
-- Verify a completed time window with legitimately dated submissions.
UPDATE public.league_duels SET
 accepted_at=now()-INTERVAL '8 days', ends_at=now()-INTERVAL '1 day',
 status='awaiting_reviews'
WHERE id=current_setting('test.duel')::uuid;
UPDATE public.training_submissions SET
 training_date=(now()-INTERVAL '3 days')::date,
 created_at=now()-INTERVAL '3 days'
WHERE id IN (current_setting('test.entry_a')::uuid,
 current_setting('test.entry_b')::uuid,current_setting('test.entry_pending')::uuid);
SELECT set_config('request.jwt.claim.sub',current_setting('test.a_auth'),true);
SET LOCAL ROLE authenticated;
DO $review$
DECLARE result jsonb;
BEGIN
 SELECT public.duel_v2_live_scores(current_setting('test.duel')::uuid) INTO result;
 IF (result->>'challenger_score')::integer<>50
  OR (result->>'opponent_score')::integer<>70
  OR (result->>'pending')::integer<>1
  OR result->>'status'<>'awaiting_reviews'
 THEN RAISE EXCEPTION 'Awaiting-review score mismatch: %',result; END IF;
END $review$;
RESET ROLE;
ROLLBACK;