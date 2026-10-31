# PR #79 — vorhandenes Abnahmepaket

Dieses Verzeichnis übergibt das bereits erstellte Paket unverändert. Es ergänzt ausschließlich Dokumentation und einen Artefakt-Job; keine Anwendung, Grafik, Konfiguration oder Datenbank wird dadurch geändert. Kein Deployment.

**Release A: TECHNISCH READY – WARTET AUF NUTZERFREIGABE.**

**Release B: GESPERRT – persönliche Grafikabnahme und separate technische Aktivierungsprüfung fehlen.** Beide Grafikmanifeste bleiben `approved:false`, `enabled:false`. PR #79 bleibt Draft.

## Download

1. [PR79-Abnahme.zip](PR79-Abnahme.zip) öffnen und auf GitHub **Download raw file** wählen. Das ZIP ist dauerhaft an diesen Git-Stand gebunden.
2. Alternativ: **Actions → PR79 acceptance gallery (no deploy) → erfolgreicher Lauf → Artifacts → PR79-Abnahme-86c5ffa**. GitHub-Anmeldung kann erforderlich sein; dieses Actions-Artefakt bleibt 30 Tage erhalten.
3. ZIP vollständig entpacken und **index.html** lokal öffnen. Kein Webserver nötig, um die Bilder zu beurteilen.

Das unveränderte Ausgangs-ZIP hat SHA-256 `af46b7697581864d2bcb85f95fe6a65c698e021b2433e1cb0d6c7f9bda59f346`. Der Job prüft diesen Hash und stellt die enthaltenen Dateien mit `index.html` direkt im Artefakt-Hauptverzeichnis bereit. Die Actions-ZIP-Kompression kann abweichen; der Inhalt ist identisch.

## Inhalt und Geltungsbereich

Die Galerie enthält Originalrekonstruktion, modulare Cool-Figur, Handschuhe vorher/nachher in Schwarz-Gold und Weiß, Mantel/Tank an und aus, vier repräsentative Outfits, Übersicht aller 32 Kombinationen, sechs Posen, Mobil-/Desktopansichten und den normalen SVG-Editor. Es sind bereits gesichtete echte Browserbilder, keine neu erstellten Mockups. Original-CI-Bild aus Run `41147556149`.

Anwendungsstand der Bilder und der isolierten Testversion: `86c5ffa62bd2ee9372ca645e05fb030951520f2b`. Die späteren Übergabecommits ändern diesen Anwendungsstand nicht. Die Dateien `STATUS.txt` und der RC-Bericht im ZIP sind bewusst der unveränderte damalige Snapshot; der aktuelle PR-Head und seine Checks stehen auf GitHub.

Der getestete Pages-Umfang enthält keine Premium-PNGs oder dieses Dokumentationsverzeichnis. Die zusätzlichen Dateien unter `testversion/site` dienen ausschließlich der lokalen Abnahme und sind kein Produktions-Build.

## Deine nächsten Schritte

- **Design:** In `index.html` Arena, Gesicht/Proportionen, Hände und Kleidung vergleichen. Die 1536×1024-Gesamtvorlage liegt nicht als Originaldatei vor; keine pixelidentische Rekonstruktion oder persönliche Freigabe behauptet.
- **iPhone/Safari und Android/Chrome:** `geraetetest.html` folgen. Enthält Start mit `node start.cjs --lan`, sichere private WLAN-Adresse, Hoch-/Querformat, Scrollen, Posen, langsame Antworten, Speichern/Verwerfen.
- **Screenreader:** VoiceOver/TalkBack bzw. NVDA, Tastatur und Zoom prüfen. Physische Geräte-/Assistenztests sind weiterhin offen; LAN-HTTP ersetzt keinen HTTPS/PWA-Test.
- **Speichern und Shop:** Speichern wird im beigefügten Teststand nur im Browser-Tab simuliert. Alle Artikel sind dort Testbesitz, Käufe sind gesperrt. Einzel-/Bundlekäufe und Fehlerfälle sind in Chromium/WebKit automatisch mit RPC-Mocks geprüft; eine persönliche Shopkauf-Abnahme benötigt einen gesonderten isolierten Testdatenstand. Keine produktiven Coins verwenden.
- **Rückmeldung:** `abnahme.html` öffnen, je Punkt **Akzeptiert / Änderungswunsch / Blockierend** wählen, Gerät und konkrete Beobachtung angeben, Textdatei herunterladen und im Chat zurückgeben. Release A und B separat bewerten.
- **Finale Freigabe:** Erst nach Nutzerabnahme und ausdrücklicher separater Merge-/Release-Erlaubnis entscheiden. Eine ausgefüllte Checkliste löst weder Merge noch Deployment aus.

Keine bekannten offenen kritischen technischen Fehler im bestätigten RC. Persönliche Designabnahme, echte Geräte-/Screenreader-Tests und finale Nutzerfreigabe bleiben offen. Empfehlung: **WARTET AUF ABNAHME**, Release A zuerst.
