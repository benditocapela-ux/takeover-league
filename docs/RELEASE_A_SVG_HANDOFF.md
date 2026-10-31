# Release A: Mein Boxer mit SVG

Eigenständiger Kandidat auf `main` (`8176e8014d134136ba210ced37b230cd61190ac8`), selektiv aus PR #79 (`77e77b85a608863bc42e91fc2fff064368c4d8f7`) übernommen. Kein Merge von PR #79 und keine Übernahme seiner Commit-Historie.

## Tatsächlicher Änderungsumfang

| Datei | Zweck |
| --- | --- |
| `mein-boxer.html` | Responsiver Editor, Arena, Fokus, Shop-/Inventar-/Save-Fehlerbehandlung; Rasterimporte und Vorschaupfade entfernt |
| `takeover-mein-boxer.css` | Navy-/Gold-Layout, unabhängiges Scrollen, Sticky, responsive Darstellung; Raster-/Debug-Stile entfernt |
| `takeover-holo.js` | Bestehender konfigurierbarer SVG-Renderer mit sechs zentralen Posendefinitionen und optionaler SVG-Schattierung |
| `takeover-mein-boxer-items.js` | Konfigurierbare SVG-Ausrüstungsbilder |
| `takeover-mein-boxer-layers.js` | Konfigurierbare SVG-Materialdetails |
| `tests/boxer-holo-browser.cjs` | UI, Kleidung, Shop, Posen, Save-Race, Netzwerkfehler, Tastatur; Premium-PNG-Tests ausgeschlossen |
| `tests/boxer-responsive-layout-browser.cjs` | Mobile/Desktop, Sticky, unabhängiges Scrollen, Resize und Tastatur; Rastertests ausgeschlossen |
| `tests/boxer-editor-transactions-browser.cjs` | Einzel-/Bundlekäufe, doppelte Bestätigung, fehlgeschlagene/null/deaktivierte Inventaraktualisierung |
| `tests/mein-boxer-editor-art-contracts.cjs` | Dynamische SVG-Ausrüstung, 432 Varianten, erhaltene RPCs |
| `tests/release-a-svg-browser.cjs` | Echter Pages-Zusammenbau, Ausschlussdateien, sechs Posen, Save/Reset, fünf URL-Modi, keine fehlenden Ressourcen |
| `tools/assemble-pages-site.cjs` | Gemeinsamer statischer Pages-Dateizusammenbau ohne Premium-Publisher |
| `tests/menu-navigation-compat.cjs` | Navigation direkt im Ergebnis des Assemblers prüfen |
| `menu-navigation-compat.cjs` | Gleiche Prüfung für den bestehenden Root-Testeinstieg |
| `.github/workflows/release-2-validation.yml` | Zusätzliche isolierte Chromium-/WebKit-Matrix |
| `.github/workflows/takeover-pages-deploy.yml` | Verwendet den getesteten Assembler; weiterhin ausschließlich main, keine Ausführung in diesem Auftrag |
| `docs/RELEASE_A_SVG_HANDOFF.md` | Diese Übergabe und Freigabegrenzen |

`premium:true` in der SVG-API bezeichnet ausschließlich Vektorschattierung. Release A enthält keinen Premium-PNG-Renderer, keine Manifeste und keine Aktivierungsschalter. Alle Konfigurationsschlüssel, vorhandenen RPC-Schnittstellen, Kataloge und Datenbankdateien bleiben erhalten.

## Ausschluss und Release B

Nicht übernommen: `assets/boxer-artpacks/v1/cool/`, `assets/boxer-artpacks/v1/modular-cool/`, `docs/review/PR79-Abnahme.zip`, beide Premium-Manifeste, Rasterruntime, Draft-Layer-/Anatomiewerkzeuge, Grafikimport/-publisher/-reporter und Premium-Grafiktests. Die bestehenden Dateien und Tests bleiben in PR #79. Das Abnahmepaket wurde nicht neu erstellt.

PR #79 bleibt Draft mit unverändertem Head `77e77b85a608863bc42e91fc2fff064368c4d8f7`; dort bleiben `approved:false` und `enabled:false`. Ausgangsprüfungen: Staging 41150088490, V2 41150088456 und Abnahmeartefakt 41150088614 erfolgreich.

**Öffentlichkeitsgrenze:** Nicht auf GitHub Pages ausgelieferte Dateien können in einem öffentlichen Repository weiterhin öffentlich zugänglich sein. Der isolierte Release-A-Branch entfernt weder Dateien noch Historie aus PR #79. Eine spätere Entfernung aus einem Branch macht bereits veröffentlichte Git-Historie, andere Referenzen oder Kopien nicht automatisch unzugänglich. Dies ist keine nachträgliche Privatisierung.

## Validierung und Reproduktion

Mit `playwright@1.56.1` und `jsdom@26.1.0`, ausschließlich lokale Server und gemockte Backend-Antworten:

- `node tests/mein-boxer-editor-art-contracts.cjs`: 432 SVG-Varianten, Ausrüstung und bestehende RPC-Hooks.
- Jeweils mit `BROWSER=chromium` und `BROWSER=webkit`: `tests/boxer-holo-browser.cjs`, `tests/boxer-editor-transactions-browser.cjs`, `tests/release-a-svg-browser.cjs`, `tests/boxer-responsive-layout-browser.cjs` (WebKit mit `EDITOR_ONLY=1`).
- Editor-Viewports 320×568, 375×667, 375×812, 390×844, 430×932, 768×1024, 1440×900 einschließlich Rückwechsel zu Mobile. Bestehender Studio-Test zusätzlich Chromium 360–1600 px.
- Pages-Test: guard/jab/sieg/cool/flex/ansage, Profil-/Kartenpose, Speichern/Verwerfen, normale URL und `?art=preview/reference/layers/modular`; keine JavaScript-Fehler, fehlgeschlagenen Ressourcen oder Premium-Anfragen.
- Kauf-/Speichertests: Einzel-/Bundlekauf, Anprobe-Sperre, doppelte Bestätigung, optionale Leistungsfehler, Inventarfehler, Save-Race, erneuter Versuch nach Netzwerkfehler; keine produktiven Schreibzugriffe.
- CSS-/JS-Struktur, bestehende Holo-Verträge, statische Release-/UX-Verträge und Navigation prüfen die Integration. CI-Ergebnis gilt jeweils für den tatsächlichen neuen PR-Head, siehe Checks im Draft-PR.

Die WebKit-Fokustests verwenden Fokus plus Enter statt browserabhängiger Mausklick-Fokussierung. Visuelle Stichproben sind keine persönliche Geräte- oder Designabnahme.

## Freigabeentscheidung

Technisches GO zur manuellen Abnahme bei vollständig grünen Checks des neuen Draft-PRs. NO-GO für automatische Produktivfreigabe.

Noch erforderlich: persönliche UI-/Outfit-Abnahme auf physischem iPhone und Android, VoiceOver/NVDA sowie ausdrückliche spätere Merge-/Deployment-Freigabe. Keine produktive Supabase-Änderung, kein Merge, kein Deployment, keine Premium-Aktivierung, kein Force-Push oder Umschreiben vorhandener Historie.
