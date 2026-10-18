-- Deliberately corrupt synthetic enrollment in disposable PostgreSQL.
-- The following integrity assertion script MUST reject this fixture.
BEGIN;
INSERT INTO public.profiles(id,auth_user_id,display_name,role,is_active)
VALUES ('ac000000-0000-0000-0000-000000000001','ad000000-0000-0000-0000-000000000001','Fixture coach','coach',true),
('ac000000-0000-0000-0000-000000000002','ad000000-0000-0000-0000-000000000002','Fixture boxer','boxer',true);
INSERT INTO public.league_coach_challenges(id,created_by,title,challenge_kind,duration_days,status)
VALUES ('ae000000-0000-0000-0000-000000000001','ac000000-0000-0000-0000-000000000001','Negative audit fixture','individual',7,'open');
INSERT INTO public.league_coach_challenge_entries(challenge_id,boxer_id,status)
VALUES ('ae000000-0000-0000-0000-000000000001','ac000000-0000-0000-0000-000000000002','withdrawn');
INSERT INTO public.league_coach_challenge_exp_ledger(challenge_id,boxer_id,awarded_exp)
VALUES ('ae000000-0000-0000-0000-000000000001','ac000000-0000-0000-0000-000000000002',25);
