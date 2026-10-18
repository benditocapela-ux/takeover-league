# Takeover League 2.0 – Foundation (development only)

This branch is isolated from main. No production database changes or deployment are included.

## Confirmed existing architecture
- Static GitHub Pages HTML: index.html, login.html, boxer.html, coach.html, features.html, awards.html.
- Supabase: 21 public tables, 34 public functions, RLS enabled on all 21 tables (per owner-supplied SQL metadata).
- Training approval: review_training inserts point_transactions with equal training points and EXP.
- Admin correction: admin_edit_training edits transaction and logs training_audit; admin_edit_training_details changes jogging_km and technique_minutes **after** that audit entry.
- Existing get_boxer_exp_level_rank uses compounded 15% thresholds, capped recursive level generation at 150.
- index.html additionally calculates public levels locally with fixed LEVEL_RANKS.
- Public leaderboard uses calendar-month points; planned seasons are quarterly.
- Existing login/navigation gates on profiles.is_active, conflicting with departed members' read-only access.

## Phase 1 scope
1. Read-only preview of current lifetime EXP under the new uncapped linear progression.
2. Audit database function grants, triggers and FK/unique/check constraints before writing migrations.
3. Define immutable/correctable EXP ledger and safe correction propagation.
4. Plan unified admin edit that records jogging_km/technique_minutes in the same audit snapshot.
5. Update backend and all frontend level displays atomically in a tested release.
6. Preserve lifetime EXP and points; never reset historical balances.

## New level formula
- Level 1 starts at 0 EXP.
- Cost from level L to L+1 = 100 + 25*(L-1).
- Start EXP for level L = 100*(L-1)+25*(L-1)*(L-2)/2.
- No level cap.
- Level 2: 100; level 3: 225; level 10: 1800; level 11: 2125; level 20: 6175.

## Release gates
- Compare all boxer EXP and old/new levels before any migration.
- Verify no public RLS data leak and all SECURITY DEFINER role checks.
- Validate correction scenarios: approved->rejected, date change, boxer transfer, jogging/technique edit, bonus reversal.
- Verify seasonal closure needs admin reason and audit; duel/challenge corrections settle consistently.
- Test logged-out, boxer, coach/admin, paused, left account flows.
- Rollback and backups ready; explicit owner approval before deploying to main or executing SQL migrations.

## Known unknowns
- Actual function bodies for achievements, duel/challenge settlement, bonuses and notifications.
- Full FK/unique/check constraints, indexes and RPC execute grants.
- Live data quality and any existing duplicate point transactions.
- Whether SQL Editor is using privileged role: preview output contains boxer names and must remain private.

## Current deliverables
- supabase/diagnostics/01_exp_level_preview.sql (read-only)
- This document (implementation and validation plan)
