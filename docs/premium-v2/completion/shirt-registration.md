# Flex-Shirt: Schulterkorrektur und Abschlussprüfung

Die aufgesetzten Schulterpolster der Flex-Pose sind durch eine zusammenhängende, auf den vorhandenen Körper registrierte Shirtgrafik ersetzt. Halsöffnung, Armloch, kurze Ärmel und Saum passen zum unveränderten Körper. Es gibt keine CSS-Verschiebung und keine neue Hautmaske.

## Ursache und Umsetzung

Die frühere kurze Ärmelquelle verwendete die Anker des langen Mantelarms. Ihr Distalpunkt lag ausserhalb des kurzen Ausschnitts; die getrennten Ärmel überlappten den Torso wie Schulterpolster. Eine reine Ankeränderung behob die fehlende gemeinsame Armlochkontur nicht.

`completion/shirt.json` registriert `completion/assets/shirt-registered.png`: 1229 × 1280 Quellpixel auf dem festen Körperraum 768 × 800, SHA-256 `04005e7022a67409e7e31657966b9c2e61d0a1081500ccfc2374d5deb058bc92`. Die unveränderte Generatorausgabe wird ausschliesslich für Flex + Shirt gewählt. Der vorhandene semantische Materialschlüssel bleibt erhalten; sämtliche Shirtfarben verwenden diese eine Quelle.

Figur und Auswahlkachel zeichnen dasselbe Piece. Der engere Kachelrahmen enthält nur das Shirt. Unter Samurai/Basic wird nur die getragene Shirtfläche auf den inneren Torso begrenzt; die isolierte Kachel zeigt das vollständige Shirt. Handschuhe, Körper, Unterteile, Besitz, Preise und Speicherpfade sind unverändert. Die Datei wird im bestehenden versionierten Veröffentlichungspaket genau einmal kopiert. Keine neue Laufzeitbibliothek.

Die neue PNG hat 468674 Bytes und benötigt dekodiert 6292480 Bytes. Gegenüber den bisherigen beiden Flex-Shirtquellen zusammen sind das 128182 zusätzliche Dateibytes und 4788232 zusätzliche dekodierte Quellbytes. Die bestehenden Lade-/Materialcachegrenzen bleiben unverändert. Es wird kein allgemeiner Performancegewinn behauptet. Andere Posen fordern die neue PNG nicht an.

Die beiden tatsächlichen Generierungsprompts und Quellreferenzen stehen in [shirt-provenance.json](shirt-provenance.json).

## Tatsächliche Prüfungen

Ausgangscommit: `6aad6108dbf59e3f800cf42b4cdea8dec7e26b26`, Ausgangs-Premiumversion `eb1613831caef596`. Kandidatenversion: `dc1a2df1a29ec58c`.

`tests/premium-shirt-registration-browser.cjs` baut beide Stände getrennt und vergleicht sie in derselben Browserengine. Der Ausgangsstand wird bei Bedarf reproduzierbar aus dem festen Git-Commit erstellt; fehlende Historie oder geänderte Baseline-Dateien führen zum Fehler.

Die PNG-Paritätsreferenz verwendet wie der veröffentlichte Adapter einen frischen Standard-Canvas, einen identischen Skalierungsschritt und genau einen PNG-Roundtrip. Diagnose-Readbacks laufen getrennt. Damit werden nicht unterschiedliche WebKit-Raster-/Alpha-Pfade verglichen. Jeder abweichende RGBA-Bytewert oder jede abweichende Bildgrösse bleibt ein Fehler; es gibt keine Pixeltoleranz. Dieser Vergleich steht im CI unmittelbar nach der Browserinstallation.

Chromium und WebKit jeweils bestanden:

- 54 Outfits: sechs Posen × Schwarz/Rot/Weiss × ohne Mantel/Samurai/Basic.
- Alle 45 Outfits der fünf anderen Posen vollständig pixelgleich zur Baseline.
- Hände und Unterteile aller 36 Kombinationen von Flex/Jab/Sieg/Ansage pixelgleich.
- Alle 54 Shirtkacheln exakt gleich der isolierten tatsächlichen Shirtgrafik, einschliesslich PNG-Roundtrip.
- Keine neue Shirt-PNG-Anfrage für Cool/Guard und für die drei anderen Posen in frischen Browserkontexten.
- Tatsächlicher veröffentlichungsnaher Editor bei 390 px: vier Posewechsel, richtige Figur und Kachel, keine Kontoschreibaufrufe.
- Neue PNG liefert 404: vollständiger SVG-Fallback mit wahrheitsgemässem Kachelstatus. Ein anschliessender Wechsel zu Jab bleibt Anime-fähig.

100-/200-%-Schulterbilder, Vorher-/Nachher-Kontaktblätter, Editorbilder und Fehleransicht liegen unter `output/shirt-qa/` und im CI-Artefakt `premium-production-proof`. Der strukturierte lokale Nachweis ist [shirt-browser-report.json](shirt-browser-report.json). Die Flex-Kontaktblätter sowie schwarze/weisse und rote Shirt-/Manteldetails wurden visuell geprüft. Das ist keine neue künstlerische Freigabe der fünf unveränderten Posen und keine physische Geräteabnahme.

Zusätzlich erneut bestanden: bestehende Editor-Preview-Suite und Live-Editor-Suite in beiden Engines; 1764 katalogisierte Material-/Item-Varianten je Engine; 20 registrierte PNG-Referenzen mit exakten SHA-256 und gültigen Ausschnitten; 33 statische Release-Verträge. Die Variantenberichte wurden durch tatsächliches Neuzeichnen erzeugt.

## Wiederverwendung: nachgewiesene Grenze

Für Jab/Sieg/Ansage wurden sowohl Armachsen als auch ein anatomischer Käfig untersucht. Ein CPU-Rasterer beseitigte die Dreiecksnähte und bewahrte Alpha ohne Doppeldeckung. Der abschliessende Käfig hatte 28 Punkte, 34 Dreiecke und in allen drei Posen null invertierte oder degenerierte Dreiecke. Dennoch blieben bei 200 % sichtbare Hautkeile, kantige Schultern und verzerrte Stoffkonturen.

**Ergebnis: eine direkt passende Pose, null von drei geprüften zusätzlichen Posen künstlerisch freigegeben.** Diese Versuche wurden nicht in den Runtime-Code übernommen. Die bisherigen drei Posen bleiben bytegenau erhalten. Der Prototyp und die verworfenen Bilder liegen unter `output/shirt-registered/`; [shirt-reuse-review.json](shirt-reuse-review.json) hält Messungen und Ablehnungsgründe fest.

Ein späterer Wiederverwendungsauftrag braucht ein für grosse Schulterrotationen geeignetes Armloch-/Ärmelmodell mit geprüfter Verdeckung und eigenen kurzen Cuff-Ankern. Weitere Massengenerierung ist durch diesen Versuch nicht begründet.

PR #94 bleibt Draft. Kein Merge, Deployment, Produktionsschreibzugriff oder Flagwechsel.
