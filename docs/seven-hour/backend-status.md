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

- Existing points duels keep inclusive Zurich acceptance/end dates and their economy. Historical rows with no trusted receipt retain `created_at <= ends_at`; future rows use the authoritative server receipt for that cutoff.
- Legacy rewards remain tie 50 each, winner 100, loser 25. Ranked rewards remain tie 50; winner same rank index 100, lower index 150, otherwise 50; loser with higher index -50, otherwise 25.
- Live, preview and settlement now share scoring validation. Missing/duplicate scoring ledgers fail closed; broken previews show null scores rather than believable partial/zero totals.
- Existing profile → duel → submission lock order, rank snapshots, payout-ledger integrity, transaction reuse and correction events remain.
- New metric contracts are immutable from invitation; accepted period/participants/duration/type/reward cannot change. New metrics start next Zurich midnight for 7/14 full local days with an exclusive end.
- Invitations compare the explicitly reviewed metric/type revisions under server locks. Changed rules/rewards/types return `40001` without creating an agreement; exact-ID lookup obeys the same list authorization.
- New submissions receive an immutable server timestamp even when authenticated boxer/coach clients or staff functions supply a forged `created_at`/receipt. There is no historical receipt backfill; missing historical receipt on a relevant approved/pending metric row fails closed.
- Km uses exact PostgreSQL numeric sums of the configured type. Missing, negative or nonfinite distance fails closed. Count uses distinct approved submission IDs of exactly the selected valid type.
- Only timely relevant submissions count/block. Pending reviews prevent closure; rejected, wrong-type, late and out-of-period submissions do not count.
- Metric settlement stores numeric final values separately. Old v2 points reads/reconcile and the integer public-history projection cannot process these rows.
- New metric results stay fixed until a reviewed explicit correction. Configuration changes do not alter an invited contract.
- Club aggregate access requires an explicit club contract and currently active/listed/non-archived participants; legacy private rows are not opened to spectators or guests.
- All V3 contracts, including points, are excluded from the anonymously readable legacy integer history. V3 points require both agreed rank snapshots; archived v2 readers are denied.
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
| Metric concurrency: explicit none / ranked | PASS: second session waited 2052 / 2045 ms; one settlement; zero / exactly two payout transactions |
| Empty metric rollback/reapply | PASS: old game data unchanged, metrics still disabled/unconfigured |
| Populated metric rollback guard | PASS: refuses to discard stored agreements; results/payouts unchanged |
| `duel-receipt-authority-transaction.sql` | PASS with actual authenticated boxer/coach roles: supplied past/null receipts overwritten, direct/definer timestamp changes blocked, late forged rows excluded from points and metrics, old NULL receipts retained |
| `duel-v3-points-privacy-transaction.sql` | PASS with actual anonymous/third-boxer roles: private and club V3 points absent from public history, authorized club aggregates visible, missing rank snapshots fail closed, archived v2 readers denied |
| `duel-receipt-rollback-guard.cjs` | PASS: a trusted receipt alone prevents evidence-destroying rollback before any V3 agreement exists |
| Reviewed invitation revisions and deep links | PASS: missing token rejected, changed mapping/type returns `40001` without insert, exact pending-ID lookup retains authorization |
| `node tests/release-static-contracts.cjs` | PASS, 33/33 |

The first concurrency timing attempt exposed a harness issue: psql buffered a marker in a single `-c`. Separate commands fixed the measurement; the final tests observed actual lock contention. No product assertions were weakened.

The final complete CI order was replayed from a fresh database (`league21_replay_duel_final_chain`) on local PostgreSQL 17.11: points schema/regressions → legacy boundaries → staff queue and rollback → points concurrency → points rollback → notification identity and rollback → metric bootstrap/migration → metric contracts/ranked/privacy/receipt/legacy-boundary suites → empty metric rollback/reapply → receipt-only rollback guard → count concurrency with no reward and ranked reward → populated metric rollback guard. Every stage passed without test changes. The fresh-chain contention waits were 2034 ms for points, 2035 ms for count/no reward and 2051 ms for count/ranked. The shared cluster already had its two test roles, so only a temporary local baseline copy skipped those two CREATE ROLE statements; repository fixtures were unchanged. Evidence: `C:/Users/bendi/Documents/Codex/tools/pg-core17/duel-final-chain.log`.

Additional final CI steps passed independently: `duel-metrics-api-contracts.cjs` bridges genuine SQL JSON from three invitations/results to the actual UI validators; Studio schema → JS parity → rollback/reapply covers 1202 own history rows and all eight achievement groups. Evidence: `C:/Users/bendi/Documents/Codex/tools/pg-core17/duel-studio-final-bridge.log`.

All eight new migrations also coexist in one isolated clone (`league21_replay_combined_final`): points, archive, notice identity, staff queue, metrics, period close, period notices and Studio. The only fixture completion added the production-like training columns `duration_minutes integer`, `club_tier text`, `training_location text` and `recorded_by uuid`. Actual authenticated/admin READ ONLY calls jointly exercised duel options/list/previews/queue, archive, period preview/notices and Studio history/summary; anonymous archive reading also passed. Metrics remained disabled/unconfigured, no periods were closed or dismissed, and the receipt trigger remained enabled. This detects schema/helper collisions; it is not managed Auth, production migration, device acceptance or a real payout test. Evidence: `C:/Users/bendi/Documents/Codex/tools/pg-core17/combined-migrations-final.log`.

## Narrow browser regression found during final CI review

The first remote Takeover 3 browser failure at the double-click submission was reproducible with a real Chromium browser and ordinary scrolling: a fast successful insert replaces the form, putting “Zur Trainingsübersicht” under the second click. The confirmation then closes despite exactly one successful insert. The same risk applies to “Weiteres Training”. Both success-action handlers now ignore click events with `detail > 1`; submission/ownership/reward logic is unchanged.

`tests/training-success-doubletap-browser.cjs` failed against the original code, then passed for both actions in Chromium and WebKit. It explicitly proves that the second real click reaches the new action, that the success remains visible with one insert, and that ordinary single-click and Enter activation still work. Two consecutive final runs passed. Geometric calibration waits for existing browser layout stability; the test does not move controls with CSS or weaken the success assertion. This is browser-engine coverage, not physical iPhone/Android acceptance or proof for every device's touch-event sequence.

Local binaries/logs: `C:/Users/bendi/Documents/Codex/tools/pg-core17/`. Logs include `duel-preview-tests.log`, `duel-points-boundaries.log`, `duel-preview-rollback.log`, `duel-notification-tests.log`, `duel-notification-rollback.log`, `duel-metric-final-rollback.log`, `duel-receipt-authority.log`, and `duel-final-regressions.log`. Independent source review identified three privacy/rank/auth gaps and the client-writable receipt risk; all four were fixed and covered by database tests, then the receipt delta was reviewed again with no further blocker found.

## Rollout and rollback boundaries

Read-only preflight/postflight and prepared rollback files are in `supabase/production-prep/`, named after each migration. They do not authorize production execution.

Apply points before notification identity before metric generation. Metrics require current v2 invite/respond, ranked snapshots, profile archive/listing and event-identity dependencies. The queue/period migrations owned by other agents have their own ordering and checks.

Points rollback restores previous functions without reversing game data. Notification rollback restores the previous writer while retaining identity/index/messages/read state. Both refuse unsafe reversal once metric APIs depend on them. Metric rollback is empty-generation only: any stored contract, numeric result, configured mapping or trusted receipt blocks it; preserve agreements/receipt evidence and use a forward fix thereafter.

## Remaining separate work

- Product UI integration and browser evidence are owned by the UI agent. Backend independent review and the documented SQL fixes are complete; no metric activation is authorized.
- PostgreSQL 16/17 CI results are separate from the local 17.11 runs and must not be claimed until received.
- Managed Supabase Auth/browser integration and manual/physical-device acceptance were not performed.
- Queue, period/archive/close and visual packages are owned by the parent/other agents; see their evidence separately.
- Production migration, merge, deployment and any real closure/reward require their separate explicit authorization.

Each migration filename was created with official Supabase CLI `migration new` (CLI 2.122.0). The local server also hosts independent synthetic archive, Studio and UI fixtures for other agents; stop it once all agents finish testing.
