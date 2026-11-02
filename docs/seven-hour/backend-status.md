# Backend audit and continuation state

Updated: 2026-11-02 08:16 UTC. This is an audit and implementation handoff, **not a completed backend release**.

## Scope and execution boundary

- Production `iqarjivcrddcixrvqbfb`: read-only metadata/function inspection only. No writes, migrations, flag changes, closures or rewards.
- Test `cfgdvcccsqwfjajuizsr`: confirmed healthy; schema/function inspection only. No synthetic write test was run.
- No backend migration is ready or applied. An empty CLI-generated migration was removed rather than shipping a misleading no-op.
- No v3 API described below exists as a result of this work. Frontend must retain existing v2 operation and fail closed for unavailable previews/new metrics.
- Initial parent budget ended 07:10 UTC. The next explicit clock check returned 08:16 UTC; major implementation stopped. Do not claim completed scoring, role, concurrency, SQL, or authenticated end-to-end tests.

## Verified installed contract

`public.duel_v2_live_scores(uuid)` delegates to `league_duel_private.duel_v2_live_scores_core(uuid)`. `public.duel_v2_reconcile(uuid)` delegates to `league_v21_private.duel_reconcile_ranked_core(uuid)`.

Current scoring uses approved submissions and matching `point_transactions` with category `training` or `legacy_import`. Legacy dates are inclusive from the Zurich acceptance date to the Zurich end date. Timely submissions satisfy `created_at <= ends_at`. Pending timely submissions prevent first settlement. Settlement locks participant profiles, then the duel, then relevant submissions in deterministic order. Duplicate and missing scoring ledgers fail closed. Live scoring checks duplicates, but does not implement the same missing-ledger check. This code difference is not evidence that production data is damaged.

Rank snapshots are captured at acceptance. Settlement requires zero snapshots for legacy or exactly two matching participant snapshots. Verified rewards:

| Rule | Outcome | EXP |
| --- | --- | --- |
| Legacy, no rank snapshots | Tie / winner / loser | 50 / 100 / 25 |
| Ranked | Tie | 50 each |
| Ranked winner | Equal rank indices | 100 |
| Ranked winner | Winner rank index below loser index | 150 |
| Ranked winner | Otherwise | 50 |
| Ranked loser | Loser rank index above winner index | -50 |
| Ranked loser | Otherwise | 25 |

Do not reinterpret rank-index ordering in UI without checking the rank definition. A unique `(duel_id, boxer_id)` reward ledger points to one `duel_exp` transaction per boxer. Corrections update that transaction, with integrity checks for missing/orphaned/mismatched ledgers. No new metric reward mapping has been approved.

The installed invite/respond functions preserve a 48-hour invitation expiry, 7/14 day durations, active-boxer checks, same-pair exclusion and active-duel limits. New metric contracts must preserve these guards.

`training_submissions.jogging_km` is numeric and `training_type_id` is bigint. Production training types currently include active `Joggen` with ID 6. This is audit evidence, not permission to infer future semantics from arbitrary labels. New configuration should bind a verified type ID, not let caller-supplied names authorize scoring. Count metrics must count distinct submission IDs without ledger joins multiplying the count.

`league_duels.challenger_score` and `opponent_score` are integer columns. A numeric metric implementation must not truncate distances into these fields or continue labelling them as training points. Preserve old v2 return types and use an explicit numeric contract/value representation.

The installed `league_v21_private.sync_public_duel_history()` copies settled integer scores/names into `league_public_duel_history_v21`. Extending this trigger naively would publish incorrect values or broaden visibility. Private legacy duels must not be exposed by a new general SELECT policy.

## Seasons and messages

The current season close path is `league_v21_private.season_transition_core`, mirrored by `20261028110000_season_single_active_next_draft.sql`. All actions currently require admin. It locks the season, rejects premature closure, locks period training, blocks pending reviews, snapshots listed active non-archived boxers, writes HoF from those results and prepares a next season as **draft**. It does not pay a new season bonus. Its close-date comparison uses `current_date`; a future change should make the Zurich boundary explicit.

New coach authority must be a narrow close permission. Activation, configuration and archival must remain separately authorized. A preview must be read-only; closing must revalidate under lock rather than trusting the preview.

Notifications are inserted directly into `boxer_notifications`; there is no general `notify_profile` helper. `league_v21_private.notifications_enabled()` gates emission. Existing duel message deduplication relies on text/time checks, and settlement text uses integer training points. A future first migration should add nullable `event_key` and a partial unique index `(recipient_id,event_key) WHERE event_key IS NOT NULL`; existing rows need not be rewritten. New writers must key the real duel/period event and use a precise result link. This column/index has **not** been added.

Public snapshot readers must recheck current profile visibility while keeping official snapshot ranks and values immutable. A reconstructed October ranking must remain labelled reconstructed; do not create retrospective official awards or payouts.

## Proposed v3 API, not implemented

The UI agent received this provisional shape. It is a design draft and must not be presented as an installed contract:

```text
duel_v3_options() -> {
  metrics:[{key,label,unit,enabled,disabled_reason,reward_rule,reward_label}],
  training_types:[{id,name}],
  visibility_options:[{key,label}], timezone:'Europe/Zurich'
}
duel_v3_invite(p_challenger uuid,p_opponent uuid,p_duration_days int,
  p_metric text,p_training_type_id bigint default null,
  p_visibility text default 'participants') -> uuid
duel_v3_list(p_scope text='mine',p_state text='all',p_limit int=20,
  p_before timestamptz=null,p_before_id uuid=null,p_search text=null) -> {
  items:[existing v2 identity/status fields + rule:{metric,unit,label,
    training_type_id,training_type_name,visibility,reward_rule,reward_label,time_rule},
    scores:{challenger_score numeric,opponent_score numeric,pending},starts_at,ends_at],
  next_cursor:{before,before_id}|null
}
```

New metrics remain disabled until a documented reward mapping is explicitly selected; even no reward is a business decision. Points duels retain legacy time semantics. New metric periods start at next Zurich midnight after acceptance and end at the exclusive midnight after 7/14 full calendar days, including DST. Snapshot metric/type/period/reward/visibility at invitation/acceptance, and prevent subsequent contract changes.

## Next concrete backend package

1. Create a migration using the CLI. Implement additive contract/numeric value storage, nullable notification event identity, strict private helpers and explicit public wrapper grants.
2. Extract a common score/validation helper used by live, preview and settlement. Preserve legacy reward and correction logic; retain submission and payout ledger checks.
3. Implement v3 options/invite/list and read-only closure preview. Guard permissions using active `profiles` records and `auth.uid()`, fixed `search_path`, no user metadata authorization. Private legacy remains participants/staff only; club summaries require explicitly agreed visibility and currently listed profiles.
4. Implement narrow explicit coach close with fresh locks/revalidation, reward contract snapshot and idempotent result. Do not expose new metric invites before reward configuration exists.
5. Add separate immutable month snapshots and paginated period readers, preserving existing season generation and next-draft behavior. No historical closure on deploy.
6. Run real transaction-isolated SQL fixtures in the confirmed test project or local Postgres. Cover all roles, decimal km, type filtering, pending/rejected/late submissions, missing/duplicate ledgers, null distance, tie/zero, DST/month boundaries, accepted contract immutability, read-only preview and two concurrent closers. None of these new-path tests ran in this work.

## Tooling

Official Supabase CLI v2.122.0 was downloaded from the upstream release and its version verified at:

`C:/Users/bendi/Documents/Codex/tools/supabase-2.122.0/supabase.exe`

No `psql` or Docker executable was found on PATH. CLI `migration new --help` was inspected. Do not apply DDL through the read-query tool. Production remains read-only. Any later shared test migration needs isolation/restoration consistent with the user request.

The Supabase skill and changelog were read. Current relevant timezone updates concerned Vancouver, Edmonton and Casablanca, not Zurich. No authentication or production database configuration was changed.
