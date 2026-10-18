# Production V2 preflight checklist

Run read-only checks before any schema change.

1. Record counts for profiles, training_submissions and point_transactions.
2. Confirm profiles role constraint accepts boxer, admin and (after migration) coach.
3. Confirm point_transactions category constraint accepts duel_exp and challenge_exp after migration.
4. Confirm coach_challenges and duels feature flags exist and remain disabled.
5. Confirm new V2 tables and functions do not overwrite legacy league_challenges or boxer_duels.
6. Verify all V2 tables have RLS enabled and no direct authenticated/anon grants.
7. Verify all 17 coach_challenge_v2 functions have role-specific auth.uid() checks and authenticated-only EXECUTE.
8. Test rollback, authorized user actions, denied access and EXP idempotency before enabling any flag.

Production deployment must remain disabled until all checks pass.

## Baseline snapshot (18 October 2026)

Production read-only counts: 14 profiles, 61 training submissions, 63 point transactions. Recheck immediately before and after deployment; live counts can grow naturally, so compare identities and sums as well as row totals.

## Prepared migration order (NOT APPLIED)

1. `20261018_allow_coach_role.sql` — add coach role compatibility.
2. `20261018_extend_transaction_categories.sql` — allow V2 EXP transaction categories.
3. `20261018_v2_feature_flags_disabled.sql` — register new V2 flags, disabled.
4. `20261018_coach_challenges_v2_schema.sql` — create four RLS-protected tables.
5. **Still required:** import/review the 17 SECURITY DEFINER RPC definitions, reconcile full test-schema constraints, run real authenticated tests and review rollback. Do not enable the feature before these steps.

The schema file intentionally uses CREATE TABLE (not IF NOT EXISTS) so existing objects cause a safe failure instead of silently retaining an incompatible definition.
