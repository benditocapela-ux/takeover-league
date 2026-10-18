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

## Achievement ownership transfer integration (2026-10-18)

- TEST Supabase rollback-only SQL: ten approved sessions earned `training_10` for Boxer 1; transferring all ten `training_submissions.boxer_id` values to Boxer 2 revoked the first award and granted the second. Separate `revoked` and `earned` event rows verified. PASS.
- A further re-earn transition test was blocked by tool safety checks; **not passed**.
- Post-test read-only inspection: zero test training submissions, achievement ledgers/events and duels; `achievements`, `duels`, and `coach_challenges` flags all false.

## Achievement DELETE regression and patch (2026-10-18)

- TEST rollback-only regression exposed a real bug: deleting one of exactly ten approved sessions left `training_10` earned, because migration 006 trigger did not handle DELETE.
- Development migration `006_achievement_v2_integrated_review.sql` updated in commit `e8f9fb9f`: trigger now fires AFTER DELETE; trigger function reconciles `OLD.boxer_id` and returns `OLD` for deletes.
- TEST rollback-only validation installed the modified trigger/function inside a transaction, earned `training_10` with ten approved sessions, deleted one, verified zero earned ledger awards and exactly one `revoked` event, then rolled back all changes. PASS. The fix has NOT been applied persistently to TEST or production.
- TEST rollback-only `earned` -> `revoked` -> `reearned` flow also passed: three event rows and one reused 25 EXP transaction.
- Follow-up: CI regression coverage for DELETE, authenticated HTTP tests, concurrency and production privilege remediation remain necessary.

## CI DELETE guard and disabled-flag behavior (2026-10-18)

- `tests/test_achievement_v2_trigger_contract.py` now statically checks the SQL DELETE trigger, `OLD.boxer_id` recalculation, and SECURITY DEFINER REVOKEs. `.github/workflows/achievement-v2-tests.yml` runs it and watches migration 006 changes. Achievement CI passed for commit `31a9e94c`.
- TEST Supabase rollback-only flag test: award earned with achievements ON; with achievements OFF, rejecting a qualifying submission did not reconcile the ledger. PASS for disabled-feature guard. This deliberately leaves a stale award *while the flag is off*, so enabling achievements after a disabled interval requires an explicitly reviewed reconciliation/backfill plan.
- These are not proof of safe production privileges or concurrency. No production changes authorized.

## Duel invitation edge cases (2026-10-18)

- TEST Supabase rollback-only: duplicate pending invite for same pair blocked; decline changes status; fresh 14-day invite after decline succeeds. PASS.
- TEST Supabase rollback-only: after shifting both `invited_at` and `expires_at` consistently to preserve CHECK constraints, a 49-hour-old invitation cannot be accepted, status becomes `expired`, zero duel EXP ledger entries. PASS.
- TEST and production not modified by these rolled-back cases. The first expiry fixture attempt violated an expected timestamp CHECK and was corrected before the successful test.

## Additional invitation security checks (2026-10-18)

- TEST rollback-only SQL: self-invitation rejected, unsupported 3-day duration rejected, valid 14-day duration accepted. PASS.
- TEST rollback-only SQL with simulated JWT subject: neither trainer nor inviting boxer can accept an invitation reserved for the opponent; pending status unchanged. PASS. Not an authenticated HTTP test.
- All six CI workflows succeeded for commit `91749c93`. Production untouched.

## Duel scoring integrity edge cases (2026-10-18)

- TEST rollback-only: database `point_transactions_submission_id_key` rejected a second scoring transaction for the same submission before reconciliation; direct duplicate-payout RPC path was therefore not exercised. Expected database invariant verified.
- TEST rollback-only: an approved submission whose training_date fell within the duel but whose created_at was after the duel ended was excluded from scoring; settlement yielded a 50/50 tie. PASS.
- No persistent test or production changes.

## Duel negative scoring, flag-off and replay checks (2026-10-18)

- TEST rollback-only: negative points on an approved training caused `duel_v2_reconcile` to fail closed, with zero duel EXP ledger rows. PASS.
- TEST rollback-only: after valid 50/50 settlement, disabling `duels` prevented subsequent reconciliation and left two existing reward ledger entries unchanged. PASS.
- TEST rollback-only with simulated boxer JWT subject: replaying `duel_v2_reconcile` after settlement was denied; two payout transactions remained unchanged. PASS. Not a real signed HTTP JWT test.
- Five CI code workflows passed for prior commit `3abac8b4`; Pages was still in progress when checked.

## Achievement status and tier integration (2026-10-18)

- TEST rollback-only: ten pending sessions earned no achievement; changing all to rejected produced no EXP transition events. PASS.
- TEST rollback-only: 25 approved sessions earned exactly two session achievement tiers, totaling 85 EXP; explicit recalculation added no events (idempotent). PASS.
- TEST read-only post-check: zero training submissions, achievement events/ledger, duel rows/ledger; achievements, duels, coach_challenges flags all false. No test residue.
- All six CI workflows completed successfully for commit `2ecdbdfa`.
