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
