-- Takeover League 2.0 / READ ONLY integrity and level comparison
-- Run in Supabase SQL Editor. No UPDATE, INSERT, DELETE, DDL or RPC calls.
-- Result set 1: consistency checks (zero rows is ideal).
WITH problems AS (
  SELECT 'duplicate_training_transactions' AS check_name, submission_id::text AS reference,
         COUNT(*)::text AS details
  FROM public.point_transactions
  WHERE submission_id IS NOT NULL
  GROUP BY submission_id HAVING COUNT(*) > 1
  UNION ALL
  SELECT 'orphan_transaction_boxer', t.id::text, t.boxer_id::text
  FROM public.point_transactions t LEFT JOIN public.profiles p ON p.id=t.boxer_id
  WHERE p.id IS NULL
  UNION ALL
  SELECT 'orphan_submission_boxer', s.id::text, s.boxer_id::text
  FROM public.training_submissions s LEFT JOIN public.profiles p ON p.id=s.boxer_id
  WHERE p.id IS NULL
  UNION ALL
  SELECT 'orphan_training_transaction', t.id::text, t.submission_id::text
  FROM public.point_transactions t LEFT JOIN public.training_submissions s ON s.id=t.submission_id
  WHERE t.submission_id IS NOT NULL AND s.id IS NULL
  UNION ALL
  SELECT 'negative_transaction_value', t.id::text,
         'points='||t.points::text||', exp='||t.exp::text
  FROM public.point_transactions t WHERE t.points<0 OR t.exp<0
  UNION ALL
  SELECT 'approved_missing_training_transaction', s.id::text, s.boxer_id::text
  FROM public.training_submissions s
  WHERE s.status='approved' AND NOT EXISTS (
    SELECT 1 FROM public.point_transactions t
    WHERE t.submission_id=s.id AND t.category='training' AND t.points>0
  )
  UNION ALL
  SELECT 'nonapproved_positive_training_transaction', s.id::text, s.status
  FROM public.training_submissions s
  JOIN public.point_transactions t ON t.submission_id=s.id
  WHERE s.status<>'approved' AND t.category='training' AND (t.points>0 OR t.exp>0)
  UNION ALL
  SELECT 'approved_training_wrong_boxer', s.id::text, t.id::text
  FROM public.training_submissions s JOIN public.point_transactions t ON t.submission_id=s.id
  WHERE s.status='approved' AND t.category='training' AND t.boxer_id IS DISTINCT FROM s.boxer_id
  UNION ALL
  SELECT 'approved_training_wrong_date', s.id::text, t.id::text
  FROM public.training_submissions s JOIN public.point_transactions t ON t.submission_id=s.id
  WHERE s.status='approved' AND t.category='training' AND t.effective_date IS DISTINCT FROM s.training_date
)
SELECT * FROM problems ORDER BY check_name, reference;

-- Result set 2: overview of transactions and submission statuses.
SELECT 'training_submissions' AS source, COALESCE(status,'<null>') AS category,
       COUNT(*) AS records, NULL::numeric AS sum_points, NULL::numeric AS sum_exp
FROM public.training_submissions GROUP BY status
UNION ALL
SELECT 'point_transactions', COALESCE(category,'<null>'),
       COUNT(*), SUM(points)::numeric, SUM(exp)::numeric
FROM public.point_transactions GROUP BY category
ORDER BY source, category;

-- Result set 3: old 15% compounded vs new +25 EXP levels.
-- This models the observed get_boxer_exp_level_rank recurrence (start 100,
-- next step CEIL(previous * 1.15)), without requiring authenticated RPC.
WITH RECURSIVE old_levels(level_number,level_start_exp,step_exp) AS (
  SELECT 1,0::numeric,100::numeric
  UNION ALL
  SELECT level_number+1,level_start_exp+step_exp,CEIL(step_exp*1.15)
  FROM old_levels WHERE level_number<150
), totals AS (
  SELECT p.id,p.display_name,
         GREATEST(0::numeric,COALESCE(SUM(t.exp),0)::numeric) AS lifetime_exp
  FROM public.profiles p LEFT JOIN public.point_transactions t ON t.boxer_id=p.id
  WHERE p.role='boxer' GROUP BY p.id,p.display_name
), new_levels AS (
  SELECT *, FLOOR((SQRT(49::numeric+(8::numeric/25::numeric)*lifetime_exp)-7::numeric)/2::numeric) AS n
  FROM totals
)
SELECT n.display_name,n.lifetime_exp,
       (SELECT MAX(o.level_number) FROM old_levels o WHERE o.level_start_exp<=n.lifetime_exp) AS old_level,
       (n.n+1)::numeric AS new_level,
       (n.n+1)-(SELECT MAX(o.level_number) FROM old_levels o WHERE o.level_start_exp<=n.lifetime_exp) AS level_difference
FROM new_levels n ORDER BY n.lifetime_exp DESC,n.display_name;
