-- Takeover League 2.0: read-only payout integrity audit.
-- ONLY for an isolated test database after migrations 007-010 are installed.
-- No writes, no mutation, no production rollout implied.
BEGIN READ ONLY;

-- Every paid duel must have exactly two payout ledger rows.
SELECT d.id AS duel_id,d.status,count(l.id) AS ledger_rows
FROM public.league_duels d
LEFT JOIN public.league_duel_exp_ledger l ON l.duel_id=d.id
WHERE d.status='settled'
GROUP BY d.id,d.status
HAVING count(l.id)<>2;

-- Every payout ledger row must have a correctly linked duel_exp transaction.
SELECT l.duel_id,l.boxer_id,l.transaction_id,l.awarded_exp,
       t.boxer_id AS transaction_boxer_id,t.category,t.points,t.exp
FROM public.league_duel_exp_ledger l
LEFT JOIN public.point_transactions t ON t.id=l.transaction_id
WHERE l.transaction_id IS NULL
   OR t.id IS NULL
   OR t.boxer_id IS DISTINCT FROM l.boxer_id
   OR t.category IS DISTINCT FROM 'duel_exp'
   OR t.points IS DISTINCT FROM 0
   OR t.exp IS DISTINCT FROM l.awarded_exp
   OR l.boxer_id NOT IN (
      SELECT d.challenger_id FROM public.league_duels d WHERE d.id=l.duel_id
      UNION ALL
      SELECT d.opponent_id FROM public.league_duels d WHERE d.id=l.duel_id
   );

-- Payouts must match winner/draw policy, independent of leaderboard points.
SELECT d.id AS duel_id,l.boxer_id,l.awarded_exp,
       CASE WHEN d.challenger_score=d.opponent_score THEN 50
            WHEN l.boxer_id=d.winner_id THEN 100 ELSE 25 END AS expected_exp
FROM public.league_duels d
JOIN public.league_duel_exp_ledger l ON l.duel_id=d.id
WHERE d.status='settled'
  AND l.awarded_exp IS DISTINCT FROM
    (CASE WHEN d.challenger_score=d.opponent_score THEN 50
          WHEN l.boxer_id=d.winner_id THEN 100 ELSE 25 END);

-- No duel_exp transaction may exist without a ledger reference.
SELECT t.id,t.boxer_id,t.exp
FROM public.point_transactions t
LEFT JOIN public.league_duel_exp_ledger l ON l.transaction_id=t.id
WHERE t.category='duel_exp' AND l.id IS NULL;

ROLLBACK;
-- Each query must return ZERO rows. Nonzero rows block release.
