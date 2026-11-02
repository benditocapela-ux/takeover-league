# Shop- und Item-Vorschauen: gezielter Folgeaudit

Stand: 2. November 2026, Fortsetzung von Draft-PR #94 auf Basis `16e2fa9`. Dieser Audit verwendet lokale Browser und synthetische SDK-Antworten. Keine echten Käufe, Kontoschreibzugriffe, Änderungen an Preisen, Besitz, Freischaltungen oder produktiven Flags. Kein Merge/Deployment.

## Befunde und Änderungen

1. **Abgebrochene Kauf-/Ausrüstungsanfrage blockierte den Shop.** Der `buy_kg_item`-/`equip_kg_item`-Aufruf stand ausserhalb eines `try/finally`. Eine verworfene Promise liess `busy` und den Button gesperrt. Vor der Korrektur schlug der neue Browserfall mit einem synthetischen Verbindungsabbruch fehl; es erschien keine Fehlermeldung. Beide Aktionen behandeln nun auch Transportausnahmen, zeigen den Fehler im offenen Detail und geben die Sperre zuverlässig frei.
2. **Bestätigter Beleg ging bei ausgefallener Nachlese in der Anzeige verloren.** Der Shop übernimmt jetzt den bestätigten Itembesitz und Kontostand beziehungsweise den vom Server zurückgegebenen Look, bevor er den Katalog erneut liest. Scheitert ausschliesslich diese Nachlese, steht ausdrücklich «Kauf bestätigt» bzw. «Ausrüstung bestätigt». Ein bereits bestätigter Kauf wird nicht erneut angeboten. Ein unpassender oder unvollständiger Beleg erzeugt keinen Besitz-/Guthabenwechsel.
3. **Verspäteter Kauf öffnete eine alte Auswahl erneut.** Ein während der Anfrage geschlossenes Detail bleibt geschlossen; eine inzwischen geöffnete andere Auswahl bleibt ausgewählt und erhält den aktuellen Besitz-/Kontostand. Es erfolgt keine automatische Wiederholung der schreibenden Anfrage.

Die Änderungen betreffen ausschliesslich die bestehende Oberfläche in `shop.html`. Die vorhandenen RPCs und serverseitigen wirtschaftlichen Regeln bleiben unverändert. Der Belegvertrag wurde gegen `buy_kg_item` in `20261028210000_kampfgeist_shop.sql` (`key`, `name`, `price`, `balance`) und den aktuellen `equip_kg_item` in `20261028220000_kampfgeist_etappe5.sql` (`look`) gelesen.

## Grafik- und Datenwahrheit

| Bereich | Geprüfter Nachweis |
| --- | --- |
| Kampfgeist-Katalog | 114 bestehende Seed-Items unverändert eingelesen; sechs repräsentative Shop-Kategorien: Avatar, Aura, Banner, Rahmen, Titel, Handschuhe. |
| Kachel → Detail | Identischer Grafik-Markup pro ausgewähltem Item; dieselben Katalogschlüssel und Preise. |
| Ausgerüstete Figur/Karte | Nach ausdrücklichem synthetischem Ausrüsten stimmt die sichtbare Karte mit dem Renderer des bestätigten Looks überein. |
| Eigenständiges Kampfgeist-System | Behält seine tatsächlichen SVG-Designs; keine Premium-PNG wird für einen SVG-Katalogartikel vorgetäuscht. Keine Katalogidentitäten ersetzt. |
| Premium-Posen und Bundle | Bestehende Suite `premium-editor-previews-browser.cjs` vom Hauptagenten nach der separaten Adapterkorrektur erneut in Chromium/WebKit bestanden: 12 Posen-Kacheln/FUT, genaue Bundle-Pixelparität, getrennte Profil-/Kartenpose, unveränderte Sperren, keine Schreibaufrufe durch Anprobe, SVG-Fallback bei fehlenden PNGs. Kein zweiter identischer Lauf durch diesen Audit. |
| Gemeinsame Premium-Konsumenten | Separater Hauptagentenfix `pending Map<key, Set<callback>>` in `takeover-premium-character.js` unabhängig gelesen: alle wartenden Konsumenten erhalten das fertige Ergebnis; keine weiteren Review-Blocker. Eigener Regressionstest des Hauptagenten in beiden Engines bestanden. |
| Mobile Details | Detail/Seite bei 320/390/430 px ohne horizontalen Überlauf; Detail bei CSS-Zoom 200 % scrollbar und schliessbar. Chromium-/WebKit-Screenshots der bestätigten Offline-Kaufanzeige visuell kontrolliert. |

## Neue gezielte Browserprüfung

`node tests/shop-preview-audit-browser.cjs` führt standardmässig **Chromium und WebKit** aus. Optional beschränkt `BROWSER=chromium` oder `BROWSER=webkit` die Engine; keine notwendige externe Konfiguration. Alle externen Zugriffe werden durch synthetische Antworten ersetzt. Der Test verändert ausschliesslich isolierten Fixture-Zustand.

Ergebnis des abschliessenden erweiterten Laufs: beide Engines bestanden; gemessene lokale Gesamtlaufzeit 39,14 Sekunden.

Geprüfte Fälle:

- Verworfene Kauf-Promise: kein erfundener Besitz, Fehlermeldung, bewusster Retry funktioniert.
- Verworfene Ausrüstungs-Promise: bestehende Figur bleibt unverändert, Retry bleibt möglich.
- Erfolgreicher Kauf plus fehlgeschlagene Katalognachlese: Besitz und bestätigter Kontostand bleiben sichtbar, kein zweiter Kaufbutton.
- Erfolgreiche Ausrüstung plus fehlgeschlagene Nachlese: tatsächlich bestätigter Look bleibt sichtbar und wird nicht erneut zum Ausrüsten angeboten.
- Beleg mit falschem Item-Schlüssel: weder Guthaben noch Besitz werden übernommen.
- Kachel-/Detail-/angewandter-Look-Parität und ursprüngliche Preise aller sechs Kategorien.
- Laufende Kaufanfrage → Escape → anderes Item → verspätete Antwort: neue Auswahl bleibt bestehen; genau eine Kaufanfrage.
- Schmale Displays, 200 % CSS-Zoom, erreichbarer Schliessen-Button und keine JavaScript-Fehler.

Zusätzliche Regressionen nach der Shopänderung: `node tests/kampfgeist-browser.cjs` (bestehender Chromium-Shopablauf einschliesslich Rang-/Coin-Sperren, Inventar, Verwaltung mit synthetischen Antworten), `node tests/kampfgeist-contracts.cjs` und gezielter `git diff --check` bestanden. Keine neue SQL-Migration erforderlich.

## Grenzen

Diese Prüfung ist keine echte Cloud-Kaufabnahme und keine physische iPhone-/Android-Abnahme. CSS-Zoom ersetzt keine Betriebssystem-Lupe. Pixel-/Markup-Parität bestätigt Quellen- und Zuordnungsrichtigkeit, keine vollständige künstlerische Abnahme aller Varianten. Pose-/Ärmelgrafiken und neue Rasterassets bleiben im getrennten Grafikpaket. Weitere Konto-/Rollenwechsel im Shop wurden hier nicht neu freigegeben oder umfassend abgenommen.

Lokale Bildnachweise: `output/continuation/shop-audit/chromium-confirmed-offline.png` und `webkit-confirmed-offline.png`. Diese Dateien sind Testausgaben, keine produktiven Assets.
