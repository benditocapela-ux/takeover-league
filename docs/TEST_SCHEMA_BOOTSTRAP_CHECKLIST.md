# Test schema bootstrap — completed prerequisites and remaining gates

Test project: `cfgdvcccsqwfjajuizsr`. Production: `iqarjivcrddcixrvqbfb` (do not modify).

## Completed in the isolated test project
- Installed migration 001 and the reviewed test-only missing-base-tables bootstrap (`supabase/preflight/TEST_ONLY_MISSING_BASE_TABLES.sql`), without copying production users.
- Installed migration 002, integrated 006, 007–023 and 025–028. 003–005 are superseded by 006; 024 is documentation/comments only.
- Confirmed 32 achievement definitions, 32 V2 rules, 17 challenge RPCs, RLS on created tables, no direct challenge-table API grants, anonymous EXECUTE denied, and feature flags disabled.
- Confirmed the test and production `profiles.role` checks both permit `boxer` and `admin` only.
- Existing `league_test_*` fixtures retained.

## Not yet completed
- Real Supabase Auth admin/boxer integration tests: the test project has zero linked profiles.
- End-to-end manual challenge review, approved/rejected EXP payouts and idempotency using real signed-in test users.
- Production schema-drift and backup/restore rehearsal, production migration plan and explicit owner authorization.

**Do not replay the full historical migration chain into production.** Green CI and schema presence are not proof of production readiness. See `docs/CHALLENGES_TEST_RELEASE_GATE_2026-10-18.md`.
