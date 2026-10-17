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

## Release contract
- Existing league points remain unchanged by duel/challenge rewards.
- Achievement reward accounting is independent.
- No public write permissions to settlement ledger.
- Boxer writes go through authorization-checked RPCs, not direct unrestricted table writes.
- All data migrations first reviewed/tested in an isolated database; live Supabase is production only.
