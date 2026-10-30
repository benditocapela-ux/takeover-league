# Takeover League · Anime-Art-Pipeline für «Mein Boxer»
Stand: 30.10.2026 · Ergänzung zu Draft-PR #79

## Ziel und Freigabestatus

Die ursprüngliche Navy-/Gold-/Cyan-Vorlage mit ernstem Anime-Boxer, gekreuzten Armen und schwarz-goldener Ausrüstung ist **verbindlich**. Die aktuelle SVG-Figur ist die belastbare Rückfalllösung, aber kein fertiger Nachbau dieser Illustration. Externe Grafikpakete aus Scenario, Layer AI oder einer professionellen Illustration können eingebaut werden, ohne die bestehenden Supabase- und Shop-Funktionen zu ersetzen.

**Zurzeit sind keine Produktions-Assets freigegeben.** Die Manifest-Datei `takeover-mein-boxer-artpack-manifest.js` steht deshalb auf `approved:false` und enthält keine Posen. In der publizierten App ändert sich am Boxer durch diese Pipeline nichts.

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
