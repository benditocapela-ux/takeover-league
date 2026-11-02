# Workflow UI: verifizierter Stand der Fortsetzung

Stand: 2026-11-02. Das folgende Paket ist im Arbeitsbranch implementiert. Keine Produktionsschreibvorgänge, kein Merge, kein Deployment.

## Fertiges Funktionspaket

### Einladung und bestehende Duelle

- Gegnerwahl/Laufzeit öffnen eine lesbare Vorschau; nur «Einladung ausdrücklich senden» ruft die bestehende Einladung-RPC auf.
- Eingabeänderung oder Sitzungswechsel verwirft die Freigabe. Der Sendehandler prüft zusätzlich den unveränderten Eingabestand.
- Joggingkilometer und Trainingsanzahl bleiben deaktiviert. Es wurden keine neuen Belohnungen erfunden.
- Gast ohne Sitzung sieht die Anmeldung, keinen technischen AuthSessionMissingError.
- Bestehende Annahme/Ablehnung/Rückzug, Live-Wertung und Einladungsabläufe sind weiter getestet.

### Schreibfreie Abschlussvorschau und ausdrückliche Buchung

- «Ergebnis prüfen» ruft ausschliesslich `duel_v2_close_preview` auf. Der frühere direkte Aufruf von `duel_v2_reconcile` wurde aus der Seite entfernt.
- `takeover-duel-close.js` zeigt Zeitraum/Regel, geprüfte Punkte, bestätigte/offene/abgelehnte Trainings, Sperrgründe und EXP je Teilnehmer: geplant, bereits gebucht, Änderung. Vorhandene Buchungsbelege werden angezeigt.
- Erst der ausdrückliche Abschluss/Korrektur ruft `duel_v2_close_confirm` mit `p_confirm=true` und der geprüften Revision auf. Ein geänderter Stand wird erneut gezeigt und benötigt einen weiteren bewussten Klick.
- Fehlende API, fehlendes Frontendmodul, unvollständige/inkonsistente Antwort oder offene Trainings bieten keine Buchungsaktion. Es gibt keinen Rückfall auf die alte mutierende reconcile-RPC.
- Antwort eines erfolgreichen Abschlusses benötigt passende echte Belege beider Teilnehmer. Doppelklick wird unterdrückt. Abmeldung verwirft ausstehende private Antworten.
- Bereits abgeschlossene Duelle können zur Belegprüfung geöffnet werden. Eine Korrektur wird nur angeboten, wenn der Server sie ausdrücklich erlaubt.
- `?duel=<uuid>` lädt für Trainer das genaue autorisierte Punkte-Duell auch jenseits der ersten 100 Einträge und hebt es hervor. Boxer erhalten unverändert nur ihre bestehende Teilnehmeransicht. Kein Link löst automatisch eine Abschlussvorschau oder Buchung aus. Ein nicht zugänglicher Link meldet dies neutral.

### Trainer-Dashboard

- Neuer Bereich «Wettkämpfe & Abschlüsse» mit Duellabschluss-, Challenge- und Saisonlinks.
- Duellstatus basiert auf der neuen schreibfreien `duel_v2_staff_queue`-RPC. Exakte serverseitige Zahlen berücksichtigen alle Punkte-Duelle. Offen, fällig, abschlussbereit und abgeschlossen sind getrennt definiert; Abschlussbereitschaft nutzt denselben geprüften Vorschau-Helper wie die Buchungsansicht.
- Duellseite bietet nur für Trainer/Admin Statusfilter, Namenssuche und echte Cursor-Paginierung mit höchstens 20 Einträgen pro Seite. Auch alte fällige Duelle hinter mehr als 100 neuen Einträgen bleiben erreichbar.
- Fehlgeschlagene Statusabfrage wird als unbekannt angezeigt. Nach Logout können verspätete Antworten keine Statusdaten wiederherstellen.
- Vier Pixel mobiler Überlauf wurde auf untrennbare deutsche Texte in vorhandenen `.cv2-tile`-Flexelementen zurückgeführt. Derselbe Fehler wurde mit unverändertem `coach.html` aus a806260 über eine lokale Serverantwort reproduziert. Eng begrenzter Umbruch-/Min-width-Fix beseitigt die Ursache, ohne horizontales Overflow zu verstecken.

## Verifikation

| Prüfung | Ergebnis |
| --- | --- |
| `node tests/duels-v2-browser.cjs` | bestanden; bestehende Abläufe plus schreibfreies Öffnen statt altem reconcile-Aufruf |
| `node tests/duel-close-ui.cjs` | bestanden; Rollen, XSS, unvollständige Daten, tatsächliche Rewards, Versionswechsel, Doppelklick, Logout |
| `node tests/coach-competition-status.cjs` | bestanden; exakte Serverzahlen jenseits 100, strenger Antwortvertrag, API-Fehler, Rollen, verspätete Antwort nach Logout |
| `node tests/duel-queue-browser.cjs` (auch `TL_BROWSER=webkit`) | 390/1280 px bestanden; 121 Einträge über sieben Seiten, alter fälliger Fall, Suche, genauer Link, fehlende API und Logout |
| PostgreSQL 17.11: `tests/duel-staff-queue-schema.sql` und `tests/duel-staff-queue-rollback.sql` | 127 SQL-Fälle über sieben Seiten, exakte Statuszahlen, Rollen, Literal-Suche, Read-only-Vergleich, spätere Metrikausschlüsse und Rollback/Reapply bestanden |
| `node tests/release-static-contracts.cjs` | 33/33 bestanden |
| `node tests/duel-close-browser.cjs` | echter Chromium, 390/1280 px; Vorschau/Bestätigung, Versionswechsel, Belege, gesperrte/fehlende/fehlerhafte Vorschau, Admin-Deep-Link, fehlendes Modul, Boxer-/Gastbarriere bestanden |
| `$env:TL_BROWSER='webkit'; node tests/duel-close-browser.cjs` | echter WebKit, gleiche Szenarien und Breiten bestanden |
| `node tests/release-live-duels-browser.cjs` | echter Chromium, 375/1280 px; bestehende Einladungs-/Live-/Annahmefälle bestanden |
| `node tests/staff-experience-browser.cjs` | echter Chromium, 320/390/1366 px; bestehende Coach/Admin-Navigation, Rollen, Suche/Paginierung und neuer Status bestanden |
| `git diff --check` für Workflow-Dateien | bestanden |

Die Browser verwenden synthetische Konten und RPC-Antworten, keine Produktionskonten. Diese Tests ersetzen keine Datenbanktests. Die zugehörige Migration wurde vom Backend-Agenten auf isoliertem PostgreSQL 17.11 geprüft; dessen eigenständige DB-/Concurrency-Nachweise stehen in `backend-status.md`.

Screenshots: `output/continuation/duel-close/{chromium,webkit}-{390,1280}-{preview,confirm,settled}.png`. Mobile Chromium-Vorschau und Bestätigungsbereich wurden visuell geprüft. Frühere Einladungsbilder: `output/seven-hour/duel-review/`.


### Mitteilungen: exakter Zähler und vollständige Seiten

- Neue gemeinsame Lese-/Markierlogik in `takeover-inbox.js` wird von Boxer Experience und dem bestehenden Studio für Coaches verwendet. Vorhandene Zielpfad-Whitelists und `mark_my_notification_read` bleiben erhalten.
- Globaler Ungelesen-Zähler verwendet eine eigene gefilterte Head-Abfrage mit `count:'exact'`; die Seitenabfrage liefert separat die exakte Gesamtzahl. Die Zahl ist nicht länger auf die ersten 20 Einträge begrenzt.
- Echte serverseitige Bereiche von höchstens 20 Einträgen, stabil nach `created_at DESC,id DESC`, mit Vor-/Zurück-Schaltflächen. Nach Lesebestätigung wird der globale Zähler erneut vom Server gelesen. Unbekannte Zahlen werden als unbekannt dargestellt, nicht als null ungelesen.
- Frische Benutzer-/Profilprüfung vor dem Lesen und Markieren. Auth-Ereignisse leeren private Daten sofort; Request-Epochen verhindern alte Seiten oder Lesebestätigungen nach Kontowechsel. Feature-Flag und bestehende RLS bleiben maßgeblich. Keine neue Berechtigung, Tabelle oder RPC.
- `tests/inbox-browser.cjs`: tatsächliches Chromium/WebKit, jeweils Boxer Experience und Legacy-Coach-Studio; 45 Einträge/35 ungelesen, 20/20/5-Seiten ohne Duplikate, korrekte Oktober-/September-Links, Fehlversuch/Retry, unbekannter Zähler bei Abfragefehler, Kontowechsel bestanden.
- `tests/inbox-races.cjs`: verspätete Auth-/Seiten-/Markierantworten, Profil-/Kontowechsel, unbestätigte Markierung, fehlender exakter Zähler und deaktiviertes Flag bestanden.
- Gemeinsame Browser-Attrappe korrigiert: Range-Offset, Count vor Pagination, Head ohne Daten und sekundäre Sortierung entsprechen nun dem echten Query-Vertrag. Die bestehende Markierfixture persistiert ihren simulierten Serverzustand, statt nur `true` zurückzugeben.
- Bestehende Gesamtsuite `node tests/takeover3-browser.cjs` vollständig in Chromium und WebKit bestanden: Konto-Umschalter, Trainingsmeldung, App-Shell und Navigation. Statische Takeover-/Release-Verträge sowie gezielter Diff-Check bestanden.
- Bilder: `output/continuation/inbox/{chromium,webkit}-{studio,legacy}.png`; WebKit-Bilder visuell geprüft. Keine Trainingshistorie geändert.

### Zusätzliche Prüfung Periodenabschluss

Der unabhängige Review identifizierte eine mögliche Übernahme einer alten Zustimmung während einer ausstehenden Benutzerprüfung. Der Hauptagent hat Benutzer/Periode vor dem Await eingefroren und die Anfrage-Epoche unmittelbar vor der schreibenden RPC erneut geprüft. `tests/period-close-races.cjs` bestätigt Schliessen/Escape, gleichen oder anderen Staff nach Periodenwechsel, alte Vorschau und normalen expliziten Abschluss. SQL-/Archivimplementierung bleibt Eigentum des separaten Hauptpakets.


### Alle drei Duellarten über denselben Vertragsablauf

- `takeover-duel-metrics.js` ergänzt Punkte, Joggingkilometer und eine genaue Trainingsart. Die neue Serverkonfiguration bleibt deaktiviert/unvollständig; die Oberfläche aktiviert nichts.
- Einladungsprüfung enthält Typ, Zeitregel, Belohnung und Sichtbarkeit. Die gespeicherte Regelrevision und Typrevision werden beim Senden unter Serversperren geprüft. Eine Änderung benötigt neue Zustimmung; Feldwechsel während der Benutzerprüfung verhindert den alten Aufruf.
- Teilnehmer-/Traineransicht mit echten 20er-Seiten, ausdrückliche Vereinsansicht nur für freigegebene angenommene Verträge, autorisierte Einzelabfrage für alte Benachrichtigungslinks. Bestehende Punktewarteschlange bleibt separat nutzbar.
- Empfänger bestätigen die gespeicherte Vereinbarung ausdrücklich. Abschlussdialog zeigt Dezimalkilometer oder ganze Trainingszahlen und unterscheidet null Prämie ohne Transaktion von rangabhängiger Regel mit zwei tatsächlichen Belegen.
- Tatsächliches Chromium/WebKit sowie echte SQL-API-JSON-Validierung gegen PostgreSQL 17.11 bestanden. Details, genaue CI-Befehle und Grenzen in [duel-metrics-ui.md](duel-metrics-ui.md).

## Bewusste Grenzen und nächster Auftrag

1. Die Punkte-Trainerwarteschlange behält ihren eigenen Zähl-/Bereitschaftsvertrag. Alle drei Duellarten sind zusätzlich über die fertig implementierte und geprüfte v3-Ansicht erreichbar; neue Metriken werden nicht in den alten Punkte-Zähler eingemischt.
2. Produktive Kilometer-/Trainingsart-Einladungen bleiben deaktiviert, bis genaue Trainingsart, Belohnungszuordnung und Freigabe ausdrücklich konfiguriert sind. Die vollständigen Abläufe wurden mit isolierten Testkonfigurationen geprüft.
3. Die geprüfte Vereinsansicht zeigt nur angenommene, ausdrücklich vereinsöffentliche v3-Verträge mit aktuell sichtbaren Beteiligten. Private Altduelle bleiben privat; keine anonyme Freigabe.
4. Der enge Coach-/Admin-Weg für Monats-/Saisonabschlüsse ist im separaten Periodenpaket implementiert und geprüft. Aktivierung und weitergehende League-Manager-Rechte bleiben begrenzt; Nachweise stehen in archive-and-closures.md.
5. Die Backend-Migration bleibt ausstehend für eine spätere ausdrücklich freigegebene Auslieferung. Auf einer Datenbank ohne neue RPCs ist die neue Abschlussaktion absichtlich gesperrt.

Die serverseitige Warteschlange und die genaue alte Ergebnisabfrage sind jetzt implementiert. Einzelheiten und SQL-Nachweise stehen in duel-queue.md. Periodenabschluss bleibt ein separater Arbeitsbereich des Hauptagenten. Der geprüfte v3-Vertrag ist nun in der Oberfläche angeschlossen; die produktive Metrikfreigabe und Belohnungswahl bleiben ausdrücklich separat.
