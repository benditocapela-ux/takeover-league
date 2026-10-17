# Test schema bootstrap checklist

Test project: cfgdvcccsqwfjajuizsr. Production: iqarjivcrddcixrvqbfb (do not modify).

Migration 001 is installed in test. Migration 002 requires public.achievement_definitions, which is absent. Migration 003/006 also require public.boxer_achievements and public.league_feature_flags, both absent. Migration 007 and 011 require league_feature_flags. The test point_transactions category check must be reviewed before EXP category changes in 002, 009, and 027.

Reconstruct the three missing base tables using reviewed schema-only DDL and RLS, without importing production user data. Preserve existing league_test_* fixtures. Keep achievements, duels and coach_challenges disabled. Apply 002 in test only after prerequisite review, then test each migration and stop on the first failure.

No production SQL is authorized. Do not treat green GitHub CI as a substitute for real Supabase integration testing.
