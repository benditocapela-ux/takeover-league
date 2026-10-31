# Premium-Produktion: überprüfbarer Stand aller 58 Katalogeinträge

Automatisch aus vorhandenem Inventar, tatsächlichen PNG-Dateien, Registrierungen, SHA-256 und aktuellem Browser-Testbericht erzeugt. Keine Live-Datenbankabfrage. Der historische PR-81-Stand bleibt in `coverage.csv`; die aktuelle Produktionsmatrix steht in `production-coverage.csv` und `production-coverage.json`.

**41/58 Katalogeinträge mit nachgewiesenen Grafikquellen; 40/58 mit aktueller technischer Testabdeckung; 0 freigegeben.**

Gesamtmatrix: 1800 Zeilen. Grafikquellen für 205 unterschiedliche Varianten-Schlüssel bzw. 410 Posezellen. Technisch integriert und geprüft: 204 Varianten-Schlüssel / 407 Posezellen. Gegenüber dem historischen SVG-only-Stand neu: 386 Posezellen; 194 Schlüssel gewinnen neue Poseabdeckung, davon waren 193 vorher in keiner Premium-Pose vorhanden. Haut- und Augenfarben sind zusätzlich enthalten, aber keine neuen Shop-Items.

**Zählweise:** Varianten-Schlüssel = Slot, Itemwert, Farbe und Zustand; jede Pose wird zusätzlich als Posezelle gezählt. Das ist keine Anzahl aller kombinierbaren Outfits und keine Anzahl neuer PNGs. Ein Teil mit zwei Posen zählt nur einmal als Varianten-Schlüssel.

Technisch geprüft sind 192 Raster-/Materialvarianten und 12 prozedurale Canvas-Varianten. Effekte/Szenen werden ausdrücklich nicht als neue PNG-Illustrationen gezählt. Glatze entfernt die Haare; die acht zulässigen Haarfarbwerte erzeugen dabei dasselbe Bild.

Technische Evidenz: aktueller, hashgebundener Chromium-/WebKit-Bericht vorhanden.

Status getrennt: `SVG only` = keine verifizierte passende Grafik; `Artwork draft` = Datei und Registrierung vorhanden; `Technically validated` = passende Variante im aktuellen Bericht beider Engines und gültige Quellhashes; `Artistically pending` = persönliche Designabnahme offen. `Approved` wird durch dieses Skript niemals gesetzt. Auch ein technisch geprüfter Entwurf bleibt deaktiviert.

| Item-Key | Name | Grafikvarianten / vorhanden | Technisch geprüft | geprüfte Posen | Status |
|---|---|---:|---:|---|---|
| hair_kurz_glatt | Kurz glatt | 8/8 | 8/8 | guard, cool | Artwork draft; Technically validated; Artistically pending |
| hair_stachel | Stachel | 8/8 | 8/8 | guard, cool | Artwork draft; Technically validated; Artistically pending |
| hair_lang_glatt | Lang glatt | 0/8 | 0/8 | – | SVG only; Not validated; Not applicable |
| hair_undercut | Undercut | 8/8 | 8/8 | guard, cool | Artwork draft; Technically validated; Artistically pending |
| hair_buzz | Buzzcut | 8/8 | 8/8 | guard, cool | Artwork draft; Technically validated; Artistically pending |
| hair_glatze | Glatze | 8/8 | 8/8 | guard, cool | Artwork draft; Technically validated; Artistically pending |
| hair_dutts | Zwei Dutts | 0/8 | 0/8 | – | SVG only; Not validated; Not applicable |
| hair_zopf | Pferdeschwanz | 0/8 | 0/8 | – | SVG only; Not validated; Not applicable |
| hair_bob | Bob | 0/8 | 0/8 | – | SVG only; Not validated; Not applicable |
| hair_wellig | Wellig | 8/8 | 8/8 | guard, cool | Artwork draft; Technically validated; Artistically pending |
| hair_locken | Locken | 8/8 | 8/8 | guard, cool | Artwork draft; Technically validated; Artistically pending |
| hair_afro | Afro | 8/8 | 8/8 | guard, cool | Artwork draft; Technically validated; Artistically pending |
| hair_afro_puffs | Afro-Puffs | 8/8 | 8/8 | guard, cool | Artwork draft; Technically validated; Artistically pending |
| hair_locs | Locs | 0/8 | 0/8 | – | SVG only; Not validated; Not applicable |
| hair_box_braids | Box Braids | 0/8 | 0/8 | – | SVG only; Not validated; Not applicable |
| hair_cornrows | Cornrows | 8/8 | 8/8 | guard, cool | Artwork draft; Technically validated; Artistically pending |
| hair_twists | Twists | 8/8 | 8/8 | guard, cool | Artwork draft; Technically validated; Artistically pending |
| hair_high_top | High-Top Fade | 8/8 | 8/8 | guard, cool | Artwork draft; Technically validated; Artistically pending |
| head_cap | Kappe | 8/8 | 8/8 | guard, cool | Artwork draft; Technically validated; Artistically pending |
| head_band | Stirnband | 8/8 | 8/8 | guard, cool | Artwork draft; Technically validated; Artistically pending |
| head_hijab | Sport-Hijab | 0/8 | 0/8 | – | SVG only; Not validated; Not applicable |
| top_tank | Tanktop | 8/8 | 8/8 | guard, cool | Artwork draft; Technically validated; Artistically pending |
| top_shirt | T-Shirt | 1/8 | 0/8 | – | Artwork draft; Not validated; Artistically pending |
| top_hoodie | Hoodie | 0/16 | 0/16 | – | SVG only; Not validated; Not applicable |
| top_jacke | Trainingsjacke | 0/8 | 0/8 | – | SVG only; Not validated; Not applicable |
| bottom_boxer | Boxershorts | 8/8 | 8/8 | guard, cool | Artwork draft; Technically validated; Artistically pending |
| bottom_kurz | Kurze Hose | 8/8 | 8/8 | guard, cool | Artwork draft; Technically validated; Artistically pending |
| bottom_jogger | Jogginghose | 8/8 | 8/8 | guard, cool | Artwork draft; Technically validated; Artistically pending |
| bottom_track | Trainingshose | 8/8 | 8/8 | guard, cool | Artwork draft; Technically validated; Artistically pending |
| glove_rot | Rot | 1/1 | 1/1 | guard, cool | Artwork draft; Technically validated; Artistically pending |
| glove_weiss | Weiss | 1/1 | 1/1 | guard, cool | Artwork draft; Technically validated; Artistically pending |
| glove_schwarzgold | Schwarz-Gold | 1/1 | 1/1 | guard, cool | Artwork draft; Technically validated; Artistically pending |
| glove_eisblau | Eisblau | 1/1 | 1/1 | guard, cool | Artwork draft; Technically validated; Artistically pending |
| glove_glut | Glut | 1/1 | 1/1 | guard, cool | Artwork draft; Technically validated; Artistically pending |
| feet_boots | Boxstiefel | 8/8 | 8/8 | guard, cool | Artwork draft; Technically validated; Artistically pending |
| feet_sneaker | Sneaker | 8/8 | 8/8 | guard, cool | Artwork draft; Technically validated; Artistically pending |
| coat_basic | Trainer-Mantel | 1/1 | 1/1 | guard | Artwork draft; Technically validated; Artistically pending |
| coat_samurai | Samurai-Jacke | 1/1 | 1/1 | guard, cool | Artwork draft; Technically validated; Artistically pending |
| coat_neon | Neon-Mantel | 0/1 | 0/1 | – | SVG only; Not validated; Not applicable |
| coat_drache | Drachen-Mantel | 0/1 | 0/1 | – | SVG only; Not validated; Not applicable |
| aura_flamme | Flamme | 1/1 | 1/1 | guard, cool | Artwork draft; Technically validated; Artistically pending |
| aura_sakura | Sakura | 1/1 | 1/1 | guard, cool | Artwork draft; Technically validated; Artistically pending |
| aura_blitz | Blitz | 1/1 | 1/1 | guard, cool | Artwork draft; Technically validated; Artistically pending |
| aura_schatten | Schatten | 1/1 | 1/1 | guard, cool | Artwork draft; Technically validated; Artistically pending |
| eyefx_kristall | Kristall | 1/1 | 1/1 | guard, cool | Artwork draft; Technically validated; Artistically pending |
| eyefx_glut | Glut-Flamme | 1/1 | 1/1 | guard, cool | Artwork draft; Technically validated; Artistically pending |
| eyefx_stern | Stern | 1/1 | 1/1 | guard, cool | Artwork draft; Technically validated; Artistically pending |
| eyefx_mond | Mond | 1/1 | 1/1 | guard, cool | Artwork draft; Technically validated; Artistically pending |
| scene_holo | Holo-Plattform | 1/1 | 1/1 | guard, cool | Artwork draft; Technically validated; Artistically pending |
| scene_dojo | Dojo | 1/1 | 1/1 | guard, cool | Artwork draft; Technically validated; Artistically pending |
| scene_neon | Neon-Stadt | 1/1 | 1/1 | guard, cool | Artwork draft; Technically validated; Artistically pending |
| scene_arena | Arena | 1/1 | 1/1 | guard, cool | Artwork draft; Technically validated; Artistically pending |
| pose_guard | Kampfstellung | 0/1 | 0/1 | – | SVG only; Not validated; Not applicable |
| pose_jab | Jab | 0/1 | 0/1 | – | SVG only; Not validated; Not applicable |
| pose_sieg | Siegerpose | 0/1 | 0/1 | – | SVG only; Not validated; Not applicable |
| pose_cool | Cool | 0/1 | 0/1 | – | SVG only; Not validated; Not applicable |
| pose_flex | Bizeps | 0/1 | 0/1 | – | SVG only; Not validated; Not applicable |
| pose_ansage | Ansage | 0/1 | 0/1 | – | SVG only; Not validated; Not applicable |

Posen, Szenen und Effekte behalten die vorhandene prozedurale/SVG-Darstellung, solange keine tatsächlich integrierte Premium-Familie nachgewiesen ist. Neue Canvas-Effekte sind separat als Canvas ausgewiesen. Ein Guard-Pilot macht nicht sämtliche sechs Pose-Items zu fertigen Illustrationen.

Reproduktion: `node scripts/inventory-premium-production.cjs`. Der technische Bericht liegt unter `docs/premium-v2/evidence/production-tests.json`; er muss `passed:true`, beide Engines, `validatedVariants` und passende `sourceHashes` enthalten. Hashverfahren `sha256-canonical-text-lf-v1`: UTF-8-Text normalisiert CRLF zu LF, PNG-/Binärdateien verwenden unveränderte Bytes. Damit lassen sich Windows- und Linux-Checkouts vergleichen. Fehlender oder veralteter Bericht fällt automatisch auf Entwurfsstatus zurück. Noch nicht kompatible vollständige Outfits müssen im Labor und im normalen Editor vollständig SVG bleiben.

Alle gezählten Rasterquellen haben passende PNG-Abmessungen, nichtleere Alpha-Pixel und SHA-256; Canvas-Quellen sind als Code separat verifiziert. Diese Checks ersetzen keine Sichtprüfung von Anatomie, Stoff, Verdeckung oder Materialien.
