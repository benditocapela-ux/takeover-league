-- Coach Challenges V2 schema. PREPARED ONLY; do not apply to production yet.
BEGIN;
CREATE TABLE public.league_coach_challenges (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 created_by uuid NOT NULL REFERENCES public.profiles(id),
 title text NOT NULL CHECK (char_length(btrim(title)) BETWEEN 3 AND 120),
 description text NOT NULL DEFAULT '',
 challenge_kind text NOT NULL CHECK (challenge_kind IN ('individual','competition','coach_goal')),
 duration_days integer NOT NULL CHECK (duration_days IN (7,14,30)),
 goal_spec jsonb,
 status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','open','active','awaiting_reviews','settled','cancelled')),
 created_at timestamptz NOT NULL DEFAULT now(),
 starts_at timestamptz,
 ends_at timestamptz,
 settled_at timestamptz,
 updated_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT coach_challenge_dates_valid CHECK (starts_at IS NULL OR ends_at IS NULL OR ends_at > starts_at),
 CONSTRAINT coach_challenge_settlement_dates_valid CHECK (settled_at IS NULL OR ends_at IS NOT NULL)
);
CREATE TABLE public.league_coach_challenge_entries (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 challenge_id uuid NOT NULL REFERENCES public.league_coach_challenges(id),
 boxer_id uuid NOT NULL REFERENCES public.profiles(id),
 joined_at timestamptz NOT NULL DEFAULT now(),
 status text NOT NULL DEFAULT 'joined' CHECK (status IN ('joined','withdrawn','completed')),
 UNIQUE(challenge_id,boxer_id)
);
CREATE TABLE public.league_coach_challenge_reviews (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 challenge_id uuid NOT NULL REFERENCES public.league_coach_challenges(id),
 boxer_id uuid NOT NULL REFERENCES public.profiles(id),
 reviewed_by uuid NOT NULL REFERENCES public.profiles(id),
 approved boolean NOT NULL,
 reason text NOT NULL CHECK (char_length(btrim(reason)) BETWEEN 5 AND 1000),
 reviewed_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(challenge_id,boxer_id)
);
CREATE TABLE public.league_coach_challenge_exp_ledger (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 challenge_id uuid NOT NULL REFERENCES public.league_coach_challenges(id),
 boxer_id uuid NOT NULL REFERENCES public.profiles(id),
 transaction_id uuid UNIQUE REFERENCES public.point_transactions(id),
 awarded_exp integer NOT NULL DEFAULT 0 CHECK (awarded_exp IN (0,25,50,100,150,200)),
 updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(challenge_id,boxer_id)
);
CREATE INDEX league_coach_challenges_creator_status_idx ON public.league_coach_challenges(created_by,status);
CREATE INDEX league_coach_challenges_status_dates_idx ON public.league_coach_challenges(status,ends_at);
CREATE INDEX league_coach_challenge_entries_boxer_idx ON public.league_coach_challenge_entries(boxer_id,status);
CREATE INDEX league_coach_challenge_reviews_reviewer_idx ON public.league_coach_challenge_reviews(reviewed_by);
CREATE INDEX league_coach_challenge_exp_ledger_boxer_idx ON public.league_coach_challenge_exp_ledger(boxer_id);
-- RLS blocks ordinary roles; table owners and BYPASSRLS roles are exempt unless FORCE RLS is enabled.
ALTER TABLE public.league_coach_challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.league_coach_challenge_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.league_coach_challenge_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.league_coach_challenge_exp_ledger ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.league_coach_challenges,public.league_coach_challenge_entries,
 public.league_coach_challenge_reviews,public.league_coach_challenge_exp_ledger FROM PUBLIC,anon,authenticated;
COMMIT;
-- No policies: access is through audited SECURITY DEFINER RPCs only.
