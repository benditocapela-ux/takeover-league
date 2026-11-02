# Arbeitsstand – Fortsetzung vom 2. November 2026

Branch: `feature/league-audit-seven-hours-20261102`. Draft-PR: [#94](https://github.com/benditocapela-ux/takeover-league/pull/94). Basis/main: `c7fbd9ff568e703db7d7b7820f0f2605d8b0d0b6`, erneut mit GitHub abgeglichen. Letzter vorheriger Remote-Head: `a806260243eb6de23c7355f983edbfc7ef165bfa`.

Nach dem ausdrücklichen „fahre weiter“ wurde die Arbeit um **08:42:58 UTC / 09:42:58 Europe/Zurich** wieder aufgenommen. Dies ist der aktuelle Integrationsstand; der erste Teilstand bleibt als [STATUS.initial.md](STATUS.initial.md) dokumentiert. Keine erfundenen Prozentzahlen oder Behauptung durchgehend geleisteter sieben Stunden.

## Schutzrahmen

**Kein Merge, kein Deployment, keine Produktionsmigration, keine Änderung produktiver Flags, keine produktiven Auszahlungen.** Produktion `iqarjivcrddcixrvqbfb` nur lesend. Auch das bestätigte gemeinsame Testprojekt `cfgdvcccsqwfjajuizsr` wurde nicht beschrieben. Alle neuen Datenbanktests laufen gegen isolierte synthetische Datenbanken auf lokalem PostgreSQL 17.11, Loopback 127.0.0.1:55481. Es wurden keine echten Benutzer, Trainings, Besitzstände oder Wirtschaftsdaten verändert.

Die offenen alten PRs #80/#78/#77/#76/#62 wurden nicht übernommen oder gemergt. Keine neuen Laufzeitabhängigkeiten, Frameworks oder Dienste.

## Zielmatrix

| Ziel | Stand | Nachweis / verbleibende Arbeit |
| --- | --- | --- |
| Gemeinsame Wertung bestehender Punkte-Duelle | Umgesetzt, getestet | Livewertung und Abschluss nutzen dieselben Ledgerprüfungen; fehlende/doppelte Buchungen blockieren. Legacy-Zeitraum und Rangbelohnungen bleiben erhalten. |
| Lesende Duellvorschau, ausdrücklicher Abschluss | Umgesetzt, getestet | Vorschau schreibt nichts; Revision, erneute Bestätigung, tatsächliche Buchungen und Fehlerzustände. Reale Zwei-Trainer-Konkurrenz und Rollback getestet. |
| Auffindbare Trainerabschlüsse | Umgesetzt für Punkte-Duelle | Serverseitige Suche, Statusfilter, 20er-Keyset-Seiten und exakte Zähler. SQL mit 127 Duellen und Browser mit 121 Duellen: alte fällige Duelle hinter 120 neueren Ergebnissen auffindbar. |
| Kilometer-/Trainingsart-Duelle | Backend vorbereitet, Integration läuft | Exakte Dezimal-/ID-Wertung, Folgetag/7–14 volle Zürcher Tage, Sichtbarkeit, unveränderlicher Vertrag, Abschluss/Korrektur und isolierte Tests. Standardkonfiguration deaktiviert, Reward-Zuordnung NULL. UI-Endabnahme und unabhängiges Review laufen. |
| Monats-/Saisonarchiv | Umgesetzt, getestet | Eindeutige Periodenschlüssel, keine vermischten Saisons, 20er-Seiten, eigener Rang ausserhalb der ersten Seite, aktuelle Profil-Sichtbarkeit. Nicht abgeschlossene Monate ausdrücklich rekonstruiert. |
| Offizielle Monats-/Saisonabschlüsse | Umgesetzt als Ergebnisabschluss, getestet | Enger Coach-/Admin-Endpunkt, lesende Vorschau, offene Trainings/Ledgerfehler blockieren, unveränderliche Monats-Snapshots. Bestehende Saisontitel und Folgeentwurf erhalten. **Keine zusätzliche Prämie eingerichtet.** |
| Periodenmeldungen und Deep Links | Umgesetzt, getestet | Eindeutige Ereignisse je Periode/Empfänger; Hinweise in Heute/Liga. Servergespeichertes Schliessen pro Profil und Phase; offizieller Abschluss erscheint trotz geschlossenem vorläufigem Hinweis erneut. |
| Inbox-Zähler und Nachladen | Umgesetzt, getestet | Exakter globaler Ungelesenzähler, 20er-Seiten, eigene Deep Links, fehlgeschlagene Bestätigung und Kontowechsel. 45 Nachrichten/35 ungelesen, beide Browser und bestehende Kontoregression bestanden. |
| Trainingshistorie vorladen | Offen | Studio lädt weiterhin bis 1.000 Vollzeilen; echte Paginierung darf Statistik/Kalender/Serie nicht verfälschen. |
| Grösseres Liga-Podium | Umgesetzt, getestet | Gemeinsame 2–1–3-Darstellung, tatsächliche Ränge, Gleichstände, Nullleistung, leere/kleine Felder, lange Namen, alle sechs Posen. Transparenter Anime-Hintergrund statt schwarzer Rechtecke. |
| Posen-/Bundle-Vorschauen | Umgesetzt, getestet | Zwölf Pose-Kacheln, FUT und Bundle pixelgleich zum echten Compositor. Anime/SVG folgt tatsächlichem Resolver. Begrenzter Cache und Modulfehler mit Wiederholung. |
| Flex-Shirt-Schultern | Ursache belegt, noch offen | Ärmelquelle und geerbte Mantelanker verursachen falschen Übergang. Versuche bei 100/200 % reichen nicht aus; keine unbewiesene Korrektur und kein pauschaler SVG-Downgrade übernommen. |
| Auth-Client, Gastzustand, LIVE-Kontrast | Vorheriges Paket erhalten | Eine SDK-Instanz; verständlicher Gastzustand; Kontrast 6.89:1. |
| Vollständige Website-/Shop-/Geräteabnahme | Teilweise | Bestehende Regressionen plus gezielte neue Pfade. Keine vollständige echte Login-/Cloud-/Gerätematrix oder künstlerische Abnahme sämtlicher Kombinationen. |

## Tatsächliche Nachweise

- **Quellverträge:** 33/33 Release-Checks, 12/12 Takeover-3, 7/7 Staff, Erhalt bestehender DOM-IDs/RPCs, JS-Regex und CSS-Struktur. Neue legitime Hooks sind ausdrücklich gelistet; keine allgemeinen Ausnahmen.
- **Echte Browser, synthetische API-Daten:** Chromium und WebKit für Abschluss, Archiv, Hinweise, Warteschlange, Konto-/Fehlerzustände. Neue Periodenabläufe bei 320/390/1280 px. Podium/Editor zusätzlich 320/360/390/430 px und Desktop.
- **Echte lokale Datenbank:** PostgreSQL 17.11 mit tatsächlichen Rollen, Read-only-Transaktionen, Wertungsgrenzen, fehlenden/doppelten Ledgers, konkurrierenden Sessions, Rollback/Reapply und Datenfingerprints. Kein Ersatz für echte Supabase-Login-/PostgREST-End-to-End-Abnahme.
- **Grafik:** 3.528 Variantenberichte aktualisiert; exakte PNG-Vorschauvergleiche und Cachegrenzen. 32 Previewvarianten → 24 Cache-Einträge, 0 ausstehende Jobs, 0 zusätzliche PNG-Quellanfragen nach Aufwärmen. Kein allgemeiner Performancegewinn behauptet.
- **GitHub-CI:** Am alten Head a806260 waren Staff/Takeover-3 grün. Zwei andere Läufe fanden veraltete Design-/Confirm-Assertions und einen montagsabhängigen Club-Slot-Test. Diese Ursachen sind lokal korrigiert. CI am nächsten gepushten Head muss neu geprüft werden; alte Resultate sind keine Freigabe.

## Migrationen und Release

Reihenfolge und Nachweise: [archive-and-closures.md](archive-and-closures.md), [backend-status.md](backend-status.md), [duel-queue.md](duel-queue.md). Die folgende Liste ist die Integrationsreihenfolge. **095422 (neue Metriken) befindet sich noch im lokalen Review und ist nicht Teil dieses ersten Fortsetzungs-Checkpoints.** Alle übrigen hier aufgeführten Migrationen sind als überprüfbare Dateien enthalten:

1. `20261102084519` gemeinsamer Punktevertrag und Duellvorschau.
2. `20261102090410` periodenbezogene Archivleser und heutige öffentliche Profil-Sichtbarkeit.
3. `20261102093606` Empfänger-/Ereignisschlüssel für Duellmitteilungen.
4. `20261102095352` begrenzte Trainerwarteschlange.
5. `20261102095422` deaktivierte neue Metrikverträge.
6. `20261102095858` ausdrückliche Monats-/Saisonabschlüsse.
7. `20261102101922` profilgebundene Periodenhinweise.

Frontend und passende RPCs gemeinsam vorbereiten. Bei fehlenden neuen APIs wird keine alte schreibende RPC als vermeintlich lesende Vorschau verwendet. Rollback in umgekehrter Abhängigkeitsreihenfolge; nach echten neuen Snapshots/Verträgen verweigern die Schutzskripte einen datenvernichtenden Schema-Rollback. Dann Daten erhalten und eine geprüfte Vorwärtskorrektur vorbereiten.

Unverändert aktiv laut Read-only-Snapshot: achievements, app_feedback, boxer_holo, card_designs, coach_challenges, coach_feedback, coach_ratings, duels, gym_training, kampfgeist_shop, notifications, performance_dashboard, self_rating, style_test, training_v2, tutorial, weekly_quests. Unverändert aus: boxer_duels, club_checkin_only, coach_goals, hall_of_fame, league_challenges, palmares, public_boxer_profiles, seasons. Alte Flags nicht als Freigabe neuer Generationen interpretieren.

## Nächste Arbeit

Metrik-Review/UI und echte Trainingshistorien-Paginierung abschliessen; den getesteten Zwischenstand pushen und CI am tatsächlichen Head auswerten. Danach die noch offenen P1-Integrationslücken und risikobasierten Regressionen priorisieren. Neue Reward-Zuordnungen bleiben eine explizite Fachentscheidung; private Altduelle werden nicht automatisch für Zuschauer geöffnet. **Nichts aus dieser Fortsetzung ist veröffentlicht.**
