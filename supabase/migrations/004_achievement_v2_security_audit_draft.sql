-- Takeover League 2.0: security hardening and audit for draft 003.
-- REVIEW ONLY. Not approved for production. Requires 002 and 003.
-- This file is an incremental review patch, NOT a complete safe deployment.
BEGIN;

-- SECURITY DEFINER functions otherwise default to PUBLIC EXECUTE.
REVOKE ALL ON FUNCTION public.recalculate_boxer_achievements_v2(uuid)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._award_achievements_on_approval()
  FROM PUBLIC, anon, authenticated;

-- Explicit append-only log of eligibility changes, independent of mutable award state.
CREATE TABLE IF NOT EXISTS public.achievement_exp_events (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 boxer_id uuid NOT NULL REFERENCES public.profiles(id),
 achievement_id uuid NOT NULL REFERENCES public.achievement_definitions(id),
 transaction_id uuid REFERENCES public.point_transactions(id),
 event_type text NOT NULL CHECK (event_type IN ('earned','revoked','reearned')),
 exp_delta integer NOT NULL,
 old_exp integer NOT NULL,
 new_exp integer NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),
 CHECK (new_exp-old_exp=exp_delta),
 CHECK ((event_type IN ('earned','reearned') AND exp_delta>0)
     OR (event_type='revoked' AND exp_delta<0))
);
ALTER TABLE public.achievement_exp_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.achievement_exp_events FROM PUBLIC, anon, authenticated;

-- A UNIQUE constraint on ledger boxer+achievement and a UNIQUE transaction_id
-- already exist from migration 002. Events are history, not a replacement for
-- transactional idempotency.

COMMIT;

-- Remaining blockers before running:
-- 1) Refactor the engine to insert events atomically on actual transitions.
-- 2) Replace regex/default reward mapping with a strict 32-row rules table.
-- 3) Test transfer deadlocks and lock ordering.
-- 4) Confirm trigger privileges under actual Supabase owner role.
-- 5) Implement owner-reviewed, read-only backfill preview.
-- 6) Validate rollback and effects of points=0 EXP tie-breaks.
