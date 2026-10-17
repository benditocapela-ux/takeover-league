# Takeover League 2.0 — Supabase environment gap assessment (2026-10-18)

**Read-only discovery only. No production or test SQL migration was applied.**

## Identified environments

- Production candidate: **Takeover Project** (`iqarjivcrddcixrvqbfb`, eu-west-1). 14 profiles, 54 training submissions, 60 point transactions. Existing achievements, flags and league tables; migration history API returned an empty list.
- Isolated test: **Takeover league test** (`cfgdvcccsqwfjajuizsr`, eu-central-1). Zero profiles, training submissions and point transactions. Contains three additional `league_test_*` tables with test rows, plus only the base app tables; migration history API returned an empty list.

## Confirmed schema incompatibilities in test

1. Migration `002_achievement_v2_schema_draft.sql` immediately updates `public.achievement_definitions`, which does not exist in the test project's public table inventory. Applying the numbered migration sequence as-is will fail at 002.
2. Test `public.profiles.role` currently permits `boxer` and `admin` only. Coach challenge RPCs use coach authorization and test fixtures create `coach` profiles; role semantics must be reconciled with the real base schema.
3. Test `public.point_transactions.category` permits only training, trainer_bonus, adjustment, legacy_import and automatic_bonus; later migrations alter this check for EXP categories. Validate exact constraint names before applying them.
4. Test has no `public.league_feature_flags` or `public.achievement_exp_ledger`. Migration 007 and 011 insert flags, so the base app schema and earlier migrations must first be established.
5. Both projects report no migration history through the Supabase API; do not assume an empty history means an empty schema or that replaying historical DDL is safe.

## Safe next actions

- Confirm which project is production and which is disposable; avoid treating the test project as an exact clone.
- Inventory base-schema creation scripts in GitHub, identify the earliest compatible baseline and dependency order, and prepare a test-only bootstrap plan.
- Check existing SQL function signatures, constraints, grants and RLS on both environments before any DDL.
- Get explicit authorization for test-environment writes separately from production writes. Do not clone personal user data into test without approval and a privacy plan.
- Verify backups and restore procedures before production migrations. Feature flags remain off until separately approved.

**Stop condition:** Never execute `001`–`028` directly against the current test schema without establishing missing base tables and reconciling role constraints.
