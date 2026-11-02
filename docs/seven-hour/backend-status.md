> Zwischencheckpoint: Das Metrikpaket 20261102095422 und seine Tests befinden sich noch im lokalen Review und folgen in einem eigenen Commit. Die nachstehenden Metriknotizen beschreiben diesen Arbeitsstand, keine Freigabe und keine bereits in diesem Commit enthaltene Migration. Punktevertrag/Event-Identität sind enthalten und separat getestet.

# Backend implementation and verification

Updated during the user-authorized continuation on 2 November 2026. The initial timed turn ended with an audit-only handoff; the following packages were implemented after “fahre weiter”.

## Delivered on the working branch

| Migration | Behavior |
| --- | --- |
| `20261102084519_duel_points_shared_preview_close.sql` | Shared legacy points scorer/reward arithmetic; live missing-ledger protection; read-only staff preview; explicit close/correction with revision revalidation and actual booking references |
| `20261102093606_duel_notification_event_identity.sql` | Nullable event identity, unique recipient/event index, exact duel links, distinct simultaneous results without duplicate alerts |
| `20261102095422_duel_metric_contracts_disabled.sql` | Complete numeric km and distinct training-count contracts/APIs, full Zurich calendar periods, immutable agreements, explicit visibility, disabled/unconfigured release and reward mappings |

No production or managed Supabase test-project writes, migrations, flag changes, real closures, payouts or account changes occurred. All writes/tests used synthetic local PostgreSQL databases. No merge or deployment.

New metrics remain **disabled** and `reward_rule=NULL`. Jogging also has no configured training-type ID. A later explicit business/release decision must select the verified jogging ID, reward mapping and release state; no client can edit this private configuration.

## Preserved rules and changed behavior

- Existing points duels keep inclusive Zurich acceptance/end dates and timely `created_at <= ends_at`. Their agreed periods and economy are not changed.
- Legacy rewards remain tie 50 each, winner 100, loser 25. Ranked rewards remain tie 50; winner same rank index 100, lower index 150, otherwise 50; loser with higher index -50, otherwise 25.
- Live, preview and settlement now share scoring validation. Missing/duplicate scoring ledgers fail closed; broken previews show null scores rather than believable partial/zero totals.
- Existing profile → duel → submission lock order, rank snapshots, payout-ledger integrity, transaction reuse and correction events remain.
- New metric contracts are immutable from invitation; accepted period/participants/duration/type/reward cannot change. New metrics start next Zurich midnight for 7/14 full local days with an exclusive end.
- Km uses exact PostgreSQL numeric sums of the configured type. Missing, negative or nonfinite distance fails closed. Count uses distinct approved submission IDs of exactly the selected valid type.
- Only timely relevant submissions count/block. Pending reviews prevent closure; rejected, wrong-type, late and out-of-period submissions do not count.
- Metric settlement stores numeric final values separately. Old v2 points reads/reconcile and the integer public-history projection cannot process these rows.
- New metric results stay fixed until a reviewed explicit correction. Configuration changes do not alter an invited contract.
- Club aggregate access requires an explicit club contract and currently active/listed/non-archived participants; legacy private rows are not opened to spectators or guests.
- Event keys distinguish invitations/acceptances/declines/settlements by duel ID and recipient. Existing messages/read state are retained; corrections do not resend the initial settlement alert.

Detailed API and release contract: [backend-v3-api.md](backend-v3-api.md).

## Real verification executed

Environment: official EDB **PostgreSQL 17.11**, local loopback `127.0.0.1:55481`. Existing production-like fixtures and actual historical RPC/migration sources were replayed. This is real SQL/database integration evidence, not a mocked interpreter, Supabase Auth login, remote test-account flow or physical device test.

| Test | Result |
| --- | --- |
| `duel-points-preview-schema.sql` and transaction suite | PASS: migration replay, missing/duplicate ledger, pending, reward plan, no preview writes, stale revision, actual bookings, retry, explicit correction, role guards |
| Existing underdog and missing-ledger regression transactions | PASS: original 150/-50 payout and idempotency preserved |
| `duel-points-boundaries-transaction.sql` | PASS: legacy Zurich/DST boundaries, exact/late cutoff, rejected/foreign ledgers, participant/third/guest/inactive/archived roles, negative totals |
| `duel-points-preview-concurrency.cjs` default mode | PASS: two real sessions; second waited 2030 ms; one event and two legacy tie payouts |
| Points rollback/reapply | PASS: all duel/transaction/ledger/event/inbox JSON witnesses unchanged |
| Notification identity and rollback suites | PASS: two identical same-minute results each notify both recipients; repeat/correction dedup; read state/deep links; historical rows and identity retained |
| `duel-metric-contracts-transaction.sql` | PASS: disabled/unconfigured gates, actual invite/acceptance, pair guards, immutable contract, 3.35 vs 3.30 km, exact 2 vs 1 count, wrong/missing type, missing/NaN distance, duplicate ledger, pending/late/rejected data, privacy, pagination, no-reward close, stored result and explicit correction |
| `duel-metric-ranked-transaction.sql` | PASS: explicitly selected existing reward mapping, zero/tie, 150/-50 actual payout, missing-ledger/stale-preview guard, retry |
| Metric DST periods | PASS: autumn 7 full days = 169 hours, spring = 167 hours; 14-day month crossing |
| Metric concurrency: explicit none / ranked | PASS: second session waited 2029 / 2037 ms; one settlement; zero / exactly two payout transactions |
| Empty metric rollback/reapply | PASS: old game data unchanged, metrics still disabled/unconfigured |
| Populated metric rollback guard | PASS: refuses to discard stored agreements; results/payouts unchanged |
| `node tests/release-static-contracts.cjs` | PASS, 33/33 |

The first concurrency timing attempt exposed a harness issue: psql buffered a marker in a single `-c`. Separate commands fixed the measurement; the final tests observed actual lock contention. No product assertions were weakened.

Local binaries/logs: `C:/Users/bendi/Documents/Codex/tools/pg-core17/`. Logs include `duel-preview-tests.log`, `duel-points-boundaries.log`, `duel-preview-rollback.log`, `duel-notification-tests.log`, `duel-notification-rollback.log`, `duel-metric-latest.log`, `duel-metric-contracts-final.log`, `duel-metric-rollback.log`.

## Rollout and rollback boundaries

Read-only preflight/postflight and prepared rollback files are in `supabase/production-prep/`, named after each migration. They do not authorize production execution.

Apply points before notification identity before metric generation. Metrics require current v2 invite/respond, ranked snapshots, profile archive/listing and event-identity dependencies. The queue/period migrations owned by other agents have their own ordering and checks.

Points rollback restores previous functions without reversing game data. Notification rollback restores the previous writer while retaining identity/index/messages/read state. Both refuse unsafe reversal once metric APIs depend on them. Metric rollback is empty-generation only: any stored contract, numeric result or configured mapping blocks it; preserve agreements and use a forward fix thereafter.

## Remaining separate work

- Product UI integration and independent review of the new metric path; no metric activation is authorized.
- PostgreSQL 16/17 CI results are separate from the local 17.11 runs and must not be claimed until received.
- Managed Supabase Auth/browser integration and manual/physical-device acceptance were not performed.
- Queue, period/archive/close and visual packages are owned by the parent/other agents; see their evidence separately.
- Production migration, merge, deployment and any real closure/reward require their separate explicit authorization.

Each migration filename was created with official Supabase CLI `migration new` (CLI 2.122.0). The local server is shared only with the root agent's independent synthetic archive fixture; stop it once all agents finish testing.
