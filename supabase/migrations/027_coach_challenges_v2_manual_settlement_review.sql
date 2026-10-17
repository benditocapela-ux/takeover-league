-- REVIEW ONLY. Manual challenge settlement with transaction-level idempotency.
-- Never execute on production without owner-approved SQL release.
BEGIN;
DO $preflight$
DECLARE definition text;
BEGIN
 SELECT pg_catalog.pg_get_constraintdef(c.oid) INTO definition
 FROM pg_catalog.pg_constraint c JOIN pg_catalog.pg_class t ON t.oid=c.conrelid
 JOIN pg_catalog.pg_namespace n ON n.oid=t.relnamespace
 WHERE n.nspname='public' AND t.relname='point_transactions'
 AND c.conname='point_transactions_category_check' AND c.contype='c';
 IF definition IS NULL OR definition !~ 'duel_exp' OR definition !~ 'achievement_exp' THEN
 RAISE EXCEPTION 'Point transaction category constraint requires manual review'; END IF;
 IF EXISTS(SELECT 1 FROM public.point_transactions WHERE category NOT IN
 ('training','trainer_bonus','adjustment','legacy_import','automatic_bonus',
 'achievement_exp','duel_exp','challenge_exp')) THEN
 RAISE EXCEPTION 'Unexpected existing transaction category'; END IF;
END $preflight$;
ALTER TABLE public.point_transactions DROP CONSTRAINT point_transactions_category_check;
ALTER TABLE public.point_transactions ADD CONSTRAINT point_transactions_category_check
 CHECK(category=ANY(ARRAY['training','trainer_bonus','adjustment','legacy_import',
 'automatic_bonus','achievement_exp','duel_exp','challenge_exp']::text[]));
CREATE UNIQUE INDEX IF NOT EXISTS point_transactions_unique_challenge_reward
 ON public.point_transactions(boxer_id,description) WHERE category='challenge_exp';

CREATE OR REPLACE FUNCTION public.coach_challenge_v2_settle_manual(p_challenge_id uuid)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $fn$
DECLARE actor public.profiles%ROWTYPE; c public.league_coach_challenges%ROWTYPE;
 v_now timestamptz; participant record; tx uuid; reward integer;
BEGIN
 SELECT * INTO actor FROM public.profiles WHERE auth_user_id=(SELECT auth.uid())
 AND is_active=true AND role IN ('coach','admin');
 IF NOT FOUND THEN RAISE EXCEPTION 'Coach authorization required'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.league_feature_flags
 WHERE feature_key='coach_challenges' AND is_enabled=true) THEN
 RAISE EXCEPTION 'Coach challenges disabled'; END IF;
 SELECT * INTO c FROM public.league_coach_challenges WHERE id=p_challenge_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Challenge not found'; END IF;
 IF actor.role<>'admin' AND c.created_by<>actor.id THEN
 RAISE EXCEPTION 'Not challenge owner'; END IF;
 IF c.status='settled' THEN
  RAISE EXCEPTION 'Challenge already settled; payout integrity must be audited';
 END IF;
 IF c.status<>'awaiting_reviews' OR c.goal_spec->>'review_mode' IS DISTINCT FROM 'manual'
 OR c.ends_at IS NULL OR c.ends_at>pg_catalog.clock_timestamp()
 OR c.goal_spec->>'reward_exp' IS NULL
 OR c.goal_spec->>'reward_exp' NOT IN ('25','50','100','150','200')
 OR pg_catalog.jsonb_typeof(c.goal_spec->'reward_exp') IS DISTINCT FROM 'number' THEN
 RAISE EXCEPTION 'Manual settlement unavailable'; END IF;
 IF EXISTS(SELECT 1 FROM public.league_coach_challenge_entries e
 LEFT JOIN public.league_coach_challenge_reviews r
 ON r.challenge_id=e.challenge_id AND r.boxer_id=e.boxer_id
 WHERE e.challenge_id=c.id AND e.status='joined' AND r.id IS NULL) THEN
 RAISE EXCEPTION 'All joined participants require a review'; END IF;
 IF EXISTS(SELECT 1 FROM public.league_coach_challenge_exp_ledger WHERE challenge_id=c.id)
 THEN RAISE EXCEPTION 'Existing challenge ledger prevents first settlement'; END IF;
 IF EXISTS(SELECT 1 FROM public.point_transactions
 WHERE category='challenge_exp' AND description='Challenge reward: '||c.id::text)
 THEN RAISE EXCEPTION 'Orphaned challenge payout exists'; END IF;
 v_now:=pg_catalog.clock_timestamp();
 FOR participant IN
 SELECT e.boxer_id,r.approved FROM public.league_coach_challenge_entries e
 JOIN public.league_coach_challenge_reviews r
 ON r.challenge_id=e.challenge_id AND r.boxer_id=e.boxer_id
 WHERE e.challenge_id=c.id AND e.status='joined' ORDER BY e.boxer_id
 LOOP
  reward:=CASE WHEN participant.approved THEN (c.goal_spec->>'reward_exp')::integer ELSE 0 END;
  tx:=NULL;
  IF reward>0 THEN
   INSERT INTO public.point_transactions
   (boxer_id,points,exp,category,description,effective_date,created_by)
   VALUES(participant.boxer_id,0,reward,'challenge_exp',
   'Challenge reward: '||c.id::text,
   (c.ends_at AT TIME ZONE 'Europe/Zurich')::date,actor.id)
   RETURNING id INTO tx;
  END IF;
  INSERT INTO public.league_coach_challenge_exp_ledger
  (challenge_id,boxer_id,transaction_id,awarded_exp)
  VALUES(c.id,participant.boxer_id,tx,reward);
 END LOOP;
 UPDATE public.league_coach_challenges SET status='settled',
 settled_at=v_now,updated_at=v_now WHERE id=c.id;
 RETURN 'settled';
END $fn$;
REVOKE ALL ON FUNCTION public.coach_challenge_v2_settle_manual(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.coach_challenge_v2_settle_manual(uuid) TO authenticated;
COMMIT;
