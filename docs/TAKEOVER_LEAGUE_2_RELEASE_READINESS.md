# Takeover League 2.0 — release readiness (review only)

This document is a checklist, not authorization to execute SQL, deploy, merge, or enable a feature.

## Verified in disposable CI

- Achievement V2 rules and contracts
- Duel V2 contracts and isolated PostgreSQL settlement
- Coach Challenges V2 schema, permissions, lifecycle, review and payout tests
- Feature flags default to disabled in migrations
- Coach-only challenge reward configuration and manual approval

## Mandatory owner decisions before production

- [ ] Approve challenge EXP choices: 25 / 50 / 100 / 150 / 200
- [ ] Approve zero EXP for rejected manual reviews
- [ ] Confirm whether rejoining an open challenge after withdrawal is desired
- [ ] Confirm automatic challenge settlement remains disabled; only manual review is eligible
- [ ] Confirm rollout sequence and who is authorized to run SQL

## Production preflight — do not run without explicit approval

- [ ] Back up live Supabase database and document rollback strategy
- [ ] Check schema compatibility and required roles/extensions
- [ ] Run read-only inventory/preflight and inspect its results
- [ ] Confirm no unexpected point transaction categories or existing challenge EXP payouts
- [ ] Review every SQL migration and its order before execution
- [ ] Confirm RLS, grants and feature flags after migrations
- [ ] Run a limited end-to-end pilot with test users and no unintended historical EXP changes
- [ ] Obtain separate authorization to enable each feature flag
- [ ] Obtain separate authorization before merging or deploying the web frontend

## Release gates

**Do not execute production SQL, merge main, deploy, or turn on feature flags** on the basis of green CI alone. Synthetic PostgreSQL tests do not verify the real production schema or user data. Record the exact release commit and obtain explicit owner approval first.

## Known limitations

- Automatic challenge progress is read-only; automatic payout is not implemented or authorized.
- Manual challenge payout is prepared in review-only migration 027 and depends on confirmed reward policy.
- Reward and review outcomes must be validated by the owner before any real-world usage.
