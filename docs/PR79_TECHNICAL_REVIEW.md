# PR #79 – technische Prüfung und Abnahmegrenzen

Ausgangsstand: `644f2c85f597886ef36017ebb87181300a10d421`, geprüft am 30. Oktober 2026. Änderungen betreffen ausschliesslich den Draft-Branch. Keine Migration, produktive Datenänderung oder Grafikaktivierung.

## Behobene Befunde

| Priorität | Befund | Korrektur / Nachweis |
|---|---|---|
| P1 | Bestätigter Kauf, anschliessender Inventarabruf schlägt fehl: gekaufter Artikel blieb gesperrt. | Erfolgreiche Kaufantwort aktualisiert Coins, Artikel- und Bundlebesitz unmittelbar; Nachladen ersetzt den Zustand nur bei gültigen Daten. Sechs Browserfälle für Einzel-/Bundlekauf mit Netzwerkfehler, leerer oder deaktivierter Antwort; Doppelbestätigung löst nur einen Kauf aus. |
| P1 | Original-PNGs auf Desktop konnten auf 0 × 0 Pixel kollabieren. | Desktop-Preview reserviert die originale 768:1216-Leinwand; reale acht Repository-PNGs werden auf Handy und Desktop geprüft. |
| P1 | Desktop-Figur verschwand beim Scrollen, weil spätere CSS-Regel `sticky` überschrieb. | Überschreibende Regel entfernt; Test scrollt tatsächlich und prüft sichtbare Bühnenposition. |
| P1, latent | Originalmasken erlaubten im Premium-Renderer Mantelentfernung trotz fehlender Anatomie. | Deklarative `configurations.cool` begrenzt diesen Satz auf die Referenzkombination; unpassende Varianten fallen vor dem Preload auf SVG zurück. Beide Freigabeschalter bleiben false. |
| P2 | Optionale Leistungsabfrage konnte den ganzen Editor blockieren. | Netzwerkfehler dieser Abfrage wird abgefangen; Haupteditor bleibt bedienbar. |
| P2 | Kaufstatus zeigte Speichern; entfernte Dialogbuttons verloren Tastaturfokus. | Getrennte Kauf-/Speichertexte, Fokus auf aktiven Tab nach entfernten/deaktivierten Controls; Panel-Fokus bleibt erhalten. |
| P2 | Desktop-Titel und Speicherstatus überlappten in WebKit. | Titel erhält eine eigene Zeile; Geometrietest prüft überschneidungsfreie Überschrift. |

## Reproduzierbare lokale Prüfungen

- `node tests/boxer-editor-transactions-browser.cjs`: echte Editorlogik mit simulierten RPCs, keine produktiven Schreibzugriffe.
- `node tests/boxer-responsive-layout-browser.cjs`: 375 × 812, 390 × 844, 430 × 932, 768 × 1024, 1440 × 900; Kategorie-, Tastatur-, Scroll- und Resizeprüfungen; Originalgrafiken auf Mobilgerät und Desktop. Zusätzlich bestehende Studio-Matrix.
- `BROWSER=webkit node tests/boxer-responsive-layout-browser.cjs`: dieselbe Matrix mit Playwright-WebKit, keine physische iPhone-Abnahme.
- `SHOTS=<Verzeichnis> node tests/boxer-holo-browser.cjs`: bestehende Integration inkl. Speichern während späterer Auswahländerungen, Kauf, Bundle, Fehlerfälle, Referenz-/Layerimport, SHA-256, Originalgrafiken und SVG-Fallback.
- `node tests/boxer-original-art-readiness.cjs` und `node scripts/validate-boxer-artpack.cjs`: 8/8 Originale, 812800 Bytes; Abmessungen, Alpha und Budget gültig.
- Bestehende Staging-Node- und Browser-Suiten sowie gezielte Renderer-Verträge sind Teil der Regression. Verbindliche Linux-Ergebnisse stehen in den Actions des jeweiligen PR-Commits.

Lokale Windows-Grenzen: Der ZIP-Importvertrag benötigt das Systemprogramm `zip`; der Publisher-Vertrag benötigt Dateisymlink-Rechte. Beide vollständigen Tests laufen unverändert unter Linux-CI. Einige ältere Browserfixtures setzen LF-Zeilenenden voraus; lokale Fixtures wurden ohne inhaltliche Änderung auf LF gelesen/normalisiert.

## Freigabestatus

Die technische Prüfung deckt lokale Browser und simulierte Backendantworten ab. Keine produktiven Kauf-, Inventar- oder Profildaten wurden verändert; serverseitige Autorisierung und Transaktionsschutz wurden nicht durch Frontend-Prüfungen ersetzt. Physische iOS-Geräte, Nutzungsrechte und die persönliche Designabnahme bleiben gesonderte Freigabeschritte.

Die Originalrekonstruktion ist vorhanden, eine unabhängig umkleidbare Premiumfigur noch nicht. Exakte fehlende Ebenen, Anatomie und Exportkoordinaten: [MEIN_BOXER_ART_GAPS.md](MEIN_BOXER_ART_GAPS.md). Es wurden keine neuen Ersatzillustrationen erzeugt. `approved:false`, `enabled:false`, Draft-Status sowie Merge-/Deploy-Grenze bleiben bestehen.
