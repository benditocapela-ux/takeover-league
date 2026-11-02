# Duellarten: geprüfte Oberfläche

Stand: 2026-11-02. Arbeitsbranch, keine Produktaktivierung, kein Produktionsschreibzugriff, kein Merge/Deployment.

## Verhalten

- Die vorhandene Einladungsmaske unterstützt Punkte, Joggingkilometer und Trainings einer ausdrücklich gewählten Art. `duel_v3_options` ist die alleinige Quelle für Freigabe, genaue Trainingsart, Belohnungsbezeichnung und Regelrevision. Kilometer/Trainingsanzahl bleiben in der ausgelieferten Konfiguration deaktiviert; die Oberfläche zeigt den Servergrund.
- Vor dem Senden stehen Gegner, Wertung, genaue Trainingsart, 7/14 Tage, Zürcher Zeitregel, Sichtbarkeit und Belohnung in einer eigenen Prüfung. Ein Feldwechsel verwirft die Freigabe. Auch während einer laufenden Benutzerprüfung verhindert eine spätere Feldänderung den RPC-Aufruf.
- `duel_v3_invite` erhält `p_expected_rule.metric_revision` und für eine Trainingsanzahl zusätzlich `training_type_revision`. Die Serverprüfung unter Sperren schliesst die Lücke zwischen Anzeige und Speicherung. `40001` lädt die Regeln neu und verlangt eine neue bewusste Prüfung; kein automatisches erneutes Senden.
- Der Empfänger liest die unveränderliche Vereinbarung aus dem gespeicherten Duell. Erst «Nach Prüfung ausdrücklich annehmen» ruft die bestehende `duel_v2_respond` auf. Die ältere Punkteansicht kann diese Prüfung bei verfügbarer neuer API nicht umgehen.
- Eine eigene Ansicht für alle Duellarten zeigt echte Seiten mit höchstens 20 Einträgen. Boxer starten bei eigenen Duellen. Trainer können ihre vollständige autorisierte Ansicht ausdrücklich auswählen. Die bestehende Punkte-Abschlusswarteschlange mit ihren exakten Zahlen bleibt erreichbar.
- Die Vereinsübersicht zeigt ausschliesslich angenommene, ausdrücklich vereinsöffentliche v3-Vereinbarungen als Gesamtstände. Private/alte Vereinbarungen, offene Einladungen, Trainingsdetails und Buchungsbelege erscheinen dort nicht. Eine widersprüchliche API-Antwort wird verworfen.
- Benachrichtigungslinks fragen über `p_duel_id` das genaue autorisierte Duell ab, auch wenn es älter als die erste Seite ist. Der Link führt keine Annahme, Vorschau oder Buchung automatisch aus.
- Kilometer bleiben numerisch; Trainingsanzahl muss ganzzahlig sein. Die Oberfläche rundet keine Trainingsanzahl aus einem falschen Wert zurecht. Unzuverlässige Scores werden als nicht berechenbar angezeigt.
- Die bestehende schreibfreie Abschlussprüfung unterstützt `none` und `ranked_v21`. `none` benötigt null EXP-Veränderung und keine Transaktion; rangabhängige Abschlüsse benötigen weiterhin zwei echte passende Belege. Eine geänderte Abschlussrevision braucht einen weiteren Klick. Der bestätigte Regelvertrag muss zum ausgewählten Duell passen.
- Fehlende neue API/Modul sperrt neue Funktionen. Der bestehende private Punktepfad bleibt nutzbar. Kontowechsel verwirft ausstehende private Antworten und alte Zustimmungen.

## Belege

| Prüfung | Ergebnis |
| --- | --- |
| `node tests/duel-metrics-ui.cjs` | Optionen/Revisionen, genaue Typen/Einheiten, Zahlen, unzuverlässige Scores, eingefrorene Abschlussregel und Nullprämie bestanden |
| `node tests/duel-metrics-browser.cjs` | Tatsächliches Chromium und WebKit: deaktivierte Defaults, Kilometer/Anzahl, revisionsgebundene Einladung, Feldwechsel während Auth, explizite Annahme, 20/3-Seiten, privater/Vereinsbereich, alter Einzel-Link, fehlendes Modul, verspätete Antwort nach Kontowechsel bestanden |
| Gleiche Browser-Suite, Trainer | Keine zusätzliche Belohnung erzeugt keine Transaktion; konfigurierte Punkte-/Anzahl-Rangregel zeigt genau zwei Belege; keine alte reconcile-RPC benutzt |
| `node tests/duel-metrics-api-contracts.cjs` | Tatsächliches PostgreSQL 17.11, separater Klon `league21_replay_duel_ui`: echte v3-Einladungs-/Abschlussantworten aus bestehenden Rollback-Fixtures durch dieselben JS-Validatoren geprüft; Kilometer/Anzahl ohne Prämie und rangabhängige Anzahl bestanden |
| `node tests/duel-close-ui.cjs`, `node tests/duel-close-browser.cjs` (Chromium/WebKit) | Bestehende Punkte-Abschlüsse, Revision, Belege, Rollen, fehlende API/Modul weiterhin bestanden |
| `node tests/duels-v2-browser.cjs`, `node tests/release-static-contracts.cjs` | Bestehender Punkteablauf und 33/33 statische Verträge bestanden |
| `node tests/duel-queue-browser.cjs` | Chromium 390/1280: 121 Fälle, alter fälliger Fall, Suche, Cursor, Einzel-Link und fehlende API weiterhin bestanden |

Die SQL-Bridge verlangt ausdrücklich eine Datenbank `league21_replay_*` über `PGDATABASE`. Sie nutzt `psql` (alternativ `PSQL`), normale `PGHOST`/`PGPORT`/`PGUSER`, führt die vorhandenen synthetischen Transaktionstests aus und rollt diese zurück. Keine verwaltete Supabase-Datenbank wurde verwendet. Ein früherer Read-only-Versuch mit minimalen, manuell erzeugten Concurrency-Fixtures wurde korrekt abgewiesen, weil diesen die genaue Trainingsart im Vereinbarungs-JSON fehlt. Die nachfolgende Bridge nutzt echte `duel_v3_invite`-Antworten und schwächt den Frontendvertrag nicht ab.

Bilder: `output/continuation/duel-metrics/{chromium,webkit}-none-settled.png` (mobil visuell geprüft). Echte SQL-Antworten: `output/continuation/duel-metrics/actual-postgres-api.json` (synthetische Daten).

## Auslieferung

Zusätzliche Datei `takeover-duel-metrics.js` vor `takeover-duel-close.js`; `duels.html` bindet sie ein. Serverabhängigkeit: fertige Migration `20261102095422_duel_metric_contracts_disabled.sql` einschließlich Regelrevision und Einzelabfrage. Keine zusätzliche Migration in diesem Frontendpaket.

Die beiden neuen Metriken sind weiter deaktiviert und haben keine voreingestellte Belohnung. Eine spätere explizite Entscheidung muss tatsächliche Joggingart, Belohnungsregel und Freigabe konfigurieren. Browser-Attrappen und lokales PostgreSQL sind keine verwaltete Auth-/RLS-End-to-End-Prüfung und keine physische iPhone-/Android-Abnahme.
