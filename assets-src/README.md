# Takeover League · Asset Pack v1 · nur Vektorquellen

**Stand:** GitHub `main` zum Beginn der Arbeit: `8176e8014d134136ba210ced37b230cd61190ac8`. Die vorhandenen Renderer `takeover-holo.js` und `takeover-kampfgeist.js` wurden vor der Erstellung geprüft. Die gelieferten SVG-Dateien **sind nicht in die Website eingebaut**, sondern sind quelloffene Einbauvorlagen für den ausführenden Entwickler. Kein neues Item, keine Rechte, Punkte, Coins oder Freischaltungen.

## Was enthält dieses Paket?

- `holo/`: 96 **pose-kompatible Teilgrafiken** statt ganzfiguriger Item-Poster. Frisuren und Kopf-Ausrüstung verwenden den Kopf-Koordinatenraum, Handschuhe/Bündchen die Handgelenk-Koordinaten, übrige Teile den 240×380-Holo-Raum.
- `kampfgeist/`: 121 **echte SVG-Motive**, zu den bestehenden Keys, inklusive einzelner und paariger Handschuhe, freier mittlerer Avatar-Ringe, Text-loser Emote-Bubbles und zehn Einlauf-Hintergründen.
- `reference/`: 25 frühere KI-PNGs **nur als Stilreferenzen**, nach existierenden Keys zugeordnet. Es werden **keine PNGs in SVG eingebettet**. Die grossen Konzept-Karten aus dem früheren V2-Pack gehören nicht zur angeforderten A/B-Layer-Liste und werden bewusst nicht mit falschen Schlüsseln eingefügt.
- `overview/`: 20 aus den tatsächlichen SVG-Dateien gerenderte, mit Datei-Keys beschriftete PNG-Übersichten und `holo-test-1.png` / `holo-test-2.png` mit je einem zusammengesetzten Boxer aus den gelieferten Layern.
- `manifest.json`: **ein Eintrag pro SVG** mit `path`, `system`, `slot`, `key`, `layer`, `pose`, `viewBox`, `colorable`.

## Pflicht-Farbplatzhalter (exakt und GROSS)

| Farbe | Bedeutung |
|---|---|
| `#FF0001` | Hauptfarbe |
| `#FF0002` | Dunkelton |
| `#FF0003` | Akzent |
| `#FF0011` | Haut |
| `#FF0012` | Hautschatten |
| `#FF0021` | Haar |
| `#FF0022` | Haar dunkel |
| `#FF0023` | Haarlicht |
| `#FF0031` | Augenfarbe |

Weitere konstante Metall-, Gold- und Glanzlichter stehen als normale Hexfarben. Kontur: `#1A1020`, in der Regel 2–3.4 SVG-Einheiten. Licht kommt oben links, Schatten unten rechts. Bevor die SVG am Bildschirm dargestellt wird, muss **sichere, fest definierte** Farbsubstitution passieren; Benutzereingaben nicht ungeprüft in SVG-XML interpolieren.

## Koordinaten, viewBox und Ebenenreihenfolge

**Holo Gesamtfläche:** `0 0 240 380`. Schultern `(78,110)`, `(162,110)`, Taille `y=176`, Beine `x=84–112` und `x=128–156`, Fussbereich `y=296–344`. Der Armverlauf wird NICHT durch feste Ärmelgrafiken ersetzt.

**Gezielte lokale viewBox-Ausnahmen sind technisch notwendig:** `hair/*`, `head/*`, `body-face-*`, `eyefx/*`, `top-hoodie-hood-up` benutzen `0 0 200 200` und werden innerhalb des bestehenden `translate(60 -6) scale(0.6)` gerendert. Handschuhe/Bandagen: `-24 -22 56 44`, an das Handgelenk transformieren. Ärmel-Manschetten: `-20 -20 44 40`, am Ärmelende transformieren. Diese Ausnahme folgt direkt aus der lokal definierten Gelenk-/Kopfgeometrie von `takeover-holo.js`; **alle körperfesten Hauptflächen** bleiben bei `0 0 240 380`. Kampfgeist hat feste viewBoxes pro Kategorie, siehe Manifest.

**Renderer-Reihenfolge (hinten nach vorne):**

1. `scene/...-background` → `aura/...-back`.
2. `body-skin-legs-base`, `body-skin-torso-base`, dann `bottom` + `feet`, dann `top`.
3. `coat-...-body` und `coat-...-trim` (wenn getragen).
4. Im Kopftransform: `hair-...-back`, `body-face-base`, `eyefx-...-eye` (für BEIDE Augen gespiegelt), `hair-...-front`, `...-strands`, `head-...-front`. Bei Hijab: `head-hijab-back` hinter die Gesichtsfläche und `...-front` davor. Bei Kapuze: das gewählte `top-hoodie-hood-up` um die Kopfkontur, `...-hood-down` in Ganzkörperkoordinaten hinter die Front.
5. Für jede Pose (`guard`, `jab`, `sieg`, `cool`, `flex`, `ansage`) `R` und `L` Arm genau wie im vorhandenen Renderer per drei Gelenkpunkten erstellen. Die Ärmel bleiben dynamische **Strokes entlang des Armpfads**. Nur `top-...-cuff` und `coat-...-cuff` als Endstück lokal einfügen; Boxhandschuhe als `...-thumbup` oder `...-thumbdown` mit `translate(wx+ux*6,wy+uy*6) rotate(atan2(...))`.
6. Der bestehende Scanner, die Nutzeroberfläche und FUT-Kartenwerte bleiben unverändert; keine Extra-Pose für das Podium erfinden.

Kampfgeist: `avatar-*` und `handschuhe-*-single` belegen den bestehenden Avatar-Layer. `aura`/`rahmen` sind **reine, mittig transparente Ringoverlays**. `banner` hat Hintergrund, links Platz für Profilbild. `titel`-Plaketten sind absichtlich **ohne Text**, `emote`-Formen ebenfalls – der existierende Renderer muss Namen und den freigegebenen Emote-Text separat zugänglich und skaliert einfügen. `einlauf` sind **statische Hintergrundgrafiken**, keine fertigen Timersysteme.

## Wichtige Grenzen

1. Die SVG-Layer sind **vollständige, einzeln gezeichnete Vektorquellen**, aber noch keine automatisch verdrahteten Laufzeit-Komponenten. Der Entwickler bindet sie an vorhandene Posen, Farben, Shop-Freigaben und an `get_holo_looks` / bestehende Kampfgeist-RPCs an.
2. Die alten hochauflösenden KI-PNGs sind **visuelle Stilreferenzen**, kein direkt übertragbares SVG-Mesh. Vor einer Veröffentlichung müssen tatsächliche Browser-Screenshots des echten Holo und die bisherigen statischen sowie Chromium-Tests grün sein.
3. In der A/B-Liste sind `u_none` und `f_none` **keine zu zeichnenden Motive**, sondern Leerzustände; `holo/pose_*` wird im bestehenden Renderer definiert und ist kein gesondertes Ausrüstungs-SVG. FUT-Kartenvorlagen sind ebenfalls nicht Bestandteil der exakt angeforderten Liste A/B.
4. Es wurden **keine bestehenden Repo-Dateien** verändert oder Produktionsdaten berührt.

## Fehlend/Offen
