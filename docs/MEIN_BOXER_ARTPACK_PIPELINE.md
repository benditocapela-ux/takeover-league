# Takeover League · Anime-Art-Pipeline für «Mein Boxer»
Stand: 30.10.2026 · Ergänzung zu Draft-PR #79

## Ziel und Freigabestatus

Die ursprüngliche Navy-/Gold-/Cyan-Vorlage mit ernstem Anime-Boxer, gekreuzten Armen und schwarz-goldener Ausrüstung ist **verbindlich**. Die aktuelle SVG-Figur ist die belastbare Rückfalllösung, aber kein fertiger Nachbau dieser Illustration. Externe Grafikpakete aus Scenario, Layer AI oder einer professionellen Illustration können eingebaut werden, ohne die bestehenden Supabase- und Shop-Funktionen zu ersetzen.

**Aktueller Stand:** Die acht Original-PNGs liegen im Repository und sind im Manifest unter `poses.cool` zugeordnet. SHA-256, 768 × 1216 Pixel, Alphakanal und Grössenbudget werden geprüft (8/8, zusammen 812800 Bytes). `approved:false` und `enabled:false` bleiben bestehen. `configurations.cool` beschränkt diese noch nicht unabhängig umkleidbaren Masken auf die exakte Referenzkombination; andere Konfigurationen verwenden SVG. Siehe [fehlende Character-Art](MEIN_BOXER_ART_GAPS.md).

**Historie:** Die nachfolgenden Abschnitte dokumentieren auch frühere lokale ZIP- und Upload-Zwischenstände. Aussagen über nicht eingecheckte Originalbilder oder ein leeres Manifest sind durch den Grafikimport in `f4d8b6e` überholt. Lokaler Dateiimport und das Ein-Klick-Laden aus dem Repository sind heute beide möglich. Künstlerische Freigabe und neue Ausrüstungsvarianten bleiben offen.

## Exportvertrag für die Illustratorin / den Illustrator

Alle Ebenen werden als **einzeln transparente PNG- oder WebP-Dateien** exportiert. Jede Datei muss denselben Bildausschnitt und dieselbe Positionierung besitzen:

- **Canvas:** exakt 768 × 1216 Pixel, transparenter Hintergrund.
- **Nullpunkt:** immer links oben bei (0, 0); keine automatische Zuschnittbox und kein Versetzen einzelner Ebenen.
- **Pose:** Die aktuell benötigte Studio-Pose wird im Manifest mit dem vorhandenen Schlüssel bezeichnet, z. B. `cool`. Die gekreuzten Arme müssen in *allen* Layern exakt ausgerichtet sein. Andere Posen haben eigene vollständige Dateisätze.
- **Zeichenstil:** stilisierter hochwertiger Anime-Boxer, nicht fotorealistisch, nicht rot-schwarz. Licht kommt konsistent von links oben. Kein Text oder eingebautes UI in Charakter-Layern.
- **Farben:** Für jede angebotene Farbvariante wird eine passende Datei benötigt. Das Frontend färbt gemalte Texturen nicht willkürlich ein.
- **Assets:** Nutzungsrechte für den öffentlichen, auch kommerziellen Website-Einsatz müssen geklärt sein. Keine ungeprüfte Verwendung fremder Marken oder geschützter Spielfiguren.

### Z-Reihenfolge der Ebenen

| Reihenfolge | Ebene | Varianten-Schlüssel (Beispiele) | Wann erforderlich? |
|---|---|---|---|
| 1 | `coatBack` | `samurai` | Mantel angelegt |
| 2 | `body` | `0` bis `7` | Immer, mit passender Haut |
| 3 | `bottom` | `boxer/schwarz` | Immer |
| 4 | `feet` | `boots/schwarz` | Immer |
| 5 | `top` | `shirt/schwarz`, `hoodie/schwarz/up` | Oberteil angelegt |
| 6 | `eyes` | `braun` | Immer |
| 7 | `hair` | `afro/schwarz` | Sichtbare Haare (nicht unter Hijab/hochgezogener Kapuze) |
| 8 | `head` | `hijab/schwarz`, `cap/schwarz` | Kopfbedeckung |
| 9 | `coatFront` | `samurai` | Mantel angelegt |
| 10 | `hands` | `wraps`, `gloves/schwarzgold` | Immer |

Der Körper-Layer enthält die für die gewählte Pose korrekten unbedeckten Körperpartien; Hände/Boxhandschuhe müssen die Arme korrekt überdecken. Für nicht vorhandene oder inkompatible Ebenen wird **die komplette SVG-Figur** gezeigt, nicht eine Mischung aus fremden Kleidungsstücken. Das verhindert, dass ein Nutzer beispielsweise einen roten Mantel auswählt, aber einen schwarzen sieht.

**Noch nicht im Rasterpack unterstützt:** aktive Aura, Spezialaugen-Effekt oder nicht unterstützte Szenen. Die Auswahl bleibt möglich, wird dann aber aus dem bisherigen SVG-Renderer angezeigt.

## Ablage und Manifest

Die Dateien werden nach Freigabe unter `assets/boxer-artpacks/v1/` abgelegt. **Nur relative, kleingeschriebene Pfade auf `.png` oder `.webp` sind zulässig**; keine dynamischen URLs, Daten-URLs, externen Domains oder `../`.

Beispiel für einen kompletten (!) Datenblock einer einzelnen Konfiguration:

```js
window.TLBoxerArtPackManifest = {
  version: 1,
  approved: true, // erst NACH Sicht- und Rechtefreigabe ändern
  canvas: { width: 768, height: 1216 },
  poses: {
    cool: {
      coatBack:  { samurai: 'coats/samurai-back.webp' },
      body:      { '6': 'body/tone-6.webp' },
      bottom:    { 'boxer/schwarz': 'bottom/boxer-black.webp' },
      feet:      { 'boots/schwarz': 'feet/boots-black.webp' },
      top:       { 'shirt/schwarz': 'top/shirt-black.webp' },
      eyes:      { braun: 'eyes/brown.webp' },
      hair:      { 'afro/schwarz': 'hair/afro-black.webp' },
      coatFront: { samurai: 'coats/samurai-front.webp' },
      hands:     { wraps: 'hands/wraps.webp' }
    }
  }
};
```

Das ist nur ein **Schema-Beispiel**, keine bereits vorhandene Grafikdatei. Für die echte Produktion müssen alle im jeweiligen Menü anwendbaren Kombinationen erstellt beziehungsweise gewünschte Pakete bewusst begrenzt werden. Bis dahin bleibt der SVG-Renderer die Anzeige.

## Integration & Tests

- `takeover-mein-boxer-artpack.js`: `create(manifest)` prüft den Manifestvertrag, wählt exakt passende Layer und erzeugt nur dann den Bildstapel.
- `takeover-mein-boxer.html`: existiert **nicht**; der tatsächliche Einstiegspunkt ist `mein-boxer.html`. Der Editor lädt die Module und nutzt neue Bilder ausschliesslich bei `?art=preview` **und** `approved:true`.
- Bild-Ladefehler und unvollständige Outfits schalten automatisch auf den alten SVG-Boxer zurück.
- **Atomarer Bildwechsel:** Der alte SVG-Boxer bleibt so lange sichtbar, bis alle Bilddateien eines komplett passenden Outfits erfolgreich vorgeladen sind. Erst dann werden alle Ebenen zusammen angezeigt. Ein einzelner Bildfehler verhindert die gesamte Umschaltung.
- **Dateivalidierung:** Vor der Freigabe `node scripts/validate-boxer-artpack.cjs` ausführen. Die Prüfung kontrolliert erlaubte lokale Pfade, 768×1216 Pixel, PNG-/WebP-Transparenzkennzeichen und maximal 2 MiB pro Datei. Der CI-Workflow führt dieselbe Prüfung aus. Auch Entwurfspakete mit `approved:false` werden geprüft, sobald das Manifest mindestens eine Pose enthält. Nur ein vollständig leeres, deaktiviertes Manifest wird übersprungen.
- **Grenze der automatischen Prüfung:** Ein vorhandener Alphakanal beweist nicht, dass Kleidung und Körper grafisch deckungsgleich sind. Das muss mit echten Bildschirmfotos, unterschiedlichen Outfits und einer Bildprüfung bestätigt werden.
- Das bestehende Datenbankmodell, die gespeicherte Konfiguration und Kauf-/Besitzinformationen werden nicht geändert.
- `tests/mein-boxer-artpack-contracts.cjs` prüft Varianten, Fallbacks, gültige Pfade und verbotene externen Ressourcen.
- Browser-Tests müssen die weiterhin funktionierende mobile Bühne, den Outfitwechsel und fehlgeschlagene Bildladungen abdecken.

## Freigabecheck

1. Eine Musterfigur **direkt gegen die freigegebene Originalvorlage** prüfen; insbesondere Gesicht, Armhaltung, schwarze/goldene Materialien.
2. Relevante Haar-, Haut- und Ausrüstungsvarianten auf deckungsgleicher 768×1216-Fläche exportieren und Rechte klären.
3. Alle Ebenen im Testbranch ablegen, Manifest auf `approved:true` setzen, `?art=preview` verwenden.
4. Browser-Screenshots kontrollieren, mobile Performance/Netzwerkvolumen messen, Save/Reset, Käufe und sichere Fallbacks testen.
5. Erst nach ausdrücklicher Freigabe den Produktivmodus und dann PR #79 freigeben/mergen. **Kein automatisches Live-Deployment.**

## Editor-Abnahme: Bedienung, Ausfälle und Datensicherheit (30.10.2026)

Das Studio verändert weiter **keine** Server-Schnittstelle und bleibt als Draft unpubliziert.

- **Zugänglichkeit:** Die fünf Bereiche «Körper», «Kleidung», «Extras», «Posen» und «Shop» verwenden einen nachvollziehbaren Tab-/Tabpanel-Zusammenhang. Links/Rechts sowie Home/End wechseln mit der Tastatur die aktive Rubrik. Aktive Auswahlknöpfe behalten nach Farb- und Ausrüstungsänderungen den Fokus.
- **Stabile Bedienung:** Bei asynchron geladenen oder fehlgeschlagenen Grafiken wird nur die zentrale Figur ersetzt – nicht das gesamte Menü. So gehen der Fokus und die Positionen in den horizontalen Ausrüstungsleisten nicht verloren.
- **Netzwerkfehler:** Speichern und Einkaufen reagieren auch auf unerwartete Promise-Abbrüche. Die Oberfläche bleibt anschliessend bedienbar und zeigt einen Fehler; Käufe werden bei einem fehlgeschlagenen Refresh nicht automatisch wiederholt.
- **Änderungen während des Speicherns:** Der gespeicherte Stand ist ein unveränderlicher Snapshot. Wenn jemand danach weitere Änderungen auswählt, bleiben diese sichtbar und als **noch nicht gespeichert** markiert.
- **Automatische Abnahme:** Der Chromium-Test simuliert Tastaturnavigation, Fokus- und Scrollpositionen, Speicherfehler, Kaufausfälle sowie Änderungen, während eine Speicheranforderung läuft. Ein zusätzliches GitHub-Review der Screenshots bleibt vor Merge erforderlich.

Die Testsimulation ist kein Ersatz für einen eingeloggten iPhone-Safari-Praxistest. Die echten Premium-Illustrationen fehlen weiterhin.

## Integrationstools für externe Game-Art (30.10.2026)

Für die konkrete Übergabe an Illustratorinnen oder Game-Art-Plattformen gibt es zwei ergänzende Hilfen:

1. **Im Browser:** Nur mit `mein-boxer.html?art=preview` erscheint am Charakter eine kleine Diagnose. Sie zeigt zuverlässig, ob das Paket nicht freigegeben ist, die Pose fehlt, ein bestimmtes Kleidungsstück nicht angelegt werden kann, die Ebenen noch laden oder eine Datei defekt ist. Der normale Editor zeigt keine Debug-Informationen.
2. **Im Repository:** `node scripts/report-boxer-artpack.cjs` erstellt eine verständliche Liste der noch fehlenden Grafiken für den schwarz-goldenen Referenzboxer (9 Basisebenen) und zählt den Stand der ersten Ausbauwelle. `node scripts/report-boxer-artpack.cjs --json` liefert dieselben Informationen maschinenlesbar. Der Bericht liest die tatsächlich vorhandenen Hautton-, Frisuren- und Augenfarben-Schlüssel aus dem gemeinsamen Holo-Renderer; keine frei erfundenen IDs.
3. **Vor Freigabe:** Mit `node scripts/validate-boxer-artpack.cjs` werden die realen Dateien geprüft. Ein Manifest-Eintrag oder grüner Abdeckungsbericht allein beweist noch nicht, dass die Grafiken existieren oder optisch richtig ausgerichtet sind.

**Nicht mitgeliefert:** hochwertige externe Anime-Grafiken; diese bleiben ein bewusst offener visueller Meilenstein. Eine nicht vorhandene Grafik wird weder durch ein beliebiges generiertes Bild noch durch das bestehende SVG als neues Premium-Asset ausgegeben.

## Premium-/SVG-Vergleich direkt im Editor (30.10.2026)

Für die Bildabnahme gibt es jetzt **einen direkten Vorher-/Nachher-Vergleich** ohne neue Datenbankfelder, Käufe oder öffentliche Einstellungen.

- Der Vergleichsschalter erscheint ausschliesslich, wenn `mein-boxer.html?art=preview` geöffnet ist, ein **freigegebenes** Manifest geladen wurde und das optionale Artpack-Modul verfügbar ist.
- Der Schalter wechselt zwischen der aktuellen SVG-Grafik und dem Premium-Asset-Renderer. Er verändert weder die Konfiguration noch das Shopinventar oder die gespeicherten Profilwerte.
- Die Auswahl der Rubrik und des Outfits bleibt beim Umschalten bestehen. Die Tastatur kann den Schalter mit Enter/Leertaste bedienen. Die Statusanzeige kennzeichnet manuell ausgewählte SVG-Grafik.
- Die Chromium-Abnahme erstellt sowohl einen Screenshot der geladenen Premium-Vorschau als auch der dazugehörigen SVG-Darstellung. Sie prüft zusätzlich Zentrierung, Bildausschnitt und Deckungsgleichheit aller Ebenen im mobilen Vorschaubereich.
- Ist das Artpack-Modul im Offline-Modus nicht verfügbar, ist der Schalter unsichtbar. Die SVG-Figur funktioniert trotzdem.

**Wichtig:** Momentan ist `approved:false`, daher wird der Vergleichsschalter auf dem realen PR-Stand noch nicht angeboten. Die neuen Tests verwenden vollständig künstliche, lokale Bild-Fixtures; sie beweisen den technisch korrekten Vergleich, **nicht** die künstlerische Qualität der noch fehlenden Game-Art.

## Sichere Aktivierung im normalen Studio (30.10.2026)

Die Studio-Grafik hat **zwei voneinander unabhängige Freigabeschalter** im Manifest `takeover-mein-boxer-artpack-manifest.js`:

| `approved` | `enabled` | Normales «Mein Boxer» | `?art=preview` |
|---|---|---|---|
| `false` | `false` | Bestehender SVG-Boxer | SVG mit Diagnose «nicht freigegeben» |
| `true` | `false` | Bestehender SVG-Boxer | Premium-Art, falls für die Auswahl vollständig; SVG-Fallback sonst |
| `false` | `true` | Bestehender SVG-Boxer | SVG mit Diagnose «nicht freigegeben» |
| `true` | `true` | Premium-Art, falls vollständig; SVG-Fallback sonst | Premium-Art mit SVG-Vergleich |

Beide Schalter sind im PR weiterhin ausdrücklich `false`. Der produktive Aufruf ohne URL-Parameter übernimmt also **niemals** ein noch nicht freigegebenes Paket. Der Vergleichsschalter und die Debug-Diagnosen bleiben auch nach einer möglichen Freigabe ausschliesslich im manuellen Testmodus `?art=preview`.

Zur kontrollierten Inbetriebnahme: Erst Grafiken vollständig in den Assetordner liefern; danach den Validator und echte mobile Vergleichsscreenshots prüfen; Rechte und Designfreigabe schriftlich festhalten; erst dann `approved:true`, im Testbetrieb prüfen und separat `enabled:true` freigeben. Die Umstellung betrifft nur den «Mein Boxer»-Editor. Öffentliche Profile und FUT-Karten verwenden weiterhin ihren eigenen SVG-Holo-Renderer, bis sie gesondert integriert und getestet werden.

**Bei Problemen:** `enabled:false` zurücksetzen, ohne gespeicherte Boxer-Daten, Shopbesitz oder Supabase zu ändern. Der SVG-Fallback bleibt in jeder Konfiguration erhalten.

## Mobiles Performance-Budget für Charaktergrafiken (30.10.2026)

Eine Figur in der fixierten Vorschau besteht aus mehreren transparenten, jeweils 768 × 1216 Pixel grossen Bildern. Für eine produktionsreife mobile Web-App reichen korrekte Bildmasse allein nicht:

- **Maximal drei parallele Ladevorgänge** im Studio. `takeover-mein-boxer-artpack.js` nutzt eine gemeinsame Warteschlange für einzelne Bilddateien; wiederholtes Auswählen derselben Ausstattung startet keine Doppel-Downloads. Die gesamte Premium-Figur wird erst nach vollständigem Laden sichtbar, ansonsten bleibt das SVG.
- **Maximal 2 MiB pro Bilddatei**, wie bisher, **zusätzlich höchstens 6 MiB pro maximalem Outfit**. Der Validator nimmt für jede der möglichen Ebenen eines Posen-Pakets die grösste definierte Variante und summiert sie konservativ. Diese Worst-Case-Grenze verhindert, dass zehn einzeln zulässige, aber gemeinsam viel zu grosse Bilder in einen mobilen Kampfanzug gelangen.
- **PNG/WebP mit transparentem Alphakanal** bleibt verpflichtend. WebP ist bei passender Qualität für die Übertragung oft deutlich kleiner; tatsächliche Bildschärfe muss gegen die bestätigte Anime-Vorlage geprüft werden.
- **Keine voreilige Live-Schaltung:** `enabled:true` bei `approved:false` wird nun auch von der Datei-Validierung ausdrücklich zurückgewiesen.
- Die automatischen Tests `tests/mein-boxer-preload-performance.cjs` und `tests/validate-boxer-artpack-contracts.cjs` prüfen den gleichzeitigen Bildabruf, gemeinsam genutzte Downloads, Fehlerbehandlung sowie das kombinierte Byte-Limit.

Die 6-MiB-Grenze ist ein Startbudget für das Studio, keine gemessene reale Netzwerklast. Nach Lieferung der echten Artwork-Dateien sind Bildqualität, iPhone-Speicherverbrauch und Ladezeiten anhand der realen Daten zu verifizieren. Sollte die gewählte Bildqualität nicht unter diesem Budget möglich sein, muss das Team die Grafikebenen optimieren und den Grenzwert mit dokumentierten mobilen Messungen neu bewerten.

## Aktualisierter Abnahmeablauf: vor der Grafikfreigabe prüfen

Die Bildprüfung läuft nun bereits mit **`approved:false`**, sobald die erste Pose im Manifest eingetragen wird. Dieser Zustand ist für den Import neuer Grafiken vorgesehen:

1. Dateien unter `assets/boxer-artpacks/v1/` ergänzen und zugehörige Posen-/Variantenpfade in das Manifest aufnehmen. `approved:false` und `enabled:false` beibehalten.
2. `node scripts/validate-boxer-artpack.cjs` ausführen: Dateipfade, Bildformate, 768×1216-Abmessungen, Alphakanäle, maximal 2 MiB je Bild und maximal 6 MiB für die grösstmögliche Ausstattung.
3. Erst nach fehlerfreier Prüfung und visueller Abnahme `approved:true` für den kontrollierten `?art=preview`-Vergleich auf dem Testbranch einsetzen. Der normale Editor bleibt wegen `enabled:false` weiterhin SVG.
4. Nur mit ausdrücklicher zusätzlicher Freigabe den produktiven Schalter `enabled:true` setzen. Bei Bedarf genügt `enabled:false` als sofortiger Rückweg zum SVG-Editor.

Die GitHub-Testworkflows besitzen ausserdem jetzt `concurrency`-Gruppen je PR. Neuere Commits können damit überholte Staging- und V2-Integrationsprüfungen ersetzen. Der getrennte GitHub-Pages-Veröffentlichungsworkflow bleibt davon unberührt.

## Tatsächliche GitHub-Pages-Auslieferung der freigegebenen Sprites (30.10.2026)

**Behobener Integrationsfehler:** Der Pages-Workflow `.github/workflows/takeover-pages-deploy.yml` hatte bisher nur Root-Dateien und den Ordner `avatars/` kopiert. Selbst bei vorhandenen und freigegebenen Premium-Grafiken wären die Bild-URLs unter `assets/boxer-artpacks/v1/` deshalb im veröffentlichten Editor auf HTTP 404 gelaufen.

Der neue Schritt `node tools/publish-boxer-artpack.cjs _site` im Pages-Build hat folgende Sicherheitsregeln:

- **Entwurf (`approved:false`):** Vorhandene Bilddateien werden validiert, aber **nicht** nach `_site/` kopiert. Ein leerer Entwurf ist weiterhin zulässig.
- **Freigegeben (`approved:true`):** Nur Dateien, die im freigegebenen Manifest über Posen und Ebenen referenziert sind, werden nach `_site/assets/boxer-artpacks/v1/` kopiert. Es werden weder unreferenzierte Grafiken noch Stilvorlagen/Entwurfsordner kopiert.
- **Prüfung vor dem Kopieren:** Fehlende Dateien, unerlaubte relative Pfade, unpassende Abmessungen und zu grosse Outfits schlagen im Build fehl. Der Kopierer prüft zusätzlich, dass Symlinks keine Dateien ausserhalb des Quellordners preisgeben.
- **Veröffentlichung:** Der vorhandene Main-Branch-Schutz im Workflow bleibt bestehen. Neu enthalten seine Änderungstrigger auch `assets/boxer-artpacks/v1/**` und den Kopier-/Validierungscode.
- **Regression:** `tests/publish-boxer-artpack-contracts.cjs` prüft das Verhalten mit künstlichen Bild-Fixtures und kontrolliert, dass GitHub Pages den sicheren Kopierpfad tatsächlich aufruft.

Beachte: Ein **öffentliches GitHub-Repository** macht hochgeladene Dateien im Repository selbst sichtbar. Dass Entwurfsbilder nicht in GitHub Pages kopiert werden, macht sie deshalb **nicht vertraulich**. Unveröffentlichte, vertrauliche Designvorlagen dürfen nicht in einem öffentlichen Repo abgelegt werden.

Damit besteht der vollständige technische Pfad: Manifest → Datei- und Grössenprüfung → ausdrückliche Freigabe → gezielte Pages-Auslieferung → kontrollierte Editor-Aktivierung. Die finalen Anime-Illustrationen werden weiterhin separat benötigt.
 
## Visuelle Referenzprüfung vor dem ersten Asset-Pack

Ein **lokaler Grafikvergleich** liegt jetzt unter `tools/boxer-art-review.html`. Er ist absichtlich kein öffentlicher Navigationspunkt und wird vom Pages-Workflow (der nur die Root-HTML-Dateien ausliefert) nicht mitveröffentlicht.

- Aus dem ausgecheckten Repository über einen lokalen Webserver öffnen: `python3 -m http.server 8000`, anschliessend `http://localhost:8000/tools/boxer-art-review.html`.
- Links den **Originalboxer mit verschränkten Armen** als PNG/WebP-Datei wählen, rechts eine neue Illustration oder transparente Ebene. Beide Bilder werden im lokalen Browser per Object-URL geöffnet, **ohne Server-Upload oder Datenbankverbindung**.
- Das Tool prüft die Leinwandgrösse von 768 × 1216 und ob transparente Pixel vorhanden sind. Im Schieberegler lassen sich die Figuren überlagern und die Kopf-/Arm-/Schuhpositionen kontrollieren.
- Die vorhandene Schnittstelle bleibt weiterhin die echte Produktionspipeline. Ein einzelner freigestellter Referenzboxer ist **kein** vollständiges Outfit-Paket und darf nicht einfach unter falschen Kleidungsschlüsseln in das Manifest eingetragen werden.
- Die Browserabnahme `tests/boxer-art-review-browser.cjs` kontrolliert lokale Dateiauswahl, Dimensionsanzeige, Überlagerung, Transparenzraster und mobiles Layout.

**Künstlerische Grenzen:** Der bestehende Referenzausschnitt ist sichtbar unsauber freigestellt (helle Ränder und Schattenreste). Er dient ausschliesslich zur Prüfung von Silhouette, Farbpalette und Verschränkung der Arme. Die Grafiken dürfen erst nach professioneller Bereinigung und separater Prüfung der austauschbaren Ebenen als Premium-Asset freigegeben werden. Referenzdateien mit ungeklärten Nutzungsrechten nicht in ein öffentliches GitHub-Repository hochladen.

## Erster Acht-Ebenen-Referenzentwurf der bestätigten Cool-Pose (30.10.2026)

Aus dem vom Nutzer visuell bestätigten Anime-Boxer (schwarz-goldener Mantel, kurzer Afro, dunkle Haut, verschränkte Arme, TAKEOVER-Shorts und hohe Stiefel) wurde ein **extern bereitgestelltes, noch nicht im Repository gespeichertes** Testpaket mit acht **768 × 1216 Pixel grossen PNGs** erstellt:

- `cool/coatBack.png` → Mantelschösse und Hintergrundteile
- `cool/body.png` → verbleibende sichtbare Haut/Körperbereiche
- `cool/bottom.png` → schwarz-goldene Boxershorts
- `cool/feet.png` → hohe Boxstiefel
- `cool/eyes.png` → Gesichts-/Augenausschnitt
- `cool/hair.png` → kurzer Afro
- `cool/coatFront.png` → Mantelärmel und Vorderteile
- `cool/hands.png` → Bandagen und verschränkte Unterarme

Eine unabhängige lokale Überprüfung hat die **pixelgenaue Rekonstruktion des Originalbilds aus diesen acht Bildern bestätigt**. Das Paket enthält ein `manifest-draft.json`, ein `composited-proof.png` und eine Vorschau der einzelnen Ebenen. Die Werte in `manifest-draft.json` sind ausdrücklich `approved:false` und `enabled:false`.

**Wesentliche Einschränkung:** Dieser erste Entwurf teilt vorhandene Pixel mittels Regionmasken auf. Er ergänzt **keine Anatomie oder Kleidung, die im freigegebenen Einzelbild verdeckt ist**. Deshalb entstehen beim Austausch/Entfernen einzelner Ebenen sichtbare Lücken. Man kann damit die Originalpose rekonstruieren und den Produktionsprozess testen, aber **noch keine vollständige, frei anpassbare Premium-Figur** liefern. Für die echte Shop-/Outfit-Integration braucht es retuschierte Unterlagen (vollständiger Körper), überlappende Mäntel/Hosen/Schuhe und alle benötigten Farb- und Posenvarianten. Das alte Holo bleibt für diese Varianten Pflicht-Fallback.

Das externe Testpaket wurde **nicht automatisch in GitHub hochgeladen**, weil die verbundenen GitHub-Textdatei-Aktionen die binären PNGs nicht direkt aus dem lokalen Arbeitscontainer übernehmen. Daher wurde das produktive Manifest nicht mit Dateiverweisen auf noch fehlende GitHub-Dateien versehen – andernfalls würden die Staging-Tests gezielt fehlschlagen.

Nach bewusstem Upload ins Repository müssen die acht Bilddateien unter `assets/boxer-artpacks/v1/cool/` abgelegt und das echte JavaScript-Manifest entsprechend dem geprüften JSON angepasst werden. Anschliessend: Dateivalidator, tatsächliche Playwright-Abnahme mit dem ersten Look und **erst danach** gesonderte visuelle Freigabe.

## Echt zusammengesetzte Acht-PNG-Vorschau im PR (30.10.2026)

Für den **ersten originalgetreuen Referenzlook** gibt es nun direkt im mobilen Editor die URL `mein-boxer.html?art=layers`. Die Original-PNG-Dateien werden dabei **nicht** aus GitHub geladen, sondern direkt auf dem Gerät des Reviewers ausgewählt. Diese Ergänzung macht die erste tatsächliche Mehr-Ebenen-Komposition im echten Editor prüfbar, ohne bereits neue Farben oder Kleidungsstücke zu erfinden.

**So wird sie geprüft:**

1. `takeover_cool_8_layer_draft.zip` vom vorherigen Arbeitspaket lokal entpacken.
2. Im Draft-Testbranch `mein-boxer.html?art=layers` aufrufen und mit einem aktivierten Boxer anmelden.
3. Unter `assets/boxer-artpacks/v1/cool/` **alle acht PNGs gleichzeitig** wählen: `coatBack.png`, `body.png`, `bottom.png`, `feet.png`, `eyes.png`, `hair.png`, `coatFront.png`, `hands.png`.
4. Die gesamte Vorlage wird nur dann als acht deckungsgleiche Bilder angezeigt, wenn die Boxer-Konfiguration dem Originallook entspricht: **Cool-Pose, Haut 6, Afro/Schwarz, braune Augen, kein Oberteil, Samurai-Mantel, schwarze Boxershorts, schwarze Boots, Bandagen, keine weiteren Effekte oder Kopfstücke**.
5. Über den Vergleichsschalter kann jederzeit wieder der echte SVG-Boxer angezeigt werden. Eine **andere** Kleidung, Pose, Frisur oder Hautfarbe zeigt unmittelbar den echten SVG-Fallback. Das Entwurfspaket bleibt geladen, damit derselbe Referenzlook erneut betrachtet werden kann.

**Sicherheitsgrenzen:**

- Das Modul `takeover-mein-boxer-draft-layers.js` wird nur bei `?art=layers` geladen. Der normale Editor, öffentliche Boxerprofile, die FUT-Karten und Shopkäufe werden nicht verändert.
- Der Browser akzeptiert nur die acht festgelegten PNG-Namen, maximal **2 MiB je Datei**, mit **768 × 1216 Pixeln**. Fehlende oder doppelte Ebenen schlagen als geschlossener, nicht teilweise gezeichneter Satz fehl. Alte lokale Bild-URLs werden beim Neuladen bzw. Seitenverlassen freigegeben.
- Die Browserschnittstelle verwendet nur lokale `blob:`-URLs. Die acht Entwurfsbilder werden **nicht an Supabase, GitHub oder einen anderen Server hochgeladen**, und sie können nicht versehentlich einen Kauf oder ein `save_my_holo` auslösen.
- Chromium prüft vollständigen achtteiligen Aufbau, exakt gleiche Rechtecke, direkten SVG-Vergleich, Fallback bei Kleidungswechsel, Fehler bei sieben Dateien sowie unsichtbaren Debugmodus auf der normalen Seite. Dazu gibt es den isolierten Contract-Test `tests/mein-boxer-draft-layers-contracts.cjs`.

Dies ist **ein echter technischer Ebenen-Test**, aber noch keine fertig individualisierbare Premium-Figur. Die Schnittsegmente bewahren dieselben Ursprungspixel. Verdeckte Anatomie und austauschbare Kleidung müssen erst professionell neu gezeichnet werden. Die beiden produktiven Manifestflags bleiben `approved:false` und `enabled:false`; kein Merge oder Deployment ohne erneute Freigabe.

## Acht-Ebenen-Prüfmodus: Masken, Original-Look und Quellenidentität (30.10.2026)

Der schon vorhandene Modus `mein-boxer.html?art=layers` wurde für die tatsächliche Weiterzeichnung ausgebaut:

1. Das lokale **achtteilige Referenzpaket** mit den bekannten Namen `coatBack.png`, `body.png`, `bottom.png`, `feet.png`, `eyes.png`, `hair.png`, `coatFront.png`, `hands.png` auswählen. Es wird nichts an GitHub oder Supabase übertragen.
2. **«Grafikebenen prüfen»** oben in der Bühne öffnen. Das Menü ist standardmässig eingeklappt, damit der Boxer vollständig sichtbar bleibt.
3. **«Original-Look ansehen»** zeigt die unveränderte, bestätigte Cool-Pose zur Designprüfung, selbst wenn der angemeldete Boxer andere Haare oder Kleidung besitzt. Der sichtbare Hinweis sagt ausdrücklich, dass dies **nicht** die aktuelle Ausrüstung des Profils ist. Der Profilzustand wird nicht geändert und kein `save_my_holo` ausgelöst.
4. Acht Kontrollkästchen lassen jede tatsächliche Pixel-Ebene separat sichtbar oder unsichtbar werden. Beispielsweise **«Mantel vorne»** deaktivieren, um die fehlende verdeckte Anatomie der Erstfassung zu erkennen. Mit allen acht aktiven Ebenen bleibt das bestätigte Gesamtbild erhalten.
5. Bei einer echten Änderung der Kleidung, Frisur, Hautfarbe oder beim Speichern endet die vorübergehende Original-Look-Übersteuerung. Die dynamische Holo-Figur bleibt die sichere Darstellung aller noch nicht gezeichneten Varianten.
6. Wenn Web Crypto verfügbar ist, berechnet der Browser **lokal SHA-256 je PNG** und vergleicht die acht Werte mit den Originaldateien aus dem vom Nutzer bestätigten Referenzpaket. Originaldateien erhalten einen positiven Herkunftshinweis; abweichende Testdateien werden als solche gekennzeichnet. Ist die Prüfung im Browser nicht möglich, wird dies offen angegeben. **Ein positiver Hash ist keine künstlerische oder produktive Freigabe der fehlenden Outfit-Varianten.**

Die Kontrollwerkzeuge verwenden eine aufklappbare `<details>`-Oberfläche und erhalten ihren Öffnungszustand bei einem Renderwechsel. Ihre Bedienung setzt nicht die Scrollposition des Ausrüstungsbereichs zurück. Der Browser-Test prüft auch eine isoliert ausgeblendete Mantelvorderseite, Fokus, Rückschalten auf SVG und die markierte, nicht gespeicherte Original-Look-Vorschau.

**Lieferstatus:** Die echten acht PNGs sind nach wie vor ausschliesslich in der dem Nutzer bereitgestellten ZIP-Datei vorhanden, nicht als binäre Dateien im GitHub-PR. Die angebundene GitHub-Schnittstelle unterstützt hier Textänderungen sowie binäre Base64-Blobs, aber **keinen direkten Transfer aus dem lokalen Dateisystem**. Daher ist kein Upload dieser Originalbilder erfolgt. Die Grafikfreigabe im Produktionsmanifest bleibt `approved:false, enabled:false`. Die verbleibende künstlerische Aufgabe ist das Nachzeichnen der verdeckten Körperbereiche unter Mantel/Armen und das Erstellen echter Kleidungsvarianten.

## Anatomische Unterzeichnung V0 hinter dem Referenzmantel (30.10.2026)

**Neuer echter Artwork-Arbeitsschritt – nicht als Premium-Illustration freigegeben:** Die Datei `takeover-mein-boxer-anatomy-blockout.js` enthält eine editierbare **768×1216-SVG-Unterzeichnung** für Schultern, Deltoide, seitlichen Brustkorb, überkreuzte Oberarme, Taille, seitliche Hosenbereiche und Beine. Die Formen liegen unter den acht originalen PNG-Masken, sodass eine Illustratorin genau erkennt, welche Körperregionen unter dem Mantel neu gezeichnet werden müssen. Die Rohskizze hat absichtlich eine vereinfachte, sichtbar nicht zum Detailgrad der bestätigten Anime-Figur passende Oberfläche.

**Benutzung im Testmodus:**

1. `mein-boxer.html?art=layers` öffnen, die acht echten PNGs vom bereitgestellten Testpaket lokal auswählen und das Menü **«Grafikebenen prüfen»** aufklappen.
2. **«Mantel vorne»** sowie optional **«Mantel hinten»** ausschalten, um die derzeit transparenten Ausschnitte zu sehen.
3. Das neue Kästchen **«Anatomie-Skizze zeigen (unfertig)»** aktivieren. Damit erscheint die Vektorskizze **hinter allen originalen Rasterebenen**. Die konkreten Lücken lassen sich mit und ohne Vektorbasis vergleichen.
4. Die Unterzeichnung wieder ausschalten. Die originalen Referenzpixel bleiben exakt unverändert. Es wird kein Profilwert gespeichert und das Produktionsmanifest bleibt `approved:false, enabled:false`.

**Sicherheit:** Die Unterzeichnung wird ausschliesslich mit `?art=layers` importiert; die Checkbox steht beim Öffnen immer auf «aus». Auch mit Unterzeichnung bleibt die bekannte Kompatibilitätsprüfung (nur der originalgetreue Cool-Look) zwingend. Kein Shirt, Mantelwechsel oder neuer Hautton wird dadurch als fertig verfügbares Premium-Outfit ausgegeben.

**Tests:** `tests/mein-boxer-anatomy-blockout-contracts.cjs` sichert Canvasgrösse, reine lokale Vektorgeometrie, nicht freigegebenen Status, standardmässig deaktivierte Unterzeichnung, Ebenenreihenfolge und SVG-Fallback ab. Der bestehende Chromium-Integrationstest erzeugt einen Screenshot **`holo-eight-layer-underpaint-blockout.png`** mit temporär ausgeblendeter Mantelvorderseite und überprüft anschliessend die unveränderte Rückkehr zum Referenzbild.

**Offene künstlerische Qualitätsarbeit:** Die Skizze ist lediglich ein *anatomisches Blockout*, noch **keine** stilsichere Body-PNG. Schultern/Arme, Seitenkörper, Muskellicht und Stoffüberlappungen müssen zur bestätigten Anime-Referenz neu gezeichnet werden. Nur eine solche saubere Illustration ermöglicht später den echten Mantel-an/Mantel-aus-Outfitwechsel. Als zusätzliche Übergabe gibt es ein lokales ZIP-Arbeitsset mit transparentem SVG/PNG, Originalmasken, direktem Dreistufenvergleich und detaillierter Art-Anweisung. Das ZIP ist nicht selbst ins GitHub-Repository übertragen worden.

## Austauschbare lokale Körperzeichnungen für das Anime-Layer-Review (30.10.2026)

Die alte starre Anatomie-Skizze kann jetzt im bereits vorhandenen achtteiligen Testmodus durch **eine echte transparente PNG-Unterzeichnung** ersetzt werden. Der PR speichert die Benutzerbilder weder im Repository noch in Supabase; das ist eine *bewusst lokale künstlerische Abnahme*, keine neue Shopfunktion.

1. `mein-boxer.html?art=layers` im PR-Testbranch öffnen und zunächst die acht Original-PNGs aus `takeover_anatomie_v1_arbeitsset.zip` auswählen.
2. «Grafikebenen prüfen» öffnen. Bei **«Eigene Körperzeichnung (PNG, 768 × 1216)»** die Datei `anatomie_textur_v1.png` oder einen professionell neu gezeichneten Nachfolger auswählen.
3. Die neue Grafik erscheint dann ausschliesslich **hinter** den weiterhin pixelgenau zusammengesetzten Originalebenen. Zum Prüfen die Ebenen «Mantel vorne» / «Mantel hinten» ausschalten und das Werkzeugmenü schliessen. Beim Wechsel von Frisur, Outfit, Hautton oder Pose bleibt der bisherige anpassbare SVG-Holo der Fallback.
4. «Eigene Zeichnung entfernen» gibt die lokale Object-URL frei. Die nicht produktionsreife SVG-V0-Unterzeichnung bleibt als Vergleich verfügbar. Auch beim Seitenverlassen werden die geladenen Dateien wieder freigegeben.

**Dateiprüfung:** PNG-MIME/Endung, maximal 2 MiB, exakt 768 × 1216 Pixel und transparenter Hintergrund an den vier Bild-Ecken. Die Ersatzdatei wird erst nach vollständigem Laden sichtbar; bei fehlerhaftem Format oder Abbruch bleibt eine vorherige gültige lokale Zeichnung erhalten. Die Regres­sionstests `tests/mein-boxer-custom-underpaint-contracts.cjs` und `tests/boxer-holo-browser.cjs` prüfen Ablehnung, URL-Freigabe, Ebenenreihenfolge und fehlende Datenbank-Speicheraktionen.

**Künstlerischer Status:** `anatomie_textur_v1.png` ist eine farblich überarbeitete **Texturstudie**, deren Hochfrequenz-Hautdetails aus der genehmigten Referenz stammen. Sie ergänzt **keine wirklich neu gezeichnete, originalgetreue Schultermuskulatur** und wird deshalb *nicht* als fertiger Anime-Body oder ausziehbarer Mantel freigegeben. Das Original bleibt die verbindliche Qualitätsvorlage. Keine Änderung der Produktionsflags `approved:false` / `enabled:false`.

Der separate ZIP-Arbeitsordner enthält `index.html`, acht unveränderte Ebenen mit überprüften Original-SHA-256-Werten, V0/V1-Unterzeichnungen, Vergleichs-JPG, README und einen reproduzierbaren Python-Entwurf.

## Einmaliger ZIP-Import der acht Originalgrafiken in den PR-Checkout

Das bisherige manuelle Kopieren der acht Original-PNGs entfällt mit dem neuen Node-Skript:

```bash
# Im lokal ausgecheckten Branch design/mein-boxer-sticky-webapp-20261030:
node scripts/import-original-cool-artpack.cjs /pfad/zu/takeover_cool_8_layer_draft.zip --dry-run
node scripts/import-original-cool-artpack.cjs /pfad/zu/takeover_cool_8_layer_draft.zip
node scripts/validate-boxer-artpack.cjs
git status --short
```

Das Skript ist absichtlich **streng auf die acht vom Nutzer bestätigten Referenzpixelmasken** beschränkt und nicht für beliebige generierte Grafiken gedacht:

- Es akzeptiert nur die exakt erwarteten Dateinamen (im ZIP-Root oder im bekannten `assets/boxer-artpacks/v1/cool/`-Pfad), 768 × 1216 RGBA-PNG, höchstens 2 MiB pro Ebene und die hinterlegten **acht originalen SHA-256-Prüfsummen**.
- Erst wenn sämtliche Dateien überprüft wurden, erzeugt es die acht Dateien im Zielverzeichnis und schreibt das JavaScript-Manifest mit der einzelnen Pose `cool`. Beide Flags bleiben **`approved:false`, `enabled:false`**; es erfolgt **keine** Veröffentlichung.
- `--dry-run` liest und prüft die Dateien, **schreibt aber nichts**. Wiederholter Import ist nur mit bereits **identischem** Manifest und identischen Zieldateien erlaubt. Abweichende Bilder oder ein bereits freigegebenes Manifest werden nicht überschrieben.
- Der separate Dateivalidator prüft die importierten PNGs anschliessend unabhängig von der Freigabestufe. Ein Git-Commit/Push bleibt ausdrücklich ein separater, bewusster Schritt des Entwicklers. **Der PR enthält zurzeit weiterhin nur das Importskript, nicht die binären Original-PNGs.**
- `tests/import-original-cool-contracts.cjs` prüft ein synthetisches ZIP, falsche Prüfsummen, keine Änderungen im Checkmodus, Manifestfreigaben, wiederholten Import und Überschreibschutz.

Diese Vorlage ist **noch kein frei umkleidbares Premium-Artpack**: Sie rekonstruiert nur den ursprünglichen Cool-Look. Vor einer späteren visuellen Freigabe sind die verdeckten Körperbereiche unter dem Mantel nachzuzeichnen.

## Körperunterzeichnung V2 – externe Arbeitsdatei, keine Produktivgrafik

Das neue Arbeitsset `takeover_anatomie_v2_arbeitsset.zip` enthält eine weitere 768×1216-RGBA-PNG-Unterzeichnung (`assets/anatomie_v2.png`) und einen Vierfachvergleich: bestätigte Referenz, fehlende Mantelanatomie, V1 und V2. Die V2 überträgt sichtbare Original-Hauttexturen auf organischere Schulterbereiche und ist **ein reproduzierbarer Retuscheversuch**, keine echte freigegebene Neuzeichnung. Die Muskel-/Stoffübergänge weichen erkennbar vom bestätigten Anime-Detailgrad ab. Ihre Erzeugungsdatei liegt im ZIP für die Weiterbearbeitung.

Sie kann im privaten `?art=layers`-Prüfmodus über **«Eigene Körperzeichnung»** geladen werden. Weder die produktiven Grafikflags noch die Shop-Auswahl ändern sich. Eine aus dieser Studie abgeleitete Shop-Freigabe ist ausdrücklich ausgeschlossen.

## Drop-in-Originalgrafiken und Ein-Klick-Test im Studio (30. Oktober 2026)

Das neue Paket **`takeover_pr79_originalgrafiken_dropin.zip`** (separat beim Nutzer bereitgestellt) enthält bereits die **acht binären Original-PNGs** in der endgültigen relativen Repository-Ordnerstruktur **plus das deaktivierte JS-Manifest**. Die beiden Manteldateien heissen im Repo `coatback.png` und `coatfront.png` (Kleinschreibung für die strengen Validator-Pfade); ihre Bildbytes bleiben mit den bestätigten SHA-256-Prüfsummen **identisch**. Die Zusammensetzung aller Ebenen wurde nochmals gegen `composited-proof.png` pixelgenau geprüft (maximale RGBA-Abweichung 0).

**Für Entwicklerinnen und Entwickler mit PR-Checkout:**

1. Branch `design/mein-boxer-sticky-webapp-20261030` auschecken.
2. Das Drop-in-ZIP im Repository-Hauptverzeichnis entpacken. Das Paket enthält die notwendigen Verzeichnisse `assets/boxer-artpacks/v1/cool/` und `takeover-mein-boxer-artpack-manifest.js`; keine manuellen Umbenennungen nötig. Vorhandene abweichende Dateien nicht unkontrolliert überschreiben.
3. `node scripts/validate-boxer-artpack.cjs` und `node tests/import-original-cool-contracts.cjs` ausführen. Der Paketzustand ist weiterhin `approved:false`, `enabled:false`.
4. Lokalen HTTP-Server starten und `mein-boxer.html?art=layers` öffnen. Nach Login im Bereich «Grafikebenen prüfen» auf **«Originalebenen aus Testbranch laden»** klicken. Acht Image-Requests erfolgen direkt vom gleichen Server; jede Datei wird **vor der Anzeige erneut mit SHA-256** gegen die freigegebenen Ursprungspixel überprüft.
5. Fehlt auch nur eine Datei, weicht ein Hash ab, oder sind die Referenzgrafiken noch nicht auf dem lokalen Server vorhanden, bleibt der bisherige **SVG-Boxer** sichtbar. Der manuelle Acht-PNG-Wähler bleibt als Alternative verwendbar. Auch während des Ladens können neuere manuelle Auswahlen den älteren Remote-Ladevorgang nicht unbeabsichtigt überschreiben.
6. Nach Prüfung: Änderungen **nur auf dem PR-Branch** committen und pushen, wenn gewünscht. Die Lieferung dieses ZIPs an den Nutzer ist **kein automatischer GitHub-Binary-Upload**.

Automatische Abnahme: `tests/mein-boxer-installed-art-contracts.cjs` prüft das Ein-Klick-Laden mit korrekten und falschen acht Hashes, gleich-origin Pfade, lokale Blob-URL-Bereinigung und Erhalt bereits valider Grafiken bei Fehlern. `tests/boxer-holo-browser.cjs` bestätigt den sicheren SVG-Fallback bei fehlenden Repo-Dateien. Staging-CI testet beides.

**Keine Produktfreigabe:** Das Paket stellt ausschliesslich die eine bestätigte, noch nicht frei umkleidbare Cool-Pose bereit. Es werden keine neuen Kleidungs-, Haut- oder Frisurenvarianten erfunden. Das Produktionsmanifest bleibt absichtlich deaktiviert, das öffentliche Profil und der Shop nutzen weiterhin das vorhandene Holo.

## PR-Abnahme: Originalgrafiken wirklich im Repository? (30. Oktober 2026)

Nach dem Import des zuvor bereitgestellten Git-Binärpatches gibt es eine **eindeutige automatische Abnahme statt bloss grüner Funktions-Mocks**:

- `node tests/boxer-original-art-readiness.cjs` läuft in GitHub Actions und zeigt im Job Summary entweder **PENDING (0/8)** oder **VERIFIED (8/8)**. **PENDING bedeutet ausdrücklich, dass die Original-PNGs nicht im PR vorhanden und noch nicht in einem echten Browser abgenommen sind**, selbst wenn sämtliche allgemeinen Tests grün sind.
- Sobald **eine** der acht Dateien hinzugefügt wurde, muss das Paket vollständig sein. Jede Datei wird anhand ihrer **exakten SHA-256-Prüfsumme** kontrolliert; die acht Einträge des noch deaktivierten Cool-Pose-Manifests müssen die korrekten kleingeschriebenen GitHub-Pfade referenzieren. Fehlende, veränderte oder nicht originalgetreue Dateien schlagen in CI fehl.
- `tests/boxer-original-art-readiness-contracts.cjs` deckt die Zustände fehlende, teilweise vorhandene, gefälschte und falsch referenzierte Dateien ab.
- `tests/boxer-holo-browser.cjs` verwendet die acht **tatsächlich im PR eingecheckten** PNGs ohne Mocks, sobald sie vorhanden sind. Der Browser lädt die echten Dateien mit dem Ein-Klick-Button, verifiziert die Hashwerte, prüft identische Leinwand-/Bildpositionen, erstellt `holo-original-8-repository-art.png` und testet den vollständigen SVG-Fallback beim Kleidungswechsel.
- Es gibt **keinen automatischen Übergang zu `approved:true` oder `enabled:true`**. Die originalen sichtbaren Pixel sind weiterhin nur eine künstlerische Cool-Pose-Referenz, nicht die fertig umkleidbare Anime-Figur.

**Erledigt:** Der Originalimport ist seit `f4d8b6e` im PR-Branch enthalten. Der ZIP-Patch muss nicht erneut angewendet werden. Die Originalprüfung meldet VERIFIED (8/8). Nächster Schritt ist die visuelle Abnahme und hochwertige Ergänzung der in `MEIN_BOXER_ART_GAPS.md` beschriebenen Körper- und Ausrüstungsebenen.
