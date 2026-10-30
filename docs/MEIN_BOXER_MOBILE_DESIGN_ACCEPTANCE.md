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

Die acht Originalmasken der Cool-Pose liegen im Repository; der Browser lädt und verifiziert sie über `?art=layers`. Sie bilden die bestätigte Figur ab, sind aber noch kein unabhängig **austauschbares** Outfit. Daher bleiben im aktuellen `takeover-mein-boxer-artpack-manifest.js` beide Schalter `approved:false` und `enabled:false`. Der normale Editor zeigt weiterhin das anpassbare SVG-Holo. Benötigte neue Ebenen und verdeckte Anatomie sind in [MEIN_BOXER_ART_GAPS.md](MEIN_BOXER_ART_GAPS.md) beschrieben.

Die responsive Regression prüft zusätzlich 375 × 812, 390 × 844, 430 × 932, 768 × 1024 und 1440 × 900 Pixel, den Wechsel zwischen Desktop und Mobilansicht, Tastaturnavigation, unabhängiges Ausrüstungsscrollen und das Original-PNG-Paket auf Mobilgerät und Desktop. `BROWSER=webkit` führt dieselbe Matrix mit Playwright-WebKit aus. Das sind simulierte Viewports, keine Prüfung auf einem physischen iPhone.

**Vor einem Merge**: CI-Ergebnisse und Screenshots sichten, am echten Mobilgerät testen, Rechte an den Premium-Illustrationen verifizieren, Visuelles gegen die Nutzerreferenz abnehmen. Kein ungeprüftes KI-Gesamtbild als auswählbares Einzel-Outfit ausgeben.

## Erste echte Anime-Referenz in der fixierten Arena (30.10.2026)

Die verbindlich bestätigte Anime-Figur (Afro, dunkle Haut, verschränkte Arme, schwarz-goldener Mantel, TAKEOVER-Shorts und hohe Stiefel) liegt als **echte freigestellte Referenz in 768 × 1216 Pixeln** vor. Die Datei wurde bewusst **nicht** als vollwertiges, anpassbares Sprite-Asset-Pack ausgegeben.

**Neue sichere Vorschau im PR:** `mein-boxer.html?art=reference` zeigt neben dem fixierten Boxer einen lokalen Dateiwähler für PNG/WebP. Die referenzierte Bilddatei wird **ausschliesslich als Object-URL im Browser** geöffnet. Die Upload-Funktion ist keine Datenbank- oder GitHub-Upload-Funktion, speichert keine Charakterdaten und ist im normalen Editor ohne URL-Parameter unsichtbar.

- Nur `image/png` und `image/webp` mit maximal **2 MiB** und exakt **768 × 1216 Pixeln** werden akzeptiert.
- Nach dem Laden wird die komplette Anime-Illustration in derselben Arena angezeigt. Der Button «Bearbeitbaren Boxer anzeigen» schaltet jederzeit auf den echten Holo-Renderer zurück.
- **Eine Änderung an Hautfarbe, Frisur, Outfit, Pose oder Anprobe beendet die statische Referenzanzeige automatisch**, damit kein Anwender eine falsche Vorstellung von modularer Änderbarkeit erhält. Die Datei bleibt lokal für erneuten Vergleich verfügbar.
- Bei Seitenwechsel wird die Object-URL freigegeben. Normale Shop-, Speicher- und Profilfunktionen bleiben unverändert.
- `tests/boxer-holo-browser.cjs` prüft einen gültigen lokalen 768×1216-PNG-Upload, die Rückkehr zu SVG nach Outfitwechsel sowie das Ausbleiben jeglicher `save_my_holo`-RPC und die Unsichtbarkeit des Werkzeugs im normalen Editor.

Für eine sofortige **offline nutzbare Demo** gibt es zusätzlich ein separates Preview-ZIP mit `index.html`, transparentem PNG und komprimiertem WebP der bestätigten Figur. Das ZIP ist eine Design-Demo, nicht der produktive App-Build. Neue Kleidungskarten in dieser Demo dienen ausdrücklich nur der visuellen Orientierung.

**Noch offen:** saubere Bildzerlegung oder Neuzeichnung in eigenständige Körper-, Haar-, Gesicht-, Mantel-, Shorts-, Schuh- und Hand-Ebenen, einschliesslich wirklich unabhängig anpassbarer Farben und Posen. Erst damit darf `takeover-mein-boxer-artpack-manifest.js` auf `approved:true` gestellt werden. Im PR bleiben die Freigabeschalter ausgeschaltet.
