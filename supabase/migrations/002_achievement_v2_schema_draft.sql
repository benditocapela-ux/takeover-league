-- Takeover League 2.0: achievement definitions, ledger and EXP transaction category.
-- STAGING ONLY. Do not run in production before review and follow-up engine migration.
-- Feature flag 'achievements' MUST remain disabled.
BEGIN;

-- Retain existing training_* IDs and award history; deactivate legacy variety rules.
UPDATE public.achievement_definitions SET is_active=false WHERE code IN ('variety_3','variety_5');

-- Add distinct category; this migration does not issue any EXP.
ALTER TABLE public.point_transactions
  DROP CONSTRAINT point_transactions_category_check;
ALTER TABLE public.point_transactions
  ADD CONSTRAINT point_transactions_category_check
  CHECK (category = ANY (ARRAY['training','trainer_bonus','adjustment','legacy_import','automatic_bonus','achievement_exp']::text[]));

-- Dedicated ledger ensures exactly one transaction per boxer and achievement.
-- An award can be reversed by a later reconciliation; the ledger remains auditable.
CREATE TABLE IF NOT EXISTS public.achievement_exp_ledger (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  boxer_id uuid NOT NULL REFERENCES public.profiles(id),
  achievement_id uuid NOT NULL REFERENCES public.achievement_definitions(id),
  transaction_id uuid UNIQUE REFERENCES public.point_transactions(id),
  exp_amount integer NOT NULL CHECK (exp_amount IN (25,60,125,250)),
  is_earned boolean NOT NULL DEFAULT false,
  last_reconciled_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(boxer_id,achievement_id)
);
ALTER TABLE public.achievement_exp_ledger ENABLE ROW LEVEL SECURITY;
-- No client access policies; SECURITY DEFINER engine will own ledger writes.
REVOKE ALL ON public.achievement_exp_ledger FROM anon, authenticated;

-- Use deterministic codes; upsert without changing IDs of existing definitions.
WITH tiered(family,title,category,thresholds) AS (
 VALUES
 ('training','Training Warrior','training',ARRAY[10,25,50,100]),
 ('consistent','Mr Consistent','consistency',ARRAY[10,25,60,120]),
 ('road','Road King','running',ARRAY[25,75,150,300]),
 ('flash','The Flash','sprints',ARRAY[5,15,30,60]),
 ('technician','The Technician','technique',ARRAY[300,900,1800,3600]),
 ('fighter','Iron Fighter','sparring',ARRAY[5,15,30,60]),
 ('engine','Iron Engine','strength',ARRAY[10,25,50,100]),
 ('complete','Complete Boxer','variety',ARRAY[1,3,7,15])
), defs AS (
 SELECT CASE WHEN family='training' THEN 'training_'||thresholds[ordinality]::text
             ELSE family||'_'||thresholds[ordinality]::text END AS code,
        title||' – '||(ARRAY['Bronze','Silber','Gold','Platin'])[ordinality] AS title,
        category,
        family||': '||thresholds[ordinality]::text AS description
 FROM tiered CROSS JOIN LATERAL unnest(thresholds) WITH ORDINALITY AS u(threshold,ordinality)
)
INSERT INTO public.achievement_definitions(code,title,description,category,is_active)
SELECT code,title,description,category,true FROM defs
ON CONFLICT(code) DO UPDATE SET title=EXCLUDED.title,description=EXCLUDED.description,
 category=EXCLUDED.category,is_active=true;

COMMIT;
