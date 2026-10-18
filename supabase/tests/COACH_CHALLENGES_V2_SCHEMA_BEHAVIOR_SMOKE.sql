-- Disposable PostgreSQL only. Coach challenge schema invariants.
BEGIN;
DO $check$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM public.league_feature_flags
                WHERE feature_key='coach_challenges' AND is_enabled=false) THEN
  RAISE EXCEPTION 'Coach challenges must default to disabled';
 END IF;
 IF EXISTS (
  SELECT 1 FROM pg_catalog.pg_class c
  JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='public'
    AND c.relname IN ('league_coach_challenges','league_coach_challenge_entries',
                      'league_coach_challenge_exp_ledger')
    AND NOT c.relrowsecurity
 ) THEN RAISE EXCEPTION 'Challenge table RLS missing'; END IF;
 IF (SELECT count(*) FROM pg_catalog.pg_class c
     JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
     WHERE n.nspname='public' AND c.relname IN
      ('league_coach_challenges','league_coach_challenge_entries',
       'league_coach_challenge_exp_ledger'))<>3 THEN
  RAISE EXCEPTION 'Challenge schema table missing';
 END IF;
END $check$;

INSERT INTO public.profiles(id,display_name,role,is_active)
VALUES ('a0000000-0000-0000-0000-000000000001','Test coach','coach',true),
       ('a0000000-0000-0000-0000-000000000002','Test boxer','boxer',true);
INSERT INTO public.league_coach_challenges
 (id,created_by,title,challenge_kind,duration_days)
VALUES ('a0000000-0000-0000-0000-000000000003',
        'a0000000-0000-0000-0000-000000000001',
        'Synthetic challenge','competition',14);
INSERT INTO public.league_coach_challenge_entries(challenge_id,boxer_id)
VALUES ('a0000000-0000-0000-0000-000000000003',
        'a0000000-0000-0000-0000-000000000002');
DO $check$
BEGIN
 BEGIN
  INSERT INTO public.league_coach_challenge_entries(challenge_id,boxer_id)
  VALUES ('a0000000-0000-0000-0000-000000000003',
          'a0000000-0000-0000-0000-000000000002');
  RAISE EXCEPTION 'Duplicate enrollment accepted';
 EXCEPTION WHEN unique_violation THEN NULL;
 END;
 BEGIN
  INSERT INTO public.league_coach_challenges(created_by,title,challenge_kind,duration_days)
  VALUES ('a0000000-0000-0000-0000-000000000001','Invalid','individual',5);
  RAISE EXCEPTION 'Invalid duration accepted';
 EXCEPTION WHEN check_violation THEN NULL;
 END;
 BEGIN
  INSERT INTO public.league_coach_challenge_exp_ledger(challenge_id,boxer_id,awarded_exp)
  VALUES ('a0000000-0000-0000-0000-000000000003',
          'a0000000-0000-0000-0000-000000000002',175);
  RAISE EXCEPTION 'Invalid reward accepted';
 EXCEPTION WHEN check_violation THEN NULL;
 END;
END $check$;
ROLLBACK;
