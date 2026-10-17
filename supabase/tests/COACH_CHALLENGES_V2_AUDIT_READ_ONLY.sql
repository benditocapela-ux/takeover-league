-- Coach Challenges V2: isolated-only read-only release audit.
-- REVIEW ONLY. Do not execute on live Supabase without owner approval.
-- First five queries must return zero rows; final query is diagnostic.
BEGIN READ ONLY;

-- No challenge should be active/settled without a complete time window.
SELECT id,status,starts_at,ends_at,duration_days
FROM public.league_coach_challenges
WHERE status IN ('active','awaiting_reviews','settled')
  AND (starts_at IS NULL OR ends_at IS NULL
       OR ends_at<>starts_at+(duration_days*interval '1 day'));

-- All joined/completed participants must be actual boxer profiles.
SELECT e.id,e.challenge_id,e.boxer_id,p.role,p.is_active
FROM public.league_coach_challenge_entries e
LEFT JOIN public.profiles p ON p.id=e.boxer_id
WHERE p.id IS NULL OR p.role<>'boxer';

-- No duplicate active participant per challenge (defense in depth).
SELECT challenge_id,boxer_id,count(*) AS duplicate_count
FROM public.league_coach_challenge_entries
WHERE status='joined'
GROUP BY challenge_id,boxer_id HAVING count(*)>1;

-- No EXP ledger row may refer to an unregistered or withdrawn participant.
SELECT l.id,l.challenge_id,l.boxer_id,l.awarded_exp
FROM public.league_coach_challenge_exp_ledger l
LEFT JOIN public.league_coach_challenge_entries e
 ON e.challenge_id=l.challenge_id AND e.boxer_id=l.boxer_id
WHERE e.id IS NULL OR e.status='withdrawn';

-- No ledger transaction may point to a different boxer or EXP amount.
SELECT l.id,l.transaction_id,l.boxer_id,l.awarded_exp,
       t.boxer_id AS transaction_boxer_id,t.exp AS transaction_exp,t.points
FROM public.league_coach_challenge_exp_ledger l
LEFT JOIN public.point_transactions t ON t.id=l.transaction_id
WHERE l.transaction_id IS NOT NULL
 AND (t.id IS NULL OR t.boxer_id IS DISTINCT FROM l.boxer_id
      OR t.exp IS DISTINCT FROM l.awarded_exp OR t.points IS DISTINCT FROM 0);

-- Informational: goal definitions and opt-in counts before activation.
SELECT c.id,c.status,c.challenge_kind,c.duration_days,
       c.goal_spec IS NOT NULL AS has_goal_definition,
       count(e.id) FILTER(WHERE e.status='joined') AS joined_count
FROM public.league_coach_challenges c
LEFT JOIN public.league_coach_challenge_entries e ON e.challenge_id=c.id
GROUP BY c.id ORDER BY c.created_at DESC;

ROLLBACK;
