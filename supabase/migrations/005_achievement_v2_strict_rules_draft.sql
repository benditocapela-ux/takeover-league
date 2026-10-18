-- Achievement V2: fixed rules and privilege hardening (REVIEW DRAFT).
-- DO NOT RUN IN LIVE SUPABASE. This is a component of the final combined migration.
-- 002 has already been applied in production; 003/004 have NOT.
BEGIN;

CREATE TABLE IF NOT EXISTS public.achievement_v2_rules (
  achievement_id uuid PRIMARY KEY REFERENCES public.achievement_definitions(id),
  metric text NOT NULL CHECK (metric IN
    ('sessions','days','jogging_km','sprints','technique_minutes',
     'sparring','strength','complete')),
  threshold numeric NOT NULL CHECK (threshold>0),
  tier integer NOT NULL CHECK (tier BETWEEN 1 AND 4),
  reward_exp integer NOT NULL CHECK (
    (tier=1 AND reward_exp=25) OR (tier=2 AND reward_exp=60)
    OR (tier=3 AND reward_exp=125) OR (tier=4 AND reward_exp=250)),
  UNIQUE(metric,tier)
);
ALTER TABLE public.achievement_v2_rules ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.achievement_v2_rules FROM PUBLIC, anon, authenticated;

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
SELECT d.id,r.metric,r.tier,r.threshold,r.reward_exp
FROM rules r JOIN public.achievement_definitions d ON d.code=r.code
ON CONFLICT(achievement_id) DO UPDATE
 SET metric=EXCLUDED.metric,tier=EXCLUDED.tier,
     threshold=EXCLUDED.threshold,reward_exp=EXCLUDED.reward_exp;

-- Fail closed if any of the 32 expected rules are missing.
DO $$
BEGIN
 IF (SELECT count(*) FROM public.achievement_v2_rules)<>32 THEN
  RAISE EXCEPTION 'Expected exactly 32 achievement rules';
 END IF;
END $$;

COMMIT;

-- Still required before activation:
-- (1) integrate engine with rules table; (2) atomic audit events on each
-- transition; (3) revoke SECURITY DEFINER function execution from PUBLIC in
-- the SAME transaction as its creation; (4) deterministic locking for boxer
-- transfers; (5) test backfill and correction cases; (6) obtain live approval.
