-- Disposable PostgreSQL integration fixture only. Never run against Supabase projects.
\set ON_ERROR_STOP on
\i tests/production-v2-schema-smoke.sql

CREATE SCHEMA IF NOT EXISTS league_v21_private;
REVOKE ALL ON SCHEMA league_v21_private FROM PUBLIC,anon,authenticated;
GRANT USAGE ON SCHEMA league_v21_private TO authenticated;

CREATE TABLE public.league_global_challenges_v21 (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 title text NOT NULL,
 description text NOT NULL DEFAULT '',
 metric text NOT NULL,
 target_value numeric NOT NULL,
 starts_at timestamptz NOT NULL,
 ends_at timestamptz NOT NULL,
 status text NOT NULL DEFAULT 'draft',
 created_by uuid NOT NULL REFERENCES public.profiles(id),
 completion_exp integer NOT NULL DEFAULT 0,
 winner_exp integer NOT NULL DEFAULT 0
);
CREATE TABLE public.league_global_entries_v21 (
 challenge_id uuid NOT NULL REFERENCES public.league_global_challenges_v21(id),
 boxer_id uuid NOT NULL REFERENCES public.profiles(id),
 joined_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(challenge_id,boxer_id)
);

UPDATE public.league_feature_flags SET is_enabled=true
WHERE feature_key IN ('coach_challenges','league_challenges');

INSERT INTO public.profiles(id,auth_user_id,display_name,role,is_active)
VALUES('77777777-7777-4777-8777-777777777777',
       '77777777-7777-4777-8777-777777777778','Test Admin','admin',true);

\i supabase/migrations/20261021223000_admin_challenge_editing.sql

BEGIN;
SELECT set_config('request.jwt.claim.sub','77777777-7777-4777-8777-777777777778',true);

INSERT INTO public.league_coach_challenges(id,created_by,title,description,challenge_kind,duration_days,goal_spec,status)
VALUES
 ('dddddddd-dddd-4ddd-8ddd-dddddddddddd','77777777-7777-4777-8777-777777777777',
  'Draft Challenge','Before edit','individual',7,NULL,'draft'),
 ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','77777777-7777-4777-8777-777777777777',
  'Open Challenge','Before edit','individual',7,
  '{"version":1,"goal_text":"Complete five sessions","review_mode":"manual","reward_exp":25,"target_value":null,"metric":null}'::jsonb,'open');

INSERT INTO public.league_coach_challenge_entries(challenge_id,boxer_id,status)
VALUES('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','joined');

INSERT INTO public.league_global_challenges_v21(id,title,description,metric,target_value,starts_at,ends_at,status,created_by)
VALUES
 ('ffffffff-ffff-4fff-8fff-ffffffffffff','Upcoming Challenge','Before edit','training_sessions',10,now()+interval '2 days',now()+interval '9 days','active','77777777-7777-4777-8777-777777777777'),
 ('99999999-9999-4999-8999-999999999999','Joined Challenge','Before edit','training_sessions',10,now()+interval '2 days',now()+interval '9 days','active','77777777-7777-4777-8777-777777777777'),
 ('88888888-8888-4888-8888-888888888888','Started Challenge','Before edit','training_sessions',10,now()-interval '1 day',now()+interval '6 days','active','77777777-7777-4777-8777-777777777777');
INSERT INTO public.league_global_entries_v21(challenge_id,boxer_id)
VALUES('99999999-9999-4999-8999-999999999999','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');

DO $test$
DECLARE blocked boolean; result jsonb;
BEGIN
 result:=public.coach_challenge_v2_admin_edit(
  'dddddddd-dddd-4ddd-8ddd-dddddddddddd','Edited Draft','Updated details','competition',14,
  'Complete five confirmed sessions',50
 );
 IF result->>'status'<>'draft' OR result->>'goal_updated'<>'true' THEN
  RAISE EXCEPTION 'Admin draft editing did not return expected result: %',result;
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.league_coach_challenges
  WHERE id='dddddddd-dddd-4ddd-8ddd-dddddddddddd'
    AND title='Edited Draft' AND challenge_kind='competition' AND duration_days=14
    AND goal_spec->>'goal_text'='Complete five confirmed sessions'
    AND (goal_spec->>'reward_exp')::integer=50)
 THEN RAISE EXCEPTION 'Admin draft edit did not persist'; END IF;

 blocked:=false;
 BEGIN
  PERFORM public.coach_challenge_v2_admin_edit(
   'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','Renamed Open','Updated details','competition',14,NULL,NULL
  );
 EXCEPTION WHEN SQLSTATE '22023' THEN blocked:=true;
 END;
 IF NOT blocked THEN RAISE EXCEPTION 'Challenge rules changed after a participant joined'; END IF;
 PERFORM public.coach_challenge_v2_admin_edit(
  'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','Renamed Open','Updated details','individual',7,NULL,NULL
 );
 IF NOT EXISTS(SELECT 1 FROM public.league_coach_challenges
  WHERE id='eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee' AND title='Renamed Open')
 THEN RAISE EXCEPTION 'Title/description edit with participants failed'; END IF;

 result:=public.league_v21_admin_edit_global_challenge(
  'ffffffff-ffff-4fff-8fff-ffffffffffff','Edited Upcoming','Updated details',
  'jogging_km',20,now()+interval '3 days',now()+interval '10 days',true
 );
 IF result->>'rules_updated'<>'true' OR NOT EXISTS(
  SELECT 1 FROM public.league_global_challenges_v21
  WHERE id='ffffffff-ffff-4fff-8fff-ffffffffffff' AND metric='jogging_km' AND target_value=20
 )
 THEN RAISE EXCEPTION 'Admin global challenge edit failed'; END IF;

 PERFORM public.league_v21_admin_edit_global_challenge(
  '99999999-9999-4999-8999-999999999999','Renamed Joined','Updated details',NULL,NULL,NULL,NULL,false
 );
 blocked:=false;
 BEGIN
  PERFORM public.league_v21_admin_edit_global_challenge(
   '99999999-9999-4999-8999-999999999999','Renamed Joined','Updated details',
   'jogging_km',20,now()+interval '3 days',now()+interval '10 days',true
  );
 EXCEPTION WHEN SQLSTATE '22023' THEN blocked:=true;
 END;
 IF NOT blocked THEN RAISE EXCEPTION 'Global challenge rules changed after a boxer joined'; END IF;

 blocked:=false;
 BEGIN
  PERFORM public.league_v21_admin_edit_global_challenge(
   '88888888-8888-4888-8888-888888888888','Renamed Started','Updated details',
   'jogging_km',20,now()+interval '2 days',now()+interval '9 days',true
  );
 EXCEPTION WHEN SQLSTATE '22023' THEN blocked:=true;
 END;
 IF NOT blocked THEN RAISE EXCEPTION 'Global challenge rules changed after start'; END IF;

 UPDATE public.league_feature_flags SET is_enabled=false WHERE feature_key='league_challenges';
 blocked:=false;
 BEGIN
  PERFORM public.league_v21_admin_edit_global_challenge(
   'ffffffff-ffff-4fff-8fff-ffffffffffff','Blocked while disabled','Updated details',NULL,NULL,NULL,NULL,false
  );
 EXCEPTION WHEN insufficient_privilege THEN blocked:=true;
 END;
 IF NOT blocked THEN RAISE EXCEPTION 'Global challenge editing ignored the disabled feature flag'; END IF;
END
$test$;
ROLLBACK;
