# Kappe und Stirnband: zwei gemeinsame Anime-Master

Umgesetzt sind die vorhandenen Item-Schlüssel `cap` und `band`, jeweils ausschließlich `headc:schwarz`. Zwei integrierte Imagegen-Aufrufe lieferten echte transparente Artwork-Quellen. Die Original-Körper- und Haar-PNGs bleiben unverändert. Exakte Prompts: `tools/premium-v2/headwear/provenance.json`; die beiden Rohquellen sind für reproduzierbare Ausschnitte im Projekt erhalten.

## Geprüfte Abdeckung

| Item | Farbe | Frisuren | Posen | Status |
|---|---|---|---|---|
| cap | schwarz | kurz_glatt | cool, guard | Technically validated / Artistically pending |
| band | schwarz | kurz_glatt, afro | cool, guard | Technically validated / Artistically pending |

**Zwei neue Item-Farbvarianten, vier Item-Farbe-Pose-Zellen, sechs tatsächlich gerenderte Pose-/Frisur-Kombinationen.** Kein Hijab, keine sieben zusätzlichen Farben, keine Langhaar- oder Kapuzenfreigabe. Die zwei Bilddateien werden für beide Posen unverändert wiederverwendet; es gibt keine separaten Cool-/Guard-Kappen oder Thumbnail-Dateien. Kappe 138.741 Byte, Stirnband 49.649 Byte; zusammen 537.600 Byte dekodierte RGBA-Rechteckfläche. Diese Angaben beziehen sich nur auf die neuen Kopfartikel, nicht den gesamten Charakter.

## Registrierung und Verdeckung

Manifest: `tools/premium-v2/headwear/manifest.json`. Jedes Teil enthält `id`, `slot`, `src` relativ zu `tools/premium-v2`, `uv`, `box`, `sha256` und `bytes`. Die 384 Pixel breiten Ausgabedateien werden ohne Seitenverhältnisänderung auf der 768×1216-Körperfläche positioniert:

- Kappe: x307/y43, Breite155, Höhe93,6458. Untere Schirmmitte oberhalb der Augen; Ohren bleiben frei.
- Stirnband: x326/y107, Breite160, Höhe49,1667. Das Vorderband liegt über Stirn/Haaransatz; Knoten und zwei Enden stehen rechts außerhalb des Gesichts.
- Kappen-Haarmaske: nur das Rechteck `[0,127,768,1089]` des vollständigen Haarlayers behalten. Damit verschwindet die kurze Haarkrone unter der Mütze; untere Schläfenpixel bleiben erhalten. **Nicht auf Afro oder Langhaar übertragen.**
- Stirnband-Haarmaske: keine Löschung; Vorderband wird nach dem Haar aufgetragen. Es enthält keine eingebrannte Haut, Haare oder andere Kleidung.

`TLPremiumHeadwear.resolve(config, manifest)` prüft ausschließlich die Kopfartikel-Unterstützung. Der aufrufende Hauptresolver muss weiterhin das vollständige Outfit prüfen. `maskHair(image, mask)` erwartet einen **bereits auf 768×1216 registrierten Haarlayer**, keinen isolierten Atlas-Ausschnitt. Für gestreamte Teile zuerst in deren `box` auf eine solche transparente Fläche zeichnen. `draw` nutzt dieselben Stücke/Quellen für Figur und Item-Ausgabe. Erst nach erfolgreichem Laden darf der Anime-Status erscheinen.

## Tatsächliche Browser- und Grafiktests

`node tests/premium-v2-headwear.cjs` besteht in Chromium und WebKit:

- Sechs echte Cool-/Guard-Kompositionen mit Kopfdetail und Ganzfigur.
- PNG-Signatur, RGBA-Kanalformat, Abmessungen, Seitenverhältnis und SHA-256.
- Kachel-/Figur-Quelle mit identischem registriertem Zeichenpfad: maximale Kanalabweichung0.
- Oberes Haar bei der Kappe transparent, untere Schläfenfläche unverändert.
- Nicht unterstützte Farben, Haare, Pose, Hijab und Kapuze werden abgewiesen.
- Vollständiger SVG-Fallback bei fehlender Variante **und blockiertem Kappen-Download**.
- Genau zwei Artwork-Anfragen für die gesamte Sechser-Galerie, keine externen Verbindungen, keine JavaScript-Fehler, keine horizontale Überbreite bei390px.

[Echter Chromium-Kontaktbogen](../../tools/premium-v2/headwear/evidence/chromium-headwear-contact.png) · [WebKit-Kontaktbogen](../../tools/premium-v2/headwear/evidence/webkit-headwear-contact.png). JSON-Berichte liegen daneben. Galerie: `tools/premium-v2/headwear/index.html`.

## Künstlerische Grenzen

Die visuelle Prüfung zeigt freie Augen/Ohren, keinen durch die Kappe ragenden Haarberg und dieselbe Registrierung beider Posen. Beide Master bleiben **Artistically pending**. Materialwirkung, Goldkanten, Kappensilhouette und Stirnbandknoten benötigen persönliche Designabnahme. Andere Frisuren können andere Verdeckungen benötigen. Für weitere Farben zunächst eine Stoffmaske kalibrieren, die goldene Kanten und Schatten schützt; keine globale Hue-Rotation.

`approved:false` und `enabled:false` bleiben unverändert. Die Galerie ist isoliert; normaler Editor, Besitz, Coins und Item-Katalog werden nicht verändert.

## Integrated production palette

The production resolver uses cap/band black-master registration, then applies eight existing headc materials while preserving gold. Its hair compatibility restrictions remain unchanged. The standalone headwear gallery still validates its original black-master contract.
