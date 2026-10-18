-- Security hardening: restrict achievement recalculation to trusted database code.
-- Prepared only; NOT executed in production.
-- Internal postgres-owned approval trigger retains owner execute rights.
BEGIN;
REVOKE EXECUTE ON FUNCTION public.recalculate_boxer_achievements_v2(uuid)
FROM PUBLIC, anon, authenticated;
COMMIT;
-- Verify after deployment that training approval trigger still awards achievements
-- and that direct anonymous/authenticated RPC invocations are denied.
