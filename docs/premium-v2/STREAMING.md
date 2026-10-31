# Bedarfsgerechte Grafikgruppen – isolierter Entwurf

`streaming-assets.json` und `streaming-assets/` exportieren die 21 Komponenten
des unveränderten PR-81-Piloten in 15 bedarfsgerechte Gruppen. Es sind keine
neuen Illustrationen. Leere transparente Außenränder werden verlustfrei entfernt,
die Zielregistrierung wird um exakt denselben ganzzahligen Abstand angepasst.
Keine Skalierung, keine Farbänderung, kein Überschreiben der Cool-Originale.

Die Gruppen bestehen aus Basis (Kopf, Beine, Schuhe, Augen), je einem Körper
pro Pose, gemeinsamen Mantelteilen, posebezogener Mantelfront und separat
ladbaren Haar-, Hosen-, Tanktop- und Handschuhvarianten. Der nicht im bisherigen
Guard-Resolver unterstützte Tanktop-Export gilt dadurch nicht als Guard-kompatibel.
Jede Datei hat Abmessungen, Bytezahl und SHA-256 im Manifest; der Quellmanifest-Hash
verhindert eine Verwechslung mit später korrigierten Zeichnungen.

## Gemessene Referenz

Outfit unverändert: Guard, Samurai, Schwarz-Gold, Afro, schwarze Shorts.
Ergebnisse aus `tests/premium-v2-streaming.cjs`, Chromium und WebKit auf dem
lokalen Windows-Rechner. Bilddaten ohne HTTP-Header; dekodierte RGBA-Fläche ist
kein gemessener GPU-/Heap-Spitzenwert.

| Kennzahl | Volle PNGs | PR-81-Sammelatlanten | Neue Gruppen |
|---|---:|---:|---:|
| Erste Bilddaten | 1.513.231 Byte | 2.024.127 Byte | 1.267.216 Byte |
| Bildanfragen | 8 | 2 | 7 |
| Dekodierte RGBA-Rechteckfläche | 29.884.416 Byte | 11.149.312 Byte | 5.065.048 Byte |
| Dekodiert in MiB | 28,5 | 10,6 | 4,83 |

Damit sinken die Bilddaten gegenüber vollständigen PNGs um 16,3 %, gegenüber
dem Sammelatlas um 37,4 %. Die dekodierte Fläche sinkt gegenüber dem Sammelatlas
um 54,6 %. Dafür steigt die Anzahl der Anfragen von zwei auf sieben.
Eine universelle Latenzverbesserung wird nicht behauptet.

Messmethode bleibt gleich: drei neue Browserkontexte pro Modus, identischer
Start vor Bildladen/Dekodieren/erstem Zeichnen; beim warmen Cool/Guard-Wechsel
110 Iterationen, zehn Aufwärmzyklen verworfen, ein Pixel-Readback pro Iteration.
Die neuen Gruppen verwenden maximal drei parallele Anfragen. V1 und der alte
Atlas verwenden ihren unveränderten alten Loader; dessen serielle Planung ist
Teil dieses Systemvergleichs, kein isolierter Kompressionsbenchmark.

| Lokaler Lauf | Volle PNGs | PR-81-Atlas | Gruppen |
|---|---:|---:|---:|
| Chromium kalt, Median | 113,4 ms | 60,0 ms | 36,2 ms |
| WebKit kalt, Median | 157,0 ms | 80,0 ms | 99,0 ms |
| Chromium warm P50/P95 | 3,1/5,2 ms | 1,3/2,5 ms | 0,8/2,3 ms |
| WebKit warm P50/P95 | 4/5 ms | 2/3 ms | 1/2 ms |

WebKit lädt die sieben Gruppen in diesem Lauf langsamer als den alten Zweieratlas,
obwohl weniger Bytes übertragen werden. Mobilfunk und physische Geräte bleiben
separat zu prüfen. Wiederholungen schwanken mit Systemlast; JSON-Berichte enthalten
alle Einzelmessungen. Neue Art- oder Materialgruppen müssen erneut gemessen werden.

## Laufzeitvertrag

`window.TLPremiumV2Streaming` ist ausschließlich ein Laborbaustein. `approved`
und `enabled` bleiben `false`. Der bestehende Editor importiert dieses Modul nicht.

```js
const loader = TLPremiumV2Streaming.createLoader();
const selected = TLPremiumV2Pilot.resolve(config, pilotAssets);
const result = await TLPremiumV2Streaming.prepareOrFallback(selected, splitAssets, loader);
if (result.renderer === 'svg') {
  // Aufrufer zeichnet die vollständige bestehende SVG-Figur; keinen Teilmix anzeigen.
} else {
  TLPremiumV2Streaming.draw(context, result.selection, result.images);
  TLPremiumV2Streaming.draw(itemContext, result.selection, result.images, 'hands');
}
```

`resolve(selection, manifest)` erhält eine bereits vollständig geprüfte
Konfiguration in Form von `selection.ids`. Es ersetzt keinen Outfit-Kompatibilitäts-
Resolver. Fehlende IDs liefern `null`. Die resultierenden Komponenten haben
`id`, `slot`, `src`, `uv`, `box` und Herkunft; `selection.canvas` ist `[768,1216]`.
Für neue Grafikquellen kann der Labor-Resolver passende Komponenten mit derselben
Struktur einsetzen. Figur und Itemkachel müssen dieselbe aufgelöste Liste verwenden.

`loader.get(src)` bzw. `loader.load(src)` lädt eine einzelne Quelle. `prepare`
dedupliziert alle `src` einer Auswahl. Eine globale Queue begrenzt alle Instanzen
dieses Moduls zusammen auf drei aktive Bildanfragen inklusive Decode. Gleichzeitige
Aufrufe derselben Instanz teilen laufende Promises. Das LRU hält standardmäßig
höchstens 16 dekodierte Bilder und 12 MiB RGBA; konfigurierbare Obergrenzen sind
64 Einträge und 32 MiB. Größere Einzelbilder werden geliefert, aber nicht gehalten.
`clear()` entfernt gespeicherte Einträge; `stats()` liefert Zähler und Budgets.

Fehlgeschlagene Promises werden entfernt und sind erneut ladbar. Ein Timeout
von standardmäßig 15 Sekunden gibt blockierte Slots frei. Fremde Origins werden
abgewiesen. `draw` prüft das vollständige Bildset vor dem ersten Zeichenbefehl,
damit ein Ladefehler keine halbe Figur hinterlässt. Der Aufrufer muss bei Fehlern
den vollständigen SVG-Fallback tatsächlich darstellen und veraltete UI-Antworten
ignorieren. `prepareOrFallback` liefert dazu ein explizites Ergebnis.

Cachebudget bedeutet nur im Loader gehaltene Referenzen: bereits an Aufrufer
zurückgegebene Bilder, HTTP-Browsercache und GPU-Kopien werden nicht dadurch
freigegeben. Ein begrenzter Präsentations-/Materialcache ist zusätzlich erforderlich.
Verschiedene Loaderinstanzen haben getrennte LRU-Caches; eine gemeinsame Instanz
pro Labor ist empfohlen, damit Requests auch instanzübergreifend dedupliziert sind.

## Prüfung und Reproduktion

```text
CANVAS_MODULE=<bestehende @napi-rs/canvas Installation> node scripts/build-premium-v2-streaming.cjs
SHOTS=<Artefaktverzeichnis> node tests/premium-v2-streaming.cjs
```

Bestanden in Chromium und WebKit: 32 Cool-/Guard-Outfits und fünf Item-Slots
mit **maximaler RGBA-Abweichung 0** zum alten Atlasrenderer; Hashes, unveränderte
Registrierung ohne Skalierung und Atlasränder; serverseitig maximal drei aktive
Requests und genau sieben statt 21 Downloads bei drei gleichzeitigen Prepares;
LRU-Budget/Eviction; fehlerhafte und fehlende Grafik → vollständiger Fallback-
Status; erneutes Laden derselben URL nach 404; keine externen Verbindungen oder
JavaScript-Fehler. Alle technischen Tests lassen die künstlerischen Gates unberührt.
