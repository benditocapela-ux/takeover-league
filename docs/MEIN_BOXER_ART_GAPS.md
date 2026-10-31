# Premium-Character-Art: Lieferumfang und offene Zeichnungen

Stand: 30. Oktober 2026. Technische Dateiannahme und künstlerische Freigabe sind getrennt. `approved:false` und `enabled:false` bleiben bestehen.

## Aktueller modularer Entwurf

Der nachfolgende Befund dokumentiert die ursprünglichen acht Masken und den früheren Lieferauftrag. Inzwischen liegt ein separater Zwölf-PNG-Satz mit neuen Kleidungszeichnungen für die V4-Körperbasis vor. Lieferumfang, 32 Kombinationen und weiterhin bestehende Grenzen stehen in [MEIN_BOXER_MODULAR_DRAFT.md](MEIN_BOXER_MODULAR_DRAFT.md). Der Originalsatz und beide Freigabeflags bleiben unverändert.

## Verifiziertes Ausgangspaket

Die acht Original-PNGs in `assets/boxer-artpacks/v1/cool/` sind zusammen 812800 Bytes gross. `node tests/boxer-original-art-readiness.cjs` prüft alle acht SHA-256-Hashes; `node scripts/validate-boxer-artpack.cjs` prüft Abmessungen, Transparenzkennzeichen und Grössenbudget. Diese Prüfungen beweisen keine vollständige verdeckte Anatomie.

Die Masken rekonstruieren genau die Cool-Pose: Haut 6, Afro/schwarz, braune Augen, kein zusätzliches Oberteil oder Headwear, Samurai-Mantel, Boxer/schwarz, Boots/schwarz und Bandagen. Aura und Augen-Effekte müssen `none`, die Szene `holo` oder `none` sein. Die Stilreferenz bleibt der dunkle Anime-Boxer mit navy-/goldenem langem Mantel und verschränkten Armen.

Diese Kombination ist in `configurations.cool` deklarativ eingeschränkt. Der Premium-Renderer prüft diese Einschränkungen vor dem Laden. Insbesondere fällt `coat:none` vollständig auf SVG zurück, anstatt die ausgeschnittenen Körperfragmente als vollständigen Körper auszugeben. Das lokale Ebenen-Prüfwerkzeug darf Masken zur Inspektion ausblenden; das ist kein Nachweis eines funktionierenden Outfit-Wechsels.

## Zeichnungsauftrag und Abhängigkeiten

Alle Exporte verwenden dieselbe transparente Leinwand **768 × 1216 px**, Ursprung links oben `(0,0)`, x nach rechts, y nach unten. Keine automatisch beschnittenen Einzeldateien, keine unabhängigen Zentrierungen oder Skalierungen. Die Originalmasken sind die Registrierungsreferenz. Exakte anatomische Gelenkpunkte müssen aus der Illustration abgenommen werden; sie sind nicht durch das SVG-Koordinatensystem definiert. Pro Datei höchstens 2 MiB, pro vollständig sichtbarem Outfit höchstens 6 MiB.

| Z | Ebene / bestehender Schlüssel | Fehlende Arbeit / Abhängigkeit |
|---|---|---|
| 1 | `coatBack.samurai` | Original vorhanden. Andere Mäntel benötigen neu gezeichnete Rückseiten passend zu derselben Pose und zu ihrer Vorderseite. |
| 2 | `body.6` | Original zeigt nur sichtbare Fragmente. Rumpf, Schulter-/Oberarmpartien unter dem Mantel und die von verschränkten Armen verdeckten Übergänge müssen anatomisch vollständig gezeichnet werden; bei kurzen Hosen oder anderen Schuhen zusätzlich freigelegte Bein-/Knöchelpartien. Keine Streckung vorhandener Pixel. Für Hauttöne 0–5 und 7 fehlen passende Varianten. |
| 3 | `bottom.boxer/schwarz` | Original vorhanden. Andere Hosenformen und Farben benötigen eigene Zeichnungen; Bund muss mit Körper, Oberteil und Mantel überlappen, Saum mit Beinen/Schuhen. |
| 4 | `feet.boots/schwarz` | Original vorhanden. Andere Schuhformen und Farben fehlen. Übergänge zu Bein, Hosensaum und Standfläche müssen in der Cool-Pose deckungsgleich sein. |
| 5 | `top` | Keine unabhängigen Oberteil-Dateien vorhanden. Tank, Shirt, Hoodie (Kapuze oben/unten) und Jacke benötigen Rumpf plus posengerechte Ärmel, mit korrekter Verdeckung durch verschränkte Arme. Falls eine einzige Ebene diese Verdeckung nicht korrekt abbildet, zuerst separate Vorder-/Hinterarm-Ebenen spezifizieren und den Renderer erweitern; nicht einfach falsche Überlagerungen liefern. |
| 6 | `eyes.braun` | Original vorhanden. Andere Augenfarben benötigen passende Pixelvarianten auf derselben Gesichtsbasis. Spezialeffekte sind bislang nur im SVG unterstützt. |
| 7 | `hair.afro/schwarz` | Original vorhanden. Weitere Frisuren/Farben fehlen; vollständiger Schädel und Ohren müssen für freigelegte Bereiche vorhanden sein. Langes Haar kann zusätzliche hintere Haar-Ebenen benötigen, bevor es korrekt integrierbar ist. |
| 8 | `head` | Keine unabhängigen Cap-/Headband-/Hijab-Dateien vorhanden. Haarverdeckung, Stirn, Ohren und Hoodie-Kollisionen sind pro Kombination visuell abzunehmen. |
| 9 | `coatFront.samurai` | Original vorhanden. Andere Mäntel benötigen Vorderseite und Ärmel, zusammen mit `coatBack` sowie Körper/Armen gezeichnet. Der Originalmantel darf erst bei vollständiger Unterzeichnung entfernbar werden. |
| 10 | `hands.wraps` | Original vorhanden. Unabhängige Handschuhvarianten benötigen neue Zeichnungen mit denselben Handgelenken und verschränkter Armhaltung. Verdeckte Hand-/Unterarmpartien sind nicht aus Masken rekonstruierbar. |

Andere Posen benötigen jeweils einen eigenen deckungsgleichen Satz. Dateien der Cool-Pose dürfen nicht auf Guard-/Kartenposen verzerrt werden. Vorhandene V0/V1/V2-Unterzeichnungen sind nicht freigegebene Studien, keine finalen Ersatzgrafiken.

## Technische Lieferannahme

1. Eine vollständig unterzeichnete Cool-Figur und ein unabhängig wechselbares Musteroutfit liefern; Registrierungsreferenz und Ebenenreihenfolge beibehalten.
2. Varianten unter relativen kleingeschriebenen `.png`-/`.webp`-Pfaden eintragen. Schema und Varianten-Schlüssel stehen in `MEIN_BOXER_ARTPACK_PIPELINE.md` und `takeover-holo.js`. Kein Einfärben gemalter Originale als Ersatz für gezeichnete Varianten.
3. Für eingeschränkte Pakete `configurations` mit einem Eintrag je Pose führen. Fehlende Pose-Einschränkung fällt sicher auf SVG zurück. Erst nach künstlerisch belegter Unabhängigkeit die entsprechenden Einschränkungen lockern; generische vollständige Pakete dürfen das optionale Feld weglassen.
4. Validator, Varianten-/Fallback-Verträge und Browserprüfung mit echten Bildern ausführen. Outfitwechsel müssen die ausgewählten Artikel zeigen, ohne Löcher, Körperduplikate, falsche Ärmel oder veränderte Standposition.
5. Original-Screenshot `holo-original-8-repository-art.png` sowie mobile und Desktop-Ansichten durch den Auftraggeber abnehmen lassen. Erst eine gesonderte Freigabe erlaubt Änderungen der Grafikschalter.

**Status:** Originalrekonstruktion technisch vorhanden; unabhängige Premium-Garderobe und künstlerische Abnahme offen. Der bestehende SVG-Renderer bleibt für alle nicht vollständig unterstützten Varianten zuständig.

## Nächster Meilenstein: verbindlicher Lieferauftrag

### Visuelle Prüfung und Quellen

Das erfolgreiche CI-Artefakt `mein-boxer-rendered-screens` aus Run `41135222396`, Commit `f088b14`, wurde heruntergeladen und gesichtet. ZIP-SHA-256: `c1b4df2fa6c73777404827f0df883a68b570143599996040812aec96a44dd88b`. `holo-original-8-repository-art.png` zeigt die Originalrekonstruktion korrekt positioniert in der mobilen Arena. Gesicht, Afro, Mantel, Shorts und Stiefel sind sichtbar; die Arena und die bereits reparierte Scrollarchitektur benötigen für diesen Kunstschritt keine Neugestaltung. Der normale Editor zeigt weiterhin das deutlich einfachere SVG, weil beide Grafikflags ausgeschaltet bleiben. Ausrüstungskacheln sind ebenfalls weiterhin SVG-Illustrationen, keine neuen Premium-Itemzeichnungen.

Die acht originalen Masken sind als Bildquellen zugänglich. Die separate dokumentierte 1536×1024-Designvorlage aus dem früheren Chat liegt im untersuchten Checkout/CI-Artefakt nicht als Originaldatei vor. Ein pixelgenauer Vergleich mit dieser Vorlage wurde daher nicht behauptet. Die zusammengesetzte 768×1216-Figur ist die verfügbare Registrierungsreferenz.

**Tatsächlich sichtbare Restprobleme der Masken:** `body.png` enthält Kragen/Ärmel und vereinzelte Mantelreste; `hands.png` enthält neben Bandagen auch Stoffkanten. Die Shortsmaske besitzt keine vollständigen seitlichen Stoffflächen unter dem Mantel. Entfernen der zwei Manteldateien legt daher nicht nur unbemalte Haut, sondern auch unvollständige Kleidung frei. Eine neue Körperbasis allein repariert das Paket nicht.

PR #78 (`cde4891`) wurde anhand README, Manifest, Torso-SVG sowie Tank-/Handschuh-PNGs geprüft. Seine lokalen Gelenkkoordinaten sind für den SVG-Renderer gedacht; die PNGs zeigen freistehende Produktansichten statt verschränkter Arme auf der 768×1216-Leinwand. Wiederverwendbar ist das Prinzip getrennt gezeichneter Körper-, Kleidungs- und Handteile. Keine dieser Dateien wurde als passendes Premium-Pose-Asset übernommen; kein Merge.

### Zwei echte Generierungsversuche, keine Grafikfreigabe

Mit dem eingebauten Imagegen-Werkzeug entstanden zwei transparente, nicht freigegebene Studien:

- **V3 – Mantel entfernt:** stilistisch konsistente vollständige Figur mit rekonstruierten Schultern/Armen, aber weiterhin eingebauten Haaren, Bandagen, Shorts und Schuhen; 997×1578 statt geforderter 768×1216 Pixel. Das ist keine modulare Körperdatei.
- **V4 – reine Körperbasis:** zusammenhängender kahler Körper mit gekreuzten Armen und schlichter Unterhose, 996×1578 Pixel. In der auf gemeinsames Displayformat normierten Diagnose sind Ärmelreste der originalen Handmasken und seitlich unbedeckte Oberschenkel neben der alten Shortsmaske sichtbar. Die Anatomie und Passform sind nicht deckungsgleich genug für den direkten Austausch.

Beide Studien wurden weder als Originalillustrationen ausgegeben noch in das Manifest eingebunden. Ihre Dateigrössen liegen unter 2 MiB, aber das genügt nicht: Leinwand, Passform und unabhängige Ausrüstung scheitern am Abnahmekriterium. Die lokalen Vergleichsbilder sind Diagnosen, keine funktionierenden Premium-Outfitwechsel. Keine Pixelstreckung, Farbmaskierung oder geometrische Füllform wurde als Reparatur eingesetzt.

### Lieferung 1: kleinstes vollständig wechselbares Outfitpaket

Zuerst **eine** sauber registrierte Pose herstellen, dann die Varianten im selben editierbaren Master zeichnen. Ausgangspunkt bleibt die Originalfigur; Studien V3/V4 dienen nur als unfreigegebene Anatomiehilfe. Liefere eine PSD/KRA mit getrennten Ebenen für Rumpf, hinteren Arm, vorderen Arm, Hände, Kopf, Haare und jedes Kleidungsstück sowie folgende **zwölf transparenten Exporte**:

| Exportdatei im Liefer-ZIP | Runtime-Slot/Schlüssel | Konkreter Inhalt |
|---|---|---|
| `body-tone-6.png` | `body[6]` | Vollständige Basis in Originalpose, Hautfarbe/Identität unverändert; keine Haare, Bandagen, Ärmel, Mantel- oder Shortsreste. Glatte Kopfhaut unter Frisuren; vollständige Schultern, Oberarme, Flanken, Hüften und Beine. |
| `coat-samurai-back.png` | `coatBack.samurai` | Nur rückwärtiger Mantel, deckungsgleich zum Vorderteil. |
| `coat-samurai-front.png` | `coatFront.samurai` | Nur Vorderteil, Revers und Ärmel; keine Haut oder Shorts eingebrannt. |
| `top-tank-schwarz.png` | `top['tank/schwarz']` | Schwarzes Tanktop im bestätigten Stil, Rumpf hinter den gekreuzten Unterarmen. Gold darf als Detail, nicht als Änderung des bestehenden Farbkeys verwendet werden. |
| `hands-gloves-schwarzgold.png` | `hands['gloves/schwarzgold']` | Zwei schwarze/goldene Handschuhe in exakt der verschränkten Handhaltung, mit passenden Manschetten; keine Ärmelreste. |
| `hands-gloves-weiss.png` | `hands['gloves/weiss']` | Zweites eigenständig gezeichnetes Paar für dieselben Handgelenke; weisses Material, keine einfache Umfärbung der bestehenden Maske. |
| `bottom-boxer-schwarz.png` | `bottom['boxer/schwarz']` | Vollständige TAKEOVER-Shorts inkl. vorher verdeckter Seitenflächen und Bund. |
| `bottom-boxer-rot.png` | `bottom['boxer/rot']` | Zweites vollständiges Shorts-Paar im gleichen Stil und Schnitt; Licht/Material neu abgestimmt. |
| `feet-boots-schwarz.png` | `feet['boots/schwarz']` | Vollständige Stiefel; keine Hautfragmente oder Mantelsäume. |
| `hair-afro-schwarz.png` | `hair['afro/schwarz']` | Originalnaher kurzer Afro ohne eingebrannte Stirn-/Gesichtsfläche. |
| `hair-kurz-glatt-schwarz.png` | `hair['kurz_glatt/schwarz']` | Alternative kurze Frisur, identischer Kopf und Haaransatz. |
| `eyes-braun.png` | `eyes.braun` | Identisch ausgerichtete braune Augen, passend zur vollständigen Gesichtsbasis. |

Die Original-Bandagen können nur nach Entfernung der Ärmelreste als optionaler dreizehnter Export hinzukommen. Diese Zusatzvariante blockiert die geforderten zwei Handschuhpaare nicht.

### Registrierung und Überlagerung

- Export immer **768×1216**, Ursprung `(0,0)`, RGBA oder transparentes WebP, ohne Trimmen, Kameraänderung oder individuelle Skalierung. Pro Datei höchstens 2 MiB, aktive Kombination höchstens 6 MiB. Originale niemals überschreiben; neue Sammlung zunächst unter einem separaten Entwurfspfad liefern.
- Alle Varianten aus **demselben Master** exportieren. Keine zwölf unabhängig neu zentrierten Bildgenerierungen. Gesicht und vorhandene sichtbare Anatomie sind Identitätsanker; die bisher verdeckten Regionen werden passend dazu neu gezeichnet.
- Registrierungsfenster der Originalmasken (inklusive Pixelkoordinaten, keine Gelenkpunkte): Augen `[334,155]–[433,193]`, Afro `[302,43]–[463,166]`, Hände/Bandagen `[280,315]–[476,427]`, Shorts `[258,483]–[506,803]`, Stiefel `[158,950]–[625,1171]`. Die Shorts müssen seitlich erweitert werden; diese Fenster sind keine Zuschnittanweisung. Die schmutzige Body-Maskengrenze ist kein gültiger Anatomieanker.
- Runtime-Reihenfolge bleibt `coatBack → body → bottom → feet → top → eyes → hair → head → coatFront → hands`. Für den ersten **ärmellosen** Tank muss die Top-Datei an den festen Vorder-/Hinterarm-Silhouetten ausgespart sein; dort bleibt die vollständig gemalte Körperbasis sichtbar. Keine transparente Lücke darf bis zum Hintergrund durchgehen. Das funktioniert für die feste Cool-Pose ohne neue Runtime-Arm-Slots.
- Im editierbaren Master bleiben beide Arme trotzdem separat, damit Tank, Mantelärmel und Handschuhe korrekt verdecken. Falls die gelieferte Zeichnung eine andere tatsächliche Z-Reihenfolge verlangt (z. B. lange Haare hinter dem Körper oder neue Ärmel über/unter Armen), zuerst einen realen Problemfall liefern; erst danach zusätzliche Runtime-Slots spezifizieren. Kein unbelegter Renderer-Umbau.

### Abnahme in 32 Kombinationen

Prüfmatrix: `coat={none,samurai}` × `top={none,tank}` × `glove={schwarzgold,weiss}` × `bottomc={schwarz,rot}` × `hair={afro,kurz_glatt}`. Fixiert: `tone=6`, `hc=schwarz`, `eye=braun`, `topc=schwarz`, `head=none`, `bottom=boxer`, `feet=boots`, `feetc=schwarz`, `hands=gloves`, `aura=none`, `eyefx=none`, `scene=holo`, beide Posen `cool`.

1. Alle 32 Kombinationen auf dunklem, hellem und Schachbretthintergrund zusammensetzen. Keine Hautlöcher, Doppelarme, Ärmelreste, offenen Shortsseiten, Halos oder falschen Vorder-/Hinterkanten. Gesicht/Schädel, Gelenke, Taille und Standposition dürfen beim Wechsel nicht wandern.
2. Jede Umschaltung muss ausschliesslich die gewählte Kategorie sichtbar ändern. Unveränderte Ebenen behalten dieselben Bilddateien und Koordinaten. Zwei Handschuh- und zwei Shortsvarianten müssen auch ohne Mantel und zusammen mit dem Tank korrekt funktionieren.
3. Kontaktbogen aller 32 Varianten und acht Einzelvergleiche liefern: Grundzustand, Mantel an, Tank an, Handschuh weiss, Shorts rot, Frisur kurz, Mantel+Tank, vollständig alternative Kombination. Keine Ebene darf durch eine vollständige bekleidete Figur ersetzt sein.
4. Abnahmeprogramm nach Lieferung: Dateiprüfung, Manifest-Zuordnung und Variantenverträge; dann Chromium/WebKit bei 390×844 und 1440×900, schnelle Wechsel während Bildladung, atomare Anzeige, Fehler einer Bilddatei und nicht vorhandene Pose → vollständiger SVG-Fallback. Speichern/Reload und Shop mit simulierten Antworten prüfen. Keine produktiven Daten verändern.
5. Neue Grafikrestriktionen erst nach Sichtprüfung passend lockern; Originalhash-Prüfung bleibt unverändert. `approved:false` und `enabled:false` bleiben auch bei diesem Meilenstein gesetzt, bis eine gesonderte Freigabe erfolgt.

**Entscheidung:** Technik für die definierte feste Pose ist vorhanden. Der nächste freigabefähige Fortschritt ist eine gemeinsam registrierte künstlerische Lieferung dieser zwölf Dateien, keine weitere CSS- oder Renderer-Optimierung. Der aktuelle Meilenstein ist künstlerisch blockiert; die beiden Studien sind ein verwertbarer Entwurf, aber kein fertiges Outfitpaket.
