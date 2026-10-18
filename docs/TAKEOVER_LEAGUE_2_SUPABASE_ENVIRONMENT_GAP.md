# Takeover League 2.0 — Supabase environment assessment (updated 2026-10-18)

## Verified environments
- **Production**: Takeover Project (`iqarjivcrddcixrvqbfb`, eu-west-1), 14 profiles, 54 training submissions, 60 point transactions in initial inventory. **No production SQL migration or feature activation authorized or performed.**
- **Isolated test**: Takeover league test (`cfgdvcccsqwfjajuizsr`, eu-central-1), zero profiles, training submissions or point transactions. Existing `league_test_*` fixtures preserved.
- Both profiles tables restrict roles to `boxer` and `admin`; there is no `coach` role in the actual schema.
- Production migration history returned empty through the API despite an existing schema. Do not interpret this as a blank database.

## Test schema preparation completed
- Reviewed test-only base-table bootstrap installed, followed by 001, 002, integrated 006, 007–023 and 025–028. 003–005 superseded by 006; 024 is comments only.
- Test now has 32 achievement definitions and 32 rules, 17 challenge RPCs and disabled achievement/duel/challenge feature flags.
- Read-only live checks confirmed no direct challenge-table grants for anon/authenticated, no anonymous RPC EXECUTE and configured SECURITY DEFINER search paths.
- Disposable PostgreSQL CI validates challenge settlement, including approved EXP, rejected zero EXP, idempotency and manual-only behavior. This is **not** a substitute for real Supabase Auth tests.

## Additional live production drift confirmed (read-only)
- No `public.coach_challenge_v2_*` or `public.achievement_v2_*` functions were returned by the production function inventory. Test contains 17 challenge RPCs.
- Production feature keys include `league_challenges` and `boxer_duels`, while the isolated test has `coach_challenges` and `duels`. Do not conflate or toggle these keys; a production-specific feature-key compatibility plan is required.
- All listed feature flags in **both** environments were false at the time of inspection. This is a snapshot, not a guarantee of future state.
- These findings reinforce that test migrations must not be blindly replayed against production.

## Outstanding gaps before production
1. Provision separate Auth users in **test only**: admin and two boxers. Link to test profiles and verify end-to-end role and privacy behavior.
2. Exercise the test challenge feature flag and manual payout workflow; restore flag to disabled afterward.
3. Inventory production constraints, grants, existing functions and drift; prepare reviewed, production-specific SQL rather than replaying test bootstrap.
4. Verify backups/restore and obtain explicit owner authorization before any production SQL, feature flag activation, merge or deployment.

See `docs/TEST_AUTH_INTEGRATION_GATE.md` and `docs/CHALLENGES_TEST_RELEASE_GATE_2026-10-18.md`.
