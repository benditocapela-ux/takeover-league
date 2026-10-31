# Produktionsplan und nächster konkreter Auftrag

**Jetzt kein Auftrag zur Vollproduktion.** Die 1.800 Matrixzellen sind Prüffälle.
Wiederverwendung ist nur für die identische Frontansicht der Pilotkomponenten
belegt. Aufwand unten ist eine Planungsschätzung in Personentagen, keine
gemessene Arbeitsersparnis; Grundlage sind ein Character Artist und ein Engineer.

## P0 – Guard-Reparatur und belastbare Masterteile

Nächster Produktionsauftrag: **Guard-Korrekturpaket A, genau ein Körperlook,
Samurai und Schwarz-/Weiß-Gold, keine zusätzlichen Items oder Posen.**

Eingaben: Cool auf `1a55e05`, `pilot-assets.json`, beide Browservergleichsbilder,
`ART_STANDARD.md`, `quality-gates.json`. Alte Artefakte nicht überschreiben.

Lieferumfang an den Character Artist:

1. Übergang der oberen Mantelfront zur unveränderten unteren Cool-Mantelfront
   im Bereich x230–540/y490–600 als separate Korrekturebene zeichnen. Einfache
   Überblendung erzeugt doppelte/abweichende Goldlinien und ist nicht abgenommen.
2. Guard-Ärmel gegen Körperbasis prüfen und vollständige Körper-Verdeckungsmasken
   für Schultern/Ellbogen liefern; keine Hautspitzen außerhalb geschlossener Ärmel.
3. Beide Guard-Handschuhe auf die **exakte** Cool-Krone, Paspel und Stickerei
   korrigieren. Gemeinsame Form-/Materialmaster statt zweier unabhängiger Neuzeichnungen.
   Anker (315,270)/(458,270) erhalten oder begründet gemeinsam revidieren.
4. Einen kleinen vollständigen rechten Arm-Master (Oberarm, Unterarm, versteckte
   Gelenkflächen) mit neutraler Frontansicht liefern. Nur daran ±10° um Ellbogen
   und Schulter testen. Bei sichtbarem Qualitätsverlust gezielte Korrekturform
   liefern; keinen Ganzkörper-Rig-Erfolg aus starren Ausschnitten ableiten.
5. Editierbare Quellen, Material-/Alpha-/Occlusion-Masken, JSON-Anker und
   verlustfreie Exporte abgeben. Kein neuer Katalogschlüssel.

Engineering: Atlas in Basis-/Pose-/Materialgruppen teilen; erste Guard-Ladung
nicht größer als der V1-Vergleich (1.513.231 Byte) bei gleicher Bildqualität.
Maximal drei parallele Preloads, kein beliebig wachsender Cache. Hybrid weiterhin
nur im Labor. Item-Thumbnails aus derselben Komponentenauflösung.

Abnahme: sämtliche offenen Guard-Art-Gates geschlossen; 16 Kombinationen in
beiden Engines, Quelle-zu-Atlas-Vergleich, Handgelenke, keine Naht bei 200 %,
gemessene Erstladedaten und echte Geräte. Erst dann Entscheidung über P1.
Geschätzt **3–5 Art + 2–3 Engineering + 1–2 QA-Tage**; Korrekturschleifen zusätzlich.

## P1 – Gemeinsame Frontansicht ausbauen

Nach P0 zuerst die Masterfamilien, die beim Pilot nicht mit Armen verformt werden:
acht Haut-/Augenfarben, alle 18 Frisuren und acht Haarfarben; danach Kappe,
Stirnband, Hijab einschließlich Masken. Parallel vier Hosen und zwei Schuhformen
mit acht Materialvarianten. Hautton-Master muss alle Körperteile konsistent
umfassen; keine isolierte Einfärbung einzelner Hände.

Arbeitsweise: **eine** Haar-/Hosen-/Schuhform in der festen Frontansicht, daraus
geprüfte Materialvarianten, anschließend Pose-Abdeckung anhand gleicher Kamera.
Lange Haare, Hijab und Kapuze brauchen gesonderte Verdeckungen. Die 144 Haar-
und 48 Hosen-/Schuhvarianten sind nicht 192 unabhängige Ganzkörperzeichnungen.
Geschätzt 8–14 Art + 3–5 Engineering + 3 QA-Tage, nachdem die Masterpipeline steht.

## P2 – Oberteile, Mäntel, Hände und zusätzliche Ansichten

Vier Oberteile, Hoodie mit beiden Kapuzenzuständen, verbleibende drei Mäntel,
Bandagen und drei weitere Handschuhfarben. Torso-/Materialmaster gemeinsam;
Ärmel und Falten nur dort neu, wo Pose oder Perspektive dies erzwingen.
Vorhandenes Cool-Tanktop hat ausgesparte Kreuzarmbereiche und ist **kein**
vollständiger Guard-Torsomaster. Zuerst unbedeckte Flächen ergänzen.

Für weitere Posen nach Guard:

1. **Flex:** gleichbleibender Kopf/Unterkörper, beide gebeugten Arme höher;
   prüft Schultergelenk und Ärmelzug. Ein passender Guard-Arm-Master ist der
   erste Wiederverwendungskandidat, kein bereits bewiesener Export.
2. **Sieg:** asymmetrischer hoher Arm, neue Achsel-/Unterarmsicht und gegebenenfalls
   Handfläche. Kopf-/Unterkörper nur bei unveränderter Kamera übernehmen.
3. **Jab:** gestreckter Arm, Verkürzung und ggf. Rumpfdrehung; eigene Handansicht
   und Brust-/Schulterkorrektur einkalkulieren.
4. **Ansage:** ausgestreckter/zeigender Arm, andere Hand-/Ärmelsilhouette;
   nach Jab als Wiederverwendungsprüfung, nicht automatisch aus dessen PNG.

Je neue Pose zuerst nur Körper + ein Oberteil/Mantel + zwei Handschuhfarben.
Erst nach dieser Probe die vorhandenen Kleidungsfamilien adaptieren.
Schätzung je ähnliche Pose 2–4 Art + 1–2 Engineering/QA-Tage; perspektivisch
andere Pose 4–7 Art + 2–3 Engineering/QA-Tage. Kleidungsfamilien zusätzlich
nach gemessener Zahl neuer Ansichten planen, nicht pauschal sechsmal zeichnen.

## P3 – Effekte, Szenen und vollständige Prüfung

Vier Auren, vier Augeneffekte und vier Szenen stilistisch angleichen. Prozedurale
SVG/Canvas-Effekte können bewusst Teil des Hybrid bleiben; sie brauchen nicht
pro Pose ein PNG. Kopf-/Silhouettenmasken korrekt anbinden. Bestehende Bundles
bleiben reine Zusammenstellungen ihrer unveränderten Item-Schlüssel.

CSV-Matrix vollständig abarbeiten: jede freigegebene Variante in jeder
unterstützten Pose, alle Ausschluss-/Fallback-Fälle, beide Profil-/Kartenposen,
Cache-/Fehlerpfade und tatsächliche Kachelgrafik. Geschätzt 3–6 Art + 2–4
Engineering + 3–5 QA-Tage für Effekte und Abschluss, ohne offene Art-Schleifen.

## Entscheidung nach jeder Stufe

Weiter nur bei gleichbleibender visueller Qualität, positiven Messwerten und
geschlossenem Abnahmeprotokoll. Wenn Arm-/Stoff-Rigging mehr Korrekturaufwand
als Schlüsselzeichnungen erzeugt, Hybrid auf wiederverwendbaren Kopf/
Unterkörper/Materialien begrenzen und anspruchsvolle Armposen gezielt zeichnen.
Kein Zwang zum vollständigen Rig. Produktionsaktivierung und Deployment bleiben
ein eigener, ausdrücklich freizugebender Schritt.
