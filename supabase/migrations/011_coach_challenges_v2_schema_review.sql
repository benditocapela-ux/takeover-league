-- Takeover League 2.0 — coach challenge storage foundation.
-- REVIEW ONLY. Do not execute on live Supabase without explicit owner approval.
-- No challenge evaluation, payout or boxer enrollment RPCs are provided here.
BEGIN;

INSERT INTO public.league_feature_flags(feature_key,display_name,is_enabled)
VALUES('coach_challenges','Coach Challenges V2',false)
ON CONFLICT(feature_key) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.league_coach_challenges (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 created_by uuid NOT NULL REFERENCES public.profiles(id),
 title text NOT NULL CHECK (char_length(btrim(title)) BETWEEN 3 AND 120),
 description text NOT NULL DEFAULT '',
 challenge_kind text NOT NULL CHECK (challenge_kind IN ('individual','competition','coach_goal')),
 duration_days integer NOT NULL CHECK (duration_days IN (7,14,30)),
 -- Target definition and metric semantics require explicit owner approval.
 goal_spec jsonb,
 status text NOT NULL DEFAULT 'draft'
   CHECK (status IN ('draft','open','active','awaiting_reviews','settled','cancelled')),
 created_at timestamptz NOT NULL DEFAULT now(),
 starts_at timestamptz,
 ends_at timestamptz,
 settled_at timestamptz,
 updated_at timestamptz NOT NULL DEFAULT now(),
 CHECK (ends_at IS NULL OR
        (starts_at IS NOT NULL AND ends_at=starts_at+(duration_days * interval '1 day'))),
 CHECK (status NOT IN ('active','awaiting_reviews','settled')
        OR (starts_at IS NOT NULL AND ends_at IS NOT NULL))
);

CREATE TABLE IF NOT EXISTS public.league_coach_challenge_entries (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 challenge_id uuid NOT NULL REFERENCES public.league_coach_challenges(id),
 boxer_id uuid NOT NULL REFERENCES public.profiles(id),
 joined_at timestamptz NOT NULL DEFAULT now(),
 status text NOT NULL DEFAULT 'joined'
   CHECK (status IN ('joined','withdrawn','completed')),
 UNIQUE(challenge_id,boxer_id)
);

-- Ledger records intended EXP per participant; no reward is paid by this
-- migration. A future payout RPC must validate eligibility, ranking and
-- transaction ownership before inserting or updating an award.
CREATE TABLE IF NOT EXISTS public.league_coach_challenge_exp_ledger (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 challenge_id uuid NOT NULL REFERENCES public.league_coach_challenges(id),
 boxer_id uuid NOT NULL REFERENCES public.profiles(id),
 transaction_id uuid UNIQUE REFERENCES public.point_transactions(id),
 awarded_exp integer NOT NULL DEFAULT 0
   CHECK (awarded_exp IN (0,25,50,100,150,200)),
 updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(challenge_id,boxer_id)
);

CREATE INDEX IF NOT EXISTS league_coach_challenges_status_idx
 ON public.league_coach_challenges(status,ends_at);
CREATE INDEX IF NOT EXISTS league_coach_challenge_entries_boxer_idx
 ON public.league_coach_challenge_entries(boxer_id,challenge_id);

ALTER TABLE public.league_coach_challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.league_coach_challenge_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.league_coach_challenge_exp_ledger ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.league_coach_challenges FROM PUBLIC,anon,authenticated;
REVOKE ALL ON public.league_coach_challenge_entries FROM PUBLIC,anon,authenticated;
REVOKE ALL ON public.league_coach_challenge_exp_ledger FROM PUBLIC,anon,authenticated;

-- No RPCs, enrollment permissions, payouts or feature activation in this draft.
COMMIT;
