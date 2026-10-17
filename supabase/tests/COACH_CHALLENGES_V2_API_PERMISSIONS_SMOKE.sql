-- Disposable PostgreSQL only: assert actual API-role grants for all challenge RPCs.
-- No production execution or feature activation.
BEGIN;
DO $check$
DECLARE signature text;
BEGIN
 FOREACH signature IN ARRAY ARRAY[
 'public.coach_challenge_v2_create_draft(text,text,text,integer)',
 'public.coach_challenge_v2_join(uuid)',
 'public.coach_challenge_v2_manage(uuid,text)',
 'public.coach_challenge_v2_withdraw(uuid)',
 'public.coach_challenge_v2_list()',
 'public.coach_challenge_v2_edit_draft(uuid,text,text,text,integer)',
 'public.coach_challenge_v2_set_goal(uuid,text,text,numeric,text)',
 'public.coach_challenge_v2_progress(uuid)',
 'public.coach_challenge_v2_review_manual(uuid,uuid,boolean,text)',
 'public.coach_challenge_v2_review_status(uuid)',
 'public.coach_challenge_v2_review_candidates(uuid)',
 'public.coach_challenge_v2_activate(uuid)',
 'public.coach_challenge_v2_begin_reviews(uuid)',
 'public.coach_challenge_v2_set_reward(uuid,integer)',
 'public.coach_challenge_v2_save_goal_reward(uuid,text,text,integer,numeric,text)',
 'public.coach_challenge_v2_settle_manual(uuid)'
 ] LOOP
  IF NOT pg_catalog.has_function_privilege('authenticated',signature,'EXECUTE') THEN
   RAISE EXCEPTION 'Authenticated API role lacks EXECUTE: %',signature;
  END IF;
  IF pg_catalog.has_function_privilege('anon',signature,'EXECUTE') THEN
   RAISE EXCEPTION 'Anonymous API role may EXECUTE: %',signature;
  END IF;
  IF EXISTS(
   SELECT 1 FROM pg_catalog.pg_proc p
   WHERE p.oid=signature::regprocedure
    AND (NOT p.prosecdef OR p.proconfig IS NULL
     OR NOT EXISTS(SELECT 1 FROM unnest(p.proconfig) setting
      WHERE setting LIKE 'search_path=%'))
  ) THEN
   RAISE EXCEPTION 'Missing SECURITY DEFINER or locked search_path: %',signature;
  END IF;
  IF EXISTS(
   SELECT 1 FROM pg_catalog.pg_proc p,
   LATERAL pg_catalog.aclexplode(
    COALESCE(p.proacl,pg_catalog.acldefault('f',p.proowner))
   ) a
   WHERE p.oid=signature::regprocedure
     AND a.grantee=0 AND a.privilege_type='EXECUTE'
  ) THEN
   RAISE EXCEPTION 'PUBLIC may EXECUTE: %',signature;
  END IF;
 END LOOP;
END $check$;

DO $tables$
DECLARE relation_name text;
BEGIN
 FOREACH relation_name IN ARRAY ARRAY[
 'league_coach_challenges',
 'league_coach_challenge_entries',
 'league_coach_challenge_exp_ledger',
 'league_coach_challenge_reviews'
 ] LOOP
  IF NOT EXISTS(
   SELECT 1 FROM pg_catalog.pg_class c
   JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
   WHERE n.nspname='public' AND c.relname=relation_name AND c.relrowsecurity
  ) THEN RAISE EXCEPTION 'RLS disabled on %',relation_name; END IF;
  IF pg_catalog.has_table_privilege('authenticated','public.'||relation_name,'SELECT')
   OR pg_catalog.has_table_privilege('authenticated','public.'||relation_name,'INSERT')
   OR pg_catalog.has_table_privilege('authenticated','public.'||relation_name,'UPDATE')
   OR pg_catalog.has_table_privilege('authenticated','public.'||relation_name,'DELETE')
   OR pg_catalog.has_table_privilege('anon','public.'||relation_name,'SELECT')
   OR pg_catalog.has_table_privilege('anon','public.'||relation_name,'INSERT')
   OR pg_catalog.has_table_privilege('anon','public.'||relation_name,'UPDATE')
   OR pg_catalog.has_table_privilege('anon','public.'||relation_name,'DELETE')
  THEN RAISE EXCEPTION 'Direct API table access granted: %',relation_name; END IF;
 END LOOP;
END $tables$;
ROLLBACK;
