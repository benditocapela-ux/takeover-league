# Gemessene Wiederverwendung zwischen Cool und Guard

Basis: 407 technisch getestete Varianten-/Posenzellen in Chromium und WebKit. Künstlerisch weiterhin ungeprüft, Premium deaktiviert.

Gezählt werden eindeutige Komponenten aus Datei, ID, UV-Ausschnitt und registrierter Zielbox. Farben vervielfachen diese Zählung nicht. Gleiche Dateien bedeuten keine identischen sichtbaren Pixelanteile: Atlanten enthalten teilweise unbenutzte Flächen. Es werden keine eingesparten Zeichenstunden behauptet.

| Familie | Cool-Komponenten | Guard-Komponenten | Identisch geteilt | Guard-Anteil | Geteilte Datei-Bytes |
|---|---:|---:|---:|---:|---:|
| hair | 11 | 11 | 11 | 100.0 % | 289237 |
| head | 2 | 2 | 2 | 100.0 % | 188390 |
| top | 1 | 1 | 0 | 0.0 % | 0 |
| bottom | 4 | 4 | 4 | 100.0 % | 705701 |
| glove | 1 | 2 | 0 | 0.0 % | 0 |
| feet | 2 | 2 | 2 | 100.0 % | 441438 |
| coat | 3 | 4 | 1 | 25.0 % | 320148 |
| aura | 0 | 0 | 0 | – | 0 |
| eyefx | 0 | 0 | 0 | – | 0 |
| scene | 0 | 0 | 0 | – | 0 |
| body | 3 | 3 | 2 | 66.7 % | 348604 |
| eyes | 1 | 1 | 1 | 100.0 % | 348604 |
| hands | 2 | 2 | 0 | 0.0 % | 0 |

Canvas: Szene, Aura und Augeneffekte teilen dasselbe Code-Modul, verwenden keine PNG-Dateien und erhalten deshalb keinen Raster-Prozentwert. Glatze ist eine Entfernung von Haaren, kein zusätzliches Artwork. Basic-Cool und Shirts sind ausgeschlossen, weil sie im integrierten Renderer blockiert sind.

Über alle akzeptierten Ganzfiguren: 23 identische Komponenten; Cool 30, Guard 32. Datei-/ID-/UV-/Box-Details und pose-spezifische Komponenten stehen in [production-reuse.json](evidence/production-reuse.json).
Geteilte Datei-Bytes werden je Familie dedupliziert, aber nicht über Familien hinweg summiert: derselbe Atlas kann zum Beispiel Körper und Augen enthalten. Der Guard-Anteil bezeichnet die Anzahl identischer registrierter Komponenten, keinen Flächenanteil, Qualitätswert oder Produktionszeitgewinn. Die zwei allein in Guard akzeptierten Basic-Mantel-Komponenten zählen hier bewusst als Guard-spezifisch.
