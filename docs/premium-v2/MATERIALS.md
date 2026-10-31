# Wiederverwendbare Material-Master

Dieses Paket erzeugt im isolierten V2-Labor echte Varianten aus vorhandenen Anime-Komponenten. Es zeichnet keine neue Anatomie. Die Originaldateien von Cool, der Editor, der Shop und alle Freigabeschalter bleiben unverändert. `approved:false`, `enabled:false`; künstlerischer Status **Artistically pending**.

## Quellen und verfügbare Familien

`tools/premium-v2/materials.json` ist der automatisch erzeugte Bestand. Der Builder liest die echten Katalogpaletten aus `docs/premium-v2/inventory.json`, die vorhandenen Atlasrechtecke und zusätzlich tatsächlich vorhandene, hashgeprüfte Teile aus `production-art/manifest.json`. Nicht vorhandene Frisuren, Kleidungsformen oder Schuhe werden nicht eingetragen.

- Acht Hauttöne: derselbe kalibrierte Materialtransfer für Kopf, Hals, Arme, Torso und Beine in Cool und Guard.
- Acht Augenfarben: Iris-Maske; Sklera, Pupille und Glanzlichter bleiben erhalten.
- Acht Haarfarben pro vorhandenem Haarform-Master. Weitere Formen werden erst mit vorhandener registrierter Quelldatei aufgenommen.
- Fünf Handschuhfarben aus einer schwarzen Leder-/Gold-Grundzeichnung pro Handansicht.
- Acht Stoff-/Lederfarben pro vorhandenem Hosen- oder Schuh-Master. Bestehende Boxer-Shorts und Boots sind geprüft; neue Formen werden über dieselbe Pipeline einzeln geprüft.

Die tatsächlichen Zahlen stehen unter `families`. `newVariantKeys` zählt gegenüber PR #81: bereits vorhandene Haut-/Augenvariante, zwei Haarformen in Schwarz, zwei Handschuhfarben, zwei Boxerfarben und schwarze Boots zählen nicht noch einmal als neue Abdeckung. Die Zahl ist keine Zahl neu gezeichneter PNGs und kein Freigabestatus.

## Materialverfahren

Kein CSS-Hue-Filter: registrierte semantische Masken trennen Haut, Iris, Haar und schwarzes Leder beziehungsweise Stoff. Kanal-/Luminanzkurven erhalten Schattierung und Falten. Das Originalmaterial bei `tone:6`, `hc:schwarz`, `eye:braun` und schwarzer Grundfarbe ist pixelgleich. Alpha und Registrierung bleiben bei allen Varianten identisch.

Die acht Hautmittelwerte sind ausdrücklich kalibrierte Premium-Werte, keine direkte flächige Verwendung der SVG-Hexwerte. Schon die alte Premium-Grafik für `tone:6` entspricht nicht wörtlich dem Kataloghexwert. Dieser bestehende Look bleibt erhalten; die weiteren sieben Werte werden kontrolliert heller/dunkler abgestuft. Künstlerische Farbabnahme bleibt offen.

Die alte Afro-Datei enthält zusätzlich Stirn, Ohren und Brauen. Deshalb verwendet sie eine eigene registrierte Haut-/Haartrennung: Haarfarbe darf diese Haut nicht blau oder pink färben; Hautton muss sie zusammen mit dem Gesicht verändern. Der Kontaktbogen hat diesen Fehler im ersten Entwurf sichtbar gemacht und die Korrektur wird automatisiert geprüft. Neue reine Haarteile verwenden die Haarmaske ohne diese Ausnahme.

Zusätzlich entfernt `hairOnly(image, id, box)` diese eingebrannten Gesichtsteile nach der Materialtransformation vollständig aus der Afro-Ausrüstung. Eine registrierte Kontur folgt den unteren Locken; Alpha wird an der Schnittkante über einen Pixel geglättet. RGB oberhalb der Schnittkante und die Originaldatei bleiben unverändert. Der Körperkopf besitzt die eigentliche Stirn, Ohren und Brauen. Figur und Kachel müssen dieselbe isolierte Haaroberfläche verwenden. Der Vergleich `hair-isolation-contact.png` zeigt den Körperkopf, den alten Überdruck und die bereinigte Montage bei Hautton 6 und 0; alle acht Haarfarben benutzen dieselbe Alpha-Isolation. Andere bereits reine Haar-Master werden unverändert zurückgegeben.

Goldbesätze, Stickerei und Kanten bleiben bei Leder-/Stoffvarianten exakt erhalten. Die bestehende SVG-Palette enthält teils andere Akzentfarben; dieses Paket verändert den Katalog nicht und behauptet nicht, das Gold sei ein identischer SVG-Akzent. Die Vorschau verwendet exakt die Materialausgabe der Figur. Varianten benötigen eine ausdrückliche künstlerische Entscheidung über die Premium-Goldfamilie.

Masken sind in `material-assets/mask-*.png` kontrollierbar, mit Koordinaten und SHA-256 im Manifest. Bei Körper/Augen/Haar bedeuten RGB: Haut/Iris/Haar; bei Ausrüstung zeigt Rot die Leder-/Stoffmaske. Alpha entspricht immer der Quellkomponente. Masken gelten für die dokumentierten Quellen und Ansichten; sie sind kein allgemeiner Segmentierer für fremde Bilder.

## API und Speicher

`TLPremiumMaterials.applyToPiece(image, pieceId, config, box)` erhält ein bereits ausgeschnittenes, 1:1 registriertes Teil. `box` ist dessen globales `[x,y,width,height]` im 768×1216-Raum. Das Resultat ist ein Canvas oder, bei unverändertem Material, direkt das Eingabebild. Figur und Item-Kachel verwenden dieselbe Funktion und dieselbe Konfiguration.

Für Haarteile anschließend `TLPremiumMaterials.hairOnly(result, pieceId, box)` verwenden. Diese separate Stufe erhält den unveränderten Basismaterialvertrag von `applyToPiece`; sie benutzt denselben begrenzten Cache.

`transformPixels` ist die deterministische Pixelvariante für Prüfungen und Exporte. Sie verändert die Eingabedaten nicht. Ungültige Varianten lösen einen Fehler aus; der aufrufende Resolver muss vollständigen SVG-Fallback ausführen.

Der interne LRU-Cache ist auf **24 Oberflächen und 8 MiB RGBA** begrenzt. `stats()` meldet Belegung/Treffer, `clear()` leert ihn. Ein einzelner größerer Canvas wird nicht gecacht. Der Cache verwendet Bildidentität; der Aufrufer sollte seine Quellausschnitte ebenfalls wiederverwenden. Es erfolgen keine zusätzlichen Downloads durch Materialwechsel. Die reine Pixeltransformation wird nicht pro Animationsframe benötigt.

## Reproduzierbare Prüfung

`CANVAS_MODULE=<@napi-rs/canvas> node scripts/build-premium-v2-materials.cjs`

`node tests/premium-v2-materials.cjs`

Der Builder erzeugt Masken, Manifest sowie Kontaktbögen für Haut, Augen, Haare und Ausrüstung. Die Browserprüfung läuft in Chromium und WebKit: alle Materialwerte pro vorhandenem Teil, unverändertes Alpha, geschützte Nichtmaterialpixel, identische Basisvariante, unterschiedliche echte Farbvarianten, Stirnschutz, Ablehnung unbekannter Werte, Cachegrenzen und tatsächliche zusammengesetzte Charakterbilder.

Berichte: `material-assets/{chromium,webkit}-material-validation.json`. Reale Browserkontaktbögen: `material-assets/{chromium,webkit}-material-characters.png`. Diese belegen technische Funktion; Hautmasken an feinen Gesichts-/Haargrenzen, Weißmaterial-Kontrast und exakte Premium-Farbentscheidungen bleiben künstlerisch abzunehmen. Keine Behauptung einer Prüfung auf physischen Mobilgeräten.
