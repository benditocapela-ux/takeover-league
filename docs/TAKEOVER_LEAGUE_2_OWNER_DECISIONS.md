# Takeover League 2.0 — owner decisions (review only)

No production SQL, deploy, merge or feature activation is authorized by this document.

## Decisions required for first production migration

| ID | Question | Current implementation | Owner decision |
|---|---|---|---|
| C1 | Reward options for approved manual challenge reviews | Coach chooses 25, 50, 100, 150 or 200 EXP per challenge; every approved participant receives that amount | **Approved by owner, 2026-10-18** |
| C2 | Rejected manual challenge review | 0 EXP, but review and zero-value ledger entry are recorded | **Approved by owner, 2026-10-18** |
| C3 | Withdrawal then rejoin while challenge is open | Rejoin permitted; active duplicate join rejected | **Approved by owner, 2026-10-18** |
| C4 | Automatic challenge settlement | Disabled; manual goal reviews only can settle | **Approved by owner, 2026-10-18** |
| C5 | Production SQL operator | No operator named or authorized | Pending |
| C6 | Backup and restore plan | Not verified against live Supabase | Pending |

## Approval scope

The owner explicitly approved C1–C4 in conversation on 2026-10-18. This is **policy approval only**, not authorization for production SQL, migration, deployment, merge, or feature-flag activation. C5 and C6 remain pending.

## Already specified by owner

Training points: boxing 50, sparring 70, technique 40, strength 30, sprint intervals 40, jogging 20.

Coach-only bonuses: feedback video 25, strong sparring progress 50, individual fight analysis 40.

Approved point history visible to all boxers; weight private and optional; individual goals can be manual.

These training points and coach bonuses are **not** the same as the proposed challenge EXP rewards in C1.

## Release discipline

Do not mark pending decisions approved by inference, silence or repeated “go” messages. “Go” authorizes continued work on the development branch, not a production change. Confirm decisions explicitly and separately from any later production SQL instruction.

The first production SQL must be prepared as an exact, reviewable script with preflight, expected results and stop conditions. The owner requires an unmistakable **ALL-CAPS instruction** before being asked to execute SQL.
