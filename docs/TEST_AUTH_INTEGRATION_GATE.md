# Supabase test project: authentication and role gate

Checked against isolated test project `cfgdvcccsqwfjajuizsr`.

- `public.profiles` has zero rows in test (14 in production). **Both** projects have the same role constraint: `boxer` and `admin`, not `coach`. Use admin for the initial trainer integration tests; adding a dedicated coach role would require a separately reviewed migration.
- `profiles.auth_user_id` references `auth.users(id)`. A profile insert alone does **not** create a usable sign-in.
- All 17 challenge RPCs grant EXECUTE to `authenticated` but deny `anon`; all 17 use SECURITY DEFINER with configured search_path. Their internal authorization must still be verified with real sessions.
- The security advisor reports 23 RLS-without-policy findings (informational) and 23 authenticated SECURITY DEFINER functions (warnings). No direct challenge-table grants were found for `anon` or `authenticated` in the test project; RPC-only tables may intentionally have no policies.
- Existing disposable PostgreSQL behavior tests are valuable but do not replace real Supabase Auth tests.

## Next safe integration test
1. Provision dedicated, non-production Supabase Auth users through the supported Auth admin interface: one admin and two boxers.
2. Link their actual auth user UUIDs to `public.profiles` in the **test project only**, with admin/boxer roles. Never copy production user credentials.
3. Verify boxer cannot create, edit, approve or settle challenges; admin can. Verify each boxer can join and withdraw only for themselves.
4. Temporarily enable `coach_challenges` **only in the isolated test project**, then test approved 150 EXP, rejected 0 EXP, idempotent retry, and reset flag to disabled.
5. Validate that challenge reward creates zero training points and that unauthorized users cannot read private reviews.
6. Do not change production or merge until the owner approves a release and backup/restore has been verified.

See `supabase/tests/COACH_CHALLENGES_V2_API_PERMISSIONS_SMOKE.sql` and `supabase/tests/COACH_CHALLENGES_V2_SETTLEMENT_BEHAVIOR_SMOKE.sql`.
