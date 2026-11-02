# Duel API and release contract

All functions described here are staged on the working branch. No managed Supabase migration or metric activation was performed.

## Default release state

The private `league_v21_private.duel_metric_config` has exactly two initial rows: `jogging_km` and `training_count`, both `enabled=false`, `reward_rule=NULL`, `jogging_training_type_id=NULL`. A client has no read/write grants on this table. New invitations require enabled **and** an explicit reward mapping; jogging also requires a configured active type ID. Neither no reward nor the existing ranked rule is selected implicitly.

Supported explicit mappings are `none` (no payout ledger/transaction) and `ranked_v21` (existing accepted rank-snapshot arithmetic, not a new economy). Synthetic fixtures exercise both and roll configuration changes back. No admin configuration UI/RPC was added; a later reviewed configuration/release action is required.

## Read and invitation APIs

| RPC | Parameters | Result |
| --- | --- | --- |
| `duel_v3_options` | none | `{metrics,training_types,visibility_options,timezone}` |
| `duel_v3_invite` | `p_challenger uuid,p_opponent uuid,p_duration_days integer,p_metric text,p_training_type_id bigint=null,p_visibility text='participants',p_expected_rule jsonb=null` | New duel UUID |
| `duel_v3_list` | `p_scope text='mine',p_state text='all',p_limit integer=20,p_before timestamptz=null,p_before_id uuid=null,p_search text=null,p_duel_id uuid=null` | `{items,next_cursor}` |
| `duel_v3_live_scores` | `p_duel_id uuid` | Aggregate numeric scores, pending, validity/provisional status, rule and period |

Options contain metric `{key,label,unit,enabled,disabled_reason,reward_rule,reward_label,revision,training_type_id,training_type_name}`, active training-type `{id,name,revision}` and visibility `{key,label}` records. The three metric keys are `points`, `jogging_km`, `training_count`. Jogging rejects a user-supplied type; the server configuration owns that ID, whose name and ID are exposed for review. Count requires an active exact bigint type ID. Points rejects a type filter.

Invitation requires `p_expected_rule={metric_revision: selectedMetric.revision, training_type_revision: selectedType.revision}`; use null for the type revision unless the metric is `training_count`. Although the signature has a default null, null is rejected with SQLSTATE `22023`. The server locks configuration/type rows before comparing their revisions. A changed rule, reward, jogging type or selected count-type definition raises `40001` without creating an invitation. Refresh options and obtain a new explicit review; do not retry silently with the new token. Disabled/unconfigured metrics remain blocked independently of the revision.

Invitation uses the existing v2 actor/pair/duration/expiry/participant locks and guards. A club-visible invitation requires both participants currently listed, active and not archived. The invitation's metric, type/name, visibility, reward mapping, timezone and time rule are snapshotted before commit, and cannot later be changed. The invited boxer sees the same contract via their list before acceptance. Existing `duel_v2_respond` retains its checks; the contract trigger computes the metric period on acceptance. Decline/withdraw behavior remains available through existing APIs.

List scope is `mine`, `club` or staff-only `staff`. A coach wanting the complete staff scope must request it explicitly; `mine` means participant ownership for every role. State is `all`, `pending`, `active`, `due` or `settled`. Limits are 1–50. Cursor fields must be provided together; `(invited_at,id)` sorts descending. Search is bounded to 100 characters and matched as a literal substring, not interpolated SQL. Optional `p_duel_id` retrieves an exact deep-linked agreement under the same authorization and scope, including old pending invitations beyond the latest page.

Each item contains v2 identity/status/date fields plus `starts_at`, `rule` and `scores`. `rule` has metric/label/unit/type/visibility/reward/time fields. `scores` is null before acceptance, otherwise `{challenger_score numeric,opponent_score numeric,pending,valid,provisional}`. Invalid live data produces null scores/`valid=false` in a list; direct live-score RPC fails closed. Settled results use stored values, not a fresh recomputation.

Club reads expose only accepted/active/completed explicitly visible contracts with both profiles still public. They return aggregate game information, not submissions, notes, emails, raw profile fields or financial transaction IDs. Guests and inactive/archived actors are denied. Private legacy contracts do not become club-visible.

## Preview and explicit close

`duel_v2_close_preview(p_duel_id uuid)` is points-only. `duel_v3_close_preview(p_duel_id uuid)` handles points and metrics. Both require active, non-archived coach/admin identity and perform no writes or row locks.

```text
{
 duel_id,status,starts_at,ends_at,
 rule:{metric,label?,unit,timezone,time_rule,reward_rule,...},
 scores:{challenger_score:numeric|null,opponent_score:numeric|null,
         pending:int,approved:int,rejected:int},
 winner_id:uuid|null,tie:boolean|null,provisional:true,
 can_close:boolean,can_correct:boolean,
 blockers:[{code,message}],
 rewards:[{boxer_id,planned_exp:int|null,booked_exp:int|null,
           delta_exp:int|null,transaction_id:uuid|null}],
 review_path:'coach.html',revision:string
}
```

Valid unpaid rows use `booked_exp=0`; an explicit `none` contract has planned/booked/delta all zero and no transaction. Invalid financial references use null and block completion. Metric previews include the inclusive display `start_day`/`end_day` and `end_exclusive=true` for the actual timestamp boundary. Points retains `legacy_inclusive_zurich_dates`.

`duel_v2_close_confirm` and `duel_v3_close_confirm` take `p_duel_id uuid,p_confirm boolean,p_expected_revision text`. Explicit true and the preview revision are required. The server locks participant profiles, the duel and relevant-period submissions in the existing order, refreshes the preview and compares the revision. Metric locking also covers other types in that period so type correction cannot race scoring. The scoring predicate still includes only the selected type.

```text
{
 outcome:'settled'|'preview_changed'|'in_progress'|'awaiting_reviews'|
         'pending_correction'|'blocked',
 preview:<fresh preview>,
 bookings:[{boxer_id,awarded_exp,transaction_id}],
 unchanged:boolean
}
```

The UI must not treat `preview_changed` as approval of the new result. Display the fresh preview and obtain another click if `can_close`/`can_correct`. A lost-response retry may return `preview_changed` with an already settled result; it returns the existing bookings and does not pay twice. A current settled revision returns `settled`/`unchanged=true`. A `none` result legitimately has `bookings=[]`; a ranked result must have two actual booking references. Pending/blocked outcomes do not imply the stored status was mutated.

The revision is a deterministic JSON fingerprint of the displayed contract/result/plan, not an authentication token. Actor checks and server locks remain authoritative. Existing direct v2 reconciliation remains available for points only; it never processes new metrics.

## Scoring and corrections

Metric periods start at the next local midnight after acceptance in `Europe/Zurich`, ending at the exclusive local midnight after 7/14 calendar days. DST days therefore need not be 24 hours. A relevant submission must have the selected type, training date inside the period and trusted `server_received_at` at/after the start and strictly before the end. Live scoring also excludes future receipt/training dates. Approved rows require one matching training/legacy-import points ledger, even when that ledger does not supply the metric's numeric value.

The additive receipt trigger always stamps `clock_timestamp()` on INSERT, overwriting supplied timestamps, and forbids any later timestamp change, including writes inside staff SECURITY DEFINER functions. Historical rows retain NULL; there is no claimed retroactive verification or backfill. An otherwise relevant approved/pending metric submission with a missing trusted receipt blocks scoring. Legacy points use `coalesce(server_received_at,created_at)` to preserve old NULL-receipt behavior while protecting every future submission from a forged `created_at`. Snapshot and settlement lock predicates use the same receipt rules.

Km sums `jogging_km` as PostgreSQL numeric. Null/negative/NaN/infinite distances are invalid, never estimated or silently zeroed. Count uses distinct approved submission IDs, not joined ledger-row counts. Timely relevant pending rows block close; rejected, late and wrong-type rows do not count/block.

Stored final numeric values stay fixed. Existing timely training corrections appear only in a staff correction preview and are persisted through explicit confirmation, with an audit event. New late submissions cannot enter the score. Ranked corrections reuse the two original reward transactions. A no-reward contract never acquires a payout just because configuration later changes.

Integer v2 reads/reconciler explicitly exclude new metric rows. The old anonymously readable integer history projects only legacy points with a NULL contract; every V3 contract, including points with participant/club visibility, is excluded. V3 settled lists enforce the agreed/current visibility. Legacy points history and payout behavior remain unchanged. V3 points contracts require both accepted rank snapshots; missing snapshots block the result instead of silently applying the legacy fallback. Archived actors are also denied by the legacy v2 list/batch entry guards.

## Notifications and rollback

Notification event keys are `duel:<uuid>:invited|accepted|declined|settled`, unique per recipient. Metric notices use the same snapshotted rule and stored numeric score/unit. Links target `/duels.html?duel=<uuid>`. Existing read markers are never reset. Corrections do not resend the initial settlement notification; the linked result reflects the current official value.

Apply points → event identity → metric generation with their verified v2/profile dependencies. Inspect the matching read-only preflight/postflight scripts before a separately authorized production release. No migration changes product flags or closes a competition.

Metric rollback refuses if any v3 contract/numeric metadata, configured release/reward mapping or non-NULL trusted receipt exists; use a forward fix to preserve agreements and timestamp evidence thereafter. This guard also applies when no V3 duel has been created. Empty-generation rollback restores legacy functions/end constraint and removes only unused metric/receipt structures. Points/notice rollback files refuse unsafe reversal while v3 APIs depend on them.

The new metric backend is tested locally; frontend option/invitation/metric-close presentation needs its own integration and browser evidence before eventual activation. Missing-RPC handling must fail closed. The default backend gate is intentional and must remain off until the explicit reward/type/release decisions are made.
