# Grafik- und Mobile-Audit – Fortsetzung nach ausdrücklichem Weiterauftrag

## Abgeschlossen: gemeinsames grösseres Liga-Podium

- Öffentliche Rangliste und Mein Takeover verwenden denselben Renderer und dieselbe Arena-Gestaltung. Namen, Punktzahlen und Rang stammen aus der bestehenden Ranglistenquelle.
- Platzierung bleibt optisch 2–1–3. Beschriftung und Sockelhöhe folgen dem tatsächlichen Rang: Gleichstände bleiben gleichrangig, Nullpunkte erhalten keine Krone oder erfundene Wertung. Fehlende Plätze, leere Rangliste und lange Namen sind abgedeckt.
- Laufender Monat wird als Zwischenstand gekennzeichnet. Die irreführende zusätzliche „Champion des Monats“-Karte ist entfernt. Öffentlicher Monatsname folgt Europe/Zurich; Link „Ergebnisse & Archiv“ führt zur separaten Ergebnisansicht.
- Figuren sind wesentlich grösser. Bei 320/360 px ist die Bühne nun 465 statt 225/246 px hoch; Figurenflächen 213/255 statt 126/145 px. Bei 390/430 px Bühne 490 px und Figurenflächen 238/280 px. Breite Posen bleiben innerhalb der Arena. Die zusätzlichen Sechs-Posen-Tests haben zunächst beschnittene Jab-/Ansage-Hände gefunden; die Layoutursache wurde vor Abschluss korrigiert.
- Authentifizierte Figuren nutzen die vorhandene Anime-Pipeline. Der Adapter respektiert nun scene:none auch nach dem asynchronen Anime-Upgrade. Dadurch verschwinden die rechteckigen Szenenhintergründe; Aura und Augeneffekte bleiben in der Pipeline erhalten. Keine PNG-Datei geändert.
- Öffentliche Gäste behalten freigegebene Avatare. Der bestehende authentifizierte Holo-Pfad bleibt berechtigungsgebunden. Keine zusätzlichen Zugriffsrechte oder anonymen Holo-Abfragen.
- Zusätzliche Prüfung mit Flex/Ansage als Spitzenreiter und langen Nachbarnamen fand überlappende Hand-/Textpixel bei 320 px. Ein reservierter Abstand unter den tieferen Rangbeschriftungen richtet alle Namen oberhalb der höchsten Figur aus, ohne die Figuren zu verkleinern oder zu beschneiden. Der erweiterte Browser-Test bestätigt null überlappende Pixel in beiden Engines.
- Verdiente Rahmen, Titel, Banner, Emotes und FUT-Karten bleiben integriert. FUT-Karten lesen ebenfalls den tatsächlichen Podiumsrang; Besitz- und Kaufpfade wurden nicht verändert.

## Ausgeführte Prüfungen

- `tests/release-static-contracts.cjs`: 33/33.
- `tests/league-podium-browser.cjs`: Chromium und WebKit; tatsächlicher veröffentlichungsnaher statischer Build, simulierte Konten und RPC-Antworten. 320/360/390/430/1000 px; öffentliche und eingeloggte Ansicht; Gleichstand, Nullpunkte, zwei/keine Teilnehmenden, lange und HTML-artige Namen, fehlende Looks. Pixelgrenzen aller sechs Anime-Posen auch als Spitzenreiter bei 320/360/390/430/1000 px; transparente Hintergrundpixel bei vollständiger Figur; getrennte Szenenvarianten im Cache.
- `tests/boxer-experience-browser.cjs`: Chromium und WebKit; bestehende Navigation, Rollen-Gates, Training, Holo und FUT-Card sowie 320/390/1366 px bestanden.
- `tests/kg-cards-everywhere-browser.cjs`: öffentliche Kampfgeist-Dekoration und authentifizierte Profil-Posen auf dem neuen Podium bestanden. Assertions für die entfernte doppelte Champion-Karte wurden auf das gemeinsame Podium angepasst; Besitz-/Dekorationsprüfungen bleiben erhalten.
- `tests/looks-everywhere-browser.cjs`: Rahmen/Titel und tatsächliche FUT-Rangzuordnung bestanden.
- `tests/kampfgeist5-browser.cjs`: Podium-Emotes und bestehende Shop-/Duell-/Kampfpfad-Integration bestanden.
- `tests/premium-completion-variants.cjs`: 1'764 katalogisierte Material-/Item-Varianten je Engine erneut gezeichnet (3'528 insgesamt); beide quellengebundenen Berichte erneuert.
- `tests/premium-completion-contracts.cjs`: beide Variantenberichte sowie 19 registrierte PNG-Referenzen mit SHA-256 und gültigen Ausschnitten bestanden.

Alle Browserdaten waren simuliert. Dies ist keine manuelle Geräteabnahme und keine Freigabe jeder möglichen Materialkombination.

## Echte Bildnachweise

Ausserhalb des Veröffentlichungsbaums: `outputs/seven-hour/graphics/` im übergeordneten Arbeitsbereich.

- `{chromium,webkit}-podium-before-{320,360,390,430,1000}.png`: unveränderte Basis.
- `{chromium,webkit}-podium-after-{320,360,390,430,1000}.png`: neue eingeloggte Ansicht mit identischen Basiskonfigurationen.
- `{chromium,webkit}-public-podium-after-{320,360,390,430,1000}.png`: öffentliche Avataransicht.
- `{chromium,webkit}-podium-{tied,zero,two,empty,long}.png`: Randfälle.
- `{chromium,webkit}-podium-poses-*.png`: echte aktuelle Anime-Layer aller sechs Posen mit Samurai-Mantel.
- `podium-layout-report.json`: gemessene Layoutdaten (width ist die gemessene Podiumsbreite, bei 320 px Viewport zum Beispiel 292 px).

## Abgeschlossen: Editor-Vorschauen und Wiederherstellung

- Zwölf Pose-Kacheln, die FUT-Abbildung im Posenbereich, Pose-Artikel und Bundle-Vorschauen verwenden denselben Resolver und dieselben registrierten Quellen wie die Hauptfigur. Anime/SVG-Kennzeichnung folgt dem tatsächlich verfügbaren Renderer.
- Ein separater Cache hält höchstens 24 vollständige Miniaturen (240 px Höhe); der Hero-Cache bleibt auf vier Einträge begrenzt, das gesamte HTML-/Bild-Cache-Limit bei 128. Hauptfigur bleibt in der Warteschlange priorisiert.
- Bundle-Kachel und Anprobe verwenden dieselbe Konfigurationsfunktion. Die Anprobe zeigt jetzt ausdrücklich die Profil-Pose des Bundles, auch wenn zuvor die Karten-Pose betrachtet wurde. Gespeicherte Karten-Pose bleibt unabhängig.
- Asynchrone Bilder aktualisieren nur Grafikbereiche/Badges. Auswahl, Tastaturfokus, Sperren, Preise und Kaufbestätigung bleiben bestehen.
- Bei fehlenden Grafikdateien bleiben vollständige SVG-Vorschauen und SVG-Badges sichtbar. Ein älteres gecachtes Adapter-Modul ohne Preview-API fällt ebenfalls auf SVG zurück.
- Fehlende Kernmodule erhalten nach acht Sekunden eine verständliche Fehlermeldung mit funktionierendem „Erneut laden“-Button.

Zusätzliche Prüfungen:

- `tests/premium-editor-previews-browser.cjs`: Chromium und WebKit; alle zwölf Pose-Bilder, die FUT-Abbildung und das Drachen-Bundle pixelgleich zum realen Compositor (jeweils PNG-Roundtrip, keine Pixel-Toleranz). Profil-/Karten-Pose unabhängig, schnelle Tastaturwechsel mit Fokus, 320/360/390/430/1100 px, echte Fehlasset-Fallbacks und Modulfehler mit erfolgreichem Reload. Keine Konto-Schreibaufrufe.
- Derselbe Test zeichnet 32 Materialvarianten in einer isolierten Adapter-Instanz: 24 Cache-Einträge, keine ausstehenden Jobs und **null zusätzliche Quellbild-Anfragen** nach dem Aufwärmen.
- `tests/premium-live-browser.cjs`: Chromium/WebKit bestanden; sechs Posen, rote Hose, Shirt-Kachel, Shirt/Mantel-Kombination und fehlende Bilddateien.
- `tests/boxer-holo-browser.cjs`: Chromium/WebKit bestanden, einschliesslich bestehender Speicher-, Anprobe- und Kaufbestätigungsabläufe mit ausschliesslich simulierten Kontodaten.
- Nachweise: `{chromium,webkit}-editor-premium-{poses,bundle}.png` sowie `editor-preview-parity.json` im oben genannten externen Evidence-Ordner.

## Noch offen: Flex-Shirt-Anatomie und weitergehende Kunstabnahme

Die Isolationsprüfung bei 100/200 % widerlegt den anfänglichen Verdacht alter Guard-Schulterreste: Der übernommene Torso ist bereits sauber beschnitten. Die sichtbaren Polster stammen aus `completion/assets/sleeve-shirt-upper.png` selbst und dessen Registrierung/Überlappung.

- `completion/sleeves.json`: Shirt-Komponente 197 × 230 Quellpixel, Weltgrösse 98.1333 × 115; geerbter Pivot `[44.39697,22.70654]`, Distalpunkt `[33.81697,179.33654]` liegt unterhalb der kurzen Komponente. Provenienz/Anker sind vom langen Mantelarm übernommen.
- `completion/poses.js` verwendet für jedes Kleidungsstück direkt `rig.parts.upper` als Achse. Garmentspezifische Anker werden bisher nicht ausgewertet. Ärmel liegen zudem über dem Torso.
- Tatsächliche Flex-Körperanker: links Schulter `[280,253.58974]`, Ellbogen `[127.25,262.30769]`; rechts `[488,253.58974]` und `[640.75,262.30769]`.
- Reine Anker-/Längenvarianten und Wiederverwendung direkt zugeschnittener Ärmel aus `tops/assets/shirt.png` wurden im Browser ausprobiert. Sie ändern die Ausrichtung, lösen aber den sichtbaren abgetrennten Schulter-/Armlochübergang noch nicht ausreichend. **Keine dieser experimentellen Änderungen wurde übernommen.** Kein pauschaler SVG-Downgrade.
- Reale Detailbilder: `flex-shirt-before-{100,200}.png`, `flex-shirt-torso-{100,200}.png`, `flex-shirt-sleeves-{100,200}.png`; nicht freigegebene Versuche `flex-shirt-candidate-*.png`, `flex-shirt-anchor-*.png`, `flex-shirt-reuse-*.png` im externen Evidence-Ordner.

Nächster Kunstauftrag: kurze Shirt-Ärmel aus derselben Materialquelle mit eigenen Schulter-/Cuff-Ankern, passendem Armloch und klarer Torso-/Ärmel-Überlappung registrieren; Flex zuerst, danach Jab/Sieg/Ansage. Erst nach sauberer 100-/200-%-Abnahme übernehmen und die Variantenberichte neu erzeugen. Shop-Gesamtprüfung und vollständige künstlerische Abnahme sämtlicher Outfitkombinationen bleiben offen.

Der erste ungeprüfte Prototyp wurde am ursprünglichen Zeitlimit zurückgenommen. Das hier dokumentierte Podium wurde erst nach dem ausdrücklichen Weiterauftrag wieder aufgenommen und geprüft. Kein Merge, Deployment, Produktionsschreibzugriff oder neu generiertes Artwork.

## Fortsetzung: vollständige Studio-Historie und CI-Provenienz

Der vollständige, unabhängig geprüfte Studio-Lesepfad ist in `studio-history.md` dokumentiert: 20 Trainings pro Serverabruf, vollständige Aggregate, tatsächliche PostgreSQL- und Browserprüfungen ohne Produktionsschreibzugriff. Die Inbox-Wrapper bleiben unverändert.

Der CI-Befund zum Effekte-Manifest war ein veralteter Quellhash nach der transparenten Podiumszene. Der Manifesthash wurde aus dem tatsächlichen Modul mit der bestehenden kanonischen LF-Methode berechnet; `premium-v2-effects.cjs` erzeugte anschließend neue echte Chromium-/WebKit-Berichte (40 Szenen-/Aura-Kombinationen, vier Augeneffekte, exakte Kachelgleichheit). Die Assertions bleiben unverändert. Zusätzlich werden Textquellhashes der Completion-Varianten auf beiden Plattformen kanonisch mit LF berechnet; PNG-Hashes bleiben bytegenau. Die Variantenberichte entstehen durch erneutes Zeichnen, nicht durch manuelles Umschreiben von Prüfergebnissen.

Die ergänzenden lokalen Material-/Rig-Regressionen bestanden in beiden Engines: 39 Materialkomponenten mit unveränderter Alpha-/Fremdmaterialmaske, neun begrenzte Gelenkstellungen mit konstanten Knochenlängen und deckenden Ankern. Die erneuten, nur messungsbedingten JSON-Ausgaben sind unter `output/final-extra-regressions/` abgelegt; keine Laufzeitgrafik wurde geändert.

## CI-Regression: Kachel und Hauptfigur laden dasselbe Outfit

Der WebKit-Timeout wurde als echter Integrationsfehler reproduziert: Die alte Benachrichtigungsmenge speicherte nur einen Callback pro Outfit. Startete eine Kachel das Laden und wählte die Hauptfigur dasselbe Outfit währenddessen, erhielt nur die Kachel die Fertigmeldung. Die neue Map aus Outfit-Schlüssel und Callback-Menge benachrichtigt beide Verbraucher, dedupliziert dieselbe Funktion und gibt Listener vor dem Neuzeichnen frei. Fehlerpfad und unveränderte neun Quellanfragen sind ebenfalls geprüft.

Vor der Korrektur war der neue verzögerte Tile→Hero-Browserfall in WebKit rot; danach bestanden Chromium und WebKit die vollständige Suite mit 32 Outfits, 16 Handschuhansichten und diesem Regressionstest. Drei zugehörige Quellverträge bestanden. Keine PNGs, Registrierungen oder Auswahl-Epochen verändert; keine Timeouts erhöht oder Assertions gestrichen.

## Fortsetzung: mehrere Figuren mit derselben angezeigten Pose

Ein separater Fehler im veröffentlichten `takeover-premium-character.js` ließ die zweite Figur als SVG stehen, wenn verschiedene gespeicherte Profilposen dieselbe angeforderte Kartenpose ergaben. Der Compositor normalisiert beide Konfigurationen auf denselben Job; die aufrufende Anime-Einbindung hat dafür aber verschiedene wartende Figuren. Der Adapter speicherte nur die erste Fertigmeldung.

Der neue `premium-shared-consumers-browser.cjs` reproduziert genau diesen Fall mit echten veröffentlichten Modulen/PNGs: Profilpose Cool und Guard, beide tatsächlich als Guard angezeigt. Vor der Korrektur blieb die zweite Figur unverändert; danach werden beide in Chromium und WebKit mit exakt demselben PNG aktualisiert. Der Adapter sammelt nun unterschiedliche Empfänger, dedupliziert dieselbe Funktion und gibt den wartenden Job vor den Rückrufen frei. Ein fehlerhafter Empfänger blockiert weder weitere Empfänger noch die Renderwarteschlange.

Die gesamte bestehende Editor-Vorschauprüfung und das responsive Liga-Podium bestanden anschließend ebenfalls in beiden Engines. Keine Grafiken, Quellanfragen oder Cachegrenzen für diese Korrektur verändert. Unabhängiger Code-Review ohne blockierenden Befund.

## Abschluss: Flex-Shirt-Schultern

Der oben dokumentierte offene Flex-Befund ist jetzt korrigiert. Eine gemeinsame, passend registrierte Shirtquelle ersetzt die aufgesetzten Ärmel. Figur und Kachel verwenden dieselbe Datei; keine Körper-/Hosen-/Handschuhänderung. Chromium und WebKit: jeweils 54 Outfits, 45 vollständig unveränderte andere Outfits, 36 unveränderte Hände-/Unterteilpaare, 54 exakte Kacheln, tatsächlicher Editor und vollständiger SVG-Fallback bei PNG-Ausfall. Die Flex-Grafik wurde bei 100/200 % in Schwarz/Rot/Weiss und ohne Mantel/Samurai/Basic geprüft.

Die weiteren drei Retarget-Versuche wurden trotz mathematisch gültiger Dreiecke wegen sichtbarer Kontur-/Stofffehler verworfen; kein CPU-Pilot gelangt in die Runtime. Echte Vorher-/Nachherbilder und alle Grenzen: [Shirt-Registrierung und Nachweise](../premium-v2/completion/shirt-registration.md). Die 3528 Variantenberichte wurden neu gezeichnet. Neue CI-Ergebnisse gehören zum finalen PR-Head. Kein Merge/Deployment.
