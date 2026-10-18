-- Rollback preparation: V2 challenge tables only.
-- Never run if challenge records, reviews or EXP ledger rows exist.
BEGIN;
DO $$
BEGIN
 IF EXISTS(SELECT 1 FROM public.league_coach_challenges LIMIT 1)
 OR EXISTS(SELECT 1 FROM public.league_coach_challenge_entries LIMIT 1)
 OR EXISTS(SELECT 1 FROM public.league_coach_challenge_reviews LIMIT 1)
 OR EXISTS(SELECT 1 FROM public.league_coach_challenge_exp_ledger LIMIT 1) THEN
 RAISE EXCEPTION 'V2 challenge data exists: rollback blocked';
 END IF;
END $$;
DROP TABLE public.league_coach_challenge_exp_ledger;
DROP TABLE public.league_coach_challenge_reviews;
DROP TABLE public.league_coach_challenge_entries;
DROP TABLE public.league_coach_challenges;
COMMIT;
-- Feature flags and transaction category additions are intentionally retained.
-- SECURITY DEFINER RPCs must be dropped separately before using this rollback.
