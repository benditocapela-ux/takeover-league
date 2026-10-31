# Character-Architektur: Entscheidung für PR #79

Stand: 31.10.2026. Entscheidung: **hybrider Ausbau in einem separaten Meilenstein; bestehendes PNG-System V1 und SVG-Fallback jetzt beibehalten.** Kein neues Rig, keine neuen Posen, keine Grafikänderungen in diesem Architektur-Meilenstein.

## Tatsächlicher Bestand

`takeover-holo.js` normalisiert dieselben gespeicherten Schlüssel für alle Renderer. Posen: `guard`, `jab`, `sieg`, `cool`, `flex`, `ansage`; `pose_profile` und `pose_card` bleiben unabhängig. Unbekannte Posen normalisieren zu `guard`. Es gibt acht Hauttöne, 18 Frisuren, acht Haarfarben, acht Augenfarben, vier Augeneffekte plus `none`; Kopfbedeckungen `cap`, `band`, `hijab`; Oberteile `tank`, `shirt`, `hoodie`, `jacke`; Hosen `boxer`, `kurz`, `jogger`, `track`; Schuhe `boots`, `sneaker`; acht Kleidungsfarben; Mäntel `basic`, `samurai`, `neon`, `drache`; Handschuhe in fünf Farben oder Bandagen; vier Auren plus `none` und die Szenen `holo`, `dojo`, `neon`, `arena`. Nicht jede Kategorie erlaubt `none`; maßgeblich bleibt `normalize`.

`takeover-mein-boxer-artpack.js` registriert V1-Bilder auf einer gemeinsamen 768×1216-Fläche. Die Ebenenfolge ist `coatBack`, `body`, `bottom`, `feet`, `top`, `eyes`, `hair`, `head`, `coatFront`, `hands`. `poses` und optionale `configurations[pose]` deklarieren unterstützte Auswahlen. Bei unvollständiger Auswahl, fehlender Pose, nicht unterstütztem Effekt oder Ladefehler bleibt die vollständige SVG-Figur sichtbar. Ein Outfit erscheint erst nach Laden aller Ebenen. Pfade dürfen in mehreren Posen wiederverwendet werden; dazu braucht es keinen neuen Renderer. Ein Regressionstest belegt diese Schemafähigkeit mit einem ausdrücklich künstlichen Beispiel, nicht die anatomische Eignung der Cool-Bilder für Jab.

`takeover-mein-boxer-modular-manifest.js` beschreibt zwölf Cool-PNGs für 32 Kombinationen: Mantel aus/Samurai × Tank aus/an × Shorts schwarz/rot × Afro/Kurzhaar × Handschuhe schwarzgold/weiß. Hautton 6, braune Augen und schwarze Boots sind fest; weitere Auswahlwerte fallen auf SVG zurück. Die acht Originalmasken sind ein anderer, eng begrenzter Cool-Satz. Beide Manifeste bleiben `approved:false`, `enabled:false`.

`takeover-mein-boxer-layers.js` ergänzt SVG mit Konturen, Nähten und Haar-Details; es ist kein bewegliches Charakter-Rig. `takeover-mein-boxer-draft-layers.js` verwaltet Originalmasken, Import-/Hashprüfung und optionale Entwurfsansichten; es bietet keine frei beweglichen anatomischen Einzelteile.

## Alternativen

| Kriterium | A: PNG pro Pose | B: vollständiges 2.5D-Rig | C: Hybrid (empfohlen) |
| --- | --- | --- | --- |
| Nähe zur Anime-Referenz | Sehr gut kontrollierbar je Zeichnung | An Gelenken, Stoff und Perspektive ohne Korrekturen begrenzt | Hochwertige Schlüsselbilder plus gezielte Korrekturen |
| Zeichenarbeit | Neue Silhouetten/Verdeckungen pro Pose | Hoher Startaufwand für verborgene Anatomie, Gelenke und Materialteile | Begrenzter Pilot, danach nur tatsächlich veränderte Teile |
| Kleidung/Handschuhe wiederverwenden | Bei identischer Form, Ansicht und Verdeckung | Gut innerhalb derselben Ansicht; keine universelle Drehbarkeit | Gemeinsame Teile mit notwendigen Ansichtsvarianten |
| Kosten/Wartung weiterer Posen | Übersichtlich bei wenigen, wachsender Export-/Registrierungsaufwand | Niedrigere Posekosten erst nach tragfähigem Rig; hohe Werkzeugkosten | Mittlere Komplexität, messbarer schrittweiser Ausbau |
| Laden/Mobilgeräte | Wenig Laufzeitlogik, viele große Texturen möglich | Kleinere Teile möglich; zusätzliche Transformation/Deformation | Bestehende statische Ausgabe erhalten, Komponenten nur bei Nutzen |
| Integration | Bereits unterstützt | Neuer Renderer, Schema, Authoring und QA notwendig | V1 beibehalten, optionalen V2-Adapter später ergänzen |
| Hauptrisiko | PNG-Menge, fehlerhafte Registrierung | Marionettenoptik, Nähte, falsche Z-Order, verlorene Referenzqualität | Zwei Ausgabewege und klare Fallback-/Versionsgrenzen nötig |

Die Dateizahl wächst bei A ungefähr mit Posen × Summe benötigter Varianten, nicht mit sämtlichen Outfitkombinationen: schon heute ergeben zwölf Dateien 32 Outfits. Trotzdem wächst die Zahl bei perspektivisch unterschiedlichen sechs Posen erheblich. Ein vollständiges Rig ist für diesen begrenzten Satz noch nicht wirtschaftlich belegt. C erlaubt einen kontrollierten Vergleich anhand einer zusätzlichen Pose, bevor ein großer Umbau beschlossen wird.

## Was wiederverwendbar ist

Unverändert nutzbar sind Konfigurationsschlüssel, Shop-/Inventarzuordnung, Normalisierung, Editor, atomarer Bildwechsel, Fallback, Prüfungen und kompatible Dateipfade. Haare, Augen, Schuhe und Unterkörper können gleich bleiben, **wenn** Kopf-/Rumpfausrichtung und Verdeckung wirklich gleich sind. Farbvarianten können zukünftig aus sauberen Materialmasken exportiert werden; bestehende schattierte PNGs werden nicht pauschal per CSS eingefärbt.

Cool-Körper und gekreuzte Arme enthalten fest gezeichnete Lichtverläufe und Verdeckungen. Verborgene Körperflächen fehlen. Das hintere Handschuhbild ist bereits für den vorderen Unterarm ausgespart. Diese Dateien sind weder universelle Handansichten noch brauchbare Gelenksegmente allein durch Zuschneiden oder Drehen. Weitere Posen brauchen getrennte Ober-/Unterarme, Hände, gegebenenfalls Vorder-/Rückansichten, verdeckte Anatomie und korrigierende Stoff-/Schattenzeichnungen. Mantelfront und -rücken bleiben getrennt; Ärmel müssen den Armen folgen. Perspektivische Verkürzungen verlangen eigene Ansichten.

## Risikoarme Vorbereitung in diesem PR

`TLHolo.POSE_DEFINITIONS` wird unveränderlich aus derselben privaten Pose-Tabelle wie der SVG-Renderer abgeleitet. Es benennt Schulter, Ellbogen und Handgelenk für `imageLeft`/`imageRight` im Koordinatenraum `svg-240x380` sowie die bestehende Arm-Zeichenfolge. Es dupliziert keine Koordinatenquelle und verändert keine Darstellung. Die Begriffe beziehen sich auf Bildseiten, nicht anatomische links/rechts.

Diese SVG-Gelenke sind **keine PNG-Anker**. Zukünftige PNG-Komponenten müssen eigene, künstlerisch vermessene Anker, Pivotpunkte, Bezugsgröße, Ansichtsvariante und poseabhängige Zeichenfolge erhalten. Ein Umrechnen des SVG-Maßstabs allein reicht nicht. V1-Layerschlüssel und gespeicherte Ausstattung bleiben stabil; feinere Komponenten werden intern auf vorhandene Slots abgebildet. Keine Datenmigration ist jetzt nötig.

## Getrennter Ausbauplan und grobe Schätzung

Schätzungen in Personentagen, keine Zusage. Annahmen: ein verfügbarer Character Artist und ein Frontend Engineer, editierbare Quelldateien, eine zusätzliche Pose in ähnlicher Perspektive, begrenzte Garderobe wie im Cool-Pilot, bestehender Editor bleibt. Tage verschiedener Rollen sind nicht automatisch Kalenderdauer; Designkorrekturen und größere Perspektivwechsel kommen hinzu.

| Phase | Ergebnis / Abnahmekriterium | Grober Aufwand |
| --- | --- | --- |
| 1: Quellen- und Teileplan | Editierbare Quellen, Gelenke, verdeckte Flächen und Wiederverwendung je Teil dokumentiert | 2–4 Art + 1 Engineering |
| 2: Guard-Pilot mit einer Kleidung/Handschuhansicht | Vergleich PNG gegen Hybrid; keine offenen Nähte, korrekte Überlagerung und Referenzqualität | 5–10 Art + 3–5 Engineering + 2 QA |
| 3: Optionaler V2-Adapter | Versionsschema, Anker/Zeichenfolge/Korrekturen, atomarer Fallback, unveränderte gespeicherte Schlüssel | 3–5 Engineering + 2 QA |
| 4: Nächste Pose ähnlicher Perspektive | Nachweis wirklich wiederverwendeter Teile; Outfits und verdeckte Bereiche geprüft | je 2–5 Art + 1–2 Engineering + 1–2 QA |
| 5: Größere Garderobe | Export-/Materialmaskenwerkzeug, Cachebudget, Variantenmatrix und Gerätetest | 3–6 Engineering + 2–3 QA; Art erst nach Teileinventar schätzbar |

Nach Phase 2 stoppen, wenn Qualität oder Wiederverwendungsquote den Zusatzaufwand nicht rechtfertigen; dann einzelne neue Posen deklarativ mit V1 ergänzen. Kein Zwang, sämtliche sechs Posen auf einmal umzubauen. Vor Phase 3 sind SVG-Gleichwertigkeit, Save/Reset, Unsupported-Pose-Fallback und unveränderte Shopwerte Pflicht. Neue Produktionsgrafiken benötigen eine separate persönliche Freigabe.

## Performancegrenzen

Aktuelle zwölf modulare PNGs: 2.095.122 Byte; konservatives größtes Outfit: 1.793.563 Byte. Maximal drei parallele Preloads, deduplizierte laufende Requests und URL-Statuscache. Der normale, nicht freigegebene Produktionspfad lädt keine Entwurfs-PNGs.

Reine RGBA-Abschätzung: 768×1216×4 = 3,5625 MiB pro Textur, zwölf Texturen 42,75 MiB; neun sichtbare Ebenen bis 32,06 MiB, jeweils **ohne** Browser-/GPU-Zusatzspeicher. Das ist keine gemessene Heap- oder Geräte-Spitze; Browser entscheiden selbst über dekodierte Caches. Für deutlich größere Posekataloge vorab Texturgrößen reduzieren, zugeschnittene Komponenten/Atlanten prüfen und einen begrenzten Cache messen. Keine zusätzliche Rig-Laufzeit oder Bibliothek in PR #79.
