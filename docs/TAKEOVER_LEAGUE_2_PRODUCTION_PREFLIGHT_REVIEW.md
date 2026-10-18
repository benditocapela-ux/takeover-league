# Production preflight review worksheet — Takeover League 2.0

**Status: NOT EXECUTED.** This worksheet is not approval to run SQL, merge, deploy, or enable features. Owner authorization is required before using the [read-only inventory](../supabase/preflight/TAKEOVER_LEAGUE_2_READ_ONLY_INVENTORY.sql).

## Environment and evidence

- Git SHA reviewed: ____________________
- Date/time of review: ____________________
- Supabase project/environment (do not paste credentials): ____________________
- Operator approved by owner: ____________________
- Backup snapshot ID / verified restore procedure: ____________________
- Inventory output reviewed by: ____________________

## Required checks

| Gate | Evidence | Pass / Fail / Blocked |
|---|---|---|
| All four CI workflows green on frozen SHA | Workflow run links | |
| Owner decisions C1–C6 explicitly confirmed | [Decision register](TAKEOVER_LEAGUE_2_OWNER_DECISIONS.md) | |
| Live schema matches prerequisites | Tables, columns, constraints from inventory | |
| Required RLS and grants compatible | Policies and grants separately reviewed | |
| Migration history reconciled; no partial V2 deployment | Supabase migration tracking | |
| point_transactions category constraint supports intended V2 categories | Actual constraint definition | |
| Existing challenge_exp rows understood (ideally none before first V2 release) | Aggregate inventory output | |
| Feature flags default OFF and remain OFF after migration | Reviewed SQL and verification query | |
| Backup and restore feasible | Owner/operator confirmation | |
| Pilot accounts and rollback decision tree agreed | Named responsible operator | |

## Hard stop conditions

Stop before any production write if: a required table/column is missing; any migration has already been partially applied; category checks differ from tested assumptions; RLS grants are unknown; pre-existing challenge EXP payouts are unexplained; backup/restore is not confirmed; or any owner policy decision remains unresolved.

## Handoff sequence

1. Owner explicitly approves the read-only preflight.
2. Operator executes only the reviewed read-only inventory and returns its results without private data or credentials.
3. Compare results against migrations and document differences.
4. Freeze and review the first exact production SQL migration, expected effects and verification queries.
5. Request separate explicit production authorization. Only then issue the owner's required ALL-CAPS instruction to execute SQL.
6. After migration, verify RLS/grants/flags, run limited pilot and obtain separate deployment/feature enablement approval.

## Unverified limitations

The current inventory does **not** enumerate every table or grant used by all 28 migrations, but it now lists Supabase migration versions where the tracking relation exists. It does not verify that recorded migrations match the live schema. Treat it as an initial inventory, not an automated production compatibility verdict. Synthetic CI does not validate the live Supabase schema.
