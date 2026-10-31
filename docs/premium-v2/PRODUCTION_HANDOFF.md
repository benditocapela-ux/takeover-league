# Autonome Premium-Produktion

Arbeitsbasis PR #81 `02414c9`, eigener Branch `art/premium-v2-catalog-production-20261031`, Draft PR #82 gegen PR #81. PR #79/#80/#81, Cool-Originale, normaler Editor, Katalog und Datenbank bleiben unverändert. Alle Freigabe-/Aktivierungsflags bleiben aus.

## Erzeugt und integriert

Die neue durchgehende Guard-Mantelfront ersetzt den fehlerhaften Übergang. Registrierte Verdeckungsmasken entfernen verborgene Hautreste unter Ärmeln. Neue Guard-Handschuhmaster erhalten die bisherigen Handgelenkboxen; exakte Ornamentidentität bleibt offen.

Gemeinsame Masken unterstützen acht Hauttöne, acht Augenfarben, acht Haarfarben, fünf Handschuhmaterialien und acht Kleidungsfarben. Gold, Alpha und neutraler Bandagenstoff bleiben geschützt. Die alte Afro-Grafik wird für Figur und Kachel von eingebrannten Gesichtsteilen getrennt. Es handelt sich nicht um globale CSS-Einfärbung.

Alle 18 bestehenden Frisurauswahlen sind im Labor vertreten, einschließlich Glatze ohne Haar-Layer. Die fünf langen Formen verwenden je einen Atlas mit getrennten Vorder-/Hinterteilen; Farben und beide Frontansicht-Posen teilen dieselben Quellen. Acht Glatzen-Farbkonfigurationen bedeuten keine acht unterschiedlichen Zeichnungen. Alle vier Hosenformen und beide Schuhformen besitzen tatsächliche Quellen und Materialvarianten. Kappe/Stirnband, Hijab, Tanktops und poseabhängige Bandagen sind integriert. Hijab und Kleidung verwenden die acht bestehenden Materialfarben. Die aktuelle vollständige Aufzählung und geprüften Zahlen stehen in der automatisch erzeugten [58-Item-Übersicht](PRODUCTION_PROGRESS.md). Die [Produktionsmatrix](production-coverage.csv) enthält alle sechs Posen, auch nicht unterstützte Fälle. Zwölf vorhandene Auren/Augeneffekte/Szenen verwenden Canvas, keine vorgetäuschten PNGs.

Figur und Kacheln benutzen dieselben Quellen, Varianten und Materialfunktionen. Nicht kompatible Gesamtkonfigurationen fallen vollständig auf SVG zurück. Die Vorschau speichert kein Profil und führt keine Käufe aus.

## Gesperrt und offen

- Shirt: echte Entwurfsquellen vorhanden, Schulter-/Armverdeckung visuell fehlerhaft. Vollständiger SVG-Fallback.
- Basic Cool: zwei Korrekturzeichnungen verbessern die Ärmel, Schulter-/Ellbogenkontur bleibt fehlerhaft. Gesperrt. Basic Guard bleibt Entwurf.
- Die hintere Samurai-Mantelbahn ist eine eigene Mantelquelle, wirkt in kleinen Kacheln aber hosenähnlich. Keine zusätzliche Hose wird eingeblendet; die Faltenlesbarkeit benötigt Art-Abnahme.
- Helle Stoffkontraste, Hautrampen, Kronenidentität und neue Mantelfalten benötigen persönliche Designfreigabe.
- Arm-Master: neun kleine Schulter-/Ellbogenbewegungen geprüft. Gelenknähte, gebackenes Licht und Torsoanschluss offen. Kein fertiges Ganzkörper-Rig, keine weiteren Premium-Posen.
- Keine physische iPhone-/Android-Prüfung und keine reale GPU-Heap-Messung.

Der alte `quality-gates.json` dokumentiert PR #81. `production-quality-gates.json` dokumentiert die neuen Entwürfe und Sperren separat.

## Nachweise und Performance

`tools/premium-v2/production.html` ist das isolierte Labor. Reale Vorher-/Nachher-Bilder und Kontaktbögen liegen in `docs/premium-v2/evidence/`, familienbezogene Nachweise in den jeweiligen Unterordnern. Prompts, Originalquellen, PNG-Hashes und Registrierung bleiben im Branch nachvollziehbar.

Technischer Status folgt vorhandenen transparenten Grafiken, passenden Quellenhashes und bestandenen Chromium-/WebKit-Berichten. Text-Hashes normalisieren CRLF zu LF; PNG-Hashes bleiben bytegenau. Veränderte Quellen ohne passenden Nachweis werden nicht als technisch geprüft ausgegeben. Varianten-/Pose-Zellen zählen keine kartesischen Komplett-Outfits.

Der verlustfreie Vergleich mit unveränderter PR-81-Kunst reduziert den Sammelatlas von 2.024.127 auf 1.267.216 Bildbytes und von 10,63 auf 4,83 MiB dekodiertes RGBA. Maximal drei parallele Bildanfragen, Deduplizierung und begrenzte LRU-Caches. WebKit kann wegen zusätzlicher Gruppen beim Kaltladen langsamer sein. Neue Produktionskunst wird separat im aktuellen Browserbericht gemessen; Materialien und Canvas-Effekte kosten zusätzliche Wechselzeit. Keine pauschale 60-FPS- oder GPU-Speicherbehauptung.

## Nächster konkreter Produktionsauftrag

1. Shirt und Basic Cool anhand gespeicherter Körper-/Maskenansichten korrigieren. Erst nach sauberer Schulterkontur und Armverdeckung freischalten; anschließend Kachelparität und beide Browser erneut prüfen.
2. Die vorhandenen langen Haarformen für zusätzliche Mantel-/Kopf-Kombinationen freistellen und prüfen. Aktuell nur ohne Mantel, Kopfbedeckung und Kapuze; Hijab zusätzlich ohne Oberteil. Kappe ist auf Kurz glatt, Stirnband auf Kurz glatt/Afro beschränkt. Keine ungeprüfte Erweiterung des Resolvers.
3. Hoodie/Jacke sowie Neon/Drache mit eigenen Materialien und Ärmeln produzieren. Kapuzenzustände separat abdecken; keine Samurai-Grafik als Ersatz ausgeben.
4. Erst nach Gelenk-/Lichtkorrekturen einen begrenzten Flex-Pilot aufbauen. Kopf, Haare, Unterkörper und Materialien weiterverwenden; poseabhängige Arme/Kleidung gezielt neu zeichnen.

Künstlerische Abnahme und reale Mobilgeräteprüfung bleiben Voraussetzung einer späteren Aktivierung. Kein Merge, kein Deployment.
