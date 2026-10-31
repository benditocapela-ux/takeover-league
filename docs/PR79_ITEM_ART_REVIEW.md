# PR79: Kragen, Schultern und originalgetreue Item-Vorschauen

Ausgangs-Head: `77e77b85a608863bc42e91fc2fff064368c4d8f7`.
PR79 bleibt Draft; PR80 bleibt unverändert. Kein Merge oder Deployment.
Beide Grafikmanifeste bleiben `approved:false`, `enabled:false`.

## Änderung

Der obere Bereich von `modular-cool/coatfront.png` passt den Kragen an die
Halsbasis und den Schulterverlauf an. Keine globale Verschiebung per CSS.
Die registrierte 768×1216-Leinwand und die Ebenenreihenfolge bleiben bestehen.
`coatback.png`, Körperbasis, beide Handschuhe und deren anatomische Anker sind
unverändert. Ab Zeile 310 sind sämtliche dekodierten RGBA-Pixel des vorderen
Mantels identisch zum Ausgangs-Head (0 geänderte Kanäle). Der SHA-256 dieses
Bereichs, zeilenweise RGBA, lautet
`51bd467d437981de93b74bbe74e3ee46436e4e5517dbc82072d90f88e3016e65`.

Die lokal begrenzte Korrektur wurde mit dem eingebauten Imagegen-Werkzeug
erstellt. Eingaben waren die vordere Mantel-Ebene als Bearbeitungsziel sowie
Körperbasis und Originalkomposit als Passform-/Stilreferenzen. Der Entwurf wurde
mit Faktor 0,63 und Ursprung (72,114) registriert, nur oberhalb Zeile 310
übernommen und zwischen Zeilen 270 und 310 eingeblendet. Registrierung,
Quellhash und Dateiinventar dokumentieren die Änderung. Dies ist keine
Behauptung einer persönlichen Grafikfreigabe oder eines pixelidentischen
Nachbaus der ursprünglichen Gesamtvorlage.

## Gemeinsame Quelle für Figur und Kacheln

Die Item-Auswahl fragt dieselbe vollständige Outfit-Auflösung wie die Figur
ab, mit der **Konfiguration nach Auswahl** und der aktuellen Profil-/Kartenpose.
Anime wird erst nach erfolgreichem gemeinsamen Preload gezeigt. Eine nicht
unterstützte Pose, Farbe, Bekleidung oder ein Bildfehler bewirkt die passende
SVG-Vorschau. Auch eine Auswahl, die ein bislang nicht unterstütztes Outfit
wieder kompatibel macht, wird korrekt erkannt.

Anime-Miniaturen verwenden direkt die ausgewählten registrierten Dateien.
Der Mantel kombiniert Rück- und Vorderseite; die anderen Kacheln enthalten
nur ihre jeweilige Ebene. Ausschnitte sind im modularen Manifest definiert.
Keine separaten Miniaturbilder, Ganzkörper-Screenshots, neuen Item-Schlüssel
oder zusätzlichen Bildquellen. Breite und hohe Ausschnitte werden proportional
eingepasst. Die zwölf vorhandenen Dateien teilen sich den gecachten Loader
mit maximal drei gleichzeitigen Preloads.

Die Beschriftungen **Anime** und **SVG** stehen an den Item-Kacheln und werden
auch als zugängliche Beschreibung ausgegeben. Entfernen-Schaltflächen wie
„Ohne“ haben kein Ausrüstungsbild und erhalten keine Renderer-Kennzeichnung.
Asynchrones Aktualisieren erhält Fokus und Scrollposition. Der normale Editor
ohne `?art=modular` bleibt SVG und lädt keine modularen PNGs.

## Prüfung und Abnahme

`tests/boxer-modular-art-browser.cjs` prüft in Chromium und WebKit jeweils 32
Outfitkombinationen sowie 16 gezielte Handschuhansichten. Ergänzte Prüfungen
vergleichen Item-Dateien mit den tatsächlich ausgerüsteten Hero-Ebenen,
prüfen proportionale Ausschnitte, vorausschauende Anime-/SVG-Kennzeichnung,
Bildfehler und den Erhalt des Tastaturfokus. Die bestehenden Handgelenk-,
Handflächen- und Unterarm-Pixelprüfungen bleiben unverändert.

Zusätzlich: Artpack-/Editor-Verträge, Preload-Limit, Charakterarchitektur,
isolierter Pages-Dateiumfang, Boxer-Holo-Integration und die sechs Posen mit
unabhängiger Profil-/Kartenpose. Browser-Automation ersetzt keine Prüfung auf
einem physischen iPhone/Android und keine persönliche Designabnahme.

Manuell im lokalen Entwurf `mein-boxer.html?art=modular&tab=kleidung` prüfen:

1. Cool-Pose, Hautton 7, schwarze Afro-/Kurzhaarfrisur, braune Augen,
   keine Kopfbedeckung/Effekte, schwarze Boxstiefel und Boxershorts in Schwarz
   oder Rot wählen. Oberteil: Ohne oder schwarzes Tanktop.
2. Samurai-Jacke wählen: Kragen/Schultern ansehen; Kachel muss denselben
   schwarz-goldenen Mantel mit „Anime“ zeigen.
3. Schwarz-Gold/Weiss wechseln: Kachel und Figur müssen dieselben Handschuhe
   zeigen, ohne Positionssprung oder verdeckten Unterarm.
4. T-Shirt wählen: Figur und Mantelkachel wechseln zu SVG. Tanktop zurückwählen:
   Anime-Darstellung kehrt zurück. Eine andere Pose muss ebenfalls auf SVG fallen.
5. Unter Körper die beiden unterstützten Frisuren wechseln und die Kacheln
   vergleichen. Andere Frisuren bleiben SVG.

Das bisherige ZIP `docs/review/PR79-Abnahme.zip` bleibt unverändert und zeigt
den **historischen** Stand vor dieser Korrektur. Es ist kein Abnahmebeleg für
die hier beschriebenen neuen Item-Kacheln oder den neuen Kragen.
