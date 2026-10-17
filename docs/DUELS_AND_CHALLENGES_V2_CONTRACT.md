# Takeover League 2.0 — Duel & Coach Challenge implementation contract

**Source:** Previously agreed user requirements. No invented game mechanics.

## Head-to-head duels
- Either a boxer or the coach can issue a challenge. **Recipient acceptance is always required**, including coach-issued duels.
- Pending invitation expires after **48 hours**. Duel starts immediately when accepted.
- Duration **7 or 14 days**, counted from acceptance.
- At most **3 active duels per boxer**.
- At most **one active duel and one pending invitation per unordered boxer pair**. Rematch permitted immediately after the previous duel's period has ended (even if settlement waits for approvals).
- Score is the sum of **approved training points**, using training dates within the duel window. Only training points count; bonuses and achievement EXP do not.
- After scheduled end, do not settle until all **timely submitted** training entries potentially affecting either boxer have been reviewed. A pending submission can delay settlement.
- Winner gets **100 EXP**, loser **25 EXP**, draw **50 EXP each**. These are EXP only, not league points; no monthly EXP cap.
- Award exactly once per boxer per duel. Corrections to eligible training submissions after settlement must recompute scores/outcome and adjust EXP accordingly without duplicating payouts. Preserve audit history.
- Guard against self-duels, stale acceptance, unauthorized initiator, unauthorized acceptor, and duplicate settlement.

## Coach Challenges (separate from head-to-head duels)
- Voluntary opt-in. Duration **7, 14 or 30 days**.
- Individual goal rewards: **50 / 100 / 200 EXP**, depending on agreed challenge target.
- Competition payouts: 1st **150 EXP**, 2nd **100 EXP**, 3rd **50 EXP**. Minimum **3 participants**. Ties share rank and associated reward. Award once.
- Coach goals: **25 EXP**.
- Need explicit challenge-specific goal definition and eligibility rules before implementing evaluation; do not assume goals, scoring metrics, or whether a particular coach challenge is competition versus goal.

## Coach challenge opt-in implementation boundary

The review-only RPCs support coach draft creation, draft publication,
pre-activation cancellation, boxer opt-in and withdrawal while enrollment
is open. Withdrawal preserves the entry with status `withdrawn` instead
of deleting its audit record. **Rejoining after withdrawal is not yet
supported**; its policy must be agreed before implementation. Opening
enrollment is not the same as activating the timed challenge. Challenge
targets, scoring, rank/tie payouts and activation remain deliberately
unimplemented pending explicit goal definitions and release review.

## Individual challenge goals (owner decision 2026-10-17)
- The coach defines each challenge-specific target; a universal fixed goal is not assumed.
- Support both **manual coach verification** and **automatic verification based on approved training entries**.
- Manual completion decisions must be authorized, auditable and rewarded at most once; boxers cannot self-approve.
- Draft goal authoring stores the explicit goal text, review mode and optional positive numeric target. **This is configuration only**; the automatic metric (e.g. approved jogging kilometres versus training sessions), event window, manual review workflow and payout are not implemented by migration 017.
- No challenge timer, automatic evaluation or EXP award may be activated from an incomplete goal definition.

## Approved-training progress contract
- Automatic goals use an explicitly selected metric: approved jogging kilometres or approved technique minutes.
- Count only approved submissions in the eventual challenge window; pending and rejected entries never contribute.
- Date-only training entries require a consistent Switzerland-local boundary policy.
- Browser data must never authorize a reward; settlement must recheck server-side records.
- Manual goals require coach approval with an audit trail.
- No EXP payout is authorized by goal configuration or a progress preview.

## Release contract
- Existing league points remain unchanged by duel/challenge rewards.
- Achievement reward accounting is independent.
- No public write permissions to settlement ledger.
- Boxer writes go through authorization-checked RPCs, not direct unrestricted table writes.
- All data migrations first reviewed/tested in an isolated database; live Supabase is production only.
