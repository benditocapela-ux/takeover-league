# Takeover League 2.0 – 45-Punkte-UX-Release-Matrix
Stand: 18.10.2026, Branch `release/takeover-league-2-ready`.

**Statusdefinition:** `Code integriert` heisst: im Release-Branch mit statischen/CI-Prüfungen, NICHT vollständige echte Browser-Abnahme. `Staging/Flag`: im Code vorhanden, benötigt zusätzliche produktive Migration oder Freischaltung. `Teilweise`: nur Teile des akzeptierten UX-Umfangs umgesetzt. `Offen`: benötigt neue Implementierung.

| Nr. | Optimierung | Status | Nachweis/Abhängigkeit |
|---:|---|---|---|
| 1 | Persönliches Dashboard | Code integriert | boxer.html |
| 2 | Training schnell einreichen | Code integriert | boxer.html |
| 3 | Aufgaben und Benachrichtigungen | Staging/Flag | boxer.html; Supabase notifications flag |
| 4 | Einheitliche Boxerprofile | Code integriert | boxer-profile.html; boxer-profile.js |
| 5 | Suche und Filter | Code integriert | coach.html; index.html |
| 6 | Direkte Duellaktionen | Code integriert | boxer-profile.js; duels.html |
| 7 | Trainer-Schnellfreigaben | Code integriert | coach.html |
| 8 | Zurück-Navigation | Code integriert | takeover-navigation.js |
| 9 | Trainingskalender | Code integriert | boxer.html |
| 10 | Trainings-Streaks | Code integriert | boxer.html |
| 11 | Fortschrittsgrafiken | Code integriert | boxer.html |
| 12 | Challenge-Fortschritt | Teilweise | challenges.html; coach-challenge-progress.js |
| 13 | Live-Duellübersicht | Staging/Flag | duels.html; 20261018211000_duel_v2_live_scores.sql |
| 14 | Favoriten & Boxer-Vergleich | Code integriert | boxer-compare.html |
| 15 | Trainingsentwürfe | Staging/Flag | boxer.html; 20261018190000_training_drafts_v2.sql |
| 16 | Sichere Bestätigungen | Code integriert | coach.html; duels.html |
| 17 | Änderungshistorie | Staging/Flag | coach.html; 20261018210000_coach_training_audit_read.sql |
| 18 | Coach-Gesamtübersicht | Code integriert | coach.html |
| 19 | Hilfetexte | Code integriert | boxer.html; challenges.html |
| 20 | Mobile Bedienung | Teilweise | takeover-navigation.css; boxer-dashboard-polish.css |
| 21 | Kontextabhängige Schnellaktionen | Code integriert | boxer.html; coach.html |
| 22 | Training wiederholen | Code integriert | boxer.html |
| 23 | Intelligente Voreinstellungen | Code integriert | boxer.html |
| 24 | Einheitliche Aktionsmenüs | Teilweise | takeover-navigation.js; coach.html |
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
| 37 | Sicheres Rückgängig | Offen | nicht umgesetzt: sicherer Punkte-/EXP-Rollback erforderlich |
| 38 | Prüfung vor Sammelaktionen | Code integriert | coach.html |
| 39 | Automatische Aktualisierung | Code integriert | coach.html; duels.html; challenges.html |
| 40 | Direktzugriff auf Boxer | Code integriert | coach.html |
| 41 | Lade- und Fehlermeldungen | Code integriert | boxer.html; coach.html |
| 42 | Schutz vor Doppeleingaben | Staging/Flag | boxer.html; 20261018200000_training_submission_idempotency.sql |
| 43 | Mobile Bottom-Sheets | Code integriert | coach.html |
| 44 | Kürzere Klickwege | Teilweise | coach.html; boxer.html |
| 45 | Einheitliche Bedienmuster | Teilweise | takeover-navigation.js; shared CSS |

**Bilanz:** 34/45 in den realen Code integriert, 5/45 als Staging/Flag vorbereitet, 5/45 teilweise umgesetzt, 1/45 offen. Die Zahl 34 ist **kein** End-to-End-Fertigstellungsgrad; vollständige produktive Abnahme aller 45 = **nicht nachgewiesen**.

**Release-Grenzen:** #3 Feature-Flag derzeit aus. #13, #15, #17 und #42 benötigen geprüfte produktive SQL-Migrationen. #37 sichere rückwirkende Änderung bestätigter Punkte/EXP ist absichtlich nicht als einfachen Undo-Button umgesetzt, weil eine transaktionale Korrektur- und Auditstrategie nötig ist. #12/#20/#24/#44/#45 verlangen zusätzliche API- und mobile E2E-Abnahme.

**Tests:** SQL-Rollenchecks auf isoliertem TEST für privaten Entwurf, persönliche Challenge-Zuweisung, Admin-Audit und Live-Duell-Zugriff; DB-Retry-ID-Eindeutigkeit transaktional überprüft. JSDOM/statische Regressionen auf GitHub Actions sind kein Ersatz für signierte HTTP- und reale Gerätesimulationen.
