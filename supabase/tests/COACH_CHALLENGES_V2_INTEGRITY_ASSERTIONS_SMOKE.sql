-- Disposable PostgreSQL only: assert challenge integrity invariants.
-- This test raises on unexpected rows; the read-only audit is informational.
BEGIN;
DO $assert$
BEGIN
 IF EXISTS (
  SELECT 1 FROM public.league_coach_challenges
  WHERE status IN ('active','awaiting_reviews','settled')
    AND (starts_at IS NULL OR ends_at IS NULL
      OR ends_at<>starts_at+(duration_days*interval '1 day'))
 ) THEN RAISE EXCEPTION 'Invalid active challenge time window'; END IF;
 IF EXISTS (
  SELECT 1 FROM public.league_coach_challenge_entries e
  LEFT JOIN public.profiles p ON p.id=e.boxer_id
  WHERE p.id IS NULL OR p.role<>'boxer'
 ) THEN RAISE EXCEPTION 'Non-boxer challenge participant'; END IF;
 IF EXISTS (
  SELECT 1 FROM public.league_coach_challenge_entries
  WHERE status='joined' GROUP BY challenge_id,boxer_id HAVING count(*)>1
 ) THEN RAISE EXCEPTION 'Duplicate joined challenge participant'; END IF;
 IF EXISTS (
  SELECT 1 FROM public.league_coach_challenge_exp_ledger l
  LEFT JOIN public.league_coach_challenge_entries e
   ON e.challenge_id=l.challenge_id AND e.boxer_id=l.boxer_id
  WHERE e.id IS NULL OR e.status='withdrawn'
 ) THEN RAISE EXCEPTION 'Unenrolled boxer has challenge EXP ledger'; END IF;
 IF EXISTS (
  SELECT 1 FROM public.league_coach_challenge_exp_ledger l
  LEFT JOIN public.point_transactions t ON t.id=l.transaction_id
  WHERE l.transaction_id IS NOT NULL
   AND (t.id IS NULL OR t.boxer_id IS DISTINCT FROM l.boxer_id
    OR t.exp IS DISTINCT FROM l.awarded_exp OR t.points IS DISTINCT FROM 0)
 ) THEN RAISE EXCEPTION 'Challenge EXP ledger transaction mismatch'; END IF;
 IF EXISTS (
  SELECT 1 FROM public.league_coach_challenges
  WHERE status IN ('active','awaiting_reviews','settled')
    AND goal_spec IS NULL
 ) THEN RAISE EXCEPTION 'Challenge active without approved goal definition'; END IF;
END $assert$;
ROLLBACK;
