-- Fresh disposable PostgreSQL only. Invoked AFTER both V2 migrations, never on Supabase.
-- Fixture accounts and roles originate from production-v2-schema-smoke.sql.
\set ON_ERROR_STOP on
UPDATE public.league_feature_flags SET is_enabled=true
WHERE feature_key IN ('coach_challenges','duels');

-- Two simultaneous reviewers settling this completed manual challenge.
INSERT INTO public.league_coach_challenges
(id,created_by,title,description,challenge_kind,duration_days,goal_spec,status,starts_at,ends_at)
VALUES (
 '90000000-0000-4000-8000-000000000001',
 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
 'Concurrent Settlement Test','Concurrency fixture only','individual',7,
 '{"version":1,"goal_text":"Complete reviewed sessions","review_mode":"manual","reward_exp":100}'::jsonb,
 'awaiting_reviews',now()-INTERVAL '9 days',now()-INTERVAL '2 days'
);
INSERT INTO public.league_coach_challenge_entries(challenge_id,boxer_id)
VALUES('90000000-0000-4000-8000-000000000001','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
INSERT INTO public.league_coach_challenge_reviews
(challenge_id,boxer_id,reviewed_by,approved,reason)
VALUES('90000000-0000-4000-8000-000000000001',
 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',true,'All sessions approved');

-- Concurrent join/rejoin by a different boxer must create one membership.
INSERT INTO public.league_coach_challenges
(id,created_by,title,description,challenge_kind,duration_days,goal_spec,status)
VALUES (
 '90000000-0000-4000-8000-000000000002',
 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
 'Concurrent Enrollment Test','Concurrency fixture only','individual',7,
 '{"version":1,"goal_text":"Join an open challenge","review_mode":"manual","reward_exp":25}'::jsonb,
 'open'
);
SELECT 'Concurrent V2 fixtures ready' AS result;
