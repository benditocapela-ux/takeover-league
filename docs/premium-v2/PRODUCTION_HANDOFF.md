# Autonome Premium-Produktion

Arbeitsbasis PR #81 `02414c9`, eigener Branch `art/premium-v2-catalog-production-20261031`, Draft PR #82. Die bisherigen PRs, Cool-Originale, Editor, Katalog und Datenbank bleiben unverändert. Alle `approved`/`enabled`-Flags bleiben aus.

## Erstes Art-/Materialpaket

Neue registrierte PNG-Master: durchgehende Guard-Mantelfront, Guard-Handschuhpaar, Stachel/Undercut/Buzz, Kurz/Jogger/Track und Sneaker. Körper, Augen, Haare und getrennt maskierte Leder-/Stoffflächen besitzen wiederverwendbare Materialvarianten. Gold und Alpha werden nicht global mitgefärbt. Die alte Afro-Grafik wird im Labor von eingebrannten Gesichtsteilen getrennt. Masken und Figur-/Kachelausgabe verwenden dieselben Quellen.

Kappe und Stirnband haben eigene eingeschränkte Haar-Kompatibilität. Ein separater Arm-Master testet neun kleine Schulter-/Ellbogenbewegungen. Das ist kein freigegebenes Ganzkörper-Rig.

Die neue Mantelfront ersetzt die fehlerhafte Überblendung. Explizite Verdeckungsmasken entfernen Hautreste unter Guard-Ärmeln. Die Krone ist verbessert, aber die exakte Ornamentidentität und neue Mantelfalten bleiben künstlerisch offen. Der Track-Hosenumfang und helle Stoffkontraste sind gezielte Sichtprüfpunkte des nächsten Passes.

## Nachweise und Bedienung

- `tools/premium-v2/production.html`: isoliertes Labor mit echtem vollständigem SVG-Fallback, Materialauswahl, Figur und identischen Item-Kacheln.
- [Automatische Übersicht aller 58 Items](PRODUCTION_PROGRESS.md), [vollständige Produktionsmatrix](production-coverage.csv).
- [Material-Master](MATERIALS.md), [Ladepipeline](STREAMING.md), [Arm-Prototyp](RIG.md), [Kopfbedeckungen](HEADWEAR.md).
- Neue Bildquellen und exakte integrierte Imagegen-Prompts: `tools/premium-v2/production-art/provenance.json`; Registrierung/Hashes: `manifest.json` daneben. Projektdateien bleiben lokal und im Arbeitsbranch reproduzierbar.

Technischer Status wird nur aus tatsächlich vorhandenen Dateien, passenden Hashes und Chromium-/WebKit-Berichten abgeleitet. Texthashes normalisieren CRLF zu LF; PNG-Hashes bleiben bytegenau. Künstlerische Freigabe bleibt aus. Die Browserautomation ersetzt keine persönliche Abnahme auf physischen Geräten.

Der verlustfreie Streaming-Vergleich nutzt unveränderte PR-81-Grafiken: 1.267.216 Byte / 4,83 MiB dekodiert statt 2.024.127 Byte / 10,6 MiB beim Sammelatlas. Maximal drei parallele Bildanfragen, begrenzter LRU-Cache. WebKit war bei der ersten Ladung mit mehr Gruppen langsamer; die Bilddatenersparnis ist keine pauschale Latenzgarantie. Das Produktionslabor mit neuen Grafiken wird gesondert gemessen.
