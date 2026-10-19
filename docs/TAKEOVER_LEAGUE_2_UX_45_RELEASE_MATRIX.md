> ⚠️ **ÜBERHOLT – historischer Entwicklungs- oder Release-Zwischenstand.** Frühere Aussagen wie «nicht veröffentlicht», «HOLD», «NICHT AUSGEFÜHRT» und «kein Live-Release» dürfen nicht mehr als aktueller Produktionsstatus gelesen werden.
> **Tatsächlich:** Takeover League 2.1 ist auf `main` (`4aae67e` → `4430bc4` → `0cd262e`) und mit der atomaren Migration `20261018231319` in Produktion. Echte Backup-/Restore-, Real-Login- und vollständige Security-Definer-Gates sind dadurch **NICHT** bestanden.
> **Verbindlicher aktueller Überblick:** [RELEASE_STATUS_2_1_2026-10-19.md](RELEASE_STATUS_2_1_2026-10-19.md). Der übrige Text bleibt unverändert als historische Momentaufnahme erhalten.

> **ARCHIVIERTER ZWISCHENSTAND.** Die Zahlen 34/45 und die einzelnen Freigabehinweise unten stammen aus einer früheren UX-Runde und sind nicht mehr aktuell. Massgeblich ist ausschliesslich [die aktualisierte 45-Punkte-Matrix](TAKEOVER_LEAGUE_2_UX_45_MATRIX_2026-10-18.md) mit **39 Code-integrierten, 5 Staging-/Flag-Funktionen und 1 eingeschränkten Rücknahmefunktion**. Kein Live-Release und keine vollständige produktive Abnahme.

# Takeover League 2.0 – UX-Nachverfolgung 1–45

Stand: 18.10.2026 · Branch: `release/takeover-league-2-ready` · **Kein Live-Release**

**34/45 Punkte sind im Release-Branch quellenbasiert umgesetzt oder durch vorhandene echte Seiten abgedeckt.** **11/45 Punkte sind nur teilweise bzw. unter Produktions-/Browser-/Berechtigungsvorbehalt integriert.** Das ist **keine Freigabe und kein 45/45-E2E-Ergebnis**. Alle 45 bedürfen vor dem Live-Release der Abnahme auf der tatsächlichen Zielumgebung.

| Nr. | UX-Punkt | Code-Status | Freigabe-Hinweis |
|---:|---|---|---|
| 1 | Persönliche Startseite | Im Branch integriert | Echte Seite/Navigation; volle Browserabnahme weiterhin ausstehend |
| 2 | Schnelltraining | Im Branch integriert | Echte Seite/Navigation; volle Browserabnahme weiterhin ausstehend |
| 3 | Aufgaben & Benachrichtigungen | Teilweise/offen | UI vorhanden; Notifications-Flag auf Produktion deaktiviert |
| 4 | Einheitliche Boxerprofile | Im Branch integriert | Echte Seite/Navigation; volle Browserabnahme weiterhin ausstehend |
| 5 | Suche & Filter | Im Branch integriert | Echte Seite/Navigation; volle Browserabnahme weiterhin ausstehend |
| 6 | Direkte Duellaktionen | Im Branch integriert | Echte Seite/Navigation; volle Browserabnahme weiterhin ausstehend |
| 7 | Trainer-Schnellfreigaben | Teilweise/offen | Nur admin ist berechtigt; echte coach-Rolle weiterhin nicht freigegeben |
| 8 | Zurücknavigation | Im Branch integriert | Echte Seite/Navigation; volle Browserabnahme weiterhin ausstehend |
| 9 | Trainingskalender | Im Branch integriert | Echte Seite/Navigation; volle Browserabnahme weiterhin ausstehend |
| 10 | Trainings-Streaks | Im Branch integriert | Echte Seite/Navigation; volle Browserabnahme weiterhin ausstehend |
| 11 | Fortschrittsgrafiken | Im Branch integriert | Echte Seite/Navigation; volle Browserabnahme weiterhin ausstehend |
| 12 | Challenge-Fortschritt | Teilweise/offen | Teilnahme-/Bewertungsfortschritt vorhanden, aber nicht alle numerischen Ziele automatisch messbar |
| 13 | Live-Duellübersicht | Teilweise/offen | Live-Score-RPC auf TEST bestanden, produktive Migration noch ausstehend |
| 14 | Favoriten & Vergleich | Im Branch integriert | Echte Seite/Navigation; volle Browserabnahme weiterhin ausstehend |
| 15 | Trainingsentwürfe | Im Branch integriert | Echte Seite/Navigation; volle Browserabnahme weiterhin ausstehend |
| 16 | Sichere Bestätigungen | Im Branch integriert | Echte Seite/Navigation; volle Browserabnahme weiterhin ausstehend |
| 17 | Änderungshistorie | Teilweise/offen | RLS-gesteuerte Status-Audit-Lesefunktion auf TEST; nicht alle Änderungen enthalten, produktiv ausstehend |
| 18 | Trainer-Gesamtübersicht | Teilweise/offen | Coach-Dashboard vorhanden, aber separate Rolle coach noch nicht gleichberechtigt |
| 19 | Hilfetexte | Im Branch integriert | Echte Seite/Navigation; volle Browserabnahme weiterhin ausstehend |
| 20 | Mobile Bedienung | Im Branch integriert | Echte Seite/Navigation; volle Browserabnahme weiterhin ausstehend |
| 21 | Kontextabhängige Schnellaktionen | Im Branch integriert | Echte Seite/Navigation; volle Browserabnahme weiterhin ausstehend |
| 22 | Training wiederholen | Im Branch integriert | Echte Seite/Navigation; volle Browserabnahme weiterhin ausstehend |
| 23 | Voreinstellungen | Im Branch integriert | Echte Seite/Navigation; volle Browserabnahme weiterhin ausstehend |
| 24 | Einheitliche Aktionsmenüs | Teilweise/offen | Bedienmuster noch nicht über alle Unterseiten vereinheitlicht |
| 25 | Eigene Rankingposition | Im Branch integriert | Echte Seite/Navigation; volle Browserabnahme weiterhin ausstehend |
| 26 | Fixierte Navigation | Im Branch integriert | Echte Seite/Navigation; volle Browserabnahme weiterhin ausstehend |
| 27 | Statusanzeigen | Im Branch integriert | Echte Seite/Navigation; volle Browserabnahme weiterhin ausstehend |
| 28 | Zwischenspeicherung | Im Branch integriert | Echte Seite/Navigation; volle Browserabnahme weiterhin ausstehend |
| 29 | Scrollposition behalten | Im Branch integriert | Echte Seite/Navigation; volle Browserabnahme weiterhin ausstehend |
| 30 | Sinnvolle leere Ansichten | Im Branch integriert | Echte Seite/Navigation; volle Browserabnahme weiterhin ausstehend |
| 31 | Coach-Aktionszentrale | Im Branch integriert | Echte Seite/Navigation; volle Browserabnahme weiterhin ausstehend |
| 32 | Sammelaktionen | Im Branch integriert | Echte Seite/Navigation; volle Browserabnahme weiterhin ausstehend |
| 33 | Boxer-Schnellansicht | Im Branch integriert | Echte Seite/Navigation; volle Browserabnahme weiterhin ausstehend |
| 34 | Zuletzt bearbeitete Boxer | Im Branch integriert | Echte Seite/Navigation; volle Browserabnahme weiterhin ausstehend |
| 35 | Aufgabenfilter | Im Branch integriert | Echte Seite/Navigation; volle Browserabnahme weiterhin ausstehend |
| 36 | Coach-Aktionsvorlagen | Im Branch integriert | Echte Seite/Navigation; volle Browserabnahme weiterhin ausstehend |
| 37 | Rückgängig-Funktion | Teilweise/offen | Echte irreversible Freigaben lassen sich nicht sicher durch einfachen Undo zurücknehmen |
| 38 | Kontrolle vor Sammelaktionen | Im Branch integriert | Echte Seite/Navigation; volle Browserabnahme weiterhin ausstehend |
| 39 | Automatische Aktualisierung | Im Branch integriert | Echte Seite/Navigation; volle Browserabnahme weiterhin ausstehend |
| 40 | Direktzugriff auf Boxer | Im Branch integriert | Echte Seite/Navigation; volle Browserabnahme weiterhin ausstehend |
| 41 | Lade- und Fehlermeldungen | Im Branch integriert | Echte Seite/Navigation; volle Browserabnahme weiterhin ausstehend |
| 42 | Schutz vor Doppeleingaben | Teilweise/offen | Anfrage-ID-Eindeutigkeit auf TEST bestanden, Migration produktiv ausstehend |
| 43 | Mobile Bottom-Sheets | Im Branch integriert | Echte Seite/Navigation; volle Browserabnahme weiterhin ausstehend |
| 44 | Kürzere Klickwege | Teilweise/offen | Klickanzahl pro Standardaufgabe noch nicht in Browser-E2E gemessen |
| 45 | Einheitliche Bedienmuster | Teilweise/offen | Visuelle/Interaktions-Konsistenz nicht vollständig browserübergreifend überprüft |

## Nachweise
- `boxer.html`: Auth, Trainingsübersicht, Sessionsentwürfe, Kalender, Streak, Wochenaktivität, Notifications-Panel, Audit-Panel, Trainingswiederholung, Eingabeschutz
- `coach.html`: echte Freigaben über `review_training`, 20er-Sammelauswahl, Vorschau-Dialog, Audit, Vorlagen über `challenges.html`, Aktivitätsfilter, Shortcuts
- `index.html`, `index-my-position.js`, `boxer-profile.*`, `boxer-compare.html`: öffentliche Profile, Ranking, eigene Position, Vergleich, Favoriten
- `duels.html`, `challenges.html`: bestehende Supabase-RPCs, polling bei Sichtbarkeit, sichere Bestätigungen; Live-Duell-Zwischenstand und aggregierter Challenge-Review-Fortschritt
- `takeover-navigation.js`, `takeover-ux-scroll.js`: zugängliche mobile Navigation und Scrollwiederherstellung
- `supabase/migrations/20261018190000_training_drafts_v2.sql`, `20261018200000_training_submission_idempotency.sql`, `20261018210000_duel_v2_live_scores.sql`, `20261018220000_training_audit_reader.sql`: nur TEST ausgeführt.

Alle Schema-Erweiterungen im TEST ersetzen **keine** Produktivmigration und keine signierten HTTP-End-to-End-Tests.
