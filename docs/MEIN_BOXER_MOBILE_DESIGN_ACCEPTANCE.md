# Takeover League · Mein Boxer · mobile Designabnahme

Stand: 30. Oktober 2026 · Pull Request #79 · **kein Merge/Deployment**

## Bestätigte visuelle Richtung

Die vom Nutzer bestätigte Web-App-Konzeptansicht dient als **Designziel**: dunkles Navy, kräftige Goldakzente, hochwertiges Arena-Licht, grosse zentrale Boxerfigur, fünf Symbol-Rubriken und darunter horizontal auswählbare Equipment-Karten. Die verbindliche Charakterreferenz ist der dunkelhäutige Boxer mit Afro, **verschränkten Armen**, schwarz-goldenem Mantel, TAKEOVER-Shorts und hohen Stiefeln. Die KI-Konzeptansicht ist ein statisches Designbild, **keine fertige Web-App und kein echtes mehrschichtiges Charakter-Asset**.

## Technische Umsetzung im Editor

- `mein-boxer.html`: echte DOM-Bühne `.mb-arena`, zwei TAKEOVER-Banner, Scheinwerfer, Ringseile und goldene Plattform; dynamisches `heroArt(cfg,pose)` bleibt unverändert die Figur.
- Oben ein kompakter Titel mit aktuellem Speicherstatus (`saved`, `dirty`, `tryon`, `busy`) und weiterhin erreichbarem Studio-Link.
- Fünf gleich breite Tab-Buttons mit zugänglichem Text und dekorativen SVG-Symbolen: **Körper**, **Kleidung**, **Extras**, **Posen**, **Shop**.
- Equipment-Karten verwenden weiterhin die bestehenden **variablen** SVG-Illustrationen; Cyan markiert die gewählte Ausrüstung. Shop, Kaufbestätigung, Speichern und Anprobe werden nicht ersetzt.
- Auf Handys (bis 819 px Breite) bleibt die obere Figur fixiert, `.mb-tabbody` scrollt unabhängig darunter. Sehr niedrige Displays und 320-px-Handys haben eigene Grössenbegrenzungen. Auf Desktop bleibt die bewährte zweispaltige Studio-Ansicht.
- Scheinwerfer, Banner, Bodenring und Navigation sind CSS/SVG – **kein eingebauter Screenshot**. Die Bühne ist `aria-hidden`, klickt nichts an und liegt hinter der Figur.

## Browserabnahme im PR

`tests/boxer-holo-browser.cjs` und das bestehende Staging-Workflow-Screenshot-Artefakt prüfen insbesondere:

1. Original-SVG oder vollständig freigegebene transparente Premium-Ebenen statt eines feststehenden Bildes.
2. Figur bleibt innerhalb des Bühnenausschnitts; die Ausrüstung bleibt darunter unabhängig scrollbar.
3. Fünf navigierbare Tabs mit korrekten Symbolen, unveränderten Auswahl- und Speicheroperationen.
4. «Gespeichert» nach dem Laden, «Nicht gespeichert» nach einer sichtbaren Auswahländerung.
5. Kein horizontaler Seitenscroll bei 320 × 568, 375 × 667, 390 × 844 und 430 × 932 Pixeln; Ausstattung und Speichern funktionieren weiterhin.
6. Referenz-Screenshots unter `holo-approved-arena-design.png`, `holo-arena-compact-phone.png`, `holo-arena-tall-phone.png` in GitHub-Actions-Artefakten, sofern Chromium-Tests erfolgreich durchlaufen.

## Noch offen vor Freigabe

Die echten, qualitativ mit der bestätigten Anime-Vorlage übereinstimmenden, **austauschbaren** Bilddateien fehlen noch. Daher bleiben im aktuellen `takeover-mein-boxer-artpack-manifest.js` beide Schalter `approved:false` und `enabled:false`. Der sichtbare Boxer ist derzeit weiterhin das anpassbare SVG-Holo. Der nächste Design-Abnahmeschritt sind reale, sauber getrennte Ebenen für Körper/Haut, Afro/Frisuren, Mantel, Oberteil, Shorts, Schuhe und Hände – mit identischer Leinwand und unveränderter Figurhaltung.

**Vor einem Merge**: CI-Ergebnisse und Screenshots sichten, am echten Mobilgerät testen, Rechte an den Premium-Illustrationen verifizieren, Visuelles gegen die Nutzerreferenz abnehmen. Kein ungeprüftes KI-Gesamtbild als auswählbares Einzel-Outfit ausgeben.
