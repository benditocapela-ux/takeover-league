# Coach Challenges V2 — verified test release gate (updated 2026-10-18)

## Installed in isolated Supabase test project
- Test: `cfgdvcccsqwfjajuizsr`. Production: `iqarjivcrddcixrvqbfb`, unchanged.
- Installed: 001, test-only base-table bootstrap, 002, integrated 006, 007–023, and **025–028**. Migrations 003–005 were superseded by 006; 024 is comments only.
- 32 achievement definitions and 32 V2 rules; 17 coach challenge RPCs; no challenge payouts or enrolled users in test.
- All 17 challenge RPCs deny anonymous EXECUTE and have SECURITY DEFINER with configured search_path. No direct challenge-table SELECT/INSERT/UPDATE/DELETE grants for anon or authenticated were found in test. These checks do **not** replace real signed-in authorization tests.
- Both production and test profiles allow only `boxer` and `admin` roles. Test has zero profiles. Use admin for the coach test identity.
- Achievement, duel and challenge feature flags remain OFF. Five GitHub workflows passed on commit `fc048df1`; later commits require their own CI checks.

## Approved policy and implementation
- C1: approved participants earn the configured 25, 50, 100, 150 or 200 EXP.
- C2: rejected manual reviews earn 0 EXP, with a recorded decision.
- C3: withdrawal and rejoin while enrollment remains open; duplicate active joins prohibited. The UI and regression test now reflect this.
- C4: manual review and settlement only; no automatic settlement.
- Disposable PostgreSQL smoke tests cover settlement and idempotency. Real Supabase Auth integration remains unverified.

## Release blockers
1. Create three **test-only** Supabase Auth accounts (admin, boxer A, boxer B), then link their actual auth IDs to test profiles. No production credentials or user data should be copied.
2. Test with real sessions: admin challenge creation, goal setup, review and settlement; boxer join, withdrawal, rejoin, and forbidden admin actions; cross-boxer access; 150 EXP approved, 0 rejected, retry idempotency and zero training points. Temporarily enable only the **test** challenge flag during controlled tests and turn it off afterward.
3. Confirm production schema drift, backup and restore, rollback and exact migration order before any production SQL.
4. Obtain explicit owner approval before production SQL, feature activation, merge or deployment.

See `docs/TEST_AUTH_INTEGRATION_GATE.md` and `supabase/tests/TEST_PROJECT_READ_ONLY_LIVE_GATE.sql`.
