# Mein Boxer – verbindliche Art Direction (30.10.2026)

## Massgebliche Vorlage

Die vom Betreiber im Chat am 30.10.2026 freigegebene 1536×1024-Vorlage zeigt links den bestehenden «Mein Boxer»-Stand, rechts die aufgewertete Variante und unten Shop, Emotes und FUT-Karten.

Sie ist die **visuelle Spezifikation**, nicht nur ein Moodboard. Kein neues rot-schwarzes Dashboard, kein fotorealistischer Boxer, keine frei erfundenen Menüs.

## Zwingende Merkmale

- Navy/Schwarz als Fläche, Gold (#f2c14e / #ffd66f) für Figur und seltene Ausrüstung, Cyan (#4fd8ff) nur als selektiver Bedienzustand.
- Anime-/Comic-Boxer mit natürlich gerenderten Haut- und Haarfarben, kontrolliertem 3D-Licht und goldenen Kanten; kein fotorealistisches Gesicht.
- Der Wunschcharakter der Referenz trägt einen schwarzen, goldbesetzten Mantel, schwarze Shorts und goldene Boxer-Schuhe; andere gespeicherte Outfits müssen trotzdem korrekt darstellbar bleiben.
- Kopf, Oberteil, Hose, Handschuhe, Schuhe, Mantel, Posen, Farbvarianten und freigeschaltete Extras bleiben frei konfigurierbar.
- Ausrüstungsbilder sollen wie eigenständige Game-Items aussehen. Keine farblosen Silhouetten als finale Item-Kunst.
- Mobile Web-App: Boxer **mittig und oben dauerhaft sichtbar**, darunter unabhängig scrollbar Körper/Kleidung/Extras/Posen/Shop; kein festes rechtes Kachelpanel.
- Der Shop, die Emotes und FUT-Karten auf der unteren Hälfte der Vorlage definieren die langfristige gemeinsame Bildsprache, sind aber **nicht** Bestandteil des aktuellen PR-Scopes.

## Umsetzung im Draft-PR #79

Die mobile Aufteilung ist fertig implementiert, nicht produktiv veröffentlicht.

**Art pass 1:** Der existierende `TLHolo.svg`-Renderer erhält eine optionale `premium:true`-Ebene mit Gesicht-/Muskel-Schattierung, Stoffnähten, Mantel-Lichtkanten und Ausrüstungs-Glanz. Die Option ist **nur im Mein-Boxer-Editor** eingeschaltet. Auf öffentlichen Karten und im Kampfsystem bleibt der alte Renderer vorerst unverändert. Vorschauen verwenden die tatsächlichen Konfigurationswerte.

**Abgrenzung:** Zusätzliche Vektordetails sind kein pixelgenauer Nachbau des aufwendig gemalten Anime-Boxers. Eine echte 1:1-Nachbildung würde gesondert gemalte, konsistente transparente Ebenen für Körper/Haare/Kleidung oder ein animierbares 2D/3D-Rig benötigen. Kein fixes PNG auf das Holo legen – das würde die individuellen Anpassungen visuell verfälschen.

## Technische Leitplanken

- Bestehende IDs, `data-set`-/`data-val`-Schlüssel, `get_my_holo`, `save_my_holo`, `buy_holo_item` und `buy_holo_bundle` bleiben erhalten.
- Keine produktive Supabase-Migration und keine Änderung von Rechten/RLS.
- Nicht nach `main` mergen, bevor ein eingeloggter Test auf iPhone (PWA/Safari) Scrollen, Outfitwechsel, Save, Shop und Menü geprüft hat.
- Performance: nur geringe dynamische SVG-Details, reduzierte Motion beachten und mobile Renderingkosten messen.
