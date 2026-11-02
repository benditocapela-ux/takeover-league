# Arbeitsstand – 2. November 2026

Start: 01:10 Europe/Zurich / 00:10 UTC. Arbeitsbudget bis 08:10 Europe/Zurich / 07:10 UTC. In der letzten Stunde keine neue grosse Funktion.
Branch: feature/league-audit-seven-hours-20261102. Basis: c7fbd9ff568e703db7d7b7820f0f2605d8b0d0b6. Vor Beginn sauberer Arbeitsbaum; keine AGENTS.md im Repository oder den geprüften Elternverzeichnissen.

## Schutz und Zuständigkeiten

Kein neuer Produktionsrelease autorisiert. Produktion iqarjivcrddcixrvqbfb ausschliesslich lesend; keine Migration, Flagänderung, Auszahlung oder echte Abschlussbuchung. Testprojekt cfgdvcccsqwfjajuizsr ist bestätigt: Takeover league test, ACTIVE_HEALTHY. Nur isolierte synthetische Testdaten/Transaktionen. Alte PRs 80, 78, 77, 76 und 62 bleiben unangetastet.

- duel_contract: Datenbank/Wertung, Duell-/Monats-/Saisonabschluss, gemeinsame Event-Identität, SQL-Nachweise.
- workflow_ui: Duellformular, Trainerabschlüsse, periodengenaues Archiv, zugehörige Browser-Tests.
- graphics_mobile: beide Podien, Anime-Anatomie, Editor-Posen/Bundle-Vorschauen, Grafikmatrix/Mobile.
- root: Integration, Studio-Historie/Inbox/Periodenhinweise, Auth-/Routenprüfung, Release-Eingaben, CI/Draft-PR.

## Verifizierte Baseline

- main weiterhin c7fbd9f, offene PRs wie Audit; Testprojekt bestätigt.
- release-static-contracts 33/33, takeover3-contracts 12/12, staff-experience-contracts 7/7, JS-Regex und CSS-Struktur bestanden.
- Produktive Flags: duels, training_v2, notifications aktiv; boxer_duels, seasons, hall_of_fame inaktiv. Keine Flags geändert.
- Reproduktion aus Code: Studio lädt 1.000 volle Trainingseinträge, Inbox begrenzt gleichzeitig Liste und Ungelesenzähler auf 20; mehrere unabhängige createClient-Stellen. Live-Warnungen werden vor Auth-Änderung im Browser geprüft.

## Priorisierte Akzeptanz

1. Gemeinsame serverseitige Duellwertung; explizite Einladung/Annahme; vollständige Regeln, enge Sichtbarkeit, Legacy unverändert. Neue Metriken ohne festgelegte Reward-Regel nicht einladbar.
2. Lesende Abschlussvorschau und expliziter idempotenter Abschluss, eng begrenzte Trainerrechte. Offene Trainings blockieren, keine erfundenen Prämien.
3. Getrennte Monats-/Saisonansichten mit periodengebundenen Links/Snapshots; rekonstruierter Monat sichtbar vorläufig. Eindeutige Mitteilungsereignisse, Profiltrennung, Nachladen und echter Ungelesenzähler.
4. Deutlich grösseres datengetriebenes Podium und korrigierte Anime-Vorschauen/Ärmel; Grafikmatrix 100/200 %, keine eingebrannten Rang-/Namensdaten.
5. Routen/Rollen/Mobile prüfen, reale Fehler priorisiert beheben; bestehender Veröffentlichungsweg bleibt erhalten.

## Nachweise unterscheiden

Quellverträge, DOM-/Browser-Mocks, echte Browser, Test-DB-RPCs und Produktions-Read-only werden getrennt protokolliert. Kein physisches Gerät verfügbar/verifiziert. Ausstehende End-to-End-Prüfungen nicht als bestanden melden.

## Offen / Entscheidungen

Neue Metrik-Rewards und neue Monats-/Saisonboni sind nicht definiert: sichere deaktivierte Konfiguration vorbereiten, keine Beträge erfinden. Private Altduelle nicht öffentlich machen. Weitere Arbeitsstände in backend-status.md, workflow-status.md und graphics-status.md.

## Abschluss: Teilstand, keine vollständige Auftragserfüllung

Der erste Uhrwert war 2026-11-02 00:10:08 UTC. Der erneute explizite Abgleich lieferte 08:16:54 UTC; auch die Windows-Uhr zeigte 09:16 Europe/Zurich. Damit war die festgelegte Grenze 07:10 UTC überschritten. Danach nur Sicherung, Integration und Abschlussprüfung begonnener kleiner Pakete. Daraus wird **keine siebenstündige produktive Arbeitszeit** abgeleitet. Grosse unvollständige Entwürfe wurden nicht als fertige Funktion übernommen.

| Ziel | Ergebnis | Nachweis / Restarbeit |
| --- | --- | --- |
| Duelle mit drei Wertungen | Teilweise | Punkte-Einladung mit lesender Prüfansicht und ausdrücklichem Senden. Kilometer/Anzahl bleiben deaktiviert; gemeinsamer SQL-Wertungsvertrag fehlt. |
| Trainerabschlüsse und sichere Belohnungen | Zurückgestellt | Produktionsvertrag lesend dokumentiert; keine neue Vorschau, Warteschlange oder Coach-Befugnis. Bestehender reconcile-Aufruf kann weiterhin buchen. |
| Monats-/Saisonarchiv und Deep Links | Zurückgestellt | Bestehender globaler Ergebnismix noch offen; keine neuen Monats-Snapshots oder Oktober-Rekonstruktion. |
| Periodenmeldungen, Inbox, Historien-Paginierung | Zurückgestellt | Kein neuer Event-Schlüssel, keine neue Bannerlogik, Zähler-/Limit-Probleme noch offen. |
| Grosses Podium, korrekte Ränge | Zurückgestellt | Baseline-Bilder und konkrete Befunde vorhanden; ungeprüfter Prototyp zurückgenommen. |
| Flex-Anatomie, Pose-/Bundle-Kacheln | Zurückgestellt | Ursachen eingegrenzt; keine Grafik korrigiert und keine Nachher-Abnahme. |
| Mehrfache GoTrue-Clients | Umgesetzt | Gemeinsame Factory in allen produktiven SDK-Erzeugern. Echter SDK-Gasttest: je drei Seiten in Chromium/WebKit, genau eine Auth-Instanz, keine Mehrfachwarnung. |
| Rollen-/Kontowechsel-Regression | Geprüfter Teilumfang | Bestehende Browser-Suite in Chromium/WebKit bestanden; synthetische Konten, keine echten Login-/Refresh-Token. |
| Trainer-Leerzustand | Umgesetzt | Meldung benennt nur Trainingsaufgaben und behauptet nicht mehr, sämtliche Wettkämpfe seien erledigt. |
| LIVE-Kontrast | Umgesetzt | Gemessener CSS-Kontrast 6.89:1 statt gleicher Vorder-/Hintergrundfarbe. |
| Release-Eingaben | Umgesetzt | Pages reagiert künftig auch auf Root-SVG und tools/premium-v2; Auth-Modul löst vorhandene Konto-/Staff-CI aus. Kein Release gestartet. |
| Vollständiges 33-Seiten-/Rollen-/Geräteaudit | Teilweise | Vorhandene Shell-/Navigationstests bestanden, aber keine vollständige echte Rollen-/DB-/Gerätematrix. |

### Ausgeführte Abschlussprüfungen

- `release-static-contracts.cjs`: 33/33; `takeover3-contracts.cjs`: 12/12; `staff-experience-contracts.cjs`: 7/7.
- `js-regex-guard.cjs` und `css-structure.cjs`: bestanden.
- `takeover3-browser.cjs`: Chromium und WebKit bestanden; Konto hinzufügen/wechseln/entfernen, Rollenwechsel, abgelaufene Sitzung, Netzwerkfehler, Tabwechsel, Training und Navigation. Supabase-Attrappe, keine echten Konten. Kurzlog: account-browser.log.
- `duels-v2-browser.cjs`: JSDOM bestanden. `release-live-duels-browser.cjs`: Chromium/WebKit, 375/1280 px, synthetische RPCs; Details in workflow-status.md.
- `auth-singleton-browser.cjs`: sechs echte SDK-Gastläufe bestanden. auth-baseline.json zeigt die produktiven Mehrfachwarnungen, auth-after.json den lokalen korrigierten Stand. Keine echte authentifizierte SDK-Abnahme.
- `assemble-pages-site.cjs`: lokales Staging erfolgreich, 81 Root-Dateien; takeover-client.js wird mitgeliefert. Premium-Konfiguration unverändert. **Kein Upload/Deployment.**
- LIVE-Badge in Chromium mit berechnetem CSS geprüft: feature-contrast.json.
- Keine neuen SQL-/RLS-/Concurrency-Tests, keine Testdatenbank-Schreibtests und keine physische iPhone-/Android-Abnahme.

### Datenbank, Flags und späterer Release

Dieses Paket enthält **null neue Migrationen**. Es benötigt die vorhandenen v2-RPCs und erweitert keine Datenrechte. Die im Backend-Dokument vorgeschlagenen v3-Verträge sind nicht installiert. Es gibt keinen anwendbaren SQL-Rollback, weil keine SQL-Änderung erstellt oder angewendet wurde.

Lesender Flag-Snapshot: aktiviert sind achievements, app_feedback, boxer_holo, card_designs, coach_challenges, coach_feedback, coach_ratings, duels, gym_training, kampfgeist_shop, notifications, performance_dashboard, self_rating, style_test, training_v2, tutorial, weekly_quests. Deaktiviert sind boxer_duels, club_checkin_only, coach_goals, hall_of_fame, league_challenges, palmares, public_boxer_profiles, seasons. Alte Flag-Namen nicht mit der Freigabe neuer Generationen gleichsetzen. Keine Flags verändert.

Vor einem späteren Release: Draft prüfen, vollständige CI am aktuellen Commit abwarten, verbleibende authentifizierte SDK-Regression und Mobile-Überlagerungen prüfen. Frontend-Importänderungen und takeover-client.js müssen zusammen veröffentlicht werden. Rollback dieses Pakets wäre ein gemeinsames Revert von Factory und Importen; bestehende Daten bleiben unverändert. Merge, Pages-Veröffentlichung und jede künftige DB-Migration erfordern die entsprechende ausdrückliche FREIGEBEN-Anweisung. Nichts davon wurde ausgeführt.

Nächstes priorisiertes Paket: gemeinsamer serverseitiger Duellvertrag samt read-only Abschlussvorschau und isolierten Rechte-/Wertungs-/Idempotenztests; danach explizite Trainerabschlüsse und periodengefiltertes Archiv. Neue Metrik-Rewards, zusätzliche Monats-/Saisonboni und Vereins-Sichtbarkeit müssen als nachvollziehbare Konfiguration festgelegt werden. Private Altduelle bleiben privat.
