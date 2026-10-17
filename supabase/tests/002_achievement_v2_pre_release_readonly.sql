-- Takeover League 2.0 / Achievement V2 pre-release tests
-- READ ONLY: run on live Supabase safely. Does not require 006 installed.
-- Expected: 32 definitions, 0 EXP transactions, flag false.
WITH expected(code) AS (
 VALUES
 ('training_10'),('training_25'),('training_50'),('training_100'),
 ('consistent_10'),('consistent_25'),('consistent_60'),('consistent_120'),
 ('road_25'),('road_75'),('road_150'),('road_300'),
 ('flash_5'),('flash_15'),('flash_30'),('flash_60'),
 ('technician_300'),('technician_900'),('technician_1800'),('technician_3600'),
 ('fighter_5'),('fighter_15'),('fighter_30'),('fighter_60'),
 ('engine_10'),('engine_25'),('engine_50'),('engine_100'),
 ('complete_1'),('complete_3'),('complete_7'),('complete_15')
)
SELECT 'expected_definition_missing_or_inactive' AS check_name,e.code AS detail
FROM expected e LEFT JOIN public.achievement_definitions d
 ON d.code=e.code AND d.is_active=true WHERE d.id IS NULL
UNION ALL
SELECT 'unexpected_active_definition',d.code
FROM public.achievement_definitions d LEFT JOIN expected e ON e.code=d.code
WHERE d.is_active=true AND e.code IS NULL
UNION ALL
SELECT 'unexpected_achievement_exp_transaction',t.id::text
FROM public.point_transactions t WHERE t.category='achievement_exp'
UNION ALL
SELECT 'unexpected_ledger_entry',l.id::text
FROM public.achievement_exp_ledger l
UNION ALL
SELECT 'feature_flag_enabled',f.feature_key
FROM public.league_feature_flags f
WHERE f.feature_key='achievements' AND f.is_enabled=true
ORDER BY check_name,detail;
-- PASS: 0 rows.
