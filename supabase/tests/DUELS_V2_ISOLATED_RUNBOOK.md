# Duel V2 — isolated database test runbook

**REVIEW ONLY.** This is a reproducible operator checklist, **not evidence that integration tests have run**. Never use a production Supabase connection string, service-role key, or real boxer data.

## Prerequisites

- Disposable Supabase local environment (Supabase CLI + Docker) or a dedicated test-only Supabase project.
- A complete **sanitized** copy of the base schema, including existing auth, profiles, training_submissions, point_transactions, feature flags and review/edit functions. The duel migrations alone do not create these dependencies.
- PostgreSQL-compatible client and the exact test-only database URL. Never commit credentials or copied personal data.
- Test accounts and JWTs for boxer A, B, C, coach and unauthenticated role; separate sessions for concurrency tests.

## Sequence (isolated test database only)

1. Verify database identity, hostname and test-only designation before running any command. Abort if the URL or environment could point to production.
2. Load the sanitized existing base schema and its prerequisite migrations in a disposable environment.
3. Run `supabase/tests/DUELS_V2_PREFLIGHT_READ_ONLY.sql`. Inspect every required column and constraint. Abort on missing columns, incompatible category values or wrong role/FK assumptions.
4. Apply the review migrations **007 → 008 → 009 → 010**, in that order, **only** in the disposable test environment. Verify the `duels` feature flag is initially false.
5. Create synthetic profiles, test auth identities, training submissions and approved transactions; turn on the `duels` flag in the disposable database only.
6. Execute all 27 scenarios in `DUELS_V2_INTEGRATION_TEST_MATRIX.md`, using isolated transactions and test-only credentials. Capture observed status, transaction IDs, EXP deltas and errors. Concurrency cases require two sessions.
7. After completed payouts, run `supabase/tests/DUELS_V2_LEDGER_AUDIT_READ_ONLY.sql`. Each of its four SELECTs must return **zero rows**. Any mismatch blocks release.
8. Reset the disposable environment and rerun the suite to prove reproducibility. Destroy the test environment after capturing sanitized results.

## Automated disposable PostgreSQL coverage

The GitHub Actions workflow `.github/workflows/duels-v2-schema-smoke.yml`
uses a synthetic PostgreSQL 16 base schema, **not a copy of the deployed
Supabase schema**. It applies review migrations 007–010 and exercises:

- Database constraints and invitation/acceptance permissions.
- Duel settlement, pending reviews, score corrections, payout tampering,
  feature flag enforcement and backdated entries.
- Batch reconciliation and duplicate-EXP protection.
- Authenticated duel list visibility and disabled accounts.
- Two simultaneous settlement sessions against the same duel, with an
  artificial payout delay, checking for duplicate ledger rows/events.

Passing CI establishes these tested behaviors **only against the synthetic
schema**. It does not establish compatibility with the deployed
`review_training`, `admin_edit_training`, or `admin_edit_training_details`
functions. Their SQL definitions and lock order must be reviewed against
the actual deployment before any live rollout. Do not treat the green
workflow as approval to run SQL in production.

## Explicitly unresolved

- Existing `review_training` and `admin_edit_training` RPCs may lock rows in a different order; inspect them before concurrency tests.
- Training-date boundaries are calendar-day based, not timestamp exact.
- Late/backdated training submissions are currently excluded when created after duel end.
- The `point_transactions` category constraint is replaced in 009 and must be checked against the **actual** deployed base schema.
- The current SQL syntax and static contract checks do not execute any database functions and cannot prove correctness.

## Test report template

| Scenario | Expected | Actual | Pass/Fail | Evidence |
|---|---|---|---|---|
| D01–D27 | Refer to matrix | Not run | Pending | — |

**Release gate:** no production migration, feature flag activation or boxer UI link until the isolated run passes, policy questions are resolved and the owner explicitly authorizes rollout.
