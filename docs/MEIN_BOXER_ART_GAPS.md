# Premium-Character-Art: Lieferumfang und offene Zeichnungen

Stand: 30. Oktober 2026. Technische Dateiannahme und künstlerische Freigabe sind getrennt. `approved:false` und `enabled:false` bleiben bestehen.

## Verifiziertes Ausgangspaket

Die acht Original-PNGs in `assets/boxer-artpacks/v1/cool/` sind zusammen 812800 Bytes gross. `node tests/boxer-original-art-readiness.cjs` prüft alle acht SHA-256-Hashes; `node scripts/validate-boxer-artpack.cjs` prüft Abmessungen, Transparenzkennzeichen und Grössenbudget. Diese Prüfungen beweisen keine vollständige verdeckte Anatomie.

Die Masken rekonstruieren genau die Cool-Pose: Haut 6, Afro/schwarz, braune Augen, kein zusätzliches Oberteil oder Headwear, Samurai-Mantel, Boxer/schwarz, Boots/schwarz und Bandagen. Aura und Augen-Effekte müssen `none`, die Szene `holo` oder `none` sein. Die Stilreferenz bleibt der dunkle Anime-Boxer mit navy-/goldenem langem Mantel und verschränkten Armen.

Diese Kombination ist in `configurations.cool` deklarativ eingeschränkt. Der Premium-Renderer prüft diese Einschränkungen vor dem Laden. Insbesondere fällt `coat:none` vollständig auf SVG zurück, anstatt die ausgeschnittenen Körperfragmente als vollständigen Körper auszugeben. Das lokale Ebenen-Prüfwerkzeug darf Masken zur Inspektion ausblenden; das ist kein Nachweis eines funktionierenden Outfit-Wechsels.

## Zeichnungsauftrag und Abhängigkeiten

Alle Exporte verwenden dieselbe transparente Leinwand **768 × 1216 px**, Ursprung links oben `(0,0)`, x nach rechts, y nach unten. Keine automatisch beschnittenen Einzeldateien, keine unabhängigen Zentrierungen oder Skalierungen. Die Originalmasken sind die Registrierungsreferenz. Exakte anatomische Gelenkpunkte müssen aus der Illustration abgenommen werden; sie sind nicht durch das SVG-Koordinatensystem definiert. Pro Datei höchstens 2 MiB, pro vollständig sichtbarem Outfit höchstens 6 MiB.

| Z | Ebene / bestehender Schlüssel | Fehlende Arbeit / Abhängigkeit |
|---|---|---|
| 1 | `coatBack.samurai` | Original vorhanden. Andere Mäntel benötigen neu gezeichnete Rückseiten passend zu derselben Pose und zu ihrer Vorderseite. |
| 2 | `body.6` | Original zeigt nur sichtbare Fragmente. Rumpf, Schulter-/Oberarmpartien unter dem Mantel und die von verschränkten Armen verdeckten Übergänge müssen anatomisch vollständig gezeichnet werden; bei kurzen Hosen oder anderen Schuhen zusätzlich freigelegte Bein-/Knöchelpartien. Keine Streckung vorhandener Pixel. Für Hauttöne 0–5 und 7 fehlen passende Varianten. |
| 3 | `bottom.boxer/schwarz` | Original vorhanden. Andere Hosenformen und Farben benötigen eigene Zeichnungen; Bund muss mit Körper, Oberteil und Mantel überlappen, Saum mit Beinen/Schuhen. |
| 4 | `feet.boots/schwarz` | Original vorhanden. Andere Schuhformen und Farben fehlen. Übergänge zu Bein, Hosensaum und Standfläche müssen in der Cool-Pose deckungsgleich sein. |
| 5 | `top` | Keine unabhängigen Oberteil-Dateien vorhanden. Tank, Shirt, Hoodie (Kapuze oben/unten) und Jacke benötigen Rumpf plus posengerechte Ärmel, mit korrekter Verdeckung durch verschränkte Arme. Falls eine einzige Ebene diese Verdeckung nicht korrekt abbildet, zuerst separate Vorder-/Hinterarm-Ebenen spezifizieren und den Renderer erweitern; nicht einfach falsche Überlagerungen liefern. |
| 6 | `eyes.braun` | Original vorhanden. Andere Augenfarben benötigen passende Pixelvarianten auf derselben Gesichtsbasis. Spezialeffekte sind bislang nur im SVG unterstützt. |
| 7 | `hair.afro/schwarz` | Original vorhanden. Weitere Frisuren/Farben fehlen; vollständiger Schädel und Ohren müssen für freigelegte Bereiche vorhanden sein. Langes Haar kann zusätzliche hintere Haar-Ebenen benötigen, bevor es korrekt integrierbar ist. |
| 8 | `head` | Keine unabhängigen Cap-/Headband-/Hijab-Dateien vorhanden. Haarverdeckung, Stirn, Ohren und Hoodie-Kollisionen sind pro Kombination visuell abzunehmen. |
| 9 | `coatFront.samurai` | Original vorhanden. Andere Mäntel benötigen Vorderseite und Ärmel, zusammen mit `coatBack` sowie Körper/Armen gezeichnet. Der Originalmantel darf erst bei vollständiger Unterzeichnung entfernbar werden. |
| 10 | `hands.wraps` | Original vorhanden. Unabhängige Handschuhvarianten benötigen neue Zeichnungen mit denselben Handgelenken und verschränkter Armhaltung. Verdeckte Hand-/Unterarmpartien sind nicht aus Masken rekonstruierbar. |

Andere Posen benötigen jeweils einen eigenen deckungsgleichen Satz. Dateien der Cool-Pose dürfen nicht auf Guard-/Kartenposen verzerrt werden. Vorhandene V0/V1/V2-Unterzeichnungen sind nicht freigegebene Studien, keine finalen Ersatzgrafiken.

## Technische Lieferannahme

1. Eine vollständig unterzeichnete Cool-Figur und ein unabhängig wechselbares Musteroutfit liefern; Registrierungsreferenz und Ebenenreihenfolge beibehalten.
2. Varianten unter relativen kleingeschriebenen `.png`-/`.webp`-Pfaden eintragen. Schema und Varianten-Schlüssel stehen in `MEIN_BOXER_ARTPACK_PIPELINE.md` und `takeover-holo.js`. Kein Einfärben gemalter Originale als Ersatz für gezeichnete Varianten.
3. Für eingeschränkte Pakete `configurations` mit einem Eintrag je Pose führen. Fehlende Pose-Einschränkung fällt sicher auf SVG zurück. Erst nach künstlerisch belegter Unabhängigkeit die entsprechenden Einschränkungen lockern; generische vollständige Pakete dürfen das optionale Feld weglassen.
4. Validator, Varianten-/Fallback-Verträge und Browserprüfung mit echten Bildern ausführen. Outfitwechsel müssen die ausgewählten Artikel zeigen, ohne Löcher, Körperduplikate, falsche Ärmel oder veränderte Standposition.
5. Original-Screenshot `holo-original-8-repository-art.png` sowie mobile und Desktop-Ansichten durch den Auftraggeber abnehmen lassen. Erst eine gesonderte Freigabe erlaubt Änderungen der Grafikschalter.

**Status:** Originalrekonstruktion technisch vorhanden; unabhängige Premium-Garderobe und künstlerische Abnahme offen. Der bestehende SVG-Renderer bleibt für alle nicht vollständig unterstützten Varianten zuständig.
