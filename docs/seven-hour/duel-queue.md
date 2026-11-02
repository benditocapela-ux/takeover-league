# Staff-Punkte-Duellwarteschlange

## Vertrag und Abhängigkeiten

CLI-erzeugte Migration: `20261102095352_duel_staff_queue_readonly.sql`.

Vorausgesetzt werden die bestehende Duell-/Profilstruktur inklusive `profiles.archived_at` und `20261102084519_duel_points_shared_preview_close.sql`. Die Queue benötigt keine neue Metrik-Migration. `coalesce(to_jsonb(d)->>'scoring_metric','points')='points'` behandelt bestehende Datensätze als Punkte und schliesst später explizit anders markierte Duelle vor dem Punkte-Preview aus. Es gibt keine Änderung an Scoring, Prämien, Snapshots, Besitz oder Feature-Flags.

`duel_v2_staff_queue(p_state text='due', p_limit int=20, p_before timestamptz=null, p_before_id uuid=null, p_search text=null, p_duel_id uuid=null)` liefert:

- `items`: höchstens 20 bisherige v2-Duell-Daten plus `close_ready` für fällige Duelle;
- `next_cursor`: `{before,before_id}` oder null, Reihenfolge `(invited_at DESC,id DESC)`;
- `counts`: exakte Zahlen für `all/open/due/ready/closed`, vor Cursor-Paginierung und innerhalb derselben Such-/ID-Auswahl;
- `state/search/duel_id/metric/limit/as_of`: prüfbarer Antwortkontext.

| Bereich | Definition |
| --- | --- |
| Offen | Noch nicht abgelaufene Einladung oder aktive Laufzeit mit Ende in der Zukunft |
| Fällig | Active/awaiting_reviews und Ende erreicht |
| Abschlussbereit | Fällig und derselbe schreibfreie Vorschau-Helper liefert `can_close=true` |
| Abgeschlossen | Status settled |
| Alle | Alle Punkte-Duelle einschliesslich abgelehnter, abgelaufener und abgebrochener Einladungen |

Abschlussbereit ist eine Teilmenge von fällig. Fehler bei der Bereitschaftsprüfung brechen die Antwort ab, statt unbekannte Fälle als erledigt zu zählen. Bereitschaft ist keine Buchungsgarantie; die explizite Bestätigung prüft die Revision erneut.

Suche ist ein literaler, nicht gross-/kleinschreibungssensitiver Namensbestandteil (maximal 80 Zeichen). `%` und `_` sind keine Wildcards. `p_duel_id` erlaubt die genaue autorisierte alte Duellansicht; eine ID-Abfrage nimmt keinen Cursor an. Unvollständige Cursor und unbekannte Statuswerte werden zurückgewiesen. Das Limit wird auf 1–20 begrenzt.

## Schutz und Datenzugriff

Der öffentliche Wrapper ist STABLE/SECURITY INVOKER. Der Helper liegt in `league_v21_private`, ist STABLE/SECURITY DEFINER mit leerem search_path und prüft zuerst `auth.uid()`, aktives nicht archiviertes Coach/Admin-Profil sowie das bestehende Duell-Flag. Anonyme Ausführung ist widerrufen. Boxer, unbekannte/inaktive/archivierte Identitäten erhalten keine Queue-Daten oder Gesamtzahlen. Es gibt keine neue Tabellenleseberechtigung und keine neue Vereinsöffentlichkeit.

Frontend-Boxer bleiben bei ihrer bisherigen Teilnehmer-RPC. Trainer verwenden ausschliesslich die neue Queue; bei fehlender API gibt es einen ehrlichen Fehler ohne Rückfall auf die abgeschnittene 100er-Liste. Einladungsfelder bleiben verfügbar. Abmeldung und überholte Filteranfragen können keine alten privaten Antworten zurückbringen.

## Echte lokale SQL-Verifikation

Isolierte neue Datenbank `league21_replay_duel_queue` auf lokalem PostgreSQL 17.11, Port 55481. Keine geteilte Test- oder Produktionsdatenbank verändert.

Die vorhandene synthetische Punkte-Preview-Grundlage wurde mit den echten Migrationen aufgebaut; nur die zwei bereits im lokalen Cluster vorhandenen Rollenerstellungen wurden beim Bootstrap ausgelassen. Danach:

`psql -X -v ON_ERROR_STOP=1 -d league21_replay_duel_queue -f tests/duel-staff-queue-schema.sql -f tests/duel-staff-queue-rollback.sql`

Verifiziert: 120 neuere abgeschlossene plus sieben weitere Duelle, darunter drei alte fällige Fälle. Exakte Werte: all127/open2/due3/ready1/closed120. Offenes Training und fehlende Punktebuchung verhindern ready. Sieben 20er-Seiten enthalten jedes Duell genau einmal trotz identischer Zeitstempel. Alter fälliger Fall und direkte ID-Abfrage funktionieren. Rollen/Flag-Grenzen, Literal-Suche, ungültige Cursor, Limit, späterer Metrikfilter und unveränderter Zustand von Duellen/Prämien/Ledgern/Events/Inbox bestehen. Rollback/Reapply erhält zusätzlich die bestehende Scoring-Funktionsdefinition.

Ein repräsentativer lokaler EXPLAIN ANALYZE auf diesem 127-Duell-Fixture ergab **22.067 ms** inklusive exakter Bereitschaftszählung (kein Produktions-SLA). Bereitschaft wird ausschliesslich für die fällige Teilmenge berechnet. Exakte Zähler müssen diese Teilmenge bei jeder Abfrage prüfen; bei deutlich grösseren Beständen ist dies erneut zu messen.

Vorbereitete Metadatenprüfung und Rollback liegen unter `supabase/production-prep/` mit derselben Migration-ID. Sie wurden nicht produktiv ausgeführt.

## Browser und Belege

`tests/duel-queue-browser.cjs` läuft in Chromium und mit `TL_BROWSER=webkit` in WebKit, jeweils 390 und 1280 px. 121 synthetische Datensätze, sieben Seiten, alter fälliger Fall, Vor-/Zurücknavigation, Filter/Suche, genaue alte ID, fehlende Queue ohne erfundene Nullzahl, weiter verfügbare Einladung, verspätete Antwort nach Logout und keine unbeabsichtigte Buchung wurden geprüft.

`tests/coach-competition-status.cjs`, die bestehende Einladungs-/Abschlussprüfung und `tests/staff-experience-browser.cjs` bleiben grün. Bilder: `output/continuation/duel-queue/`; früheres Abschluss-Paket: `output/continuation/duel-close/{chromium,webkit}-{390,1280}-{preview,confirm,settled}.png`.
