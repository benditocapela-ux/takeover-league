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
- **Dateivalidierung:** Vor der Freigabe `node scripts/validate-boxer-artpack.cjs` ausführen. Die Prüfung kontrolliert erlaubte lokale Pfade, 768×1216 Pixel, PNG-/WebP-Transparenzkennzeichen und maximal 2 MiB pro Datei. Der CI-Workflow führt dieselbe Prüfung aus. Bei `approved:false` wird die produktive Dateiprüfung bewusst übersprungen.
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
