# Gezielte visuelle Nachweise

Echte Chromium-Aufnahmen mit synthetischen Konten/RPC-Antworten und tatsächlichen Artwork-Dateien. Kein Produktionskonto und keine physische Geräteabnahme. Die zugehörigen WebKit-Läufe und weiteren Breiten sind in den Testberichten dokumentiert.

| Bereich | Vorher | Nachher / überprüfter Stand |
| --- | --- | --- |
| Podium bei 390 px | [Vorher](chromium-podium-before-390.png) | [Grössere Figuren, 2–1–3](chromium-podium-after-390.png) |
| Posen / Bundle | Alte allgemeine SVG-Vorschauen | [Posen](chromium-editor-premium-poses.png), [Bundle](chromium-editor-premium-bundle.png); pixelgleich zum Compositor geprüft |
| Trainerabschluss | Alte Vorschau konnte unmittelbar buchen | [Begrenzte Warteschlange](duel-queue-mobile.png), [ausdrücklicher Periodenabschluss](period-close-mobile.png) |
| Archiv | Global gemischte Saisonränge | [Ausgewählter Monatsrückblick](archive-month-mobile.png) |
| Flex-Shirt-Anatomie | [100 %](flex-shirt-before-100.png), [200 %](flex-shirt-before-200.png) | **Noch nicht korrigiert.** [Isolierter Torso bei 200 %](flex-shirt-torso-200.png) zeigt: Die falschen Schulterpolster kommen aus der separaten Ärmelkomponente. |

Die vorgeschlagenen Ärmelversuche wurden nicht übernommen. Es gibt dafür kein freigegebenes Nachher-Bild. Namen, Punkte und Platzierungen auf den Podien werden aus Daten gerendert und sind nicht ins Artwork eingebrannt.

Weitere echte Chromium-Aufnahmen: [Metrischer Abschluss ohne Prämie](metric-close-mobile.png), [gefilterte Trainingshistorie mit vollständigen Gesamtzahlen](studio-history-mobile.png). Synthetische Testdaten, keine Produktionsauszahlung.

Fortsetzung: [bestätigter Shop-Kauf trotz ausgefallener Katalognachlese](shop-confirmed-offline.png). Der bestätigte Besitz bleibt sichtbar; statt erneutem Kauf wird Ausrüsten angeboten. Tatsächliche Chromium-Aufnahme mit synthetischem Kaufbeleg, kein echter Kauf. Der entsprechende WebKit- und Fehlerablauf ist im [Shop-Audit](../shop-audit.md) dokumentiert.
