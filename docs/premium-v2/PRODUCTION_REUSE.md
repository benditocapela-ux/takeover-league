# Gemessene Wiederverwendung zwischen Cool und Guard

Basis: 519 technisch getestete Varianten-/Posenzellen in Chromium und WebKit. Künstlerisch weiterhin ungeprüft, Premium deaktiviert.

Gezählt werden eindeutige Komponenten aus Datei, ID, UV-Ausschnitt und registrierter Zielbox. Farben vervielfachen diese Zählung nicht. Gleiche Dateien bedeuten keine identischen sichtbaren Pixelanteile: Atlanten enthalten teilweise unbenutzte Flächen. Es werden keine eingesparten Zeichenstunden behauptet.

| Familie | Cool-Komponenten | Guard-Komponenten | Identisch geteilt | Guard-Anteil | Geteilte Datei-Bytes |
|---|---:|---:|---:|---:|---:|
| hair | 22 | 22 | 22 | 100.0 % | 2257268 |
| head | 3 | 3 | 3 | 100.0 % | 365687 |
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

Über alle akzeptierten Ganzfiguren: 35 identische Komponenten; Cool 42, Guard 44. Datei-/ID-/UV-/Box-Details und pose-spezifische Komponenten stehen in [production-reuse.json](evidence/production-reuse.json).
Geteilte Datei-Bytes werden je Familie dedupliziert, aber nicht über Familien hinweg summiert: derselbe Atlas kann zum Beispiel Körper und Augen enthalten. Der Guard-Anteil bezeichnet die Anzahl identischer registrierter Komponenten, keinen Flächenanteil, Qualitätswert oder Produktionszeitgewinn. Die zwei allein in Guard akzeptierten Basic-Mantel-Komponenten zählen bewusst als Guard-spezifisch.
