# Takeover League 2.1 – Integrationsstand und Release-Gates
Stand: 18. Oktober 2026 · Entwicklungsbranch: `develop/takeover-league-2.1-all-features` · PR #11 **Draft**.

**HOLD – KEIN GO LIVE FÜR 2.1.** Die bestehende Takeover League 2.0 bleibt auf `main` und produktiver Supabase unverändert.

## Neun Bereiche, aktueller REALER Implementierungsstand

| Bereich | Neue echte Code-Bestandteile | Stand / offene Arbeit |
|---|---|---|
| Achievement-Automatik und Nachvergütung | `league_v21_reconcile_achievements` (admin-only; max. 25 Boxer pro Aufruf, bestehender ledgergesicherter Reconciler), `league-manager.html`; öffentlicher, synchronisierter Badge-Snapshot | **Teilweise**: Test-Admin-Runde mit ROLLBACK erfolgreich. Kein produktiver Backfill. Ausstehend: Massentest bei echten historischen Daten, Auszeichnungen auf realem Account und bestätigte EXP-Integrität. |
| Duell-EXP und Mehrgegner | Rangabhängige, **auszahlungsfreie Vorschau** `league_v21_duel_reward_quote`: gleich +100; gegen höheren Rang +150; gegen tieferen +50; -50 für besiegten höher eingestuften Favoriten | **Nicht fertig**: Reale Duellabrechnung nutzt weiterhin ihre alte Ledger-Logik. Ein weiterer Tool-Test der Quote wurde durch Sicherheitschecks blockiert. Keine Umgehung, keine Auszahlung, keine Mehrgegner-Duellabrechnung. |
| Erweitertes Boxerprofil | Öffentlicher Radar aus vorhandenen freigegebenen Liga-RPCs, Badge-Sammlung und persönliche Rekorde (bestätigte Sessions, Trainingstage, maximale Jogging-/Technik-Einheit). `league_public_badges_v21`, `league_public_records_v21`, `boxer-profile.html/.js` | **Code integriert (Staging)**: Projektion/Entzug von Badges und Admin-Synchronisierung von Rekorden im TEST geprüft; private Daten bleiben verborgen. Noch fehlend: reale Nutzersitzung und Freigabe. |
| Individuelle Ziele | Private Ziel-/Fortschrittstabellen mit RLS, Boxer-Eingabe `goals.html`, Admin-Zuweisung im `league-manager.html`; `league_v21_save_goal`, `league_v21_record_goal_progress` | **Code integriert (Staging)**: eigene Ziele, bestätigte automatische Messwerte und manuelle Schritte. Fremdzugriff im TEST abgewehrt. Noch offen: automatische Abschlussbelohnung mit eigener ledgergesicherter Prüfregel. |
| Head-to-Head | `boxer-compare.html`: fünf öffentliche Kategorien, visuelle Gegenüberstellung und Favoriten | **Code integriert**: Kategorienvergleich ist kein historischer Duellrekord. Echte gegnerbezogene Duellbilanz noch offen. |
| Hall of Fame & Palmarès | `league-history.html`, öffentliche Ehrungen und Saison-Podiumshistorie | **Code integriert (Staging)**: Saison-Titel/Podium werden beim validierten Saisonabschluss einmalig angelegt. Freie manuelle Palmarès-Ehrungen oder weitere Titelarten noch nicht umgesetzt. |
| Saisons | `league_seasons_v21`, `league_season_results_v21`, `league_v21_admin_create_season`, `league_v21_admin_season_action`, Admin UI | **Code integriert (Staging)**: nur Admin, Draft → active → closed, unveränderlicher Ranking-Snapshot; Admin-/Rollback-Test bestanden. Automatischer Abschlussplaner noch offen. |
| Liga-Challenges | `league_global_challenges_v21`, `league_global_entries_v21`, `league-challenges.html` mit Teilnahme und bestätigtem Fortschritt, Admin-Erstellung/-Veröffentlichung in `league-manager.html` | **Code integriert (Staging)**: idempotenter Join und Fremddaten-Schutz im TEST bestanden. Siegerlogik, Punkte/EXP-Vergaben, öffentliche Endrangliste offen. |
| Feature-Integration | Menü `takeover-navigation.js`, Trainer-Schnellaktionen, gemeinsame 2.1-Seiten | **Code integriert**: alle 2.1-Module in einem Entwicklungsbranch; produktive Feature-Flags bewusst unverändert. |

## Testnachweise
- Neue Tabellen für Ziele, manuelle Fortschrittsbuchungen, Saisons, Saisonergebnisse, Hall of Fame, Global Challenges, private Anmeldungen, öffentliche Badges und öffentliche Rekorde **nur in isoliertem Supabase TEST** installiert.
- Rollen/RLS: Boxer darf eigenes Ziel anlegen und manuellen Fortschritt erfassen, aber kein Fremdziel verändern; Global Challenge Join ist idempotent und Boxer können fremde Anmeldungen nicht sehen.
- Saison-Admin: Boxer kann keine Saison erstellen; Admin kann Draft aktivieren und abgelaufene Saison einmalig abschliessen, bei Wiederholung keine Doppelbuchung. Transaktion mit ROLLBACK.
- Achievements: Nicht-Admin abgewiesen; Admin verarbeitet zwei Boxer im transaktionalen Test, ROLLBACK, bestehende EXP-Ledgerfunktion wiederverwendet.
- Public Badge-Snapshot: Insert/DELETE trigger synchronisiert mit den privaten Earned-Badges; ROLLBACK, anon nur SELECT.
- Public Records: Admin-Sync verarbeitet zwei Boxer, Nicht-Admin abgewiesen. Kein Zugriff auf Gewicht/Notizen; ROLLBACK. Der anfängliche Fehler `max(uuid)` wurde korrigiert und erneut erfolgreich geprüft.
- `tests/league-21-foundations.cjs` ist in die bestehenden Github-Release-Validierungsschritte eingebunden. GitHub CI gegen Draft-PR #11 beachten.

## Vor einem 2.1-GO-LIVE weiterhin nötig
1. Duell-EXP in der **tatsächlichen** Coach-Reconcile-RPC vollständig, ledger-idempotent und mit getesteten historischen Korrekturen implementieren. Kein Umgehen der vorhandenen Tool-Sicherheitsblockade für den separaten Quote-Test.
2. Mehrgegner-Wettkämpfe, Endränge/Sieger und Belohnungen für globale Challenges inklusive Duplikatschutz implementieren.
3. Individuelle Zielerreichung und einmalige EXP-Vergaben ohne clientseitiges Vertrauen implementieren.
4. Historische Achievement-Nachberechnung mit repräsentativen Daten auf isoliertem TEST prüfen, inklusive Wiederholung und Rücknahme; keine blinde Massenbuchung auf Produktion.
5. Saison-Ergebnisse nach Abschluss an echten Daten und mit Abweichungen/Korrekturen testen; Live-API-Rechte und Schema-Exposition prüfen.
6. Browser-/Auth-End-to-End-Tests für neue Seiten, Responsive UI, echte Admin- und Boxerrollen; Supabase Security Advisor.
7. Separates GO LIVE für 2.1 einholen. Keine Migrationen oder Feature-Flags produktiv aktivieren, kein Merge von PR #11 ohne vollständige Gate-Prüfung.

**Wichtig:** Die neun Bereiche werden gemeinsam entwickelt und aufeinander abgestimmt, aber dieser Stand ist eine umfangreiche **Staging-Integration**, kein vollständiges 2.1-Release.
