# Coach Challenges V2 — verified test release gate (2026-10-18)

## Verified in isolated Supabase test project
- Project: Takeover league test (`cfgdvcccsqwfjajuizsr`). Production project is not modified.
- Applied: 001, test-only baseline, 002, integrated 006, 007–023. Drafts 003–005 intentionally superseded by 006.
- 024 is comments only: not executable SQL and not applied.
- 025 is NOT applied: execution was blocked by tool security checks. 026–028 also remain unapplied.
- Four GitHub workflows were successful at commit `911f1f36` (static contracts, achievements, duel schema smoke, coach challenges).

## Required before release
1. Resolve 025 execution block through an authorized route; do not bypass security checks. Then apply 025, 026, 027, 028 in order in test.
2. Verify EXP amounts 25/50/100/150/200, rejected reviews yield 0, withdrawn rejoin behavior, coach-only manual settlement, and idempotency using disposable test records.
3. Verify authorization, RLS and SECURITY DEFINER functions with boxer/coach/admin sessions, including cross-boxer data access.
4. Review migration 027 payout integrity, uniqueness index, transaction-category constraint and rollback behavior; do not assume static checks prove behavior.
5. Reconcile production schema and data against migrations, prepare tested backup/restore plan, and obtain explicit owner authorization BEFORE any production SQL.
6. Keep feature flags disabled until approval; do not merge or deploy without owner authorization.

## Approved policy
C1 selectable EXP 25/50/100/150/200; C2 rejected manual review 0 EXP; C3 rejoin after withdrawal while open, no duplicate active joins; C4 no automatic settlement, coach reviews manually.
