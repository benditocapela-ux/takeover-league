# TAKEOVER LEAGUE 2.0 — GO-LIVE GATE & OPERATOR RUNBOOK
Stand: 18.10.2026 · Staging branch: `release/takeover-league-2-ready` · Draft-PR #8

**Status: HOLD — NO PRODUCTION DEPLOYMENT AUTHORIZED.**
This document is the exact release gate, not an instruction to execute production migrations automatically.
`main` and production Supabase must remain untouched until a separate approved GO LIVE **after the gate has passed**.

## Verified automatically or in TEST
1. Supabase TEST `cfgdvcccsqwfjajuizsr`: private RLS draft owned by the authenticated boxer, training request-id uniqueness, isolated personal coach challenge targeting, admin-only training audit, participant-only duel live scores, 15-minute same-admin undo of a rejected training without ANY linked point transaction, and avatar RPC anon privilege removal.
2. Critical denied paths were tested using transaction-scoped role/JWT-context simulation (`SET LOCAL ROLE authenticated`; `auth.uid()`), with ROLLBACK. This is NOT a substitute for a real signed Supabase Auth REST session.
3. GitHub V2 Integration Checks: PostgreSQL 16 and 17 migration/schema role tests, concurrency tests, personal-target privacy, rewards, and activation/disable rehearsal PASS.
4. GitHub staging validation: JSDOM and static contracts, Chromium 375/768/1280 public UI plus mocked authenticated Boxer/Coach workflow on mobile PASS.
5. The PostgreSQL 16/17 CI now includes an actual pg_dump/pg_restore of **synthetic** staging fixtures, verifying restored record counts; it does not verify a real production backup.
6. Production was queried READ-ONLY: 13 active boxers, 56 approved trainings, 0 approved submissions lacking regular or legacy ledger, 0 rejected submissions with nonzero linked awards, 0 duplicate linked transactions. Snapshot must be repeated immediately before release.

## Release SQL — prepared, NOT executed in production
Follow only verified additive migrations required by the live schema, in this order:

1. `supabase/migrations/20261018170000_private_boxer_challenge_assignment.sql` (tested on production-like disposable PostgreSQL 16 & 17; isolated Supabase TEST requires alias compatibility because preexisting V2 functions have different return types).
2. `supabase/migrations/20261018190000_training_drafts_v2.sql` (boxer-private draft RLS).
3. `supabase/migrations/20261018200000_training_submission_idempotency.sql` (unique partial index on boxer/request ID).
4. `supabase/migrations/20261018210000_coach_training_audit_read.sql` (admin-only audited history).
5. `supabase/migrations/20261018211000_duel_v2_live_scores.sql` (participant-only provisional score).
6. `supabase/migrations/20261018213000_admin_undo_recent_rejection.sql` (same admin / 15 min / no linked ledger / audited).
7. `supabase/migrations/20261018214000_avatar_rpc_permissions.sql` (revoke anon for avatar setter; preserve authenticated boxer role).
8. `supabase/migrations/20261018220000_training_audit_reader.sql` (limited own-training history).
9. `supabase/migrations/20261018230000_notification_mark_read.sql` (idempotent inbox read acknowledgement for the owning authenticated boxer only; RLS and flag stay in force).

There is only one migration per timestamp in the current release diff. Do not include `supabase/test-only/` fixtures in production. Inspect `supabase_migrations.schema_migrations` or the project's migration history before applying; if a schema object already exists, reconcile deliberately, never blind DROP/REPLACE or overwrite history.

## Remaining operational release gates (MUST pass)
- [ ] **Production backup and restore**: obtain a current, restorable backup/PITR checkpoint under the owner's account, restore to an isolated copy, compare row counts and permissions. The connected tools do not provide a production backup export or restore operation, so this gate is NOT certified.
- [ ] **Real Supabase Auth**: dedicated non-production boxer, admin and coach credentials; sign in with actual HTTPS JWTs. Verify owners can only read/write own private fields; anon and other boxers cannot approve, view notes/weight, read audit/targets or obtain private duels. TEST SQL impersonation and browser SDK mocks alone do NOT close this gate.
- [ ] **Feature scope**: approve exclusions or finish all 45 required UX items. Current matrix has 34 code-integrated, five staged/flagged, five partially and one partial guarded undo (now six partial and zero entirely missing). Approval as a complete 45-point release is NOT yet demonstrated.
- [ ] **Auth security**: enable Supabase Auth leaked-password protection in project settings (Security Advisor warns it is off); check account security, MFA and password-reset flows.
- [ ] **RLS/privileged RPC audit**: re-run advisors; public leaderboard/award/level read RPCs are intentional read-only surfaces. `is_league_admin()` returns false for anonymous and is referenced by RLS; do not revoke it blindly. `update_my_boxer_avatar()` anon execution is denied by staged migration. 54 authenticated SECURITY DEFINER functions were scanned; five public read functions and an admin-wrapper lacked direct auth markers but the wrapper calls an admin-checked function. Perform final independent security review on the production-equivalent migrated schema.
- [ ] **Real devices**: manually verify iOS Safari and Android Chrome on actual devices, login, training submit, status, charts, coach batch action, duel acceptance, challenge, rejection undo, offline/slow network and refresh.
- [ ] **Role policy**: production `review_training` is intentionally admin-only; user must ensure the actual trainer account is active `admin`. Do not silently widen rights to `coach`.
- [ ] **Final CI**: every required workflow green against the final, frozen release SHA with no mismatched branch or partial run; record SHA.
- [ ] **Post-migration smoke**: signed HTTPS tests and integrity baseline, rerun security advisors and snapshot comparisons BEFORE merging to `main` or exposing new UX. Verify privately staged RPCs have no `anon` privileges.
- [ ] **Feature flags**: enable only explicitly approved features, one at a time after verification. `achievements`, `notifications`, `performance_dashboard`, `coach_feedback` were disabled at the last read-only check.

## Activation / emergency strategy
Before changing anything, record the release SHA, current Pages artifact SHA, database backup ID, feature-flag state, counts and a reachable rollback operator.
If staging database tests and signed Auth gate pass, apply reviewed SQL in order under the user's explicit production authorization. Then verify point/EXP history, duel/challenge ledgers, RLS and preview routes. Merge and deploy only when all gates are PASS and the user says GO LIVE.

To recover the frontend, revert to the recorded known-good Pages commit. For new features, disable only the new feature flags via reviewed emergency SQL rather than destroying data. Schema migrations are additive: DO NOT blindly reverse them after real user data is written. Restore requires the verified backup/PITR plan and a planned maintenance window.

**NO LIVE until operational checks are completed. Passing CI alone is insufficient.**


---

## Änderungsvermerk – UX-Finalisierung, 18.10.2026

Die im Release-Branch zuvor als teilweise bezeichneten UX-Punkte #12, #20, #24, #44 und #45 besitzen jetzt funktionsfähige, automatisiert browsergetestete Integrationen in den wirklichen Seiten. Auch #3 hat eine aktive persönliche Aufgabenübersicht, während die Benachrichtigungs-Inbox weiterhin nur bei aktiviertem Flag geladen wird. Der private Cloud-Entwurf (#15) wird nach Inaktivität automatisch gespeichert, sobald seine geprüfte Migration produktiv verfügbar ist.

**Codebilanz vor Freischaltung:** 39 UX-Punkte im realen Code integriert; fünf weitere besitzen funktionsfähige Staging-/Feature-Flag-Integrationen (#3, #13, #15, #17, #42); #37 bleibt auf die sichere Rücknahme unvergüteter, abgelehnter Trainings beschränkt. Die vollständige Codeabdeckung darf nicht als 45 erfolgreich live geprüfte Funktionen ausgegeben werden.

### Vom Eigentümer ausdrücklich zurückgestellte Prüfungen
- **Kein vorgezogenes Produktionsbackup/Restore verlangt:** Der Benutzer akzeptiert ausdrücklich das Verlustrisiko. Weder die CI-Fixture noch Supabase TEST ersetzen eine echte Produktivsicherung. Vor unvermeidlichen destruktiven Migrationen trotzdem Stop statt Datenrisiko akzeptieren; additive Migrationen bevorzugen.
- **Keine realen Benutzeranmeldungen vor dem Live-Release verlangt:** Auth-/RLS-Zugriffe wurden auf TEST durch Rollensimulation und lokal im Browser durch Mock-Supabase überprüft, nicht durch reale signierte JWTs. Direkt nach einem allfälligen GO LIVE sind echte Boxer-/Admin-Login-Smoke-Tests die erste Priorität, bevor alle Boxer die neuen Funktionen verwenden.
- Diese Waiver sind **keine bestandenen Tests** und keine Sicherheitsgarantie. Es bleibt Aufgabe des Releaseoperators, das Restrisiko bei der separaten GO-LIVE-Entscheidung zu berücksichtigen.

### Verbleibende technische Aktivierungsabhängigkeiten
- Migrationsliste oben vollständig auf produktionsgleicher Struktur und in richtiger Reihenfolge prüfen, bei GO LIVE nur notwendige additive SQL-Stücke unter expliziter Freigabe anwenden.
- Prüfen, ob Feature-Flag `notifications` und weitere derzeit deaktivierte Anzeigen nach serverseitiger Prüfung aktiviert werden sollen. Privilegien und RLS vor jeder Aktivierung erneut validieren.
- Trainer-Berechtigung: die Produktions-RPC `review_training` bleibt absichtlich `admin`-only; `coach` erhält durch neue UI keine impliziten Sonderrechte.
- Code-Seiten `boxer.html`, `coach.html`, `challenges.html`, `duels.html` veröffentlichen neu `takeover-quick-actions.js` per bestehender statischer `*.js`-Kopie im GitHub-Pages-Workflow.
- **Nicht freigegeben:** `main`-Merge, produktives SQL, produktive Feature-Flags, Live-Pages. Dies bleibt einem getrennten GO LIVE vorbehalten.

### Inbox-Abnahme nach expliziter Produktionsmigration
Bei GO LIVE erst Migration `20261018230000_notification_mark_read.sql` anwenden und die RLS-/Funktionsrechte überprüfen, **danach** bei Freigabe das Feature-Flag `notifications` aktivieren. Bestehende Produktions-Trigger erzeugen Benachrichtigungen nur für neue Freigaben/Ablehnungen und bei aktivierten Flags; alte Trainings erhalten nicht rückwirkend Mitteilungen. Der Browser übersetzt den bestehenden Triggerpfad `/boxer.html` in eine sichere Projekt-URL. Der Button `Als gelesen markieren` ruft ausschliesslich `mark_my_notification_read` auf. Aktivierung nie ohne gesicherte Rechte- und UI-Prüfung.
