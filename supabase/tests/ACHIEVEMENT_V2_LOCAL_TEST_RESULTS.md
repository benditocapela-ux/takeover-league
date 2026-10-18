# Achievement V2 local test execution

Executed 2026-10-17 in isolated Python environment, no Supabase connection.

Command: `python -m unittest discover -s /mnt/data/takeover_tests -v`

Result: **8 tests passed, 0 failed**.

Tests cover rule counts, Royce preview (+25 EXP), repeated reconciliation (+0 on second pass), skipping thresholds, revoke/re-earn, technique threshold, six-type minimum, and maximum 3680 EXP.

Scope limitation: a local test reproduction of the repository's pure-Python test logic was run; GitHub Actions workflow status and PostgreSQL integration tests were **not** verified.

## Release blockers still open
- Migration 006 is REVIEW ONLY; no live execution.
- Lock-ordering during cross-boxer transfers could deadlock; requires deterministic ordering or a different trigger/reconciliation architecture.
- Mutable `point_transactions.exp` with separate events must be explicitly accepted or replaced by append-only adjustment accounting.
- Need an isolated PostgreSQL/Supabase environment to test SECURITY DEFINER privileges, RLS, triggers, and transaction rollback.
- Flag stays false; initial backfill preview remains Royce +25 EXP.
