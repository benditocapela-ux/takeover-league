# Premium-Produktion: überprüfbarer Stand aller 58 Katalogeinträge

Automatisch aus vorhandenem Inventar, tatsächlichen PNG-Dateien, Registrierungen, SHA-256 und aktuellem Browser-Testbericht erzeugt. Keine Live-Datenbankabfrage. Der historische PR-81-Stand bleibt in `coverage.csv`; die aktuelle Produktionsmatrix steht in `production-coverage.csv` und `production-coverage.json`.

**21/58 Katalogeinträge mit nachgewiesenen Grafikquellen; 20/58 mit aktueller technischer Testabdeckung; 0 freigegeben.**

Gesamtmatrix: 1800 Zeilen. Grafikquellen für 121 unterschiedliche Varianten-Schlüssel bzw. 241 Posezellen. Technisch integriert und geprüft: 120 Varianten-Schlüssel / 240 Posezellen. Gegenüber dem historischen SVG-only-Stand neu: 110 Varianten-Schlüssel / 220 Posezellen. Haut- und Augenfarben sind zusätzlich enthalten, aber keine neuen Shop-Items.

**Zählweise:** Varianten-Schlüssel = Slot, Itemwert, Farbe und Zustand; jede Pose wird zusätzlich als Posezelle gezählt. Das ist keine Anzahl aller kombinierbaren Outfits und keine Anzahl neuer PNGs. Ein Teil mit zwei Posen zählt nur einmal als Varianten-Schlüssel.

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
| hair_wellig | Wellig | 0/8 | 0/8 | – | SVG only; Not validated; Not applicable |
| hair_locken | Locken | 0/8 | 0/8 | – | SVG only; Not validated; Not applicable |
| hair_afro | Afro | 8/8 | 8/8 | guard, cool | Artwork draft; Technically validated; Artistically pending |
| hair_afro_puffs | Afro-Puffs | 0/8 | 0/8 | – | SVG only; Not validated; Not applicable |
| hair_locs | Locs | 0/8 | 0/8 | – | SVG only; Not validated; Not applicable |
| hair_box_braids | Box Braids | 0/8 | 0/8 | – | SVG only; Not validated; Not applicable |
| hair_cornrows | Cornrows | 0/8 | 0/8 | – | SVG only; Not validated; Not applicable |
| hair_twists | Twists | 0/8 | 0/8 | – | SVG only; Not validated; Not applicable |
| hair_high_top | High-Top Fade | 0/8 | 0/8 | – | SVG only; Not validated; Not applicable |
| head_cap | Kappe | 1/8 | 1/8 | guard, cool | Artwork draft; Technically validated; Artistically pending |
| head_band | Stirnband | 1/8 | 1/8 | guard, cool | Artwork draft; Technically validated; Artistically pending |
| head_hijab | Sport-Hijab | 0/8 | 0/8 | – | SVG only; Not validated; Not applicable |
| top_tank | Tanktop | 1/8 | 0/8 | – | Artwork draft; Not validated; Artistically pending |
| top_shirt | T-Shirt | 0/8 | 0/8 | – | SVG only; Not validated; Not applicable |
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
| coat_basic | Trainer-Mantel | 0/1 | 0/1 | – | SVG only; Not validated; Not applicable |
| coat_samurai | Samurai-Jacke | 1/1 | 1/1 | guard, cool | Artwork draft; Technically validated; Artistically pending |
| coat_neon | Neon-Mantel | 0/1 | 0/1 | – | SVG only; Not validated; Not applicable |
| coat_drache | Drachen-Mantel | 0/1 | 0/1 | – | SVG only; Not validated; Not applicable |
| aura_flamme | Flamme | 0/1 | 0/1 | – | SVG only; Not validated; Not applicable |
| aura_sakura | Sakura | 0/1 | 0/1 | – | SVG only; Not validated; Not applicable |
| aura_blitz | Blitz | 0/1 | 0/1 | – | SVG only; Not validated; Not applicable |
| aura_schatten | Schatten | 0/1 | 0/1 | – | SVG only; Not validated; Not applicable |
| eyefx_kristall | Kristall | 0/1 | 0/1 | – | SVG only; Not validated; Not applicable |
| eyefx_glut | Glut-Flamme | 0/1 | 0/1 | – | SVG only; Not validated; Not applicable |
| eyefx_stern | Stern | 0/1 | 0/1 | – | SVG only; Not validated; Not applicable |
| eyefx_mond | Mond | 0/1 | 0/1 | – | SVG only; Not validated; Not applicable |
| scene_holo | Holo-Plattform | 0/1 | 0/1 | – | SVG only; Not validated; Not applicable |
| scene_dojo | Dojo | 0/1 | 0/1 | – | SVG only; Not validated; Not applicable |
| scene_neon | Neon-Stadt | 0/1 | 0/1 | – | SVG only; Not validated; Not applicable |
| scene_arena | Arena | 0/1 | 0/1 | – | SVG only; Not validated; Not applicable |
| pose_guard | Kampfstellung | 0/1 | 0/1 | – | SVG only; Not validated; Not applicable |
| pose_jab | Jab | 0/1 | 0/1 | – | SVG only; Not validated; Not applicable |
| pose_sieg | Siegerpose | 0/1 | 0/1 | – | SVG only; Not validated; Not applicable |
| pose_cool | Cool | 0/1 | 0/1 | – | SVG only; Not validated; Not applicable |
| pose_flex | Bizeps | 0/1 | 0/1 | – | SVG only; Not validated; Not applicable |
| pose_ansage | Ansage | 0/1 | 0/1 | – | SVG only; Not validated; Not applicable |

Posen, Szenen und Effekte behalten die vorhandene prozedurale/SVG-Darstellung, solange keine tatsächlich integrierte Premium-Familie nachgewiesen ist. Ein Guard-Pilot macht nicht sämtliche sechs Pose-Items zu fertigen Illustrationen.

Reproduktion: `node scripts/inventory-premium-production.cjs`. Der technische Bericht liegt unter `docs/premium-v2/evidence/production-tests.json`; er muss `passed:true`, beide Engines, `validatedVariants` und passende `sourceHashes` enthalten. Hashverfahren `sha256-canonical-text-lf-v1`: UTF-8-Text normalisiert CRLF zu LF, PNG-/Binärdateien verwenden unveränderte Bytes. Damit lassen sich Windows- und Linux-Checkouts vergleichen. Fehlender oder veralteter Bericht fällt automatisch auf Entwurfsstatus zurück. Noch nicht kompatible vollständige Outfits müssen im Labor und im normalen Editor vollständig SVG bleiben.

Alle gezählten Quellbilder haben passende PNG-Abmessungen, Alphakanal und SHA-256. Dieser Dateicheck ersetzt keine Sichtprüfung von Anatomie, Stoff, Verdeckung oder Materialien.
