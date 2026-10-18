# Takeover League 2.0 – production rollout (NOT APPLIED)

## Release artifact

**Single atomic versioned migration:** `supabase/migrations/20261018131000_coach_challenges_v2.sql`.

This contains the four guarded compatibility/schema modules, an internal authenticated-actor helper and **all 17** coach challenge V2 RPCs. It starts with collision checks and finishes by verifying both V2 feature flags remain disabled, all four new tables have RLS enabled and anonymous callers cannot execute RPCs or select V2 tables. The transaction aborts on failure. Do **not** apply it to production until the release gates below are satisfied.

The `20261018_*.sql` files in this folder are editable source modules, not additional migrations to execute after the bundle. `tests/production-v2-migration-bundle.cjs` fails CI if the bundle drifts from those modules. The explicit rollback files must only be used with empty V2 tables and must remove V2 RPCs before their tables. Never use CASCADE or overwrite live EXP.

## Verified in disposable PostgreSQL CI

- Exact versioned migration installs cleanly on PostgreSQL 16.
- Existing profiles, point transactions and legacy feature flags remain intact.
- Coach creates/edits/publishes/activates; boxer joins/withdraws/rejoins.
- Admin can inspect challenges; unrelated coach and boxer cannot manage another coach's records.
- Feature-disabled and anonymous RPC calls are rejected; normal users have no direct access to any V2 table.
- Manual review blocks premature settlement; approved and rejected participants are handled distinctly.
- Approved boxer gets one `challenge_exp` transaction and one ledger entry, with no duplicate EXP on repeated settlement.
- All 17 RPC grants checked; both RPC and empty-table rollbacks exercised.
- Mock browser and static frontend checks continue to run.

**Remaining before release:** Validate the actual Supabase Auth/PostgREST/RLS environment with temporary accounts; inspect production database triggers and constraint compatibility; recheck existing user balances/history; complete the final UI/backend integration review and deliberate feature activation. Disposable PostgreSQL tests are not equivalent to live Supabase E2E. Keep `window.TAKEOVER_CHALLENGES_V2_ENABLED=false` and database `coach_challenges.is_enabled=false` until both sets of gates pass.

## Baseline (18 October 2026, historical reference)

Previous production snapshot: 14 profiles, 61 training submissions, 63 point transactions. These counts change naturally; take a new read-only baseline immediately before any rollout and compare identifiers, balances and totals rather than expecting exact historic counts.

## Independent security fix (NOT APPLIED)

`20261018_restrict_achievement_recalculation.sql` revokes direct client EXECUTE of unrestricted `recalculate_boxer_achievements_v2(uuid)`. Review its effect on the postgres-owned training-approval trigger before deploying it separately. It is **not bundled** with the coach challenges migration.
