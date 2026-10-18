-- Takeover League 2.0: production transaction category compatibility
-- PREPARED ONLY. Do not run until the full V2 migration is reviewed.
-- This preserves existing rows and existing accepted categories.
BEGIN;
DO $$
DECLARE actual text; expected text;
BEGIN
 SELECT pg_get_constraintdef(c.oid) INTO actual FROM pg_constraint c
 WHERE c.conrelid='public.point_transactions'::regclass
 AND c.conname='point_transactions_category_check' AND c.contype='c';
 IF actual IS NULL THEN
  RAISE EXCEPTION 'Missing category constraint; abort migration';
 END IF;
 IF actual NOT LIKE '%achievement_exp%' OR actual NOT LIKE '%automatic_bonus%'
    OR actual NOT LIKE '%legacy_import%' THEN
  RAISE EXCEPTION 'Unexpected transaction category constraint: %',actual;
 END IF;
 IF EXISTS (SELECT 1 FROM public.point_transactions WHERE category NOT IN
 ('training','trainer_bonus','adjustment','legacy_import','automatic_bonus','achievement_exp','duel_exp','challenge_exp')) THEN
  RAISE EXCEPTION 'Unknown existing category; abort migration';
 END IF;
END $$;
ALTER TABLE public.point_transactions DROP CONSTRAINT point_transactions_category_check;
ALTER TABLE public.point_transactions ADD CONSTRAINT point_transactions_category_check
CHECK (category IN ('training','trainer_bonus','adjustment','legacy_import','automatic_bonus','achievement_exp','duel_exp','challenge_exp'));
COMMIT;
-- Verification: SELECT category,count(*) FROM public.point_transactions GROUP BY category;
