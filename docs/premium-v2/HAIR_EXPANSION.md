# Haarproduktion: sieben wiederverwendbare Formen

Sieben eigenständige schwarze Anime-Haarform-Master wurden mit dem integrierten Imagegen-Werkzeug erzeugt, registriert und im tatsächlichen Komponentenrenderer geprüft. Keine neuen Shop-Items, keine Änderungen der Cool-Originale. Alle Dateien bleiben im isolierten Entwurfsbereich; `approved:false`, `enabled:false`, **Artistically pending**.

| Bestehender Item-Key | Datei | Registrierung x/y/w/h | PNG-Bytes |
|---|---|---|---:|
| wellig | `hair-expansion/assets/wellig.png` | 311 / 50 / 146 / 109 | 26.102 |
| locken | `hair-expansion/assets/locken.png` | 309 / 45 / 150 / 115 | 28.377 |
| high_top | `hair-expansion/assets/high_top.png` | 313 / 50 / 142 / 107 | 27.914 |
| cornrows | `hair-expansion/assets/cornrows.png` | 322 / 57 / 124 / 95 | 19.391 |
| twists | `hair-expansion/assets/twists.png` | 309 / 48 / 150 / 109 | 29.636 |
| afro_puffs | `hair-expansion/assets/afro_puffs.png` | 289 / 54 / 190 / 101 | 37.713 |
| dutts | `hair-expansion/assets/dutts.png` | 290 / 59 / 188 / 100 | 33.793 |

Die sieben bedarfsgerecht ladbaren Laufzeitdateien benötigen zusammen **202.926 Byte**. Acht Haarfarben werden aus jedem Master mit derselben bestehenden Materialfunktion erzeugt: **56 echte Materialvarianten**, in **112 Cool-/Guard-Kombinationen** geprüft. Es gibt sieben neue Form-Master plus zwei gezielte Korrekturdurchgänge, keine 56 einzeln generierten Varianten und keine Kopien pro Pose.

## Grafik und Registrierung

Wellig verwendet breite S-Wellen, Locken erkennbare Ringellocken und High Top eine kompakte hohe, abgeflachte Silhouette mit eng gekräuselter Textur. Licht und Material orientieren sich an den bestehenden schwarzen Anime-Haaren. Alle sieben Quellen enthalten ausschließlich Haar; Stirn, Ohren, Augen und Brauen werden vom Körperkopf geliefert. Keine nachträglich eingebrannten Gesichtsausschnitte oder fremden Kleidungsstücke.

Der Builder ermittelt die Alpha-Grenzen, skaliert das vollständige Haar proportional und richtet die gemessene mittlere Haarlinie bei x384/y111–113 aus. Es werden keine einzelnen Locken verschoben oder transparente Teile neu gezeichnet. Registrierte Abmessungen, Quellausschnitte, Quellhashes und Laufzeithashes stehen in `tools/premium-v2/hair-expansion/manifest.json`.

Das Head-Fit-Kontaktblatt wurde visuell geprüft: keine schwebende Lücke am Scheitel, freie Gesichtspartie, abgestimmte Schläfen und dieselbe Kopfpassform in Cool/Guard. Die genaue ästhetische Freigabe der Silhouetten und Farbrampen bleibt beim Auftraggeber. Perspektivwechsel oder Kopfdrehungen in weiteren Posen sind damit nicht freigegeben.

Cornrows besitzen echte transparente Kanäle zwischen den Zöpfen; dadurch erscheint der tatsächliche Hautton des Körperkopfs. Twists haben getrennte kurze Strähnenenden. Afro Puffs behalten zwei seitliche Volumen und eine zusammenhängende mittlere Haarkappe. Der erste Puffs-Entwurf hinterließ eine sichtbare kahle Stelle am Scheitel; ein gezielter Imagegen-Edit ergänzt die zentrale Haarkappe. Ein zusätzlicher Alpha-Test am Scheitel verhindert die Wiederkehr dieses Fehlers. Die verworfene erste Quelle bleibt ausschließlich zur Provenienz erhalten. Die drei zuerst fertiggestellten Quellen und Runtime-Dateien wurden unverändert bewahrt.

## Quellen, Prompts und Reproduktion

Modus: **built-in imagegen**, je ein Aufruf pro Haarform plus ein gezielter Crown-Cap-Edit für Afro Puffs. Die exakten Prompttexte stehen in `tools/premium-v2/hair-expansion/prompts.json`; Referenzen waren der registrierte Stachel-Haarmaster und die bestehende Cool-Körperfigur.

Rohquellen im Projekt:

- `tools/premium-v2/hair-expansion/sources/wellig.png` – Imagegen-Datei `exec-8b432821-9aa9-4d3f-9571-f572b7714444.png`
- `tools/premium-v2/hair-expansion/sources/locken.png` – `exec-720f1b4d-6bfb-4128-a37b-0d74064207bc.png`
- `tools/premium-v2/hair-expansion/sources/high_top.png` – `exec-126816d7-901a-4fd3-95fc-0b6b27c01961.png`

- `tools/premium-v2/hair-expansion/sources/cornrows.png` – `exec-65c273bf-c49d-45c4-967a-664070b70121.png`
- `tools/premium-v2/hair-expansion/sources/twists.png` – `exec-0f7a1792-5052-47a7-bce4-e572abab85a6.png`
- `tools/premium-v2/hair-expansion/sources/afro_puffs-v2.png` – finaler Korrekturmaster `exec-61f80745-b97b-400b-84f8-359f286d1fa6.png`; ursprüngliche verworfene Quelle `afro_puffs.png` stammt aus `exec-b6e1a9ef-d476-47a3-bb5c-c91471b9abbc.png`.

Generierungssitzung: `01a190d9-8361-7761-b3d9-0457093edebe`. Die Rohquellen bleiben erhalten; Neugenerierung ist nicht deterministisch, die Registrierung aus diesen Quellen schon.

`CANVAS_MODULE=<@napi-rs/canvas> node scripts/build-premium-v2-hair-expansion.cjs`

`node tests/premium-v2-hair-expansion.cjs`

## Prüfungen

Chromium und WebKit bestanden jeweils 112 Kombinationen. Die Prüfung verwendet `TLPremiumProduction.draw`, den tatsächlichen Komponentenrenderer, mit den vorhandenen Cool-/Guard-Körpern, den sieben neuen Haarquellen und allen acht Materialwerten. Figur und Haar-Kachel beziehen dieselbe Quellkomponente. Die über dem Körper komponierte Kachel stimmt im Haarbereich mit der Figur bis auf maximal einen Rundungsschritt pro Kanal überein. PNGs behalten echte Teiltransparenz; deshalb wäre ein nackter RGB-Vergleich der Kachel mit der bereits über Haut komponierten Figur fachlich falsch.

Zusätzlich: Hashes, Registrierung, ausreichend echte Haarpixel, freie Gesichtskoordinaten, Scheitelabdeckung, Quellenwiederverwendung zwischen Posen/Farben, keine externen Anfragen oder Browserfehler, unveränderte Freigabeflags. Textfingerprints verwenden kanonische LF-Zeilenenden, PNG-Hashes unveränderte Binärbytes.

Kontaktbögen und JSON-Berichte: `tools/premium-v2/hair-expansion/evidence/{chromium,webkit}-hair-contact.png` und `{chromium,webkit}-validation.json`. Sie zeigen tatsächliche Körpermontagen, vergrößerte Kopfansichten und alle 56 originalgetreuen Haar-Kacheln. Der isolierte Test hält andere Ausrüstung auf dem bestehenden Pilotstand, um die neue Haarregistrierung gesondert zu prüfen.

## Dutts crown correction

The seventh form, dutts, uses a separate compact smooth-bun master. Its initial shallow central cap exposed a scalp sliver in actual body composition. A targeted built-in Imagegen correction increased the upper crown only; original and corrected sources remain preserved (dutts.png and dutts-v2.png). The final registered asset is 188×100 at [290,59], 33793 bytes. The explicit crown pixel test at (384,70) applies to dutts as well as afro_puffs. Prompt and correction are recorded in prompts.json. Both poses reuse one silhouette and the same eight hair materials. No artistic approval.

Dutts generation sources: initial exec-a9c00850-525f-4e36-a9fb-c0046f5ca932.png; corrected exec-8d55ef69-11c0-4b15-828a-7d5b79cb116d.png. Both used the built-in Imagegen tool and preserve genuine transparency.

