# PR #79: technische Abnahme und Freigabegrenzen

Stand: 31.10.2026. Ausgangscommit `080bcf81dd5d56ce2e2d1662395534a56c37d978`. Dieser Meilenstein verändert keine Bilder, Ausstattungswerte, RPCs oder Datenbankmigrationen.

## Ergebnis und Grenzen

**Technisch für die manuelle Freigabe vorbereitet**, sofern die verpflichtenden GitHub-Prüfungen des jeweils aktuellen Heads grün sind. Es wurde kein verbleibender P0-/P1-Fehler festgestellt. Das ist keine persönliche Designabnahme und keine Merge-Erlaubnis. PR #79 bleibt Draft. Beide Manifeste bleiben `approved:false`, `enabled:false`. Kein Merge, Deployment oder Zugriff zur Änderung produktiver Supabase-Daten wurde vorgenommen.

Die Produktion verwendet weiterhin SVG. `?art=modular` öffnet nur die explizite Entwurfsvorschau; im ausgelieferten Dateiumfang fehlen die Entwurfs-PNGs, sodass auch diese URL sicher zu SVG zurückfällt. Keine automatischen Save-/Buy-Aufrufe entstehen durch Vorschau, Posewechsel oder Reset.

## Änderungen dieses Meilensteins

- Zentrale, unveränderliche Gelenkmetadaten aus der bestehenden SVG-Pose-Tabelle. Keine zweite Koordinatenquelle, kein neuer Renderer und keine Änderung gespeicherter Schlüssel. 150 SVG-Ausgaben über sechs Posen, fünf Oberteile und fünf Mantelzustände sind bytegleich zum Ausgangscommit.
- Der reale Pages-Workflow und isolierte Tests verwenden denselben `tools/assemble-pages-site.cjs`. Die bisherige Dateiauswahl und der bestehende Artwork-Publisher bleiben erhalten. Ein bereits befülltes Zielverzeichnis wird abgewiesen, damit alte Medien nicht unbemerkt in einem wiederverwendeten Build verbleiben.
- Architektur-, Build- und Browserregressionen: sämtliche Posen, getrennte Profil-/Kartenpose, Save-Race, Reset/Reload, verspätete Bilder und fehlende Draft-Dateien im tatsächlichen Dateizusammenbau.
- Bestehende Workflow-Vertragstests auf den gemeinsamen Assembler umgestellt; Navigation prüft tatsächlich kopierte Dateien. Der Symlink-Ausbruchtest des Artwork-Publishers nutzt unter Windows eine Directory Junction, unter Linux einen Verzeichnis-Symlink, ohne den Schutztest zu überspringen.

## Validierung

| Bereich | Ergebnis / Nachweis |
| --- | --- |
| Echte modulare PNGs | Chromium und WebKit je 32 Outfits + 16 fokussierte Handschuhansichten; Pixelabdeckung, freie Unterarme, Alpha-Versatz, atomarer Wechsel und Ladefehler bestanden |
| Posen und Zustand | Neue Browserregression in beiden Engines: alle sechs Posen; fünf nicht unterstützte Rasterposen exakt mit erwarteter SVG-Ausgabe verglichen; Profil/Karte unabhängig; Save während weiterer Änderung, Reset und Reload bestanden |
| Layout / Tastatur | Beide Engines: Mein Boxer 375×812, 390×844, 430×932, 768×1024, 1440×900, Resize; zusätzliche Studio-Breiten 360–1600; Original-PNG mobile/desktop bestanden |
| Shop / Inventar | Bestehende Transaktionstests: Einzel-/Bundlekauf, Doppelbestätigung, fehlende/fehlerhafte Inventarantwort, optionale Leistungsabfrage und gekaufte Ausstattung speichern bestanden; lokale RPC-Mocks |
| Bestehende Integration | Boxer-Holo-Browsertest: Frisuren/Hauttöne/Kleidung, Speichern, Anprobe, Kauf/Bundle, Profil-/Kartenposen und deaktiviertes Flag bestanden |
| Verträge / Sicherheit | Artpack-, Editor-, Preload-, Publisher-, Architektur-, Build-, Accessibility-, Release- und weitere bestehende Staging-Verträge; vollständige Linux-CI ist die abschließende Referenz |
| Build-Dateiumfang | Isoliert: 66 Rootdateien, 14 Avatar-Dateien, 0 freigegebene Premium-PNGs; keine Entwurfsbilder, Tests/Tools/Docs/Secrets-Verzeichnisse oder drei ausgeschlossene Previewseiten |
| Darstellungsfehler | Keine unerwarteten `pageerror` in neuen Szenarien; erwartete 404 bei absichtlich fehlenden Draft-PNGs führen zur vollständigen SVG-Figur |
| Grafikbestand | Keine Assetänderung in diesem Meilenstein; SHA-Prüfung der acht Originale bestanden; Handschuhstil nicht verändert |

Unter Windows kann der bestehende ZIP-Importtest wegen fehlendem `zip`-Programm nicht laufen; er bleibt unverändert im Linux-CI und muss dort bestehen. Das ist keine übersprungene CI-Prüfung. Alle relevanten CI-Läufe und Ergebnisse sind am aktuellen PR-Head verknüpft; ältere grüne Commits ersetzen diese Prüfung nicht.

Die isolierte Browserprüfung verwendet den echten Dateizusammenbau und beide unveränderten Manifeste. Nachrichtenabfrage, Release-Metadaten/Cachebusting, Upload und Deployment des Pages-Workflows wurden **nicht** als Produktionslauf ausgeführt. Deren bestehende Workflow-Prüfungen bleiben erhalten. Der Workflow ist weiterhin auf `main` begrenzt; dieser PR löst keinen Pages-Release aus.

## Befunde nach Schwere

- **P0/P1:** keine verbleibenden Fehler in den geprüften Szenarien gefunden.
- **P2:** potenziell veraltete Build-Dateien in wiederverwendetem Staging werden jetzt durch ein erforderliches leeres Ziel verhindert. Keine weitere relevante offene P2-Regression festgestellt.
- **Testanpassung:** alte Shell-String-Erwartungen und Windows-Symlink-Erstellung waren Test-/Umgebungsprobleme, keine Darstellungsfehler.
- **Design:** Handschuhposition anatomisch technisch abgeschlossen; Handschuhstil und Übereinstimmung von Gesicht/Anatomie mit der gewünschten Anime-Originalreferenz bleiben dem finalen künstlerischen Pass vorbehalten.
- **Bewusste Funktionsgrenze:** Nur Cool und 32 Kombinationen haben diesen modularen PNG-Satz. Die anderen Posen/Varianten werden korrekt als SVG dargestellt. Das ist weder ein unsichtbarer Boxer noch eine Zusage vollständiger Anime-Ausstattung.

## Konflikte und Performance

Beim Abgleich ist `main` (`8176e8014d134136ba210ced37b230cd61190ac8`) Vorfahr des PR-Heads; der Ausgangsstand lag 0 Commits hinter und 199 vor main. GitHub meldete den PR als konfliktfrei zusammenführbar. Vor einer späteren Freigabe erneut prüfen; das ersetzt keinen Merge und rechtfertigt kein Überschreiben fremder Änderungen.

Kein neuer Laufzeit-Renderer, keine neue Runtime-Abhängigkeit. Drei parallele Preloads und deduplizierte Requests bleiben erhalten. Die Texturspeicherschätzung und Grenzen für einen größeren Posekatalog stehen in der [Architekturentscheidung](BOXER_CHARACTER_ARCHITECTURE.md); es wurde kein physisches Geräte-/GPU-Speicherprofil erhoben.

## Noch manuell erforderlich

1. Persönlicher Vergleich mit der Anime-Originalreferenz, insbesondere zurückgestellter Handschuhstil, Gesicht/Anatomie und Kombinationen. Technische Pixelprüfungen ersetzen diese Entscheidung nicht.
2. Physisches iPhone/Safari und mindestens ein Android-Gerät: dynamische Browserleisten, Hoch-/Querformat, Scroll/Sticky, Touch, Speicherverhalten. WebKit-Automation ist kein physischer iPhone-Test.
3. Tatsächliche Screenreader-Prüfung mit VoiceOver oder NVDA ergänzen. Tastatur, Fokus, Semantik und automatisierte Accessibility-Verträge sind geprüft; echte assistive Bedienung wurde nicht behauptet.
4. Aktuellen Head, CI und Konfliktstatus prüfen; anschließend ausdrückliche Freigabe einholen. Erst danach separat über Merge entscheiden. Premium-Aktivierung ist eine eigenständige Entscheidung nach Grafikabnahme und passenden Auslieferungsprüfungen; Flags bleiben bis dahin aus.

Strategie, Wiederverwendung, Risiken und Aufwand je Ausbauphase: [BOXER_CHARACTER_ARCHITECTURE.md](BOXER_CHARACTER_ARCHITECTURE.md). Dieser Auftrag implementiert keine weiteren Posen und kein Rig.
