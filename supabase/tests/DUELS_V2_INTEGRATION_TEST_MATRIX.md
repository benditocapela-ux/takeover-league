# Takeover League 2.0 — isolated duel integration matrix

**Status:** test plan only. No live Supabase execution. Requires an isolated PostgreSQL/Supabase environment with representative copies of the existing schema and auth roles. Do not run review migrations 007–010 against production before passing these tests and owner approval.

## Setup

1. Start an isolated test database. Apply the existing base schema and prerequisite migrations; do **not** copy real athlete records or credentials.
2. Create test-only profiles: coach/admin, boxer A, boxer B, boxer C and boxer D. Provide authenticated JWT contexts with auth.uid() resolving to their profile auth_user_id.
3. Apply reviewed duel migrations 007, 008, 009, 010 **only to the isolated database**. Confirm the duels feature flag starts disabled. Activate it only in the test database.
4. Create test training submissions and matching approved point_transactions using the same category, constraints and update semantics as production's training review RPC. Use transactions for test setup only.
5. After each case, query league_duels, league_duel_exp_ledger, point_transactions and league_duel_events. Compare total EXP and ledger consistency.

## Mandatory scenarios

| ID | Setup and action | Expected result |
|---|---|---|
| D01 | Boxer A invites B for 7 days; B accepts | pending → active; accepted_at and ends_at exactly 7 days apart |
| D02 | Coach creates A vs B; B accepts | Coach is creator but B still explicitly accepts |
| D03 | Boxer C attempts to accept A vs B | Authorization failure; invitation unchanged |
| D04 | Invite expired after 48 hours | Cannot activate; old pending slot can be released |
| D05 | A challenges self; 6-day duration; inactive boxer | All rejected without new duel |
| D06 | Four concurrent accepted duels involving A | Maximum 3 active duels; fourth acceptance rejected |
| D07 | A vs B and B vs A invitations at the same time | At most one pending invitation for unordered pair |
| D08 | Active duel reaches end; new invitation between same pair | Rematch allowed without deleting old audit/payout |
| D09 | Approved training A=100, B=60 within period; no pending | Winner A: +100 EXP; loser B: +25 EXP; league points +0 |
| D10 | Both scores 60 | Draw; +50 EXP each |
| D11 | Reconcile same completed duel twice | Exactly one duel_exp transaction per boxer; no extra EXP |
| D12 | One timely pending submission | No initial settlement; awaiting_reviews |
| D13 | Pending review arrives after end; coach approves then reconciles | Correct final score; one payout per boxer |
| D14 | Settled A wins; coach corrects qualifying training so B wins | Same two payout transaction IDs; A EXP 100→25, B 25→100; no duplicate transactions |
| D15 | Settled duel receives pending review | Remains settled with existing payout; returns pending_correction |
| D16 | Corrupt test-only ledger: transaction points to another boxer's payout | Reconciliation raises integrity error; no unrelated transaction changed |
| D17 | Non-coach invokes reconcile/reconcile_due | Permission error; no writes |
| D18 | Duels flag disabled | All invitation, read and reconciliation RPCs reject calls |
| D19 | Training created after duel end but backdated into period | Document current exclusion; obtain owner approval of policy before release |
| D20 | Boundary-date training submitted before accepted_at clock time | Document date-only inclusion; obtain owner approval of policy before release |
| D21 | Parallel training approval/edit and duel reconciliation | No deadlock, partial payout or inconsistent pending/scored state; review lock ordering |
| D22 | 250 settled duels; paginate p_after in 100-row batches | All 250 visited once per scan; stable ordering; no starvation |
| D23 | Failed second payout transaction during settlement | Whole reconciliation rolls back: no partial payout or settled status |
| D24 | Existing point transaction categories include custom values | Migration 009 does not silently narrow the category constraint; resolve compatibility first |
| D25 | Client reads raw duel tables without RPC grants | Denied; authorized RPC exposes only intended data |
| D26 | Two coaches reconcile the same duel simultaneously | Ledger remains unique and EXP paid once |
| D27 | Coach revisits a settled duel with unchanged scores | No new payout or duplicate settlement audit event |

## Release criteria

- All mandatory scenarios executed on isolated database with logged pass/fail results.
- No duplicate EXP, incorrect league points, partial settlement, privilege escalation, or deadlock.
- Confirm real review_training / admin_edit_training transaction categories and lock order.
- Explicit owner decisions on date-only boundary and late/backdated submission rules.
- Confirm current live point_transactions category CHECK before any alteration.
- Production remains unchanged until owner authorizes rollout.
