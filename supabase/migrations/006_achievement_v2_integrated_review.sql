-- Takeover League 2.0 – INTEGRATED ACHIEVEMENT ENGINE (REVIEW ONLY)
-- NOT FOR LIVE EXECUTION. 002 is live; this replaces draft 003/004/005.
-- Requires separate review of permissions, lock ordering and correction audit.
BEGIN;

CREATE TABLE IF NOT EXISTS public.achievement_v2_rules (
 achievement_id uuid PRIMARY KEY REFERENCES public.achievement_definitions(id),
 metric text NOT NULL CHECK(metric IN ('sessions','days','jogging_km','sprints','technique_minutes','sparring','strength','complete')),
 threshold numeric NOT NULL CHECK(threshold>0),
 tier integer NOT NULL CHECK(tier BETWEEN 1 AND 4),
 reward_exp integer NOT NULL CHECK((tier=1 AND reward_exp=25) OR (tier=2 AND reward_exp=60) OR (tier=3 AND reward_exp=125) OR (tier=4 AND reward_exp=250)),
 UNIQUE(metric,tier)
);
ALTER TABLE public.achievement_v2_rules ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.achievement_v2_rules FROM PUBLIC,anon,authenticated;

WITH rules(code,metric,tier,threshold,reward_exp) AS (
 VALUES
 ('training_10','sessions',1,10,25),('training_25','sessions',2,25,60),('training_50','sessions',3,50,125),('training_100','sessions',4,100,250),
 ('consistent_10','days',1,10,25),('consistent_25','days',2,25,60),('consistent_60','days',3,60,125),('consistent_120','days',4,120,250),
 ('road_25','jogging_km',1,25,25),('road_75','jogging_km',2,75,60),('road_150','jogging_km',3,150,125),('road_300','jogging_km',4,300,250),
 ('flash_5','sprints',1,5,25),('flash_15','sprints',2,15,60),('flash_30','sprints',3,30,125),('flash_60','sprints',4,60,250),
 ('technician_300','technique_minutes',1,300,25),('technician_900','technique_minutes',2,900,60),('technician_1800','technique_minutes',3,1800,125),('technician_3600','technique_minutes',4,3600,250),
 ('fighter_5','sparring',1,5,25),('fighter_15','sparring',2,15,60),('fighter_30','sparring',3,30,125),('fighter_60','sparring',4,60,250),
 ('engine_10','strength',1,10,25),('engine_25','strength',2,25,60),('engine_50','strength',3,50,125),('engine_100','strength',4,100,250),
 ('complete_1','complete',1,1,25),('complete_3','complete',2,3,60),('complete_7','complete',3,7,125),('complete_15','complete',4,15,250)
)
INSERT INTO public.achievement_v2_rules(achievement_id,metric,tier,threshold,reward_exp)
SELECT d.id,r.metric,r.tier,r.threshold,r.reward_exp FROM rules r
JOIN public.achievement_definitions d ON d.code=r.code
ON CONFLICT(achievement_id) DO UPDATE SET metric=EXCLUDED.metric,tier=EXCLUDED.tier,threshold=EXCLUDED.threshold,reward_exp=EXCLUDED.reward_exp;

DO $$ BEGIN
 IF (SELECT count(*) FROM public.achievement_v2_rules)<>32 THEN
  RAISE EXCEPTION 'Achievement V2 expects 32 rules';
 END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.achievement_exp_events (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 boxer_id uuid NOT NULL REFERENCES public.profiles(id),
 achievement_id uuid NOT NULL REFERENCES public.achievement_definitions(id),
 transaction_id uuid REFERENCES public.point_transactions(id),
 event_type text NOT NULL CHECK(event_type IN ('earned','revoked','reearned')),
 old_exp integer NOT NULL,
 new_exp integer NOT NULL,
 exp_delta integer NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),
 CHECK(new_exp-old_exp=exp_delta)
);
ALTER TABLE public.achievement_exp_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.achievement_exp_events FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.recalculate_boxer_achievements_v2(p_boxer_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $fn$
DECLARE
 v_enabled boolean;
 v_s record;
 v_r record;
 v_progress numeric;
 v_should boolean;
 v_tx uuid;
 v_was boolean;
 v_old_exp integer;
 v_new_exp integer;
BEGIN
 SELECT is_enabled INTO v_enabled FROM public.league_feature_flags WHERE feature_key='achievements';
 IF v_enabled IS DISTINCT FROM true THEN RETURN; END IF;
 PERFORM 1 FROM public.profiles WHERE id=p_boxer_id AND role='boxer' AND is_active=true FOR UPDATE;
 IF NOT FOUND THEN RETURN; END IF;

 SELECT count(s.id)::numeric AS sessions,
        count(DISTINCT s.training_date)::numeric AS days,
        coalesce(sum(s.jogging_km) FILTER(WHERE tt.name='Joggen'),0)::numeric AS jogging_km,
        coalesce(sum(s.technique_minutes) FILTER(WHERE tt.name='Techniktraining'),0)::numeric AS technique_minutes,
        count(s.id) FILTER(WHERE tt.name='Sprint-Intervalle')::numeric AS sprints,
        count(s.id) FILTER(WHERE tt.name='Sparring')::numeric AS sparring,
        count(s.id) FILTER(WHERE tt.name='Krafttraining')::numeric AS strength,
        least(count(s.id) FILTER(WHERE tt.name='Reguläres Boxtraining'),
              count(s.id) FILTER(WHERE tt.name='Sparring'),
              count(s.id) FILTER(WHERE tt.name='Techniktraining'),
              count(s.id) FILTER(WHERE tt.name='Krafttraining'),
              count(s.id) FILTER(WHERE tt.name='Sprint-Intervalle'),
              count(s.id) FILTER(WHERE tt.name='Joggen'))::numeric AS complete
 INTO v_s
 FROM public.training_submissions s
 LEFT JOIN public.training_types tt ON tt.id=s.training_type_id
 WHERE s.boxer_id=p_boxer_id AND s.status='approved';

 FOR v_r IN
   SELECT r.achievement_id,r.metric,r.threshold,r.reward_exp
   FROM public.achievement_v2_rules r
   JOIN public.achievement_definitions d ON d.id=r.achievement_id
   WHERE d.is_active=true ORDER BY r.achievement_id
 LOOP
  v_progress:=CASE v_r.metric
   WHEN 'sessions' THEN v_s.sessions WHEN 'days' THEN v_s.days
   WHEN 'jogging_km' THEN v_s.jogging_km WHEN 'technique_minutes' THEN v_s.technique_minutes
   WHEN 'sprints' THEN v_s.sprints WHEN 'sparring' THEN v_s.sparring
   WHEN 'strength' THEN v_s.strength WHEN 'complete' THEN v_s.complete END;
  v_should:=v_progress>=v_r.threshold;
  INSERT INTO public.achievement_exp_ledger(boxer_id,achievement_id,exp_amount,is_earned)
  VALUES(p_boxer_id,v_r.achievement_id,v_r.reward_exp,false)
  ON CONFLICT(boxer_id,achievement_id) DO NOTHING;
  SELECT transaction_id,is_earned INTO v_tx,v_was
  FROM public.achievement_exp_ledger
  WHERE boxer_id=p_boxer_id AND achievement_id=v_r.achievement_id FOR UPDATE;
  IF v_was IS DISTINCT FROM v_should THEN
   v_old_exp:=CASE WHEN v_was THEN v_r.reward_exp ELSE 0 END;
   v_new_exp:=CASE WHEN v_should THEN v_r.reward_exp ELSE 0 END;
   IF v_tx IS NULL THEN
    IF NOT v_should THEN RAISE EXCEPTION 'Unexpected unearned ledger transition'; END IF;
    INSERT INTO public.point_transactions(boxer_id,submission_id,points,exp,category,description,effective_date)
    VALUES(p_boxer_id,NULL,0,v_new_exp,'achievement_exp','Achievement V2',current_date)
    RETURNING id INTO v_tx;
   ELSE
    UPDATE public.point_transactions SET exp=v_new_exp,points=0
    WHERE id=v_tx AND boxer_id=p_boxer_id AND category='achievement_exp';
    IF NOT FOUND THEN RAISE EXCEPTION 'Achievement transaction integrity failure'; END IF;
   END IF;
   INSERT INTO public.achievement_exp_events
    (boxer_id,achievement_id,transaction_id,event_type,old_exp,new_exp,exp_delta)
   VALUES(p_boxer_id,v_r.achievement_id,v_tx,
     CASE WHEN v_should AND v_old_exp=0 AND EXISTS(
       SELECT 1 FROM public.achievement_exp_events e
       WHERE e.boxer_id=p_boxer_id AND e.achievement_id=v_r.achievement_id)
      THEN 'reearned' WHEN v_should THEN 'earned' ELSE 'revoked' END,
     v_old_exp,v_new_exp,v_new_exp-v_old_exp);
  END IF;
  UPDATE public.achievement_exp_ledger
   SET transaction_id=v_tx,is_earned=v_should,exp_amount=v_r.reward_exp,last_reconciled_at=now()
   WHERE boxer_id=p_boxer_id AND achievement_id=v_r.achievement_id;
  IF v_should THEN
   INSERT INTO public.boxer_achievements(boxer_id,achievement_id,source_key,metadata)
   VALUES(p_boxer_id,v_r.achievement_id,'achievement_v2',
    jsonb_build_object('reward_exp',v_r.reward_exp,'threshold',v_r.threshold))
   ON CONFLICT(boxer_id,achievement_id) DO NOTHING;
  ELSE
   DELETE FROM public.boxer_achievements
   WHERE boxer_id=p_boxer_id AND achievement_id=v_r.achievement_id;
  END IF;
 END LOOP;
END
$fn$;

-- Must be revoked in same transaction as function creation.
REVOKE ALL ON FUNCTION public.recalculate_boxer_achievements_v2(uuid) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public._award_achievements_on_approval()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $fn$
BEGIN
 IF TG_OP='UPDATE' AND OLD.boxer_id IS DISTINCT FROM NEW.boxer_id THEN
  -- TODO: boxer transfers can deadlock when two admins swap boxers concurrently.
  PERFORM public.recalculate_boxer_achievements_v2(OLD.boxer_id);
 END IF;
 PERFORM public.recalculate_boxer_achievements_v2(NEW.boxer_id);
 RETURN NEW;
END
$fn$;
REVOKE ALL ON FUNCTION public._award_achievements_on_approval() FROM PUBLIC,anon,authenticated;

DROP TRIGGER IF EXISTS trg_auto_achievements_approved ON public.training_submissions;
CREATE TRIGGER trg_auto_achievements_approved
AFTER INSERT OR UPDATE OF status,boxer_id,training_type_id,training_date,jogging_km,technique_minutes
ON public.training_submissions FOR EACH ROW
EXECUTE FUNCTION public._award_achievements_on_approval();

COMMIT;

-- BLOCKERS BEFORE LIVE RELEASE:
-- A. Function owner, trigger privileges, and SECURITY DEFINER execution must be tested.
-- B. Concurrent transfer deadlock avoidance and test fixtures are outstanding.
-- C. Event audit records transitions, but the point_transactions EXP value remains mutable;
--    decide if immutable compensating entries are required.
-- D. The feature flag must stay FALSE; backfill requires separate explicit approval.
-- E. Check all 32 rule definitions and code/name mappings against live schema.
