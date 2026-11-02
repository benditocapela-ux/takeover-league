# PR #94: lokaler Release Candidate für acht Migrationen

Prüfstand: `16e2fa9fa382074a7fd27003cf079603b3727e30`, 2. November 2026. Dieses Dokument bereitet eine spätere Entscheidung vor. **Keine Produktionsfreigabe, keine Ausführung, kein Merge, kein Deployment und keine Aktivierung.** Die lokale PostgreSQL-Testinstanz bleibt gestoppt. Für diese Vorbereitung wurden keine verwalteten Datenbanken verändert oder Zugangsdaten ausgelesen.

Das [gepinnte Manifest](release-candidate-manifest.json) umfasst acht Vorwärtsmigrationen und deren vorhandene Preflight-, Postflight- und Rollback-Dateien: insgesamt **28 unterschiedliche SQL-Dateien**. Es beschreibt den geprüften Dateistand, nicht den Installationsstand einer Datenbank oder eine Freigabe des gesamten Frontends. Ändert sich eine dieser Dateien, muss der Kandidat neu geprüft und sein Manifest bewusst aktualisiert werden.

## Eigenes Paket; kein erweitertes V2.1-Bündel

`tests/build-league-21-release.cjs` wählt genau die 25 älteren Dateien mit dem Namensmuster `*_league_21_*.sql`. **Keine der folgenden acht Migrationen ist darin enthalten.** Das alte Bündel ist ein V2→V2.1-Installationskandidat und darf weder als dieses PR-94-Paket bezeichnet noch auf eine bereits vorhandene V2.1-Installation erneut angewandt werden.

Der neue [lokale Paketprüfer](../../tests/build-seven-hour-release-candidate.cjs) liest ausschließlich Dateien. Er hat keine Datenbank-, Netzwerk-, Shell- oder SQL-Ausführungsfunktion. Er kopiert acht eigenständige Transaktionen und ihre Prüfscripte; er erzeugt bewusst kein ungeprüftes Gesamt-SQL-Bündel. Bestehende Ausgabeverzeichnisse werden nicht überschrieben, zusätzliche/unbekannte Dateien oder abweichende Prüfsummen im Kandidaten werden abgelehnt.

Vom Repository-Hauptverzeichnis aus:

```text
node tests/build-seven-hour-release-candidate.cjs --check
node tests/build-seven-hour-release-candidate.cjs --output output/pr94-release-candidate-16e2fa9
node tests/build-seven-hour-release-candidate.cjs --verify output/pr94-release-candidate-16e2fa9
node tests/seven-hour-release-candidate-contracts.cjs
```

Die Prüfsummen beziehen sich auf SHA-256 des UTF-8-Inhalts mit **LF-Zeilenenden**. Der Paketprüfer normalisiert ausschließlich CRLF→LF beim Lesen der Quellen; die erzeugten Paketdateien enthalten exakt LF. Ein Windows-Checkout kann deshalb eine andere rohe `Get-FileHash`-Summe als der exportierte Kandidat haben. Für den exportierten Kandidaten stimmen rohe Dateisumme und Manifest überein. Semantische Änderungen, zusätzliche Dateien und veränderte Kommentare werden erkannt; dies ersetzt kein SQL-Review.

## Exakte Vorwärtsreihenfolge und Prüfsummen

Alle Dateien liegen unter `supabase/migrations/`. Die vollständigen Prüfsummen der Prüf- und Rückbaudateien stehen zusätzlich im Manifest.

| Nr. | Datei | SHA-256 / LF |
| --- | --- | --- |
| 1 | `20261102084519_duel_points_shared_preview_close.sql` | `4c5ee2aba4c9771357fcd1abbdd9ba74b971fe5843a8dd42c8aaeb0c751baa71` |
| 2 | `20261102090410_period_archive_readers.sql` | `20c9ac1192245af4e4f8ae8d35458e00e779ce18f613ec2c2303284971bb0921` |
| 3 | `20261102093606_duel_notification_event_identity.sql` | `0919cb1b778b9087bc78d82407b5a333aa4227d7cd44cc1847120643806aece7` |
| 4 | `20261102095352_duel_staff_queue_readonly.sql` | `e2e1cbe7e1d4ce5258bcd007f9265cd3f49b62d9f076cf96795556bd113c319e` |
| 5 | `20261102095422_duel_metric_contracts_disabled.sql` | `a62c433c425ed916d08cc06e28f0a4861cf8b1d22b39f2834fd7cc379f2ec8e9` |
| 6 | `20261102095858_period_close_preview_snapshot.sql` | `3d10b704f42050eb7451903d10a205ee51334b7b64c838760e4adbf78b1f273a` |
| 7 | `20261102101922_period_notices_profile_state.sql` | `d868ef95724992e569a41412937ca1ad2a0864dbc0f3e6f9e9245d8ae27d6ed8` |
| 8 | `20261102103929_studio_training_history_summary.sql` | `ebc357f4437dd24962d8d00f7fe41778beee6e091d1b114e4618bd49fd9e01b3` |

Nr. 4 nutzt Nr. 1. Nr. 5 benötigt den Punktevertrag und die Mitteilungsidentität; sie ersetzt Punkte-/Mitteilungsfunktionen nochmals um die generationsübergreifenden Guards. Nr. 6 benötigt Archiv und Mitteilungsidentität. Nr. 7 benötigt Nr. 6 und die Mitteilungsidentität. Nr. 8 ist fachlich unabhängig, bleibt für eine reproduzierbare Installation an letzter Stelle. Diese Reihenfolge erhält die Abhängigkeiten und entspricht der chronologischen Migrationsfolge.

Die vorhandenen Dateien enthalten jeweils `BEGIN`/`COMMIT`. **Acht Dateien sind keine gemeinsame atomare Transaktion.** Ein Fehler in Nr. 6 setzt bereits bestätigte Nr. 1–5 nicht zurück. Kein äußeres `--single-transaction` um diese Dateien und keine Verkettung, die nach einem Fehler fortsetzt. Auch ein Rollbackscript ist kein automatischer Fehlerbehandlungsblock.

## Voraussetzungen vor einer später separat autorisierten Installation

1. Exakten Ziel-Ref, Datenbankversion, Installationshistorie und aktuellen Schema-/Funktionsstand festhalten. Produktion und gemeinsames Testprojekt sind in diesem Auftrag keine Schreibziele. Eine bestätigte Projekt-URL oder ein gesunder Projektstatus ist keine Freigabe und kein Schema-Nachweis.
2. Vorhandene V2.1-Tabellen und Hilfsfunktionen müssen vollständig vorhanden sein: insbesondere `league_seasons_v21`, `league_season_results_v21`, `league_hall_of_fame_v21`, Rang-Snapshots, `duel_reconcile_ranked_core`, V2-Live-Scores, Invite/Respond/List/Reconcile, `season_transition_core`, `notifications_enabled` und bestehender Duel-Notification-Trigger.
3. `profiles` benötigt `auth_user_id`, Rolle, Aktivstatus, `is_listed` und `archived_at`. Studio benötigt unter anderem `training_submissions.duration_minutes`, `club_tier`, `training_location`, `recorded_by`; die Produktionsherkunft dieser Spalten ist vorher zu bestätigen. Die vier Ergänzungen im lokalen Kombinationsfixture waren ausschließlich Fixture-Vervollständigung und sind **keine** weitere Produktionsmigration.
4. Die alte Enddatums-Constraint muss genau einmal dem bekannten Ausdruck `ends_at = accepted_at + duration_days ...` entsprechen. Unbekannte bereits installierte Receipt-/V3-/Archivobjekte oder Funktionsabweichungen bedeuten zunächst **Stopp und Abgleich**, nicht blindes `IF NOT EXISTS` oder Überschreiben.
5. Inhalt und Historie zusammen prüfen: Paketieren oder SQL manuell ausführen erzeugt keine Supabase-Migrationshistorie. Ein später autorisierter Operator muss Installationsweg und Historie konsistent halten. Kein pauschales `supabase db push`, solange dadurch zusätzliche ältere, hier nicht geprüfte Pending-Migrationen mitlaufen könnten; keine History-Repair-Anweisung ohne tatsächlichen Nachweis.
6. Passenden Wiederherstellungsnachweis und genehmigte Betriebsgrenzen für Locks/Statement-Laufzeit besitzen. Normale Index-/Constraint-DDL kann blockieren; das Paket enthält keine `CONCURRENTLY`-Magie. Bei Lock-Timeout, unklaren aktiven Schreibprozessen oder fehlendem Wiederherstellungsweg stoppen. Die frühere lokale Backup-/Restore-Probe ist kein aktuelles Produktionsbackup.
7. Passenden Frontendstand und Reihenfolge festlegen. Missing-RPC-Fallbacks sind geprüft, ersetzen aber keine erfolgreiche Backendinstallation. Keine neuen Einladungstypen oder zusätzlichen Belohnungen freischalten. Die neuen Konfigurationszeilen müssen `enabled=false`, `reward_rule=NULL`, `jogging_training_type_id=NULL` behalten.

## Vorhandene Prüfdateien und konkrete Stopbedingungen

Die Dateien liegen unter `supabase/production-prep/`; nachfolgend bezeichnet „Stamm“ den vollständigen Namen aus der Reihenfolgetabelle ohne `.sql`. Vorher jeweils `preflight_<Stamm>.sql`, danach `postflight_<Stamm>.sql`; bei gemeinsamem Script heißt es `pre_postflight_<Stamm>.sql` und wird vor/nach dem Schritt ausgewertet. Alle Dateipfade sind im Manifest explizit hinterlegt.

| Nr. | Vorhandene Prüfung | Erwartung / Stoppbedingung |
| --- | --- | --- |
| 1 | getrennte Pre-/Postflight | Vorhandene Rang-/Live-Funktionen und Archivspalte; relevante genehmigte Trainings haben genau einen passenden Ledger. Danach gemeinsame Scorer in Live/Reconcile, restriktive Ausführungsrechte, unveränderte Flags. Fehlende/mehrdeutige Ledger vor Freigabe klären. |
| 2 | getrennte Pre-/Postflight | Season-/Honors-Snapshots und Sichtbarkeitsspalten vorhanden. Danach beide restriktiven Sichtbarkeitspolicies, öffentlicher Leser, interner Row-Helper nicht anonym ausführbar. Keine verlorene Policy akzeptieren. |
| 3 | gemeinsamer Pre-/Postflight | Vor Erstinstallation Event-Spalte/Index nicht vorhanden; danach nullable Textspalte und UNIQUE `(recipient_id,event_key)` mit NULL-Ausnahme. Nachrichten-/Read-Zustände dürfen nicht rückwirkend verändert werden; keine neuen Client-Schreibrechte. |
| 4 | gemeinsamer Pre-/Postflight | Gemeinsame Preview vorhanden. Danach Queue-Helfer/API, erwarteter Cursorindex, STABLE/geschützter Suchpfad und kein anonymer Execute-Zugriff. |
| 5 | getrennte Pre-/Postflight | Bekannte End-Constraint, Profil-/Event-Voraussetzungen und Funktionsstand. Danach genau zwei deaktivierte/unbelegte Metrik-Konfigurationen, keine Client-Konfigurationsrechte; Receipt-Trigger aktiv, immutable, SECURITY INVOKER/leerem Suchpfad, nicht direkt aufrufbar. Alte Receipts bleiben NULL; kein Backfill. Unerwartete Konfiguration oder Triggerabweichung: Stopp. |
| 6 | getrennte Pre-/Postflight | Archiv, Season-Transition und Notification-Identity vorhanden; keine unbekannte Closure-Tabelle. Danach anonyme Preview/Confirm gesperrt, private Snapshots nicht client-lesbar/schreibbar, Immutability-Trigger aktiv und keine durch DDL erzeugten Abschlüsse. |
| 7 | gemeinsamer Pre-/Postflight | Closure-/Event-Struktur vorhanden. Danach genau vorgesehene Notice-/Dismiss-APIs und privater Zustand. Kein Hintergrundabschluss, keine Rückdatierung von Bestätigungen; Rollen-/Flag-Guards bleiben vorhanden. |
| 8 | gemeinsamer Pre-/Postflight | Vollständige benötigte Trainingsspalten. Danach beide Leser/Indizes, leere Suchpfade, keine anonymen Helper-/API-Rechte, eigene aktive/nicht archivierte Identität als Filter. Keine Trainingsdatenänderung durch DDL. |

Die vorhandenen Pre-/Postflight-Dateien sind überwiegend **lesende Berichte**, keine vollständigen automatischen Release-Gates. Ein SQL-Prozess mit Exitcode 0 genügt daher nicht: Ergebnisse gegen die Tabelle prüfen und einen dokumentierten Entscheid festhalten. Postflight ruft keine Confirm-, Reconcile-, Invite- oder Dismiss-Aktion auf. Für Sicherheits- und Datenzustand vor/nach der Installation aggregierte Zähler und vorhandene Flags erfassen; keine Benutzertexte, Tokens oder Passwörter in CI-/Freigabeprotokolle übernehmen. Live-Traffic kann legitime Änderungen erzeugen und muss bei einem Vergleich ausdrücklich berücksichtigt werden.

## Rückbaugrenzen und Reihenfolge

Bei einem Fehler zuerst weitere Schritte stoppen, abhängige Clientaktionen aussetzen und den tatsächlichen Installations-/Datenstand sichern. Kein automatisches Entfernen von Beweisdaten. Ein Rückbau wäre separat zu autorisieren und nur bei erfüllten Guards in umgekehrter Abhängigkeitsfolge möglich: **8 → 7 → 6 → 5 → 4 → 3 → 2 → 1**. Unabhängige Teile können bestehen bleiben; das ist anhand des Fehlers zu entscheiden.

| Nr. | Grenze der vorhandenen `rollback_<Stamm>.sql` |
| --- | --- |
| 8 | Nur Leser/Indizes/privates Schema werden entfernt; abhängiges Studio-Frontend vorher zurücksetzen. Trainingsdaten bleiben bestehen. Unerwartete zusätzliche Abhängigkeiten nicht per CASCADE beseitigen. |
| 7 | Schon eine gespeicherte Profilbestätigung verhindert den destruktiven Rückbau. Bestätigungen/Lesestatus erhalten; vorwärts reparieren. |
| 6 | Ein offizieller Abschluss oder Monats-Snapshot blockiert den Rückbau. Nr. 7 vorher behandeln. Keine nachträgliche Auszahlungskorrektur oder Snapshot-Löschung als „Rollback“. |
| 5 | **Jeder** V3-Vertrag, numerische Wert/Metadatum, konfigurierte Zuordnung oder nicht-NULL `server_received_at` blockiert den Rückbau. Somit kann bereits das erste normale neue Training nach Migration die Grenze überschreiten, auch bei deaktivierten Kilometern/Anzahl. Receipt-/Vertragsevidenz bewahren und vorwärts reparieren. |
| 4 | Queue-API/Helfer/Index entfernen, bevor Punkte-Preview-Helfer zurückgesetzt werden. Keine fachlichen Daten werden gelöscht. |
| 3 | Nur den alten Writer wiederherstellen; `event_key`, Index, Texte und Read-Marker bleiben bestehen. Nr. 5 muss vorher sicher behandelt sein. **Danach die ursprüngliche Vorwärtsdatei nicht blind erneut ausführen**, da additive Objekte erhalten bleiben; einen überprüften Writer-Fix vorbereiten. |
| 2 | Erst abhängige Periodenobjekte behandeln. Snapshot-Daten bleiben erhalten; Rücknahme entfernt die neuen Sichtbarkeitsregeln und stellt damit älteres Sichtbarkeitsverhalten wieder her. Das benötigt eine Datenschutzprüfung. Kein CASCADE. |
| 1 | Vorher Nr. 5 und Nr. 4 behandeln. Vorhandener Guard prüft den erwarteten Reconciler. Restore früherer Funktionen, keine Rückbuchung bestehender Ledger/Rewards. |

Ein deaktiviertes Feature ist keine Zusage, dass Schema und Daten später beliebig zurückgesetzt werden können. Frontend-Rollback plus Erhalt sicherer Backendstrukturen ist nach einem überschrittenen Datenguard oft der passende Ausgangspunkt; die konkrete Reparatur muss geprüft werden.

## Verifikation, die bereits vorliegt

Root-Handoff zu `16e2fa9`: alle sieben CI-Workflows grün, einschließlich SQL-Replay unter PostgreSQL 16/17. Lokal wurden die geordnete Gesamtkette, Rechte mit echten PostgreSQL-Rollen, parallele Abschlüsse, Receipt-Manipulationen, Rückbaugrenzen und echte SQL→UI-Verträge geprüft. Der Kombinationssmoke installierte alle acht Migrationen in einem isolierten synthetischen Klon und rief deren Leser gemeinsam in READ ONLY auf. Details und Beweisgrenzen stehen in [backend-status.md](backend-status.md).

Diese Vorbereitung startet keine Datenbank und wiederholt unveränderte SQL-Tests nicht. Neu geprüft werden Dateiauswahl, gepinnte Prüfsummen, Reihenfolge/Abhängigkeiten, exakter Paketinhalt und Ablehnung veränderter/zusätzlicher Paketdateien. Ein aktueller Zielprojekt-Preflight und eine echte Supabase-Auth-/PostgREST-Abnahme sind damit nicht ersetzt.

Der neue Offline-Vertragstest ist bestanden: Erstellen/Prüfen, Ablehnung eines vorhandenen Ausgabeordners, manipulierte SQL-Datei, abweichende CRLF-Bytes im Export, zusätzliche SQL-Datei und eine fälschlich auf `true` geänderte Freigabe im Paketmanifest. Danach wurde der unveränderte Kandidat unter `output/pr94-release-candidate-16e2fa9` erneut erfolgreich geprüft. Die Tests verändern ausschließlich eigene temporäre Dateikopien, keine Migrationsquellen.

## Offenes Gate: echte verwaltete Auth-/PostgREST-Abnahme

**Weiterhin offen und ohne isolierte Zugänge nicht seriös ausführbar.** Im aktuellen Arbeitsauftrag wurden keine eigenen Testidentitäten/Sitzungen geliefert; die überprüften passenden Umgebungsvariablennamen enthielten keine bereitgestellten Test-Loginwerte. Es wurden keine Credential-Dateien, Browser-Tokens oder geheimen Schlüssel ausgelesen. Die synthetischen Testkonten und `request.jwt.claim.sub` in lokalen SQL-Tests sind keine gültigen Supabase-Auth-Sitzungen.

Ein Projekt-Publishable-Key identifiziert die Anwendung, nicht den angemeldeten Menschen; ein Secret-/Service-Key umgeht RLS und ist daher kein Ersatz für die Rollenabnahme. Auch MCP-/Management-Zugriff beweist keine normale Benutzersitzung. Siehe [Supabase API Keys](https://supabase.com/docs/guides/getting-started/api-keys) und [Data-API-Zugriffssteuerung](https://supabase.com/docs/guides/api/securing-your-api).

Für dieses Gate wären zuerst ein ausdrücklich freigegebenes isoliertes Ziel mit installiertem Kandidaten und getrennte synthetische Benutzer/Profilzuordnungen erforderlich: Teilnehmer A/B, fremder Boxer, Coach/Admin, inaktives und archiviertes Profil. Mit echten Login-Sitzungen dann im Browser/SDK prüfen: Schema-Cache/RPC-Signaturen, Parameter/JSON, Gast- und Fremdzugriff, private/Vereins-Sichtbarkeit, Rollenwechsel/abgelaufene Sitzung, exakte Historie/Unread-Zustände sowie serverseitige Receipt- und Revisionsguards. Schreibende Invite/Accept/Close/Dismiss-Tests nur im freigegebenen isolierten Bestand; am Ende Daten-/Reward-/Nachrichten-Idempotenz prüfen. Keine stillschweigende Nutzung echter Produktionskonten und keine Neuanlage im gemeinsamen Testprojekt aus diesem Runbook.

Freigabezustand bleibt: **lokal verpackbarer, geprüfter Kandidat; echte verwaltete Abnahme und Produktionsentscheidung ausstehend.**
