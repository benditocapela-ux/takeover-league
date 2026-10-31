# Begrenzter Arm-Master: technischer Versuch, keine Rig-Freigabe

Im isolierten Labor `tools/premium-v2/rig/index.html` sind **drei echte Anime-Rasterteile** umgesetzt: anatomisch rechter Oberarm, Unterarm und geschlossene Faust. Zwei integrierte Imagegen-Aufrufe erzeugten einen Masterbogen und einen gezielten Korrekturpass. Die exakten Prompts stehen in `tools/premium-v2/rig/provenance.json`. Die Cool- und Guard-Originalgrafiken wurden nicht verändert.

Der erste Bogen hatte deutlich ausgestellte Handgelenk-Enden und kreisförmige Ellbogenkappen. Die zweite Zeichnung reduziert diese zu schmalen, glatten Überlappungsflächen. Zusätzlich richtet der Renderer die Faustachse zur Unterarmachse aus. Die tatsächlichen Browserbilder dokumentieren diesen Unterschied:

- [Vorher, erste Zeichnung und Registrierung](../../tools/premium-v2/rig/evidence/before-art-correction.png)
- [Nachher, neun Winkelkombinationen](../../tools/premium-v2/rig/evidence/chromium-arm-contact.png)
- [Registrierungsanker](../../tools/premium-v2/rig/evidence/chromium-arm-anchors.png)

## Registrierung und Wiederverwendung

Alle neun Zustände kombinieren Schulterwinkel −10/0/+10° mit Ellbogenwinkel −10/0/+10°. Oberarm, Unterarm und Faust bleiben jeweils dieselben PNG-Dateien. Die Schulter sitzt bei (160,180) auf einer 450×500 Laborfläche. Ellbogen und Handgelenk werden hierarchisch aus den lokalen Ankern berechnet; die Faust folgt der Unterarmachse. Winkel außerhalb dieser neun Zustände werden abgewiesen.

Der Builder segmentiert ausschließlich die drei großen zusammenhängenden Alpha-Komponenten. Er speichert ihre Originalpixel ohne Neuzeichnung oder Materialwechsel; kleine unverbundene Generierungsreste werden verworfen. Ausschnitte, Quelle, SHA-256, lokale Anker und pro Teil einheitlicher Maßstab stehen in `manifest.json`. Die drei Maßstäbe dienen der initialen Proportionsregistrierung; während der Bewegung gibt es keine Dehnung. Das ist keine Behauptung pixelgleicher Wiederverwendung aus Cool: Der Arm wurde neu gezeichnet.

## Tatsächlich geprüfter Umfang

`node tests/premium-v2-rig.cjs` besteht in Chromium und WebKit. Je neun Zustände: konstante Schulter–Ellbogen- und Ellbogen–Handgelenk-Länge, deckende Gelenkanker, keine abgeschnittenen Canvas-Ränder, drei gemeinsame Quellbilder, Fehler bei nicht unterstütztem Winkel, ausgeschaltete Freigabeschalter, keine JavaScript-Fehler und keine horizontale Überbreite bei 390 px. PNG-Signaturen, RGBA-Kanalformat und Dateihashes werden geprüft. Messberichte: `tools/premium-v2/rig/evidence/*-rig.json`.

Diese Tests beweisen technische Registrierung, nicht Anatomie oder Gelenkqualität. Ein deckender Mittelpunkt allein beweist insbesondere keine nahtfreie Verbindung. Die neun Browserzustände wurden visuell geprüft: die groben ausgestellten Enden und kugelförmigen Ellbogenränder sind im Korrekturpass reduziert, eine schmale Handgelenkkante und der Wechsel bereits eingezeichneter Glanzlichter bleiben sichtbar.

## Offene Art-Gates

- Handgelenknaht bei 200 % mit einer lokalen Korrekturzeichnung schließen, statt Anatomie zu verformen.
- Oberarm/Schulter an eine passende armfreie Torsozeichnung anschließen. Kein alter Guard-Arm darf darunter sichtbar bleiben.
- Lichtführung bei gedrehtem Unterarm künstlerisch prüfen; Rasterrotation rotiert auch eingezeichnete Highlights.
- Vollständige Guard-Silhouette, Ellenbogenkrümmung, Kleidungsärmel und Hautmaterial-Abgleich erst danach prüfen.
- Keine Freigabe für Jab/Flex/Sieg/Ansage, keine Perspektivwechsel, keine Behauptung eines vollständigen Skelett-Rigs.

**Status:** erzeugt und technisch getestet; künstlerisch offen. `approved:false`, `enabled:false`. **Drei neue Masterkomponenten, neun Laborzustände, null zusätzlich freigegebene Katalog- oder Outfitvarianten.** Die Figuren-/Item-Auswahl im normalen Editor bleibt unberührt.

Rebuild: `CANVAS_MODULE=<@napi-rs/canvas> node scripts/build-premium-v2-rig.cjs`, danach Browserprüfung erneut ausführen. Beide Rohbögen liegen im Projekt, daher ist die Komponentenextraktion reproduzierbar; die generative Zeichnung selbst ist nicht deterministisch.
