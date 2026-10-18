# Challenge V2 — real integration and production gate (18 October 2026)

## Test project: observed evidence

- Project: `cfgdvcccsqwfjajuizsr` (TEST ONLY). Production is `iqarjivcrddcixrvqbfb`.
- Three Auth-linked active profiles: Test-Trainer (`admin`), Test-Boxer 1 (`boxer`), Test-Boxer 2 (`boxer`).
- `Test-Challenge 001` (`6ef56ece-6825-4a98-b804-b46c80230806`): created, opened, joined by both boxers, Boxer 1 withdrew and rejoined, activated, time-shifted in **test only** while preserving 7-day constraint, reviewed and manually settled.
- Approved Boxer 1: **150 EXP**, one linked point transaction. Rejected Boxer 2: **0 EXP**, documented ledger entry without point transaction. Exactly two ledger entries, 150 EXP total; status `settled`. Browser no longer offers settle action.
- Genuine authenticated Boxer 1 RPC request to `coach_challenge_v2_settle_manual` returned HTTP 400, PostgreSQL `P0001`, `Coach authorization required`. Earlier HTTP 401/PGRST301 was invalid JWT, **not** a valid authorization test.
- Read-only catalog checks: all 17 challenge RPCs reference `auth.uid()`, anonymous EXECUTE denied; six privileged RPCs contain coach/admin authorization checks. This is static inspection, **not** live boxer-credential negative testing of all functions.
- Subsequent read-only verification: `settled`, 2 ledger rows, 150 EXP, 1 linked positive transaction. Direct replay of settlement RPC as trainer not tested; UI hides action.

## Production read-only findings

- Production existing data: 14 profiles, 54 training submissions, 60 point transactions. Preserve all.
- `league_feature_flags.display_name` is NOT NULL with no default; new flag inserts must explicitly supply it.
- Production migration history currently empty while schema exists; test history has 26 entries. Do not infer migration equivalence from migration versions.
- Production feature flags remain OFF; no production migration, deploy, or feature enablement authorized.

## Release blockers / follow-up

1. Reconcile each intended migration with live production constraints, policies, existing objects, point category check, and migration history. Produce a reviewed exact production-specific SQL plan, not an unmodified replay of test migrations.
2. Obtain backup snapshot and verified restore procedure, including accountable operator.
3. Verify all privileged RPCs against actual boxer identity (or isolated Auth test harness); only settlement has genuine negative API evidence so far.
4. Confirm settlement replay idempotency with authenticated trainer on isolated test data, without modifying production.
5. CI green on frozen SHA and owner authorization required separately for production SQL, deployment, and feature enablement. Do not enable production flags as part of schema installation.

**NO PRODUCTION SQL EXECUTED.**
