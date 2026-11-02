# Grafik- und Mobile-Audit – tatsächlicher Stand

## Geprüft

- Basis c7fbd9f: veröffentlichter statischer Build mit simulierten Kontodaten, Chromium und WebKit.
- Browser-Test anime-everywhere-browser: Heute, eingeloggtes Podium (Guard und Jab) und FUT-Card verwenden die Anime-Pipeline. Beide Engines bestanden.
- Echte Vorher-Bilder des Podiums bei 320, 360, 390, 430 und 1000 CSS-Pixeln liegen außerhalb des Veröffentlichungsbaums unter outputs/seven-hour/graphics/{chromium,webkit}-podium-before-{Breite}.png.
- Öffentliche Rangliste nutzt freigegebene öffentliche Avatare. get_holo_looks ist laut separat geprüftem Produktionsvertrag nicht anonym ausführbar. Keine Berechtigung erweitert und kein öffentlicher Holo-Aufruf ergänzt.
- Index nutzt jetzt den gemeinsamen takeover-client.js-Wrapper. Mein-Boxer, Shop und Boxer-Experience haben keine direkten Supabase-CDN-Imports; Boxer-Experience nutzt TLPerf.client.

## Nachgewiesene offene Probleme

1. Eingeloggtes Podium ist bei kleinen Geräten nur 225–246 px hoch, Figuren etwa 126–145 px; deutlich kleiner als die gewünschte Referenz.
2. renderPodium beschriftet die visuelle Slot-Reihenfolge 2–1–3 statt des serverseitigen rank_position. Gleichstände und Nullpunkt-Ränge sind daher nicht korrekt dargestellt.
3. Öffentliche Rangliste bezeichnet den aktuellen Zwischenstand als „Champion des Monats“; der Monatsabschluss ist dafür nicht nachgewiesen.
4. Editor-Pose- und Bundle-Kacheln rufen H.svg direkt auf, während normale Item-Kacheln den Premium-Adapter verwenden. Eine gemeinsame Preview-API benötigt einen eigenen begrenzten Cache, da der aktuelle Hero-Cache nur vier Einträge hält.
5. Flex-Shirt: Die aus Guard übernommene Torso-Maske enthält möglicherweise alte Schulterkappen zusätzlich zu den neuen retargeteten Ärmeln. Dies ist eine begründete Ursache, noch keine abgeschlossene Grafikdiagnose oder Korrektur.
6. Editor wartet ohne Timeout auf TLPerf/TLHolo; ein fehlgeschlagenes Modul kann dauerhaft blockieren.

## Nicht abgeschlossen

Das Sieben-Stunden-Zeitfenster war bei der Implementationsphase bereits überschritten. Ein noch ungeprüfter gemeinsamer Podium-Prototyp wurde deshalb vollständig aus dem Repository zurückgenommen. Die Quellskizze wurde nur außerhalb des Veröffentlichungsbaums in outputs/seven-hour/graphics/unverified-podium-prototype aufbewahrt. Es gibt keine verifizierten Nachher-Bilder und keine abgeschlossene Premium-/Editor-/Shop-Änderung in diesem Paket. Keine Aussagen über 100-/200-%-Grafikabnahme oder gesamte Website-Mobile-Abnahme.

## Nächster konkreter Auftrag

Zuerst gemeinsamen Podium-Renderer mit tatsächlichen Rängen, Nullpunkt-/Gleichstand-/Unter-drei-Zuständen und dynamischen Namen bauen. Öffentliche Avatare bleiben öffentlich; private Looks nur im berechtigten Kontext. Danach 320/360/390/430 und Desktop in Chromium/WebKit einschließlich langer Namen und fehlender Looks prüfen. Anschließend separate begrenzte Premium-Preview-API für Pose-/Bundle-Kacheln und gezielte Torso-/Ärmel-Maskenkorrektur für Flex mit echten 100-/200-%-Vergleichen.

Keine Grafik neu generiert. Keine Produktionsänderung, kein Merge oder Deployment.
