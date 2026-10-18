-- Takeover League 2.0: read-only EXP/level migration preview.
-- Execute in Supabase SQL Editor. No data is modified.
-- Formula: cumulative EXP to reach level L = 100*(L-1)+25*(L-1)*(L-2)/2.
-- Uses numeric arithmetic to avoid integer overflow for ordinary league totals.
WITH totals AS (
  SELECT p.id AS boxer_id, p.display_name,
         GREATEST(0::numeric, COALESCE(SUM(t.exp),0)::numeric) AS lifetime_exp,
         GREATEST(0::numeric, COALESCE(SUM(t.points),0)::numeric) AS lifetime_points
  FROM public.profiles p
  LEFT JOIN public.point_transactions t ON t.boxer_id=p.id
  WHERE p.role='boxer'
  GROUP BY p.id,p.display_name
), level_estimate AS (
  SELECT *, GREATEST(0::numeric,
    FLOOR((SQRT(49::numeric + (8::numeric/25::numeric)*lifetime_exp)-7::numeric)/2::numeric)
  ) AS n
  FROM totals
), levels AS (
  SELECT *, (n+1)::numeric AS new_level,
         (100*n + 25*n*(n-1)/2)::numeric AS level_start_exp,
         (100*(n+1)+25*(n+1)*n/2)::numeric AS next_level_exp
  FROM level_estimate
)
SELECT boxer_id, display_name, lifetime_exp, lifetime_points,
       new_level, level_start_exp, next_level_exp,
       lifetime_exp-level_start_exp AS exp_into_level,
       next_level_exp-lifetime_exp AS exp_to_next_level
FROM levels
ORDER BY lifetime_exp DESC, display_name;
