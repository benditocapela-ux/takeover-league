# Premium Character System V2 – Guard-Pilot

Basis: PR #79, `1a55e0516c45ee3c457fc7f073cd8e412721b83e`.
Separater Branch: `design/premium-character-v2-guard-20261031`.
PR #79 und #80 bleiben unverändert, Draft und ungemergt. Kein Deployment.

**Entscheidung: Hybrid weiter untersuchen; noch keine Serienproduktion.**
Der Pilot belegt pixelgleiche Wiederverwendung von acht Komponenten und einen
kleineren dekodierten Texturbestand. Er belegt weder ein vollständiges Rig noch
eine freigegebene Guard-Illustration. Taille/Ärmel des Mantels und die genaue
Handschuh-Ornamentik benötigen einen gezielten Korrekturauftrag. Die offenen
Gates sind maschinenlesbar in `tools/premium-v2/quality-gates.json` hinterlegt.

## Vollständiger Bestand

Quelle ist der Repository-Katalog, keine Live-Datenbankabfrage. Die einzige
Katalogbefüllung der Holo-Items liegt in `20261029140000_boxer_holo.sql`;
Normalisierung, erlaubte Werte und Farbpaletten stammen aus `takeover-holo.js`.
Das Inventarskript liest diese Quellen, statt eine zweite Itemliste zu pflegen.

| Kategorie | Katalogeinträge | Farb-/Zustandsvarianten | Cool-Premium-Varianten |
|---|---:|---:|---:|
| Frisuren | 18 | 144 | 2 |
| Kopfbedeckungen | 3 | 24 | 0 |
| Oberteile | 4 | 40, einschließlich Hoodie oben/unten | 1 |
| Hosen | 4 | 32 | 2 |
| Handschuhe | 5 | 5 | 2 |
| Schuhe | 2 | 16 | 1 |
| Mäntel | 4 | 4 | 1 |
| Auren | 4 | 4 | 0 |
| Augeneffekte | 4 | 4 | 0 |
| Szenen | 4 | 4 | 0 – bestehende prozedurale Hintergründe |
| Posen | 6 | 6 | Cool als Pose, keine separate Item-Ebene |
| Hauttöne, Augenfarben, Bandagen | keine zusätzlichen Shop-Items | 8 + 8 + 1 | 1 + 1 + 0 |

Insgesamt **58 Katalogeinträge, drei bestehende Bundles, 21 Konfigurationsschlüssel,
300 Varianten und 1.800 Abdeckungszeilen** über sechs Posen. Dies ist eine
Prüfmatrix, keine Bestellung von 1.800 PNGs. Pose-/Szenen-/Effektzeilen sind
Metadaten bzw. Overlay-/Hintergrundaufgaben, keine eigenständigen Körperteile.
`none`/Entfernen und `hood` sind zusätzlich vollständig in den erlaubten
Konfigurationswerten dokumentiert; sie sind keine neuen Katalogeinträge.

- [Inventar mit allen Item-Keys, Namen, Farben/Hexwerten, Defaults und Bundles](inventory.json)
- [Vollständige Abdeckungsmatrix als CSV](coverage.csv)
- [Dieselbe Matrix als JSON](coverage.json)
- [Verbindlicher Art-Standard](ART_STANDARD.md)
- [Priorisierter Produktionsplan und nächster Auftrag](PRODUCTION_PLAN.md)

Posen: `guard`, `jab`, `sieg`, `cool`, `flex`, `ansage`.
Schlüssel: `tone`, `hair`, `hc`, `eye`, `eyefx`, `head`, `headc`, `top`, `hood`,
`topc`, `bottom`, `bottomc`, `hands`, `glove`, `feet`, `feetc`, `coat`, `aura`,
`scene`, `pose_profile`, `pose_card`. Profil- und Kartenpose bleiben unabhängig.

Matrix-Legende: `premium-v1-unapproved` = vorhandene Cool-Grafik, weiterhin
deaktiviert; `pilot-shared-exact` = im Guard-Piloten aus derselben Quelle;
`pilot-partial-or-new-unapproved` = teilweise wiederverwendet bzw. neue Guard-Ansicht;
`svg-only` = keine passende Premium-Ausgabe. Wiederverwendungsvorschläge für
weitere Posen sind ausdrücklich bedingt, keine bereits abgenommene Abdeckung.
Auch ein vorhandenes Teil wird nur in einer vollständig unterstützten
Konfiguration als Premium dargestellt. Der Pilot unterstützt kein Tanktop.

## Umsetzung und Grenzen

Das Labor `tools/premium-v2/index.html` zeigt vorhandenes Cool, Guard als
Vollflächen-PNG und denselben Guard aus zwei Komponentenatlanten. Es unterstützt
16 Guard-Outfits: Mantel an/aus × zwei Handschuhfarben × zwei Frisuren × zwei
Shortsfarben. Es ist **nicht** in `mein-boxer.html` eingebunden. Damit bleiben
Editor, Besitz, Coins, Katalog, Konfigurationsspeicherung und Datenbank unberührt.
Der reale Pages-Assembler schließt das komplette Labor aus.

Vier begrenzte Imagegen-Entwürfe wurden erstellt: Guard-Körper, Manteloberteil
und die beiden vollständigen Handschuhansichten. Sechs ausgelieferte PNGs sind
zwei Atlanten plus vier daraus gebackene Vollflächen-Vergleichsebenen, keine
Massenproduktion. Rohentwürfe bleiben lokal; Quellhashes, Registrierung und
Prompts dokumentieren ihre Herkunft. Der Offline-Builder benötigt die vier
passenden Quelldateien und `@napi-rs/canvas`; der Browserbetrieb benötigt keine
zusätzliche Renderbibliothek.

Die Architektur ist ein **statischer Hybrid aus gemeinsamen Teilen und
poseabhängigen Schlüsselzeichnungen**. Oberkörper/Arme sind noch kein
unabhängig bewegliches Skelett. Neue verborgene Flächen und perspektivische
Handansichten bleiben echte Zeichenarbeit. Ein Atlas allein löst das nicht.

## Gemessene Wiederverwendung

Referenz-Outfit: Guard, Samurai, Schwarz-Gold, schwarze Shorts, Afro, nackter
Oberkörper. Acht von zwölf Komponenten sind exakte Cool-Ausschnitte:
Mantelrücken, Kopf, Unterkörper, Shorts, Schuhe, Augen, Haare, untere Mantelfront.
In Chromium und WebKit: **maximale Alphaabweichung 0 und maximale RGB-Abweichung
an opaken Pixeln 0** für alle acht Ausschnitte.

Neue Komponenten je Outfit: Oberkörper/Arme, obere Mantelfront, linke und rechte
Guard-Handschuhansicht. Quote nach Komponenten **66,7 %**, nach den Rechteckflächen
der ausgewählten Komponenten **73,2 %** (904.775 / 1.236.675 Texel).
Rechtecke enthalten Transparenz und Überlagerungen; die Zahl ist ausdrücklich
keine Quote sichtbarer Bildpixel oder eingesparter Arbeitszeit.

Die acht Komponenten behalten ihre Ansicht und Anker. Kopf-/Hüftdrehung,
Standwechsel oder zusätzliche Verdeckung können die Wiederverwendung aufheben.
Cool-Arme und Cool-Handschuhe werden für Guard nicht als wiederverwendbar gewertet.

## PNG gegen Komponenten – tatsächlicher Vergleich

Messung: lokale Windows-Umgebung, Playwright 1.56.1, Chromium und WebKit,
768×1216-Ausgabe. Drei kalte Browserkontexte je Modus, 100 gemessene warme
Posewechsel nach zehn Aufwärmzyklen. Ein Pixel-Readback erzwingt die Rasterarbeit.
Dies sind Labormessungen, keine physischen iPhone-/Android- oder FPS-Zusagen.

| Referenz-Guard mit Mantel | V1-Vollflächen | Komponentenatlanten |
|---|---:|---:|
| Bildanfragen | 8 | 2 |
| Bilddaten, ohne HTTP-Header | 1.513.231 Byte | 2.024.127 Byte |
| Dekodierte RGBA-Rechteckfläche | 29.884.416 Byte / 28,5 MiB | 11.149.312 Byte / 10,6 MiB |
| Geschätzte Dekodierflächen-Reduktion | – | 62,7 % |

**Nachteil:** 33,8 % mehr Bilddaten für das erste Outfit. Der gemeinsame Atlas
enthält bereits beide Posen und weitere Varianten. Deshalb ist ein großer
Sammelatlas kein fertiger mobiler Ladeplan. Nächster technischer Schritt:
kleiner Basisatlas plus separat ladbare Pose-/Slot-/Materialgruppen; feste
Cachebudgets und Originalpixel erhalten. GPU-Zusatzspeicher/Heap-Spitzen wurden
nicht gemessen; RGBA-Flächen sind nur eine nachvollziehbare Untergrenzenrechnung.

Im ersten vollständigen Messlauf: warmer Cool/Guard-Wechsel Chromium P50/P95
8,3/10,9 ms → 5,0/6,8 ms, WebKit 10/16 ms → 4/7 ms. Kaltes Laden/Dekodieren/
erstes Zeichnen als Median: Chromium 287 → 182,7 ms, WebKit 231 → 118 ms.
Wiederholungen schwanken mit Systemlast; maßgeblich sind die mitgelieferten
Browser-JSON-Berichte. Niedrigere lokale Latenz trotz höherer Bytes ist kein
Nachweis besserer Ladezeit über Mobilfunk.

Voll-PNG und Atlas wurden aus denselben Guard-Komponenten erzeugt. Über alle
16 Outfits beträgt die größte mittlere Kanalabweichung rund 0,0000046 auf der
Skala 0–255. Diese Ausgabeparität prüft den Renderer; sie beweist keine neue
Illustrationsqualität. Die separate Quelle-zu-Atlas-Prüfung belegt echte
Wiederverwendung unabhängig vom gebackenen Vergleich.

## Aufwand und Qualitätsentscheidung

| Ansatz | Nutzen | Kosten/Risiko | Entscheidung |
|---|---|---|---|
| Weiteres PNG je Pose/Slot | Bestehender Renderer; leicht künstlerisch kontrollierbar | Wiederholte Zeichnung, große transparente Texturen, viele Dateien | Vergleich und Fallback beibehalten |
| Vollständiges 2.5D-Rig | Potenziell viele Posen aus denselben Gliedmaßen | Verborgene Anatomie, Schulter-/Ellbogenkorrekturen, Stoff, Ansichtswechsel und Authoring nötig | Noch nicht wirtschaftlich/visuell bewiesen |
| Gemeinsame Teile + posebezogene Korrekturen | Gemessene Pixelwiederverwendung, kleinere Dekodierfläche, Item-/Figur-Gleichheit | Materialmasken, Abhängigkeiten, Seam-QA und gezielte neue Ansichten erforderlich | Begrenzten Guard-Folgeauftrag durchführen |

Eine hohe Wiederverwendungsquote rechtfertigt keinen sichtbaren Qualitätsverlust.
Mantelübergang/Taillentrim und Ärmelverdeckung bleiben blockierende Befunde;
die Guard-Kronen weichen vom Cool-Ornament ab. Keine weiteren Itemfamilien
generieren, bevor diese Gates bestanden sind. Bilder des Piloten zeigen den
tatsächlichen Zwischenstand einschließlich dieser Mängel.

## Reproduzierbare Prüfungen

`node scripts/inventory-premium-v2.cjs`

`node tests/premium-v2-contracts.cjs`

`BROWSER=chromium,webkit SHOTS=<output> node tests/premium-v2-pilot-browser.cjs`

Browserprüfungen: 16 Kombinationen je Engine, Renderer-Pixelparität,
Quelle-zu-Atlas-Pixelvergleich, Handschuhanker/Varianten-Silhouette, fehlende
Unterstützung, 390px-Overflow, keine externen Verbindungen und reale Bildanfragen.
CI legt Vergleichsbilder, reine Figuren, Itembilder und Mess-JSON als Artefakte ab.
Die Prüfungen bescheinigen technische Verträge, keine künstlerische Freigabe.

Alle bisherigen Premium-Freigabeschalter sowie die neuen Pilotflags bleiben aus.
Kein Merge, Deployment, Datenbankzugriff oder neue Shop-Items.
