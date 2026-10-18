# Takeover League 2.0 – Produktions-Release vom 18. Oktober 2026

## Verifiziert: veröffentlicht

- Supabase-Projekt: `iqarjivcrddcixrvqbfb` (Produktion).
- SQL-Migration `takeover_v2_secure_achievement_recalculation_20261018`: erfolgreich; direkter anonymer und authentifizierter Zugriff auf die interne Achievement-EXP-Neuberechnung entzogen, postgres und service_role behalten Rechte.
- SQL-Migration `takeover_v2_coach_challenges_20261018131000`: erfolgreich; 4 RLS-Tabellen, 17 Funktionen.
- SQL-Migration `takeover_v2_duels_20261018133000`: erfolgreich; 3 RLS-Tabellen, 6 Funktionen.
- SQL-Migration `takeover_v2_activate_coach_challenges_and_duels_20261018`: erfolgreich; beide Backend-Feature-Flags auf **true**.
- Postflight-Abfrage: `release_integrity_passed=true`, alle 23 geschützten RPCs, 7 RLS-Tabellen, 0 defekte EXP-Ledger; nach Aktivierung nochmals bestätigt.
- GitHub-PR #3 erfolgreich als Squash in `main` gemerged (SHA `509afc385b2febb3a38e755cc4cee7ed553f110d`); beide Frontend-Feature-Flags gemeinsam im Commit `611da428f24e8729c54210b48bd0c9159e9d1017` aktiviert.
- GitHub-Pages-Deployment: [Workflow #39132702934](https://github.com/benditocapela-ux/takeover-league/actions/runs/39132702934) **success**. Sein abschliessender Live-HTTP-Test hat beide V2-Seiten sowie Homepage und Login-/Boxer-/Coach-Dashboards erfolgreich abgerufen.

## Öffentliche Seiten

- [Startseite](https://benditocapela-ux.github.io/takeover-league/)
- [Coach Challenges](https://benditocapela-ux.github.io/takeover-league/challenges.html)
- [Boxer-Duelle](https://benditocapela-ux.github.io/takeover-league/duels.html)

## Datenstand nach Aktivierung (read-only Kontrollabfrage)

| Merkmal | Wert |
|---|---:|
| Profile | 14 |
| Trainingsmeldungen | 61 |
| Punktetransaktionen | 66 |
| Punkte insgesamt | 2230 |
| EXP insgesamt | 2230 |
| Neue Challenges | 0 |
| Neue Duelle | 0 |
| Aktive V2-Flags | 2 |

Die vor dem Release vorhandenen Aggregate waren dieselben. V2-Migration und Aktivierung haben keine Trainings-, Profil- oder EXP-Buchungen hinzugefügt.

## Bewusst akzeptierte Risiken & nächste Schritte

Der Nutzer hat ausdrücklich zugestimmt, **ohne Datenbankbackup** und **ohne vorherige echte Login-/Benutzer-End-to-End-Tests** zu veröffentlichen. Ein Datenverlust ist ohne Backup potenziell irreversibel. Die Bestätigung der Web-Seiten per HTTP und die SQL-/RLS-/CI-Tests **sind kein Ersatz für reale Benutzer-/Geräteprüfungen**.

Erster Schritt: mit wenigen echten Boxern und dem Admin Login, Challenges, Duelle, Trainingsansicht, Freigaben und EXP verifizieren, **bevor** die Funktionen breit eingesetzt werden. Falls ein kritischer Defekt auffällt, zuerst `supabase/production-prep/emergency_disable_v2_flags_only.sql` auf Produktion ausführen und anschliessend die beiden Frontend-Flags wieder deaktivieren; bestehende Tabellen/EXP nicht löschen.

Es verbleiben Supabase-Security-Advisor-Warnungen bei älteren öffentlich zugänglichen SECURITY-DEFINER-RPCs (nach Patch: 7), Schutz vor geleakten Passwörtern und RLS-Tabellen ohne Policies (absichtlich nicht öffentlich zugänglich). Diese Warnungen sind separat zu priorisieren; nicht pauschal als behoben deklarieren.

Die Details der ursprünglichen Release-Kontrollen stehen in `docs/RELEASE_NACH_FREIGEBEN.md` sowie den read-only SQL-Preflight- und Postflight-Skripten.
