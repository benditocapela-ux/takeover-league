# Gemeinsamer Character-Art-Standard V2

## Koordinaten, Anatomie und Ansicht

Designfläche 768×1216, transparente RGBA-Pixel, sRGB. Ursprung links oben,
x nach rechts, y nach unten. Anatomische Seite und Bildseite getrennt benennen:
`anatomicalRight` erscheint in Frontansicht links. SVG-Anker im Raum 240×380
sind keine PNG-Anker; keine automatische Skalierung als Passformbeweis.

Cool bleibt Identitäts-/Materialreferenz: Kopf-/Kieferform, Augenabstand,
Hautpalette, Muskelvolumen, Haaransatz und Licht. Richtwerte im Pilotraum:
Kopfkrone y65, Kinn y225, Schulterhöhe y270–300, Hüft-/Bundlinie y550–575,
Knöchel etwa y1010, Bodenkontakt y1165, Körpermittellinie x384. Kein wechselnder
Kopfmaßstab, keine automatisch verbreiterten Hände und kein wandernder Boden.
Die Körperkontur ist die maßgebliche Referenz, nicht diese gerundeten Zahlen.

| Pose | Schulter links/rechts im Bild | Ellbogen links/rechts | Handgelenk links/rechts |
|---|---|---|---|
| Guard-Pilot | ca. (255,290)/(515,290) | ca. (245,415)/(530,415) | (315,270)/(458,270) |
| Cool | ca. (250,290)/(515,290) | ca. (230,420)/(540,430) | vorderer Arm (420,386), hinterer Arm (310,374) |

Guard-Anker sind Pilotenwerte, noch kein freigegebenes anatomisches Rig.
Cool-Handgelenkanker stammen aus der bestehenden Registrierung. Bei gekreuzten
Armen lässt sich „Hand links im Bild“ nicht mit „Arm beginnt links“ gleichsetzen.
Jeder Arm benötigt später eine explizite Schulter→Ellbogen→Hand-Kette.

Aktueller Wiederverwendungsraum: gleiche Frontkamera, gleiche Kopf-/Hüft- und
Fußausrichtung. Für Jab/Ansage erst prüfen, ob die gewünschte Premium-Geste
Rumpfdrehung oder starke Verkürzung braucht. Ein bloßes Verschieben der Cool-Arme
würde fehlende Brustflächen und falsche Verdeckungen offenlegen.

## Komponentenvertrag

Jedes zukünftige Masterteil erhält `id`, bestehenden Item-/Slot-Schlüssel,
`viewId`, Quellhash, Materialvariante, lokalen Ursprung, Designmaßstab,
Alpha-/Schnittmaske, Pivot, benannte Gelenkanker, z-Order und zulässige Posen.
Atlanten tragen UV-Rechtecke und mindestens zwei Pixel Sicherheitsabstand.
Keine automatische Spiegelung einer linken Hand in eine rechte ohne geprüfte
Daumen-/Licht-/Ornamentkorrektur. Keine eingebrannten benachbarten Kleidungsstücke.

Der Pilot implementiert `id`, `slot`, `origin`, `atlas`, `uv`, `box` und
quellengleiche Registrierung. Unabhängige Arm-Pivots, Verdeckungsmasken und
Verformungskorrekturen sind **Folgearbeit**, nicht schon durch das JSON erledigt.

Künftige Masteraufteilung:

- Körper: Kopf/Hals, Torso, Becken/Beine, Oberarm/Unterarm pro Seite mit
  vollständig gezeichneten verdeckten Gelenkbereichen; Hände getrennt.
- Kleidung: Torso, linke/rechte Ärmel, Kragen/Kapuze, Vorder-/Rückteil,
  Mantelschwänze; durchgängige Goldkanten und Nähte über Schnittstellen.
- Hände: vollständige Ansicht links/rechts für Guard, Seite/Verkürzung für
  Jab/Ansage, ggf. Handrücken/Handfläche für Sieg/Flex. Cool-Sonderverdeckung
  als Maske, nicht als Loch im universellen Handschuhmaster.
- Kopf: Haare hinten/vorn, Kappe/Stirnband/Hijab/Kapuze mit expliziter
  gegenseitiger Verdeckung, Augen-/Effektanker lokal zum Kopf.

## Material- und Farbstandard

Key-Licht von oben links/vorn, zurückhaltendes rechtes Kantenlicht; dieselbe
Lichtrichtung bei Haut, Haaren, Leder und Metall. Haut behält warme Mitteltöne,
weiche Volumenlichter und erkennbare Muskelanatomie. Schwarzes Leder hat dunkle
Grundfarbe und kontrollierte Glanzflächen; Gold ist warmes Metall mit hellen
Kanten, kein gelber Plastikfüllton. Weißes Leder hat kühle graue Schatten,
Goldornamente bleiben unverändert. Keine gemischte fotografische/Comic-Textur.

Alle erlaubten Farben/Hexwerte stehen in `inventory.json`. Dafür später
editierbare Materialmasken (Basisfarbe, Schatten, Glanz, Metall, Stickerei)
anlegen. Keine globale CSS-Hue-Rotation der schattierten PNGs. Weiße, dunkle und
gesättigte Stoffe benötigen kalibrierte Tonwertkurven. Die fünf bestehenden
Handschuhvarianten haben eigene Akzentpaletten; Weiß im Premium-Piloten behält
das vorhandene Gold-Design. Jede Abweichung zur SVG-Palette ist als explizite
Art-Entscheidung zu dokumentieren, kein versteckter Fallback auf andere Farben.

## Ebenen und Verdeckungen

V1-Kompatibilität: Mantel hinten → Körper → Hose → Schuhe → Oberteil → Augen →
Haare/Kopfbedeckung → Mantel vorne → Hände. Im Hybrid intern feiner aufteilen:
Hintergrund/Aura → Mantelrücken/Haare hinten → hintere Gliedmaßen → Torso/Beine
→ Kleidung → vordere Gliedmaßen/Ärmel → Kopf/Gesicht/Haare vorn → Handschuhe →
posebezogene Schatten und Korrekturen. Die jeweilige Pose deklariert den
gerichteten Verdeckungsgraphen; es gibt keine universelle Arm-Reihenfolge.

Hoodie oben verdeckt Haare entsprechend der tatsächlichen Haube; Hijab
ersetzt die Haaransicht. Ein Mantel braucht getrennte Ärmel-/Torso-/Schwanzmasken.
Bandagen, Handschuhe und Unterarme dürfen keine fremde Haut/Ärmel mitbringen.
Vorschaukacheln filtern dieselbe aufgelöste Komponentenliste wie die Figur;
Mantel kombiniert alle Mantelteile. Status erst nach vollständiger Unterstützung
und erfolgreichem Laden, ansonsten vollständiger SVG-Fallback im Editor.

## Abnahmekriterien

1. Kopf-/Bodenkontakt bei Ansichtswechsel stabil; gemeinsame Teile bei 1:1-Ausgabe
   pixelgleich. Gefiltertes Upscaling ist kein Nachweis neuer Details.
2. Beide Handschuhfarben: gleiche Anker, vollständige Handabdeckung, freie
   Unterarme und anatomisch richtige Daumen. Alpha-IoU ist nur ein ergänzender
   Test, kein Ersatz für Sichtprüfung.
3. Keine sichtbare Öffnung/Naht an Hals, Schulter, Ellbogen, Handgelenk oder Bund;
   keine doppelte Goldkante, Schattengeister oder unpassenden Schnittkanten.
4. Ornament-, Material- und Farbidentität zur Cool-Referenz. Identische
   Item-Quellen in Figur und Kachel, keine fremde Kleidung im Ausschnitt.
5. Prüfung bei 100 % und 200 %, auf dunklem/hellem Hintergrund, Mantel an/aus,
   beiden Handschuhfarben und zwei Unterkörpervarianten, Chromium/WebKit.
6. Danach physische iPhone-/Android-Prüfung, begrenzter Cache und explizite
   persönliche Grafikfreigabe. Bis dahin alle Premiumflags deaktiviert.
