-- Takeover League 2.0: duel foundation, DRAFT ONLY, NOT FOR LIVE EXECUTION.
-- Depends on public.profiles and public.point_transactions.
-- Acceptance, settlement and correction RPCs are NOT implemented by this schema.
BEGIN;

-- Feature is opt-in. The application must not expose unfinished RPCs.
INSERT INTO public.league_feature_flags(feature_key,is_enabled)
VALUES('duels',false)
ON CONFLICT(feature_key) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.league_duels (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 challenger_id uuid NOT NULL REFERENCES public.profiles(id),
 opponent_id uuid NOT NULL REFERENCES public.profiles(id),
 created_by uuid REFERENCES public.profiles(id),
 initiated_by_coach boolean NOT NULL DEFAULT false,
 status text NOT NULL DEFAULT 'pending'
   CHECK (status IN ('pending','active','awaiting_reviews','settled','declined','expired','cancelled')),
 duration_days integer NOT NULL CHECK (duration_days IN (7,14)),
 invited_at timestamptz NOT NULL DEFAULT now(),
 expires_at timestamptz NOT NULL DEFAULT (now()+interval '48 hours'),
 accepted_at timestamptz,
 ends_at timestamptz,
 settled_at timestamptz,
 challenger_score integer NOT NULL DEFAULT 0 CHECK(challenger_score>=0),
 opponent_score integer NOT NULL DEFAULT 0 CHECK(opponent_score>=0),
 winner_id uuid REFERENCES public.profiles(id),
 updated_at timestamptz NOT NULL DEFAULT now(),
 CHECK (challenger_id<>opponent_id),
 CHECK (expires_at>invited_at),
 CHECK (status<>'active' OR (accepted_at IS NOT NULL AND ends_at IS NOT NULL)),
 CHECK (ends_at IS NULL OR (accepted_at IS NOT NULL AND ends_at=accepted_at+(duration_days * interval '1 day'))),
 CHECK (winner_id IS NULL OR winner_id IN (challenger_id,opponent_id))
);

-- One pending invitation and one active duel per unordered boxer pair.
-- awaiting_reviews remains occupied for payout reconciliation, but its
-- period has ended; immediate rematches after the end require careful RPC checks.
CREATE UNIQUE INDEX IF NOT EXISTS league_duels_one_pending_per_pair
ON public.league_duels(least(challenger_id,opponent_id),greatest(challenger_id,opponent_id))
WHERE status='pending';

CREATE UNIQUE INDEX IF NOT EXISTS league_duels_one_active_per_pair
ON public.league_duels(least(challenger_id,opponent_id),greatest(challenger_id,opponent_id))
WHERE status='active';

-- Active rematches after an earlier period ends require closing the prior
-- active status first; settlement may remain awaiting review separately.

CREATE INDEX IF NOT EXISTS league_duels_challenger_status_idx
ON public.league_duels(challenger_id,status,ends_at);
CREATE INDEX IF NOT EXISTS league_duels_opponent_status_idx
ON public.league_duels(opponent_id,status,ends_at);

-- Immutable event history and mutable current payout ledger: one per boxer/duel.
CREATE TABLE IF NOT EXISTS public.league_duel_exp_ledger (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 duel_id uuid NOT NULL REFERENCES public.league_duels(id),
 boxer_id uuid NOT NULL REFERENCES public.profiles(id),
 transaction_id uuid UNIQUE REFERENCES public.point_transactions(id),
 awarded_exp integer NOT NULL DEFAULT 0 CHECK(awarded_exp IN (0,25,50,100)),
 updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(duel_id,boxer_id)
);

CREATE TABLE IF NOT EXISTS public.league_duel_events (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 duel_id uuid NOT NULL REFERENCES public.league_duels(id),
 boxer_id uuid REFERENCES public.profiles(id),
 event_type text NOT NULL CHECK(event_type IN
   ('invited','accepted','declined','expired','awaiting_reviews','settled','corrected','cancelled')),
 payload jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.league_duels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.league_duel_exp_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.league_duel_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.league_duels FROM PUBLIC,anon,authenticated;
REVOKE ALL ON public.league_duel_exp_ledger FROM PUBLIC,anon,authenticated;
REVOKE ALL ON public.league_duel_events FROM PUBLIC,anon,authenticated;

-- IMPORTANT: No RPCs or grants are included. Keep feature unavailable.
-- Before implementing settlement: inspect training point transaction semantics,
-- late submissions, date boundaries, profile roles and monthly leaderboard RPCs.
COMMIT;
