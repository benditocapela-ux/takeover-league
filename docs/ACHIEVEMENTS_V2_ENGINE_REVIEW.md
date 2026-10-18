# Achievement V2 engine draft 003 – blocking review findings

Live state confirmed by owner after executing 002: 32 active definitions, 34 total, 0 ledger rows, 0 achievement EXP transactions, feature flag false.

**DO NOT RUN 003 YET.**

1. **Critical privilege escalation:** PostgreSQL functions grant EXECUTE to PUBLIC by default. `recalculate_boxer_achievements_v2(uuid)` is SECURITY DEFINER and accepts an arbitrary boxer ID without caller authorization. Before deployment, revoke EXECUTE from PUBLIC, anon, authenticated in the same transaction as CREATE FUNCTION; only the trigger function should invoke it. Confirm ownership/trigger privilege and test.
2. **Existing trigger timing:** Admin edit updates status/boxer/type/date before it updates point_transactions. An AFTER UPDATE trigger will run inside that statement, before transaction maintenance. This is acceptable only if the achievement engine reads solely submissions, but lock ordering must be evaluated for concurrent transfers.
3. **History/audit:** Current draft deletes boxer_achievements on revocation and updates point_transactions.exp to 0. This erases historical award state and changes transaction history. Explicitly decide whether a compensating adjustment or an append-only event ledger is required; preserve immutable audit of award/revoke/re-earn.
4. **Index and definition safety:** Current engine uses code-prefix regex and a default ELSE 250 for any unrecognized threshold. It must whitelist exactly 32 codes/thresholds or derive reward from a constrained immutable rules table.
5. **Training type ID mapping:** Draft hardcodes 1..6; validate production mapping by IDs, not only names.
6. **Concurrency:** Locking profiles row serializes reconciliation per boxer, but simultaneous admin boxer transfers can lock old/new boxer in opposite order. Use deterministic lock ordering or deferred reconciliation.
7. **Flag activation and backfill:** Do not activate before code review. Backfill must be idempotent, preview per-boxer changes, and explicitly owner-approved.
8. **Schema changes in 002 already live:** Never rerun a destructive rollback without checking dependencies; do not assume 002 was harmless to metadata (it altered constraint and deactivated legacy variety).
9. **Tie-break:** Monthly points unchanged because achievement transactions have points=0, but lifetime EXP tie-breaker can reorder boxers with equal monthly points; owner should explicitly accept.
10. **No test environment:** Do not claim safety without testing. Prepare read-only previews and rollback strategy; avoid running live mutations until explicit approval.
