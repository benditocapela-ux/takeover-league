\set ON_ERROR_STOP on
BEGIN;
DO $$ BEGIN IF current_database() NOT LIKE 'league21_replay_%' THEN RAISE EXCEPTION 'Disposable database required'; END IF; END $$;
CREATE FUNCTION pg_temp.privacy_assert(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERT: %',label; END IF; END $$;
CREATE FUNCTION pg_temp.points_rule() RETURNS jsonb LANGUAGE sql STABLE AS $$
 SELECT jsonb_build_object('metric_revision',(SELECT m->>'revision' FROM jsonb_array_elements(public.duel_v3_options()->'metrics') m WHERE m->>'key'='points'),'training_type_revision',NULL) $$;
INSERT INTO public.profiles(id,auth_user_id,display_name,role,is_active,is_listed,archived_at) VALUES
 ('51111111-1111-4111-8111-111111111111','5aaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Private Points Alpha','boxer',true,true,NULL),
 ('52222222-2222-4222-8222-222222222222','5bbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','Private Points Beta','boxer',true,true,NULL),
 ('53333333-3333-4333-8333-333333333333','5ccccccc-cccc-4ccc-8ccc-cccccccccccc','Points Spectator','boxer',true,true,NULL),
 ('54444444-4444-4444-8444-444444444444','5ddddddd-dddd-4ddd-8ddd-dddddddddddd','Archived Points Coach','coach',true,false,now());
SELECT set_config('request.jwt.claim.sub','5aaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',true);
SET LOCAL ROLE authenticated;
SELECT set_config('privacy.private',public.duel_v3_invite('51111111-1111-4111-8111-111111111111','52222222-2222-4222-8222-222222222222',7,'points',NULL,'participants',pg_temp.points_rule())::text,true);
RESET ROLE;
UPDATE public.league_duels SET status='active',accepted_at='2026-06-01 10:00Z',ends_at='2026-06-08 10:00Z' WHERE id=current_setting('privacy.private')::uuid;
CREATE TEMP TABLE points_rank_witness AS SELECT * FROM public.league_duel_rank_snapshots_v21 WHERE duel_id=current_setting('privacy.private')::uuid;
DELETE FROM public.league_duel_rank_snapshots_v21 WHERE duel_id=current_setting('privacy.private')::uuid;
SELECT set_config('request.jwt.claim.sub','cccccccc-cccc-4ccc-8ccc-cccccccccccc',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE p jsonb; BEGIN
 p:=public.duel_v3_close_preview(current_setting('privacy.private')::uuid);
 PERFORM pg_temp.privacy_assert(NOT (p->>'can_close')::boolean AND p#>>'{rule,reward_rule}'='ranked_v21'
  AND p#>>'{rule,visibility}'='participants' AND p#>>'{rewards,0,planned_exp}' IS NULL,'missing v3 points rank snapshots cannot silently become legacy rewards');
 BEGIN PERFORM public.duel_v2_reconcile(current_setting('privacy.private')::uuid);
  RAISE EXCEPTION 'Missing agreed rank snapshot accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
END $$;
RESET ROLE;
INSERT INTO public.league_duel_rank_snapshots_v21 SELECT * FROM points_rank_witness;
SET LOCAL ROLE authenticated;
DO $$ DECLARE p jsonb; r jsonb; BEGIN
 p:=public.duel_v3_close_preview(current_setting('privacy.private')::uuid);
 r:=public.duel_v3_close_confirm(current_setting('privacy.private')::uuid,true,p->>'revision');
 PERFORM pg_temp.privacy_assert(r->>'outcome'='settled','private v3 points settle normally after integrity repair');
END $$;
SELECT set_config('request.jwt.claim.sub','5ccccccc-cccc-4ccc-8ccc-cccccccccccc',true);
DO $$ BEGIN
 BEGIN PERFORM public.duel_v3_live_scores(current_setting('privacy.private')::uuid);
  RAISE EXCEPTION 'Third boxer viewed private points'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM pg_temp.privacy_assert(NOT EXISTS(SELECT 1 FROM public.duel_v2_list_mine() WHERE id=current_setting('privacy.private')::uuid),'legacy list does not expose private participant data');
END $$;
RESET ROLE;
SET LOCAL ROLE anon;
SELECT pg_temp.privacy_assert(NOT EXISTS(SELECT 1 FROM public.league_public_duel_history_v21 WHERE duel_id=current_setting('privacy.private')::uuid),'anonymous projection excludes private v3 points');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','5aaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',true);
SET LOCAL ROLE authenticated;
SELECT set_config('privacy.club',public.duel_v3_invite('51111111-1111-4111-8111-111111111111','52222222-2222-4222-8222-222222222222',7,'points',NULL,'club',pg_temp.points_rule())::text,true);
RESET ROLE;
UPDATE public.league_duels SET status='active',accepted_at='2026-06-10 10:00Z',ends_at='2026-06-17 10:00Z' WHERE id=current_setting('privacy.club')::uuid;
SELECT set_config('request.jwt.claim.sub','cccccccc-cccc-4ccc-8ccc-cccccccccccc',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE p jsonb; r jsonb; BEGIN
 p:=public.duel_v3_close_preview(current_setting('privacy.club')::uuid);
 r:=public.duel_v3_close_confirm(current_setting('privacy.club')::uuid,true,p->>'revision');
 PERFORM pg_temp.privacy_assert(r->>'outcome'='settled','club v3 points settle normally');
END $$;
SELECT set_config('request.jwt.claim.sub','5ccccccc-cccc-4ccc-8ccc-cccccccccccc',true);
SELECT pg_temp.privacy_assert((public.duel_v3_live_scores(current_setting('privacy.club')::uuid)->>'challenger_score')::numeric=0,'signed-in club viewer sees explicit aggregate');
RESET ROLE;
SET LOCAL ROLE anon;
SELECT pg_temp.privacy_assert(NOT EXISTS(SELECT 1 FROM public.league_public_duel_history_v21 WHERE duel_id=current_setting('privacy.club')::uuid),'club contract does not become anonymous public data');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','5ddddddd-dddd-4ddd-8ddd-dddddddddddd',true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 BEGIN PERFORM public.duel_v2_list_mine(); RAISE EXCEPTION 'Archived active coach read v2 points'; EXCEPTION WHEN raise_exception THEN
  IF SQLERRM<>'Not authorized' THEN RAISE; END IF; END;
 BEGIN PERFORM public.duel_v2_reconcile_due(false,NULL); RAISE EXCEPTION 'Archived active coach reconciled points'; EXCEPTION WHEN raise_exception THEN
  IF SQLERRM<>'Only a coach may reconcile duels' THEN RAISE; END IF; END;
END $$;
RESET ROLE;
ROLLBACK;
\echo V3 points: anonymous projection privacy, explicit signed-in club visibility, strict accepted rank contract and archived legacy-list guards passed.
