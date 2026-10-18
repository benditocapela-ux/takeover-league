# Takeover League 2.0 – 45-Punkte-UX-Release-Matrix
Stand: 18.10.2026, Branch `release/takeover-league-2-ready`.

**Statusdefinition:** `Code integriert` heisst: im Release-Branch mit statischen/CI-Prüfungen, NICHT vollständige echte Browser-Abnahme. `Staging/Flag`: im Code vorhanden, benötigt zusätzliche produktive Migration oder Freischaltung. `Teilweise`: nur Teile des akzeptierten UX-Umfangs umgesetzt. `Offen`: benötigt neue Implementierung.

| Nr. | Optimierung | Status | Nachweis/Abhängigkeit |
|---:|---|---|---|
| 1 | Persönliches Dashboard | Code integriert | boxer.html |
| 2 | Training schnell einreichen | Code integriert | boxer.html |
| 3 | Aufgaben und Benachrichtigungen | Staging/Flag | boxer.html; Supabase notifications flag; `20261018230000_notification_mark_read.sql` – echte Inbox mit sicherem Lesestatus im TEST geprüft |
| 4 | Einheitliche Boxerprofile | Code integriert | boxer-profile.html; boxer-profile.js |
| 5 | Suche und Filter | Code integriert | coach.html; index.html |
| 6 | Direkte Duellaktionen | Code integriert | boxer-profile.js; duels.html |
| 7 | Trainer-Schnellfreigaben | Code integriert | coach.html |
| 8 | Zurück-Navigation | Code integriert | takeover-navigation.js |
| 9 | Trainingskalender | Code integriert | boxer.html |
| 10 | Trainings-Streaks | Code integriert | boxer.html |
| 11 | Fortschrittsgrafiken | Code integriert | boxer.html |
| 12 | Challenge-Fortschritt | Code integriert | challenges.html: Laufzeit, Coach-/Boxerbewertung, bestätigte Eigenleistungen bei automatischen Zielen; keine EXP-Vergabe im Frontend |
| 13 | Live-Duellübersicht | Staging/Flag | duels.html; 20261018211000_duel_v2_live_scores.sql |
| 14 | Favoriten & Boxer-Vergleich | Code integriert | boxer-compare.html |
| 15 | Trainingsentwürfe | Staging/Flag | boxer.html; 20261018190000_training_drafts_v2.sql |
| 16 | Sichere Bestätigungen | Code integriert | coach.html; duels.html |
| 17 | Änderungshistorie | Staging/Flag | coach.html; 20261018210000_coach_training_audit_read.sql |
| 18 | Coach-Gesamtübersicht | Code integriert | coach.html |
| 19 | Hilfetexte | Code integriert | boxer.html; challenges.html |
| 20 | Mobile Bedienung | Code integriert | takeover-navigation.css; boxer-dashboard-polish.css; takeover-quick-actions.js; Chromium mobile Tests (echte Endgeräte nicht getestet) |
| 21 | Kontextabhängige Schnellaktionen | Code integriert | boxer.html; coach.html |
| 22 | Training wiederholen | Code integriert | boxer.html |
| 23 | Intelligente Voreinstellungen | Code integriert | boxer.html |
| 24 | Einheitliche Aktionsmenüs | Code integriert | takeover-quick-actions.js: einheitlicher Dialog und kontextbezogene Schnellaktionen mit Rollensichtbarkeit |
| 25 | Eigene Rankingposition | Code integriert | index-my-position.js |
| 26 | Fixierte Navigation | Code integriert | takeover-navigation.css |
| 27 | Klare Statusanzeigen | Code integriert | boxer.html; coach.html |
| 28 | Zwischenspeicherung | Code integriert | boxer.html |
| 29 | Scrollposition behalten | Code integriert | takeover-ux-scroll.js |
| 30 | Sinnvolle leere Ansichten | Code integriert | boxer.html; coach.html |
| 31 | Coach-Aktionszentrale | Code integriert | coach.html |
| 32 | Sammelaktionen | Code integriert | coach.html |
| 33 | Boxer-Schnellansicht | Code integriert | coach.html |
| 34 | Zuletzt bearbeitete Boxer | Code integriert | coach.html |
| 35 | Aufgabenfilter | Code integriert | coach.html |
| 36 | Coach-Aktionsvorlagen | Code integriert | challenges.html |
| 37 | Sicheres Rückgängig | Teilweise | coach.html; 20261018213000_admin_undo_recent_rejection.sql – nur eigene Ablehnung innerhalb 15 Min., ohne verknüpfte Buchung; bestätigte Punkte ausschliesslich über geprüfte Admin-Korrektur |
| 38 | Prüfung vor Sammelaktionen | Code integriert | coach.html |
| 39 | Automatische Aktualisierung | Code integriert | coach.html; duels.html; challenges.html |
| 40 | Direktzugriff auf Boxer | Code integriert | coach.html |
| 41 | Lade- und Fehlermeldungen | Code integriert | boxer.html; coach.html |
| 42 | Schutz vor Doppeleingaben | Staging/Flag | boxer.html; 20261018200000_training_submission_idempotency.sql |
| 43 | Mobile Bottom-Sheets | Code integriert | coach.html |
| 44 | Kürzere Klickwege | Code integriert | boxer.html Aufgaben/Links; coach.html Sammelaktionen; takeover-quick-actions.js: Direktaktionen |
| 45 | Einheitliche Bedienmuster | Code integriert | takeover-navigation.js; takeover-quick-actions.js; Dialoge, Navigation, Lade-/Fehleranzeigen und zugängliche Buttons |

**Bilanz:** 39/45 im echten Release-Code integriert, 5/45 als Staging/Flag integriert und für produktive Migration/Freischaltung vorbereitet, 1/45 teilweise/sicherheitsbedingt begrenzt (#37), 0/45 ungeplant. **Keine Freigabe zu behaupteten 45/45 produktiv abgeschlossen.** Die Zahl 34 ist **kein** End-to-End-Fertigstellungsgrad; vollständige produktive Abnahme aller 45 = **nicht nachgewiesen**.

**Release-Grenzen:** #3 Feature-Flag derzeit aus. #13, #15, #17 und #42 benötigen geprüfte produktive SQL-Migrationen. #37 ist auf sichere, punktlose Ablehnungsrücknahmen beschränkt (im TEST inkl. RLS, Replay-Sperre, Audit und Null-Ledger-Guard geprüft); bereits bestätigte/vergütete Trainings gehen weiter über die bestehende kontrollierte Admin-Korrektur. #12/#20/#24/#44/#45 besitzen jetzt reale Benutzeroberflächen, serverseitig geschützte Datenabfragen oder gemeinsame Navigation. Die jeweiligen finalen Live-/Endgeräte-Abnahmen sind weiterhin ausstehend.

**Tests:** SQL-Rollenchecks auf isoliertem TEST für privaten Entwurf, persönliche Challenge-Zuweisung, Admin-Audit und Live-Duell-Zugriff; DB-Retry-ID-Eindeutigkeit transaktional überprüft. JSDOM/statische Regressionen auf GitHub Actions sind kein Ersatz für signierte HTTP- und reale Gerätesimulationen.


## Integrationsrunde – 18.10.2026: offene UX-Punkte
- `boxer.html`: Eigene offene Trainings und Direktaktionen unter „Meine nächsten Schritte“ (#3), private Cloud-Entwürfe bei vorhandener RLS-Tabelle mit 1,3 Sekunden Debounce, expliziter Löschung und Sitzungs-Fallback (#15), unverändert idempotente Einreichung bei verfügbarem Request-ID-Index (#42).
- `challenges.html`: Laufzeitbalken, Teilnahmestatus, Review-Fortschritt; bei automatischen Metriken nach authentifizierter Anmeldung ausschliesslich eigene bestätigte Trainingssummen ohne automatische EXP-Vergabe (#12).
- `takeover-quick-actions.js`: einheitliche schnelle Navigation mit responsivem Bottom-Sheet und `Ctrl/⌘+K`; verborgene Coach-Abschnitte werden beim Öffnen ausgefiltert (#20,24,44,45).
- `duels.html`, `coach.html`: einheitlicher Schnellzugriff. Vorhandene Live-Scores (#13), Audit-Historie (#17), Undo (#37) bleiben serverseitig abgesichert und weiterhin an die jeweilige Migration gebunden.
- Ohne die separat genehmigte produktive Migration oder Freischaltung bleiben #3 (Inbox), #13, #15 (Cloud), #17 und #42 **Staging-Funktionen**. UI-Konsistenz und Tests sind nicht mit einem nachweislich funktionierenden Live-Feature gleichzusetzen.

**Inbox-Nachtrag:** Die im produktiven Schema vorhandenen Trigger für Trainingsfreigabe/Coach-Feedback und die Besitzer-RLS wurden read-only überprüft. Neue `mark_my_notification_read`-RPC im isolierten Supabase-TEST: Besitzerzugriff, Fremdzugriff, wiederholte Ausführung und anonyme Rechte geprüft. Funktion bleibt bei produktiv ausgeschaltetem Flag deaktiviert; keine Live-Freischaltung erfolgt.
