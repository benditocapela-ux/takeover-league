-- Coach Challenges V2: production-oriented RPC implementation (part 1/2).
-- PREPARED ONLY. Requires the four V2 tables and disabled V2 feature flags.
-- All public functions use SECURITY DEFINER with explicit actor/owner checks.
-- Do not deploy to production until integration and role tests pass.
BEGIN;
CREATE SCHEMA league_private;
REVOKE ALL ON SCHEMA league_private FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION league_private.coach_v2_actor()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $func$
DECLARE v_actor jsonb;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.league_feature_flags
                WHERE feature_key='coach_challenges' AND is_enabled IS TRUE)
 THEN RAISE EXCEPTION 'Coach Challenges not enabled' USING ERRCODE='42501'; END IF;
 SELECT pg_catalog.jsonb_build_object('id',p.id,'role',p.role) INTO v_actor
 FROM public.profiles p WHERE p.auth_user_id=auth.uid() AND p.is_active IS TRUE;
 IF v_actor IS NULL OR (v_actor->>'role') NOT IN ('boxer','coach','admin')
 THEN RAISE EXCEPTION 'Active league profile required' USING ERRCODE='42501'; END IF;
 RETURN v_actor;
END
$func$;
REVOKE ALL ON FUNCTION league_private.coach_v2_actor() FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.coach_challenge_v2_create_draft(
 p_title text,p_description text,p_kind text,p_duration_days integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $func$
DECLARE a jsonb:=league_private.coach_v2_actor(); v_id uuid;
BEGIN
 IF a->>'role' NOT IN ('coach','admin') THEN RAISE EXCEPTION 'Coach role required' USING ERRCODE='42501'; END IF;
 IF char_length(pg_catalog.btrim(COALESCE(p_title,''))) NOT BETWEEN 3 AND 120 OR
    p_kind NOT IN ('individual','competition','coach_goal') OR p_kind IS NULL OR
    p_duration_days NOT IN (7,14,30) OR p_duration_days IS NULL
 THEN RAISE EXCEPTION 'Invalid challenge title, kind or duration' USING ERRCODE='22023'; END IF;
 INSERT INTO public.league_coach_challenges(created_by,title,description,challenge_kind,duration_days)
 VALUES((a->>'id')::uuid,pg_catalog.btrim(p_title),COALESCE(p_description,''),p_kind,p_duration_days)
 RETURNING id INTO v_id;
 RETURN pg_catalog.jsonb_build_object('id',v_id,'status','draft');
END
$func$;

CREATE OR REPLACE FUNCTION public.coach_challenge_v2_edit_draft(
 p_id uuid,p_title text,p_description text,p_kind text,p_days integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $func$
DECLARE a jsonb:=league_private.coach_v2_actor(); c public.league_coach_challenges%ROWTYPE;
BEGIN
 IF a->>'role' NOT IN ('coach','admin') THEN RAISE EXCEPTION 'Coach role required' USING ERRCODE='42501'; END IF;
 IF char_length(pg_catalog.btrim(COALESCE(p_title,''))) NOT BETWEEN 3 AND 120 OR
    p_kind NOT IN ('individual','competition','coach_goal') OR p_kind IS NULL OR
    p_days NOT IN (7,14,30) OR p_days IS NULL
 THEN RAISE EXCEPTION 'Invalid challenge data' USING ERRCODE='22023'; END IF;
 SELECT * INTO c FROM public.league_coach_challenges WHERE id=p_id FOR UPDATE;
 IF c.id IS NULL THEN RAISE EXCEPTION 'Challenge not found' USING ERRCODE='P0002'; END IF;
 IF (a->>'role') <> 'admin' AND c.created_by <> (a->>'id')::uuid
 THEN RAISE EXCEPTION 'Not challenge owner' USING ERRCODE='42501'; END IF;
 IF c.status <> 'draft' THEN RAISE EXCEPTION 'Only drafts can be edited' USING ERRCODE='22023'; END IF;
 UPDATE public.league_coach_challenges SET title=pg_catalog.btrim(p_title),
 description=COALESCE(p_description,''),challenge_kind=p_kind,duration_days=p_days,updated_at=now()
 WHERE id=c.id;
 RETURN pg_catalog.jsonb_build_object('id',c.id,'status','draft');
END
$func$;

CREATE OR REPLACE FUNCTION public.coach_challenge_v2_save_goal_reward(
 p_challenge_id uuid,p_goal_text text,p_review_mode text,p_reward_exp integer,
 p_target_value numeric,p_metric text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $func$
DECLARE a jsonb:=league_private.coach_v2_actor(); c public.league_coach_challenges%ROWTYPE;
BEGIN
 IF a->>'role' NOT IN ('coach','admin') THEN RAISE EXCEPTION 'Coach role required' USING ERRCODE='42501'; END IF;
 SELECT * INTO c FROM public.league_coach_challenges WHERE id=p_challenge_id FOR UPDATE;
 IF c.id IS NULL THEN RAISE EXCEPTION 'Challenge not found' USING ERRCODE='P0002'; END IF;
 IF a->>'role'<>'admin' AND c.created_by<>(a->>'id')::uuid
 THEN RAISE EXCEPTION 'Not challenge owner' USING ERRCODE='42501'; END IF;
 IF c.status<>'draft' THEN RAISE EXCEPTION 'Goal locked after publication' USING ERRCODE='22023'; END IF;
 IF char_length(pg_catalog.btrim(COALESCE(p_goal_text,''))) NOT BETWEEN 5 AND 1000
 OR p_review_mode IS DISTINCT FROM 'manual'
 OR p_reward_exp NOT IN (25,50,100,150,200) OR p_reward_exp IS NULL
 OR (p_target_value IS NOT NULL AND p_target_value<=0)
 THEN RAISE EXCEPTION 'Invalid manual goal or EXP reward' USING ERRCODE='22023'; END IF;
 UPDATE public.league_coach_challenges SET
 goal_spec=pg_catalog.jsonb_build_object('version',1,
 'goal_text',pg_catalog.btrim(p_goal_text),'review_mode',p_review_mode,
 'reward_exp',p_reward_exp,'target_value',p_target_value,'metric',p_metric),
 updated_at=now() WHERE id=c.id;
 RETURN pg_catalog.jsonb_build_object('id',c.id,'reward_exp',p_reward_exp,'review_mode','manual');
END
$func$;

CREATE OR REPLACE FUNCTION public.coach_challenge_v2_set_goal(
 p_challenge_id uuid,p_goal_text text,p_review_mode text,p_target_value numeric,p_metric text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $func$
DECLARE a jsonb:=league_private.coach_v2_actor(); c public.league_coach_challenges%ROWTYPE;
BEGIN
 IF a->>'role' NOT IN ('coach','admin') THEN RAISE EXCEPTION 'Coach role required' USING ERRCODE='42501'; END IF;
 SELECT * INTO c FROM public.league_coach_challenges WHERE id=p_challenge_id FOR UPDATE;
 IF c.id IS NULL THEN RAISE EXCEPTION 'Challenge not found' USING ERRCODE='P0002'; END IF;
 IF a->>'role'<>'admin' AND c.created_by<>(a->>'id')::uuid
 THEN RAISE EXCEPTION 'Not challenge owner' USING ERRCODE='42501'; END IF;
 IF c.status<>'draft' THEN RAISE EXCEPTION 'Goal locked after publication' USING ERRCODE='22023'; END IF;
 IF char_length(pg_catalog.btrim(COALESCE(p_goal_text,''))) NOT BETWEEN 5 AND 1000
 OR p_review_mode IS DISTINCT FROM 'manual'
 OR (p_target_value IS NOT NULL AND p_target_value<=0)
 THEN RAISE EXCEPTION 'Invalid goal definition' USING ERRCODE='22023'; END IF;
 UPDATE public.league_coach_challenges SET
 goal_spec=COALESCE(goal_spec,'{}'::jsonb) || pg_catalog.jsonb_build_object(
 'version',1,'goal_text',pg_catalog.btrim(p_goal_text),
 'review_mode','manual','target_value',p_target_value,'metric',p_metric),
 updated_at=now() WHERE id=c.id;
 RETURN pg_catalog.jsonb_build_object('id',c.id,'goal_text',pg_catalog.btrim(p_goal_text));
END
$func$;

CREATE OR REPLACE FUNCTION public.coach_challenge_v2_set_reward(
 p_challenge_id uuid,p_reward_exp integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $func$
DECLARE a jsonb:=league_private.coach_v2_actor(); c public.league_coach_challenges%ROWTYPE;
BEGIN
 IF a->>'role' NOT IN ('coach','admin') THEN RAISE EXCEPTION 'Coach role required' USING ERRCODE='42501'; END IF;
 SELECT * INTO c FROM public.league_coach_challenges WHERE id=p_challenge_id FOR UPDATE;
 IF c.id IS NULL THEN RAISE EXCEPTION 'Challenge not found' USING ERRCODE='P0002'; END IF;
 IF a->>'role'<>'admin' AND c.created_by<>(a->>'id')::uuid
 THEN RAISE EXCEPTION 'Not challenge owner' USING ERRCODE='42501'; END IF;
 IF c.status<>'draft' THEN RAISE EXCEPTION 'Reward locked after publication' USING ERRCODE='22023'; END IF;
 IF p_reward_exp IS NULL OR p_reward_exp NOT IN (25,50,100,150,200)
 THEN RAISE EXCEPTION 'Invalid EXP reward' USING ERRCODE='22023'; END IF;
 UPDATE public.league_coach_challenges
 SET goal_spec=COALESCE(goal_spec,'{}'::jsonb)||pg_catalog.jsonb_build_object('reward_exp',p_reward_exp),
 updated_at=now() WHERE id=c.id;
 RETURN pg_catalog.jsonb_build_object('id',c.id,'reward_exp',p_reward_exp);
END
$func$;

CREATE OR REPLACE FUNCTION public.coach_challenge_v2_manage(
 p_challenge_id uuid,p_action text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $func$
DECLARE a jsonb:=league_private.coach_v2_actor(); c public.league_coach_challenges%ROWTYPE; next_status text;
BEGIN
 IF a->>'role' NOT IN ('coach','admin') THEN RAISE EXCEPTION 'Coach role required' USING ERRCODE='42501'; END IF;
 SELECT * INTO c FROM public.league_coach_challenges WHERE id=p_challenge_id FOR UPDATE;
 IF c.id IS NULL THEN RAISE EXCEPTION 'Challenge not found' USING ERRCODE='P0002'; END IF;
 IF a->>'role'<>'admin' AND c.created_by<>(a->>'id')::uuid
 THEN RAISE EXCEPTION 'Not challenge owner' USING ERRCODE='42501'; END IF;
 IF p_action='open' AND c.status='draft' THEN
   IF pg_catalog.char_length(pg_catalog.btrim(COALESCE(c.goal_spec->>'goal_text','')))<5
   OR c.goal_spec->>'review_mode' IS DISTINCT FROM 'manual'
   OR COALESCE((c.goal_spec->>'reward_exp')::integer,0) NOT IN (25,50,100,150,200)
   THEN RAISE EXCEPTION 'Valid manual goal and reward required' USING ERRCODE='22023'; END IF;
   next_status:='open';
 ELSIF p_action='cancel' AND c.status IN ('draft','open') THEN next_status:='cancelled';
 ELSE RAISE EXCEPTION 'Unsupported action or status transition' USING ERRCODE='22023';
 END IF;
 UPDATE public.league_coach_challenges SET status=next_status,updated_at=now() WHERE id=c.id;
 RETURN pg_catalog.jsonb_build_object('id',c.id,'status',next_status);
END
$func$;

CREATE OR REPLACE FUNCTION public.coach_challenge_v2_join(p_challenge_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $func$
DECLARE a jsonb:=league_private.coach_v2_actor(); c public.league_coach_challenges%ROWTYPE; current_status text;
BEGIN
 IF a->>'role'<>'boxer' THEN RAISE EXCEPTION 'Boxer role required' USING ERRCODE='42501'; END IF;
 SELECT * INTO c FROM public.league_coach_challenges WHERE id=p_challenge_id FOR UPDATE;
 IF c.id IS NULL OR c.status<>'open' THEN RAISE EXCEPTION 'Challenge not open' USING ERRCODE='22023'; END IF;
 SELECT status INTO current_status FROM public.league_coach_challenge_entries
 WHERE challenge_id=c.id AND boxer_id=(a->>'id')::uuid FOR UPDATE;
 IF current_status='completed' THEN RAISE EXCEPTION 'Entry already completed' USING ERRCODE='22023'; END IF;
 IF current_status='withdrawn' THEN
 UPDATE public.league_coach_challenge_entries
 SET status='joined',joined_at=now() WHERE challenge_id=c.id AND boxer_id=(a->>'id')::uuid;
 ELSIF current_status IS NULL THEN
 INSERT INTO public.league_coach_challenge_entries(challenge_id,boxer_id)
 VALUES(c.id,(a->>'id')::uuid);
 END IF;
 RETURN pg_catalog.jsonb_build_object('challenge_id',c.id,'status','joined');
END
$func$;

CREATE OR REPLACE FUNCTION public.coach_challenge_v2_withdraw(p_challenge_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $func$
DECLARE a jsonb:=league_private.coach_v2_actor(); c public.league_coach_challenges%ROWTYPE;
BEGIN
 IF a->>'role'<>'boxer' THEN RAISE EXCEPTION 'Boxer role required' USING ERRCODE='42501'; END IF;
 SELECT * INTO c FROM public.league_coach_challenges WHERE id=p_challenge_id FOR UPDATE;
 IF c.id IS NULL OR c.status<>'open' THEN RAISE EXCEPTION 'Withdrawal no longer available' USING ERRCODE='22023'; END IF;
 UPDATE public.league_coach_challenge_entries SET status='withdrawn'
 WHERE challenge_id=c.id AND boxer_id=(a->>'id')::uuid AND status='joined';
 IF NOT FOUND THEN RAISE EXCEPTION 'No active enrollment' USING ERRCODE='22023'; END IF;
 RETURN pg_catalog.jsonb_build_object('challenge_id',c.id,'status','withdrawn');
END
$func$;

CREATE OR REPLACE FUNCTION public.coach_challenge_v2_activate(p_challenge_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $func$
DECLARE a jsonb:=league_private.coach_v2_actor(); c public.league_coach_challenges%ROWTYPE; started timestamptz:=pg_catalog.clock_timestamp();
BEGIN
 IF a->>'role' NOT IN ('coach','admin') THEN RAISE EXCEPTION 'Coach role required' USING ERRCODE='42501'; END IF;
 SELECT * INTO c FROM public.league_coach_challenges WHERE id=p_challenge_id FOR UPDATE;
 IF c.id IS NULL THEN RAISE EXCEPTION 'Challenge not found' USING ERRCODE='P0002'; END IF;
 IF a->>'role'<>'admin' AND c.created_by<>(a->>'id')::uuid
 THEN RAISE EXCEPTION 'Not challenge owner' USING ERRCODE='42501'; END IF;
 IF c.status<>'open' THEN RAISE EXCEPTION 'Challenge must be open' USING ERRCODE='22023'; END IF;
 UPDATE public.league_coach_challenges
 SET status='active',starts_at=started,ends_at=started+pg_catalog.make_interval(days=>c.duration_days),
 updated_at=started WHERE id=c.id;
 RETURN pg_catalog.jsonb_build_object('id',c.id,'status','active');
END
$func$;

-- Lock down all nine public entrypoints before transaction commits.
DO $grant$
DECLARE sig text;
BEGIN
 FOREACH sig IN ARRAY ARRAY[
 'coach_challenge_v2_create_draft(text,text,text,integer)',
 'coach_challenge_v2_edit_draft(uuid,text,text,text,integer)',
 'coach_challenge_v2_save_goal_reward(uuid,text,text,integer,numeric,text)',
 'coach_challenge_v2_set_goal(uuid,text,text,numeric,text)',
 'coach_challenge_v2_set_reward(uuid,integer)',
 'coach_challenge_v2_manage(uuid,text)',
 'coach_challenge_v2_join(uuid)',
 'coach_challenge_v2_withdraw(uuid)',
 'coach_challenge_v2_activate(uuid)'] LOOP
 EXECUTE 'REVOKE ALL ON FUNCTION public.'||sig||' FROM PUBLIC, anon';
 EXECUTE 'GRANT EXECUTE ON FUNCTION public.'||sig||' TO authenticated';
END LOOP;
END
$grant$;
COMMIT;
