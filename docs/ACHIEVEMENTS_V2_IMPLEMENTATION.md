# Takeover League 2.0 – Achievements implementation specification (not yet deployed)

## Verified live prerequisites (owner SQL exports)
- 13 active boxers; 47 approved sessions: boxing 19, sparring 0, technique 11 (280 minutes), strength 10, sprints 1, jogging 6 (30.50 km).
- Six existing definitions; zero awarded. Reuse training_10, training_25, training_50, training_100 IDs. Retire variety_3 and variety_5 from new awards without deleting history.
- Unique boxer_achievements(boxer_id,achievement_id), achievement_definitions(code), point_transactions(submission_id).
- point_transactions.category check only training, trainer_bonus, adjustment, legacy_import, automatic_bonus. New achievement_exp category requires explicit constraint migration.
- Existing AFTER INSERT OR UPDATE OF status trigger calls _award_achievements_on_approval. Current function checks feature flag and active boxer, awards only exact 10/25/50/100 and 3/5 distinct types; no retroactive or EXP awards. A second trigger sends training-decision notifications.
- No custom triggers on boxer_achievements or point_transactions.
- Approved legacy_import transactions exist and must be counted by approved training_submissions, not transaction category.

## 32 approved tiers
| Category | Source | Thresholds |
|---|---|---|
| Training Warrior | approved sessions | 10,25,50,100 |
| Mr Consistent | distinct approved training dates | 10,25,60,120 |
| Road King | approved jogging_km on jogging sessions | 25,75,150,300 |
| The Flash | approved sprint sessions | 5,15,30,60 |
| The Technician | approved technique_minutes on technique sessions | 300,900,1800,3600 |
| Iron Fighter | approved sparring sessions | 5,15,30,60 |
| Iron Engine | approved strength sessions | 10,25,50,100 |
| Complete Boxer | minimum approved sessions across all six training types | 1,3,7,15 |

Rewards per tier: 25,60,125,250 EXP, zero league points, total maximum 3680 EXP per boxer.

## Migration invariants
1. Do not enable achievements flag before the replacement logic is installed and tested.
2. Maintain stable definition codes and existing training_* IDs; add 28 new codes. Disable variety_3/variety_5 only after checking other dependencies.
3. Add point_transactions category achievement_exp and a durable, unique award-to-transaction key (e.g. dedicated award ledger with unique boxer_id,achievement_id; transaction_id unique). Never rely solely on description or source_key.
4. Every award creates at most one EXP transaction (points=0) atomically; rerunning backfill has zero net effect.
5. Recalculate from current approved submissions on approval, reversal, correction of date/boxer/type/km/minutes, including admin_edit_training_details; existing AFTER UPDATE OF status alone does not cover detail edits.
6. Correction policy: remove/reverse unearned award EXP, with immutable or compensating transaction audit and race-safe locking. Existing achievement rows should reflect current eligibility while preserving an audit trail.
7. Backfill in a transaction, preview expected per-boxer awards and EXP changes first; test rollback.
8. SECURITY DEFINER functions must check role or be trigger-only with restrictive EXECUTE grants, fixed search_path, and RLS review.
9. Do not alter existing training points or lifetime EXP except explicit newly earned achievement EXP.
10. Protect paused/left membership semantics, historical approved sessions and retroactive corrections.
11. Preserve achievement eligibility across repeated approvals; avoid threshold equality-only checks.

## Before executable migration
- Confirm column definitions/defaults of boxer_achievements and point_transactions, feature flag state, and FK/index dependencies.
- Inspect admin_edit_training and admin_edit_training_details and review_training bodies for recalculation hooks and audit order.
- Agree on correction ledger design and validate that adding achievement_exp does not break any RPC queries that sum all point_transactions.
- Stage migration in development branch only; live SQL requires explicit owner approval.
