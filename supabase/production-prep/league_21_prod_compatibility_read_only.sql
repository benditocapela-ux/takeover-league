-- Takeover League 2.1: production-specific READ-ONLY compatibility gate. No writes.
WITH b AS (
  SELECT
    (SELECT count(*)=0 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='public' AND c.relkind='r' AND c.relname LIKE '%_v21') AS clean_v21_install,
    (SELECT count(*)=2 FROM pg_attribute a
      WHERE (a.attrelid='public.point_transactions'::regclass AND a.attname='description'
       OR a.attrelid='public.training_submissions'::regclass AND a.attname='notes')
       AND a.attnotnull AND a.attnum>0 AND NOT a.attisdropped) AS production_nonnull_text,
    (SELECT count(*)=2 FROM pg_attribute a
      WHERE a.attrelid='public.training_submissions'::regclass
       AND ((a.attname='jogging_km' AND a.atttypid='numeric'::regtype)
         OR (a.attname='technique_minutes' AND a.atttypid='integer'::regtype))
       AND a.attnum>0 AND NOT a.attisdropped) AS quantitative_training_columns,
    (SELECT count(*)=2 FROM pg_trigger t
      WHERE t.tgrelid='public.training_submissions'::regclass AND NOT t.tgisinternal
        AND t.tgenabled='O' AND t.tgname IN ('trg_auto_achievements_approved','trg_notify_training_decision')) AS existing_training_triggers_active,
    (SELECT count(*)=1 FROM pg_constraint k WHERE k.conrelid='public.league_duel_exp_ledger'::regclass
       AND k.conname='league_duel_exp_ledger_awarded_exp_check' AND k.contype='c'
       AND pg_get_constraintdef(k.oid) LIKE '%100%') AS old_duel_exp_constraint_located,
    (SELECT count(*)=1 FROM pg_constraint k WHERE k.conrelid='public.point_transactions'::regclass
       AND k.contype='c' AND pg_get_constraintdef(k.oid) LIKE '%challenge_exp%'
       AND pg_get_constraintdef(k.oid) LIKE '%duel_exp%') AS point_transaction_categories_supported,
    (SELECT pg_get_function_result('public.duel_v2_reconcile(uuid)'::regprocedure)='text') AS duel_reconcile_signature_ok,
    (SELECT count(*)=0 FROM public.training_submissions s WHERE s.status='approved' AND
      NOT EXISTS (SELECT 1 FROM public.point_transactions t WHERE t.submission_id=s.id
                  AND t.boxer_id=s.boxer_id AND t.category IN ('training','legacy_import'))) AS approved_training_has_points,
    (SELECT count(*)=0 FROM public.point_transactions
      WHERE submission_id IS NOT NULL AND category IN ('training','legacy_import')
      GROUP BY submission_id HAVING count(*)<>1 LIMIT 1) AS no_duplicate_training_transactions,
    (SELECT count(*)=0 FROM public.league_duel_exp_ledger l
      LEFT JOIN public.point_transactions t ON t.id=l.transaction_id
      WHERE l.transaction_id IS NOT NULL
        AND (t.id IS NULL OR t.boxer_id<>l.boxer_id OR t.category<>'duel_exp' OR t.exp<>l.awarded_exp)) AS existing_duel_rewards_consistent,
    (SELECT count(*)=0 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='public' AND c.relkind='r'
      AND NOT c.relrowsecurity) AS public_tables_have_rls,
    (SELECT count(*)=0 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='public' AND c.relkind='v') AS no_unprotected_public_views
), verdict AS (
 SELECT to_jsonb(b) AS details,
 (SELECT bool_and(v) FROM jsonb_each_text(to_jsonb(b)) AS p(k,vtxt)
  CROSS JOIN LATERAL (SELECT vtxt::boolean AS v) x) AS passed FROM b
)
SELECT jsonb_build_object('league_21_prod_compatibility_passed',passed,'checks',details,
 'limits','Read-only structural gate; not equivalent to a fully restored production clone or authenticated test.') AS compatibility_report
FROM verdict;