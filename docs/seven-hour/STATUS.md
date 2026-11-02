# Arbeitsstand – Fortsetzung vom 2. November 2026

Branch: `feature/league-audit-seven-hours-20261102`. Draft-PR: [#94](https://github.com/benditocapela-ux/takeover-league/pull/94). Basis/main: `c7fbd9ff568e703db7d7b7820f0f2605d8b0d0b6`, erneut mit GitHub abgeglichen. Vorheriger Integrations-Head: `1136d37ef1a478a2fb917e06fbbec982c4644df2`. Der finale Head und seine CI-Ergebnisse werden im Draft-PR geführt.

Nach dem ausdrücklichen „fahre weiter“ wurde die Arbeit um **08:42:58 UTC / 09:42:58 Europe/Zurich** wieder aufgenommen. Dies ist der aktuelle Integrationsstand; der erste Teilstand bleibt als [STATUS.initial.md](STATUS.initial.md) dokumentiert. Keine erfundenen Prozentzahlen oder Behauptung durchgehend geleisteter sieben Stunden.

## Schutzrahmen

**Kein Merge, kein Deployment, keine Produktionsmigration, keine Änderung produktiver Flags, keine produktiven Auszahlungen.** Produktion `iqarjivcrddcixrvqbfb` nur lesend. Auch das bestätigte gemeinsame Testprojekt `cfgdvcccsqwfjajuizsr` wurde nicht beschrieben. Alle neuen Datenbanktests laufen gegen isolierte synthetische Datenbanken auf lokalem PostgreSQL 17.11, Loopback 127.0.0.1:55481. Es wurden keine echten Benutzer, Trainings, Besitzstände oder Wirtschaftsdaten verändert.

Die offenen alten PRs #80/#78/#77/#76/#62 wurden nicht übernommen oder gemergt. Keine neuen Laufzeitabhängigkeiten, Frameworks oder Dienste.

## Zielmatrix

| Ziel | Stand | Nachweis / verbleibende Arbeit |
| --- | --- | --- |
| Gemeinsame Wertung bestehender Punkte-Duelle | Umgesetzt, getestet | Livewertung und Abschluss nutzen dieselben Ledgerprüfungen; fehlende/doppelte Buchungen blockieren. Legacy-Zeitraum und Rangbelohnungen bleiben erhalten. |
| Lesende Duellvorschau, ausdrücklicher Abschluss | Umgesetzt, getestet | Vorschau schreibt nichts; Revision, erneute Bestätigung, tatsächliche Buchungen und Fehlerzustände. Reale Zwei-Trainer-Konkurrenz und Rollback getestet. |
| Auffindbare Trainerabschlüsse | Umgesetzt, getestet | Serverseitige Suche, Statusfilter, 20er-Keyset-Seiten und exakte Zähler. SQL mit 127 Duellen und Browser mit 121 Duellen: alte fällige Duelle hinter 120 neueren Ergebnissen auffindbar. |
| Kilometer-/Trainingsart-Duelle | Umgesetzt und getestet, deaktiviert | Exakte Dezimal-/ID-Wertung, Folgetag/7–14 volle Zürcher Tage, unveränderliche Regeln und Sichtbarkeit, ausdrückliche Einladung/Annahme, Abschluss/Korrektur. Revisionsgebundene Zustimmung, echte SQL→UI-Verträge und unabhängiges Review bestanden. Default deaktiviert, Reward-Zuordnung NULL. |
| Monats-/Saisonarchiv | Umgesetzt, getestet | Eindeutige Periodenschlüssel, keine vermischten Saisons, 20er-Seiten, eigener Rang ausserhalb der ersten Seite, aktuelle Profil-Sichtbarkeit. Nicht abgeschlossene Monate ausdrücklich rekonstruiert. |
| Offizielle Monats-/Saisonabschlüsse | Umgesetzt als Ergebnisabschluss, getestet | Enger Coach-/Admin-Endpunkt, lesende Vorschau, offene Trainings/Ledgerfehler blockieren, unveränderliche Monats-Snapshots. Bestehende Saisontitel und Folgeentwurf erhalten. **Keine zusätzliche Prämie eingerichtet.** |
| Periodenmeldungen und Deep Links | Umgesetzt, getestet | Eindeutige Ereignisse je Periode/Empfänger; Hinweise in Heute/Liga. Servergespeichertes Schliessen pro Profil und Phase; offizieller Abschluss erscheint trotz geschlossenem vorläufigem Hinweis erneut. |
| Inbox-Zähler und Nachladen | Umgesetzt, getestet | Exakter globaler Ungelesenzähler, 20er-Seiten, eigene Deep Links, fehlgeschlagene Bestätigung und Kontowechsel. 45 Nachrichten/35 ungelesen, beide Browser und bestehende Kontoregression bestanden. |
| Trainingshistorie | Umgesetzt, getestet | Eigene 20er-Keyset-Seiten, getrennte vollständige Aggregate; 1.202 Trainings in echter SQL-Fixture, alle acht Fortschrittsfamilien und Wochenserie gegen vollständige bisherige Berechnung geprüft. Browser: Filter, Fehler, doppelte Klicks, Konto-/Antwortwechsel. |
| Grösseres Liga-Podium | Umgesetzt, getestet | Gemeinsame 2–1–3-Darstellung, tatsächliche Ränge, Gleichstände, Nullleistung, leere/kleine Felder, lange Namen, alle sechs Posen. Transparenter Anime-Hintergrund statt schwarzer Rechtecke. |
| Posen-/Bundle-Vorschauen | Umgesetzt, getestet | Zwölf Pose-Kacheln, FUT und Bundle pixelgleich zum echten Compositor. Anime/SVG folgt tatsächlichem Resolver. Begrenzter Cache und Modulfehler mit Wiederholung. |
| Gleichzeitiges Laden von Kachel und Hauptfigur | Umgesetzt, getestet | Zwei Aufrufer desselben Outfit-Preloads erhalten beide ihre Fertigmeldung; gleiche Callback-Funktionen bleiben dedupliziert. Fehlerpfad und Freigabe ebenfalls geprüft. Im echten WebKit vor Fix rot, nach Fix vollständige Chromium-/WebKit-Suite grün, ohne Timeout-Erhöhung. |
| Mehrere Profil-/Kartenfiguren mit gleicher angezeigter Pose | Umgesetzt, getestet | Der veröffentlichte Premium-Adapter benachrichtigt alle Konsumenten desselben normalisierten Renderjobs. Unterschiedliche gespeicherte Profilposen mit gleicher angezeigter Kartenpose bleiben nicht mehr teilweise als SVG hängen. Reproduktion vor Fix rot, danach beide Engines grün; Editor-/Podium-Regressionssuiten ebenfalls bestanden. |
| Offline prüfbarer Release-Kandidat | Vorbereitet, nicht freigegeben | Acht Migrationen, 28 SQL-Dateien mit gepinnten Prüfsummen, Abhängigkeiten und Rückbaugrenzen. Dateibasiertes Pack/Verify mit Manipulations-/Überschreibschutz. Kein SQL ausgeführt. Siehe [Release-Kandidat](release-candidate.md). |
| Shop-Fehler und Item-Wahrheit | Umgesetzt, getestet | Transportfehler geben Kauf/Ausrüstung wieder frei, bestätigte Belege bleiben bei ausgefallener Nachlese sichtbar, verspätete Antworten öffnen keine alte Auswahl. Sechs bestehende SVG-Kategorien auf Kachel-/Detail-/Look-Parität und Preise geprüft, Chromium/WebKit sowie schmale Displays/200-%-Zoom. Siehe [Shop-Audit](shop-audit.md). |
| Flex-Shirt-Schultern | Ursache belegt, noch offen | Ärmelquelle und geerbte Mantelanker verursachen falschen Übergang. Versuche bei 100/200 % reichen nicht aus; keine unbewiesene Korrektur und kein pauschaler SVG-Downgrade übernommen. |
| Doppeltipp nach schneller Trainingsantwort | Umgesetzt, getestet | Reale Scroll-/Klickfolge traf nach erfolgreichem Insert bereits die neue Zurück-/Weiter-Aktion. Beide Erfolgsschaltflächen ignorieren den zweiten Klick derselben Klickfolge; Einzelklick und Enter bleiben bedienbar. Chromium/WebKit, genau ein Insert. |
| Emotes und Moderation in der neuen Duellansicht | Umgesetzt, getestet | Sichtbare eigene Duelle/Staff behalten Emotes, Einlauf und Moderation. Vereinsübersicht fragt keine privaten Emote-Verläufe ab. Chromium/WebKit: verspätete Konto-/Auswahlantworten verworfen; unabhängiges Review bestanden. |
| Auth-Client, Gastzustand, LIVE-Kontrast | Vorheriges Paket erhalten | Eine SDK-Instanz; verständlicher Gastzustand; Kontrast 6.89:1. |
| Vollständige Website-/Shop-/Geräteabnahme | Teilweise | Bestehende Regressionen plus gezielte neue Pfade. Keine vollständige echte Login-/Cloud-/Gerätematrix oder künstlerische Abnahme sämtlicher Kombinationen. |

## Tatsächliche Nachweise

- **Quellverträge:** 33/33 Release-Checks, 12/12 Takeover-3, 7/7 Staff, Erhalt bestehender DOM-IDs/RPCs, JS-Regex und CSS-Struktur. Neue legitime Hooks sind ausdrücklich gelistet; keine allgemeinen Ausnahmen.
- **Echte Browser, synthetische API-Daten:** Chromium und WebKit für Abschluss, Archiv, Hinweise, Warteschlange, Konto-/Fehlerzustände. Neue Periodenabläufe bei 320/390/1280 px. Podium/Editor zusätzlich 320/360/390/430 px und Desktop.
- **Echte lokale Datenbank:** PostgreSQL 17.11 mit tatsächlichen Rollen, Read-only-Transaktionen, Wertungsgrenzen, fehlenden/doppelten Ledgers, konkurrierenden Sessions, Rollback/Reapply und Datenfingerprints. Kein Ersatz für echte Supabase-Login-/PostgREST-End-to-End-Abnahme.
- **Gemeinsames Migrationspaket:** Alle acht Migrationen koexistieren in einem separaten Klon des finalen Duell-Fixtures. Fehlende vorhandene Produktionsspalten wurden nur im Fixture ergänzt. Tatsächliche authentifizierte Read-only-Aufrufe von v2/v3-Duellen, Warteschlange, Archiv, Periodenvorschau/-hinweisen und Studio sowie anonymem Archiv bestanden; keine neuen Abschlüsse, Metriken deaktiviert. Log: `C:/Users/bendi/Documents/Codex/tools/pg-core17/combined-migrations-final.log`.
- **Grafik:** 3.528 Variantenberichte aktualisiert; exakte PNG-Vorschauvergleiche und Cachegrenzen. 32 Previewvarianten → 24 Cache-Einträge, 0 ausstehende Jobs, 0 zusätzliche PNG-Quellanfragen nach Aufwärmen. Kein allgemeiner Performancegewinn behauptet.
- **GitHub-CI:** Am geprüften Ausgangsstand der jüngsten Fortsetzung `16e2fa9` sind **alle sieben Workflows grün**, einschließlich vollständiger Premium-Produktion und PostgreSQL 16/17. Neue Änderungen benötigen eigene Prüfungen am neuen Head; der Draft-PR führt deren aktuellen Status. Ältere erfolgreiche Runs ersetzen diese Prüfung nicht.

## Migrationen und Release

Reihenfolge und Nachweise: [archive-and-closures.md](archive-and-closures.md), [backend-status.md](backend-status.md), [duel-queue.md](duel-queue.md). Die folgende Liste ist die Integrationsreihenfolge. Alle acht Migrationen liegen mit gezielten Prüfungen und Rückrollskripten vor; keine wurde in einer verwalteten Datenbank installiert:

1. `20261102084519` gemeinsamer Punktevertrag und Duellvorschau.
2. `20261102090410` periodenbezogene Archivleser und heutige öffentliche Profil-Sichtbarkeit.
3. `20261102093606` Empfänger-/Ereignisschlüssel für Duellmitteilungen.
4. `20261102095352` begrenzte Trainerwarteschlange.
5. `20261102095422` deaktivierte neue Metrikverträge.
6. `20261102095858` ausdrückliche Monats-/Saisonabschlüsse.
7. `20261102101922` profilgebundene Periodenhinweise.
8. `20261102103929` eigene Trainingshistorie und vollständige Statistik.

Frontend und passende RPCs gemeinsam vorbereiten. Bei fehlenden neuen APIs wird keine alte schreibende RPC als vermeintlich lesende Vorschau verwendet. Rollback in umgekehrter Abhängigkeitsreihenfolge; nach echten neuen Snapshots/Verträgen verweigern die Schutzskripte einen datenvernichtenden Schema-Rollback. Dann Daten erhalten und eine geprüfte Vorwärtskorrektur vorbereiten.

Unverändert aktiv laut Read-only-Snapshot: achievements, app_feedback, boxer_holo, card_designs, coach_challenges, coach_feedback, coach_ratings, duels, gym_training, kampfgeist_shop, notifications, performance_dashboard, self_rating, style_test, training_v2, tutorial, weekly_quests. Unverändert aus: boxer_duels, club_checkin_only, coach_goals, hall_of_fame, league_challenges, palmares, public_boxer_profiles, seasons. Alte Flags nicht als Freigabe neuer Generationen interpretieren.

## Vorbereitung eines späteren Release und offene Punkte

- Zuerst den aktuellen Draft-Head und sämtliche CI-Resultate prüfen. Funktionsumfang und Risiken anhand von [Duell-UI](duel-metrics-ui.md), [Backendvertrag](backend-v3-api.md), [Studio](studio-history.md), [Archiv/Abschluss](archive-and-closures.md) und [Routen/Rollen](routes-and-roles.md) abnehmen.
- Vor einer freigegebenen Migration die vorbereiteten Read-only-Preflights gegen den dann aktuellen Produktionsstand ausführen, Backup/Wiederherstellbarkeit belegen, Abhängigkeiten und sperrende Indexanlage auf der tatsächlichen Datenmenge prüfen. Die vorhandene V2.1-Release-Datei enthält diese neuen Migrationen nicht. Das separate [Runbook samt gepinntem Manifest](release-candidate.md) bereitet das neue Paket vor; eine spätere Freigabe muss es ausdrücklich umfassen.
- Frontend und RPCs gemeinsam ausliefern. Die neuen Metriken bleiben ohne bewusste Konfiguration deaktiviert. Tatsächliche Joggingart und Reward-Zuordnung (auch ausdrücklich keine zusätzliche Prämie) sind Fachentscheidungen. Für neue Monats-/Saisonboni existiert keine freigegebene Wirtschaftsregel.
- Private Altduelle bleiben privat. Historische Trainings ohne vertrauenswürdigen Eingangsstempel werden nicht nachträglich als pünktlich bestätigt. Der neue serverseitige Eingangsstempel gilt nur für neu eingereichte Trainings; sichere Rollback-Skripte bewahren bereits erzeugte Belege.
- Die Flex-Shirt-Ärmelkorrektur bleibt zurückgestellt: neue, sauber registrierte Ärmelquelle nötig. Kein freigegebenes Nachher-Artwork vorhanden. Vollständige künstlerische Abnahme, Shop-Detailaudit, echte Supabase-Login-/PostgREST-Integration und physische iPhone-/Android-Prüfung bleiben offen.

**Kein Merge, kein Deployment, keine produktive Migration oder Abschlussbuchung ausgeführt.** Sämtliche Änderungen liegen ausschliesslich im Arbeitsbranch/Draft-PR. Nach der finalen Übergabe läuft keine behauptete autonome Hintergrundarbeit weiter.
