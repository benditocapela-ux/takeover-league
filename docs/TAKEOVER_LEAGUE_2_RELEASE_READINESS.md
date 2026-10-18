# Takeover League 2.0 — release readiness (review only)

This document is a checklist, not authorization to execute SQL, deploy, merge, or enable a feature.

## Verified in disposable CI

- Achievement V2 rules and contracts
- Duel V2 contracts and isolated PostgreSQL settlement
- Coach Challenges V2 schema, permissions, lifecycle, review and payout tests
- Feature flags default to disabled in migrations
- Coach-only challenge reward configuration and manual approval

Owner decision register: [Takeover League 2.0 owner decisions](TAKEOVER_LEAGUE_2_OWNER_DECISIONS.md).

## Mandatory owner decisions before production

- [x] Approve challenge EXP choices: 25 / 50 / 100 / 150 / 200
- [x] Approve zero EXP for rejected manual reviews
- [x] Confirm whether rejoining an open challenge after withdrawal is desired
- [x] Confirm automatic challenge settlement remains disabled; only manual review is eligible
- [ ] Confirm rollout sequence and who is authorized to run SQL

## Production preflight — do not run without explicit approval

- [ ] Back up live Supabase database and document rollback strategy
- [ ] Check schema compatibility and required roles/extensions
- [ ] After explicit owner authorization, run [read-only inventory](../supabase/preflight/TAKEOVER_LEAGUE_2_READ_ONLY_INVENTORY.sql) and inspect its results; the script itself is not permission to execute
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

## First production SQL gate — exact handoff

Current release candidate: **not approved for production**. Owner approved challenge policy C1–C4 on 2026-10-18; production operator and backup/restore plan (C5–C6) are still pending. Before issuing an all-caps instruction to run SQL, collect and record the owner's decisions above and complete the following steps in order:

1. Freeze the intended Git commit and verify that all four GitHub workflows are green for that exact SHA.
2. Obtain a live Supabase schema inventory using **read-only** queries only after the owner authorizes that action; compare tables, check constraints, RLS policies, grants, extensions and migration history against the reviewed migration chain.
3. Confirm backups, restore access, responsible operator and a rollback plan appropriate for additive schema changes and financial/EXP records.
4. Reconcile any discrepancies found in the live inventory and rerun isolated PostgreSQL tests on the revised migrations.
5. Obtain explicit owner confirmation of the manual EXP reward and rejection policy, withdrawal/rejoin behavior, and disabled automatic settlement.
6. Present the first exact SQL script, its expected output, stop conditions and verification steps **before** requesting execution. Never combine unrelated migrations into an unreviewed bulk instruction.
7. Only after these gates and explicit authorization, tell the owner in **ALL CAPS** that the first SQL is ready to execute. A green workflow alone does not authorize that message.

### Stop conditions

Stop without writing to production if the read-only inventory shows an unknown schema version, an unexpected point transaction category, existing challenge payout records, an incompatible category check constraint, or missing backup/restore arrangements. Never infer production readiness from synthetic fixtures.

## 2026-10-18 additional isolated integration evidence

- TEST Supabase six training types seeded to match production points; production unchanged.
- Achievement rollback-only integration: 10 approved sessions awarded training_10 (+25 EXP), second reconciliation was idempotent, rejection revoked achievement and zeroed EXP, earned/revoked events recorded. All test records rolled back.
- Duel rollback-only integration with simulated request JWT subject: boxer invitation and acceptance; trainer settlement awarded 100/25 EXP; repeated settlement did not duplicate payouts; pending review blocked settlement; after rejection a 50/50 draw paid correctly. All duel test records rolled back. These are database tests, NOT real authenticated HTTP API tests.
- Production read-only duel scoring data integrity: zero approved submissions lacking scoring transaction, zero duplicate scoring transactions, zero mismatched training owners, zero unlinked scoring transactions, zero linked adjustments.
- Production security advisor reports anonymous EXECUTE on SECURITY DEFINER `public.recalculate_boxer_achievements_v2(uuid)`. Reviewed migration 006 revokes this; production implementation and permissions require explicit review/correction before enabling achievements. Do not alter production grants without owner approval.
- Still blocked: real authenticated duel/achievement API negative tests, concurrency/lock-order, production backup/restore, migration-history reconciliation, production security fix, and owner-approved rollout.

## Additional duel SQL integration verification (2026-10-18)

- Latest release-readiness commit `b5701b04`: all six GitHub workflows completed successfully at that exact SHA.
- TEST Supabase rollback-only SQL: a later valid reviewed training changed the duel winner from Boxer 1 to Boxer 2, corrected existing EXP ledger entries to 25/100, kept exactly two reward transactions, and recorded one `corrected` event. PASS.
- TEST Supabase rollback-only SQL with simulated JWT subject: boxer attempt to invoke `duel_v2_reconcile` failed with coach-only authorization error, did not create reward ledger; simulated trainer then settled. PASS. This is NOT a signed HTTP JWT test.
- After rollback, all three TEST feature flags remained disabled. Production remains unchanged.
