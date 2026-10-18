# Achievement V2 – executable test matrix before live deployment

Status: migration 002 installed on live; migration 006 NOT installed; feature flag false. Live preview: Royce one Training Warrior Bronze +25 EXP, everyone else zero.

## Preflight (read-only, may run live)
Run `supabase/tests/002_achievement_v2_pre_release_readonly.sql`; zero rows = pass. This checks setup only.

## Mandatory isolated-database integration tests (DO NOT perform on live)
1. **Backfill**: Seed 10 approved boxing sessions for boxer A, 9 for B. Enable flag and reconcile; A gets training_10 once, exactly +25 EXP and 0 points; B gets none.
2. **Idempotency**: Reconcile A twice; exactly one ledger, one point transaction, one event and one boxer_achievement.
3. **Threshold skipping**: Seed 25 approved sessions in a single batch; both training_10 and training_25 must be earned (+85 EXP).
4. **Metric scope**: Jogging km count only approved Joggen, technique minutes only approved Techniktraining, distinct days deduplicated, complete boxer requires all 6 types.
5. **Revoke**: Change one approved session to rejected to drop A from 10 to 9; earned row no longer active, EXP returns to 0, event history records -25, monthly points reflect only training correction.
6. **Re-earn**: Restore session; +25 EXP exactly once, event history records reearned.
7. **Details edit**: Modify jogging_km/technique_minutes via admin_edit_training_details without changing status; award/revoke should occur correctly.
8. **Transfer**: Move an approved session from A to B; recalc both, no leftover EXP; repeat with simultaneous opposing transfers to check for deadlocks.
9. **Unauthorized invocation**: anon/authenticated cannot execute reconciliation function or write protected rules, ledger or event tables.
10. **Failure atomicity**: Force failure after award transaction insert; transaction rollback leaves no orphan ledger/event/EXP transaction.
11. **Existing records**: Old legacy_import approved submissions count for achievement thresholds; existing training points/EXP remain unchanged.
12. **Leaderboard**: Achievement transactions points=0; lifetime EXP increases; tie-break by EXP may change ranking among equal monthly points.
13. **Notifications**: Existing training decision notification trigger remains installed and functional.

## Review blockers
- Current 006 uses profile-row locks during per-row AFTER triggers. Concurrent boxer transfers may deadlock. Implement deterministic lock ordering and test.
- Current 006 mutates point_transactions.exp on revoke; audit events record changes but transaction ledger is not append-only. Decide accounting policy and test invariants.
- Confirm function execution privileges, ownership and default grants under actual Supabase deployment role.
- Validate that the owner wants the lifetime-EXP tie-break.
- Do not enable achievements until backfill preview and rollback checks pass.
