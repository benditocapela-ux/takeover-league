# Gemessene Wiederverwendung zwischen Cool und Guard

Basis: 560 technisch getestete Varianten-/Posenzellen in Chromium und WebKit. Künstlerisch weiterhin ungeprüft, Premium deaktiviert.

Gezählt werden eindeutige Komponenten aus Datei, ID, UV-Ausschnitt und registrierter Zielbox. Farben vervielfachen diese Zählung nicht. Gleiche Dateien bedeuten keine identischen sichtbaren Pixelanteile: Atlanten enthalten teilweise unbenutzte Flächen. Es werden keine eingesparten Zeichenstunden behauptet.

| Familie | Cool-Komponenten | Guard-Komponenten | Identisch geteilt | Guard-Anteil | Geteilte Datei-Bytes |
|---|---:|---:|---:|---:|---:|
| hair | 22 | 22 | 22 | 100.0 % | 2257268 |
| head | 3 | 3 | 3 | 100.0 % | 365687 |
| top | 3 | 6 | 0 | 0.0 % | 247841 |
| bottom | 4 | 4 | 4 | 100.0 % | 715047 |
| glove | 1 | 2 | 0 | 0.0 % | 0 |
| feet | 2 | 2 | 2 | 100.0 % | 441438 |
| coat | 5 | 4 | 2 | 50.0 % | 389744 |
| aura | 0 | 0 | 0 | – | 0 |
| eyefx | 0 | 0 | 0 | – | 0 |
| scene | 0 | 0 | 0 | – | 0 |
| body | 3 | 3 | 2 | 66.7 % | 348604 |
| eyes | 1 | 1 | 1 | 100.0 % | 348604 |
| hands | 2 | 2 | 0 | 0.0 % | 0 |

Canvas: Szene, Aura und Augeneffekte teilen dasselbe Code-Modul, verwenden keine PNG-Dateien und erhalten deshalb keinen Raster-Prozentwert. Glatze ist eine Entfernung von Haaren, kein zusätzliches Artwork. Shirts bleiben ausgeschlossen. Basic Cool ist nach registrierter Verdeckung enthalten; der Hoodie ist nur in Guard verfügbar.

Über alle akzeptierten Ganzfiguren: 36 identische Komponenten; Cool 46, Guard 49. Datei-/ID-/UV-/Box-Details und pose-spezifische Komponenten stehen in [production-reuse.json](evidence/production-reuse.json).
