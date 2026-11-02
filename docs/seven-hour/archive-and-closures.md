# Periodenarchiv, Abschluss und Hinweise

Dieses Paket repariert den früher global nach Rang sortierten Saisonmix. Monat und Saison besitzen getrennte Schlüssel; ein rekonstruierter Oktober wird nicht als abgeschlossene Herbstsaison ausgegeben. Öffentlich bleiben nur aktuell aktive, gelistete, nicht archivierte Profile sichtbar; gespeicherte Ränge werden bei ausgeblendeten Profilen nicht neu durchnummeriert.

## Verträge

- `league_archive_period(kind,key,limit,offset)`: read-only, maximal 50 Datensätze (UI 20), positive Topplätze, passende Ehrungen, eigener Rang unabhängig von der Seite. Monatsregel entspricht dem bisherigen Monatsranking (Punkte, Lifetime-EXP, Name/ID). Saisonrekonstruktion entspricht dem vorhandenen Saisonabschluss (nur Boxer, Punkte/Perioden-EXP auf mindestens null, Ranggleichstände).
- `league_period_close_preview(kind,key)`: nur aktive, nicht archivierte Coach/Admin-Profile; vollständig lesend, auch in echter READ ONLY-Transaktion getestet. Zeitraum, offene/bestätigte/abgelehnte Trainings, Ledgerfehler, erste 20 Ergebnisse, Gesamtzahl, Revision und vorhandene Ehrungsregel. Kein Zusatzbonus konfiguriert, keine geplanten Buchungen.
- `league_period_close_confirm(kind,key,true,revision)`: ausdrücklicher Ergebnisabschluss. Präziser Perioden-Advisory-Lock und relevante Trainingslocks; danach gemeinsame Vorschau neu berechnen. Bei geänderten Daten neue Bestätigung verlangen. Eine konsistente Vorschau liefert die gespeicherten Zeilen, nicht eine abweichende erneute Rangberechnung.
- Monate: eigener unveränderlicher Snapshot und Abschluss-Audit. Spätere rückdatierte Buchungen ändern ihn nicht. Keine automatisch erzeugten Monatstitel.
- Saisons: vorhandene positive Top-3-Titel, bestehende Daten und Folgeentwurf erhalten; Coaches bekommen nur den engen Abschlussweg. Aktivierung bleibt admin-only. Auch die alte ausdrückliche Admin-Abschlussaktion delegiert auf den gemeinsamen Vertrag. League Manager führt zur lesenden Vorschau.
- Mitteilungen: `period:<kind>:<key>:closed` plus Empfänger als eindeutige Identität, exakter Archiv-Link, keine fiktive Auszahlung. Zwei verschiedene Abschlüsse unmittelbar nacheinander bleiben zwei Ereignisse.
- `league_period_notices()`: begrenzt auf den vergangenen Monat und höchstens drei aktuelle relevante Saisons. Alte Ergebnisse bleiben über Archiv und Inbox auffindbar. Kein unbegrenzter Verlauf.
- `league_period_notice_dismiss(event_key)`: nur der aktuelle aktive Nutzer, nur ein existierendes aktuelles Ereignis. Server speichert Profil/Periode/Phase; alte vorläufige Hinweise unterdrücken keinen neuen offiziellen Abschluss. Passende eigene Inbox-Nachricht wird als gelesen bestätigt, fremde Inbox bleibt unverändert. Keine globale Browserpräferenz.

Die Bestätigung friert den geprüften Buchungsstand ein. Neu eingereichte Trainings/Buchungen nach diesem konsistenten Stand schreiben einen offiziellen Snapshot nicht still um. Eine spätere administrative Ergebnisrevision ist **nicht** neu eingeführt. Keine nachträgliche automatische Belohnung.

## Prüfungen

Reale lokale PostgreSQL-17.11-Fixtures:

- `tests/period-archive-schema.sql`: zwei getrennte Saisons, Monatsgrenzen, begrenzte Seiten, eigener Rang ausserhalb Seite 1, gespeicherte Namen, gleiche Ränge/Nullpunkte, aktuelle Profil-Sichtbarkeit auch bei bisherigen direkten Tabellenlesern; anonym/authentifiziert und READ ONLY.
- `tests/period-close-schema.sql` plus `period-close-transaction.sql`: Gast/Boxer/archivierter Coach verweigert, Coach darf gezielt abschliessen, Coach darf nicht aktivieren; laufende Saison blockiert; offene Trainings und fehlende/doppelte Ledgers blockieren; Revision geändert; Wiederholung; kein Bonus; heutige Sichtbarkeit und unveränderliche Snapshot-Zeilen.
- `period-close-concurrency.cjs`: zwei tatsächliche PostgreSQL-Sessions (Coach/Admin), zweite wartet auf denselben Periodenlock. Genau ein Snapshot, zwei Empfänger-Mitteilungen, keine neue Punkte-/EXP-Buchung.
- `period-close-rollback.sql`: Rollback/Reapply erhält Profile, Ledger, Saison-, Ergebnis-, Ehrungs- und Inboxzeilen bytegleich.
- `period-notices-transaction.sql` und `period-notices-rollback.sql`: Konto-/Ereignistrennung, erneutes Erscheinen nach offiziellem Abschluss, zwei Perioden, eigenes Read-Acknowledgement, Rollen/Flag und Rollback ohne Inboxänderung.

Echte Chromium-/WebKit-Browser mit **synthetischen RPCs**:

- `period-archive-browser.cjs`: 320/390/1280 px, Periodenwechsel und exakte Links, 42 Zeilen in drei Seiten, Fehler/leere Antworten, eigener Rang, Kontoabmeldung, verspätete Antworten.
- `period-close-browser.cjs`: keine Aktion beim Öffnen, blockierte/unverfügbare/ungültige Vorschau, Escape/Fokus, ausdrückliches Bestätigen, veraltete Revision, Doppelklick, Serverfehler, gespeicherten Snapshot zurücklesen, Bestätigung sichtbar halten.
- `period-close-races.cjs`: gezielter DOM-Nachweis für Schliessen/Abbrechen und Kontowechsel während ausstehender Identitätsprüfung. Die alte Bestätigung darf dann keinen RPC mehr senden.
- `period-notices-browser.cjs`: Kontowechsel, zwei verschiedene Perioden, genaue Ziel-URLs, alter geschlossener Hinweis versus neuer Abschluss, Fehler/Logout, 320/390/1280 px.
- Native iPhone-/Android-Geräte und echte authentifizierte Supabase-/PostgREST-Aufrufe wurden hier nicht abgenommen.

## Voraussetzungen und Rücknahme

Archiv: bestehende V2.1-Saison-/Ergebnistabellen und Profile mit `archived_at`. Abschluss zusätzlich vorhandene Trainings-/Punkte- und Mitteilungstabellen, bestehende Saisontitel-Unique-Regel, `notifications_enabled()`, vorherige Event-Identity-Migration. Hinweise bauen auf dem Monatsabschluss auf. Die neuen Tabellen liegen im privaten Schema; API-Rollen bekommen keine direkten Tabellenrechte.

Zu jeder Migration liegen Read-only-Preflight/Postflight und ein Rückrollskript in `supabase/production-prep`. Hinweise zuerst zurücknehmen, dann Abschluss, zuletzt Archivleser. Nach gespeicherten offiziellen Resultaten oder Profil-Acknowledgements verweigert die Rücknahme eine Löschung dieser Daten; dann Frontend zurücknehmen und Daten erhalten. Der frühere Archiv-Rollback würde auch die hinzugefügte heutige Profil-Sichtbarkeit zurücknehmen und ist deshalb kein automatischer Notfallknopf.

Keine dieser Migrationen wurde in Produktion oder im gemeinsamen Supabase-Testprojekt ausgeführt. Keine Feature-Flags geändert, keine echte Periode abgeschlossen.
