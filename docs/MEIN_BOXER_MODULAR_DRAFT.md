# Modularer Cool-Entwurf – zwölf registrierte PNGs

Stand: 30. Oktober 2026. Dieser Entwurf ergänzt die acht unveränderten Originalmasken. Er ist ausschließlich unter `mein-boxer.html?art=modular` erreichbar. Beide Manifeste behalten `approved:false` und `enabled:false`; PR #79 bleibt Draft.

## Lieferumfang

Alle zwölf Dateien unter `assets/boxer-artpacks/v1/modular-cool/` besitzen dieselbe transparente Leinwand von 768 × 1216 Pixeln:

- `body.png`: neue V4-Körperbasis, kahler Kopf, vollständiger Körper mit gekreuzten Armen, Unterhose und nackten Füßen.
- `eyes.png`, `feet.png`: braune Augen und schwarze/goldene Stiefel.
- `hair-afro.png`, `hair-short.png`: vorhandene Afrozeichnung und neu gezeichneter Kurzhaarschnitt.
- `bottom-black.png`, `bottom-red.png`: vollständige TAKEOVER-Shorts inklusive seitlicher Stoffflächen.
- `hands-blackgold.png`, `hands-white.png`: zwei Handschuhvarianten für die gekreuzten Arme.
- `coatback.png`, `coatfront.png`: hinterer Mantel und Vorderseite mit Ärmeln.
- `top-tank.png`: schwarzes Tanktop mit transparentem Ausschnitt für die davorliegenden Arme.

Elf Dateien stammen aus neuen Imagegen-Zeichnungen einschließlich der bereits vorhandenen V4-Studie. Die Afrozeichnung stammt unverändert aus `cool/hair.png`. Für die Registrierung wurden die vollständigen Zeichnungen ausschließlich proportional skaliert und verschoben. Es gibt keine Laufzeitverzerrung, kein CSS-Recoloring und keine Rekonstruktion verdeckter Haut aus den alten Masken. Die Farbvarianten wurden als eigene Bilder erzeugt. `registration.json` dokumentiert Quelle, Skalierung und Versatz; `inventory.json` dokumentiert die finalen Hashes und Größen.

## Unterstützte Kombinationen

32 Kombinationen: Mantel aus/Samurai × Oberteil aus/Tank × Shorts schwarz/rot × Afro/Kurzhaar × Handschuhe schwarzgold/weiß. Feste Grundlage: Cool-Pose, Haut 6, braune Augen, schwarze Haare, schwarze Boots, kein Headwear, keine Aura oder Augeneffekte. Nicht unterstützte Auswahlen verwenden den vollständigen SVG-Renderer.

Die Ebenenreihenfolge lautet Mantel hinten → Körper → Shorts → Stiefel → Tank → Augen → Haare → Mantel vorne → Handschuhe. Beim Wechsel lädt der Renderer alle benötigten Bilder, bevor er das gesamte Outfit einblendet. Während des Ladens oder bei einem fehlenden Bild erscheint die vollständige SVG-Figur. Der Hinweis „Entwurf – nicht freigegeben“ bleibt sichtbar. Die Vorschau verändert weder gespeicherte Konfigurationen noch Besitz oder Kontostand.

## Prüfung und Grenzen

Lokal bestanden: Chromium 32/32 und WebKit 32/32, jeweils zusätzlich Desktop 1440×900, atomarer Ladewechsel und fehlende PNG-Datei. Die vier vergrößerten Outfitbögen (alle 32 Varianten) und Browseransichten wurden visuell gesichtet. Der Draft-Hinweis verdeckt Haare/Augen nicht. Die Prüfung fand und behob einen Desktop-Container mit null Breite sowie einen mobilen Höhensprung durch den langen Verwerfen-Button. Die neun Mein-Boxer-Vertrags-/Preloadprüfungen und die bestehende responsive Editor-Matrix sind erfolgreich. Zwölf PNGs: zusammen 2.140.836 Bytes, größte Datei 530.922 Bytes; konservatives größtes Outfit 1.816.704 Bytes.

`node tests/boxer-modular-art-browser.cjs` prüft alle 32 Kombinationen mit tatsächlichen Repository-PNGs in Chromium und WebKit: Layerauswahl, gemeinsame Leinwand, mobile Bühnenstabilität, fehlenden Seitenüberlauf, Draftkennzeichnung, unveränderten Standardmodus, atomaren Wechsel und 404-Fallback. `SHOTS` speichert die Browseransichten für die visuelle Prüfung. Die beiden modularen Vertragstests prüfen außerdem Gating, Konfigurationsgrenzen, Request-Deduplizierung und Fehlerzustände.

Der Satz ist ein funktionsfähiger, begrenzter Artwork-Entwurf, keine Freigabe der gesamten Garderobe. Die neue Anatomie und das Gesicht unterscheiden sich von der Originalrekonstruktion; die Datei `hair-short.png` zeigt einen kurzen strukturierten Schnitt. Andere Hauttöne, Posen, Frisuren, Kleidungsformen und Ausrüstungskacheln sind damit nicht neu gezeichnet. Ein physisches iPhone wurde nicht getestet. Die persönliche künstlerische Abnahme bleibt offen; kein Merge, Deployment oder Aktivieren der Grafikflags ist Bestandteil dieses Schritts.
