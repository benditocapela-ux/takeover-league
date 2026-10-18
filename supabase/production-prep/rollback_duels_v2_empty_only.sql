-- Prepared rollback of the isolated duels V2 module only.
-- Only safe before any real duel rows or EXP payouts have been created.
BEGIN;
DO $guard$
BEGIN
 IF EXISTS(SELECT 1 FROM public.league_duels LIMIT 1)
 OR EXISTS(SELECT 1 FROM public.league_duel_events LIMIT 1)
 OR EXISTS(SELECT 1 FROM public.league_duel_exp_ledger LIMIT 1)
 THEN RAISE EXCEPTION 'Duel data exists: rollback is blocked'; END IF;
END $guard$;
DROP FUNCTION public.duel_v2_reconcile_due(boolean,uuid);
DROP FUNCTION public.duel_v2_reconcile(uuid);
DROP FUNCTION public.duel_v2_respond(uuid,boolean);
DROP FUNCTION public.duel_v2_list_mine();
DROP FUNCTION public.duel_v2_eligible_boxers();
DROP FUNCTION public.duel_v2_invite(uuid,uuid,integer);
DROP TABLE public.league_duel_exp_ledger;
DROP TABLE public.league_duel_events;
DROP TABLE public.league_duels;
-- Preserve legacy boxer_duels and all existing EXP, points and feature flags.
COMMIT;
