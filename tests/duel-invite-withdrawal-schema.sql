-- Disposable PostgreSQL integration fixture only. Never run against Supabase projects.
\set ON_ERROR_STOP on
\i tests/production-v2-schema-smoke.sql

ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_role_check CHECK (role IN ('boxer','coach','admin'));

INSERT INTO public.profiles(id,auth_user_id,display_name,role,is_active)
VALUES('12121212-1212-4212-8212-121212121212',
       '33333333-3333-4333-8333-333333333333','Test Boxer Two','boxer',true);

CREATE TABLE public.league_duels (
 id uuid PRIMARY KEY,
 challenger_id uuid NOT NULL REFERENCES public.profiles(id),
 opponent_id uuid NOT NULL REFERENCES public.profiles(id),
 created_by uuid NOT NULL REFERENCES public.profiles(id),
 initiated_by_coach boolean NOT NULL DEFAULT false,
 status text NOT NULL CHECK (status IN ('pending','active','awaiting_reviews','settled','declined','expired','cancelled')),
 expires_at timestamptz NOT NULL,
 updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.league_duel_events (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 duel_id uuid NOT NULL REFERENCES public.league_duels(id),
 boxer_id uuid REFERENCES public.profiles(id),
 event_type text NOT NULL CHECK (event_type IN ('invited','accepted','declined','expired','awaiting_reviews','settled','corrected','cancelled')),
 created_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.league_feature_flags(feature_key,display_name,is_enabled)
VALUES('duels','Duels',true)
ON CONFLICT(feature_key) DO UPDATE SET is_enabled=true;

\i supabase/migrations/20261023210000_duel_invite_withdrawal.sql

INSERT INTO public.league_duels(id,challenger_id,opponent_id,created_by,initiated_by_coach,status,expires_at)
VALUES
 ('dddddddd-dddd-4ddd-8ddd-dddddddddddd','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','12121212-1212-4212-8212-121212121212','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,'pending',now()+interval '24 hours'),
 ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','12121212-1212-4212-8212-121212121212','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',true,'pending',now()+interval '24 hours'),
 ('ffffffff-ffff-4fff-8fff-ffffffffffff','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','12121212-1212-4212-8212-121212121212','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,'active',now()+interval '24 hours'),
 ('99999999-9999-4999-8999-999999999999','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','12121212-1212-4212-8212-121212121212','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,'pending',now()-interval '1 minute');

BEGIN;
SELECT set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
DO $test$
DECLARE blocked boolean;
BEGIN
 IF public.duel_v2_withdraw_invite('dddddddd-dddd-4ddd-8ddd-dddddddddddd') <> 'cancelled'
 THEN RAISE EXCEPTION 'Boxer could not withdraw own pending invitation'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.league_duels WHERE id='dddddddd-dddd-4ddd-8ddd-dddddddddddd' AND status='cancelled')
 OR NOT EXISTS(SELECT 1 FROM public.league_duel_events WHERE duel_id='dddddddd-dddd-4ddd-8ddd-dddddddddddd' AND event_type='cancelled')
 THEN RAISE EXCEPTION 'Withdrawal was not recorded'; END IF;

 blocked:=false;
 BEGIN
  PERFORM public.duel_v2_withdraw_invite('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee');
 EXCEPTION WHEN insufficient_privilege THEN blocked:=true;
 END;
 IF NOT blocked OR NOT EXISTS(SELECT 1 FROM public.league_duels WHERE id='eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee' AND status='pending')
 THEN RAISE EXCEPTION 'Boxer withdrew a coach-created invitation'; END IF;

 blocked:=false;
 BEGIN
  PERFORM public.duel_v2_withdraw_invite('ffffffff-ffff-4fff-8fff-ffffffffffff');
 EXCEPTION WHEN SQLSTATE '22023' THEN blocked:=true;
 END;
 IF NOT blocked OR NOT EXISTS(SELECT 1 FROM public.league_duels WHERE id='ffffffff-ffff-4fff-8fff-ffffffffffff' AND status='active')
 THEN RAISE EXCEPTION 'Active duel was not protected'; END IF;

 IF public.duel_v2_withdraw_invite('99999999-9999-4999-8999-999999999999') <> 'expired'
 THEN RAISE EXCEPTION 'Expired invitation was not normalized'; END IF;
END
$test$;

SELECT set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
DO $test$
BEGIN
 IF public.duel_v2_withdraw_invite('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee') <> 'cancelled'
 THEN RAISE EXCEPTION 'Coach could not withdraw pending invitation'; END IF;
END
$test$;

DO $test$
BEGIN
 IF has_function_privilege('anon','public.duel_v2_withdraw_invite(uuid)','EXECUTE')
 THEN RAISE EXCEPTION 'Anonymous role can execute duel withdrawal'; END IF;
 IF NOT has_function_privilege('authenticated','public.duel_v2_withdraw_invite(uuid)','EXECUTE')
 THEN RAISE EXCEPTION 'Authenticated role cannot execute duel withdrawal'; END IF;
END
$test$;
ROLLBACK;
