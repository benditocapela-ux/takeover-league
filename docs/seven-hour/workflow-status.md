# Workflow UI: verifizierter Stand

Stand: 2026-11-02. Keine Produktionsschreibvorgänge, kein Merge, kein Deployment.

## Umgesetzt

- Bestehende Punkte-Duelle: Gegnerwahl und Laufzeit öffnen eine lesbare Einladungsvorschau. Erst «Einladung ausdrücklich senden» ruft die bestehende Einladung-RPC auf.
- Vorschau enthält beide Namen, Wertung, Laufzeit, Annahmefrist und Sichtbarkeit. Bestehende Belohnung bleibt serverseitig; neue Beträge werden nicht erfunden.
- Änderung einer Eingabe verwirft die Vorschau. Zusätzlich prüft der Sendehandler den gesamten Eingabestand und die Sitzung. Auch eine programmatische Änderung ohne Change-Ereignis kann keine ungeprüften Regeln senden.
- Laufende Anfragen sind gegen Doppelklick und Sitzungswechsel geschützt. Bestehende Annahme, Ablehnung, Rückzug, Live-Wertung und Trainerabschluss bleiben erhalten.
- Joggingkilometer und Trainingsanzahl sind deaktiviert; ihre fehlende Freigabe wird erklärt. Keine spekulativen v3-RPCs sind im produktiven Browsercode verdrahtet.
- Fehlende Gastsitzung zeigt die Anmeldung, nicht den technischen Fehler «Auth session missing».
- duels.html, coach.html und league-manager.html verwenden die gemeinsame Client-Factory. league-history.html besitzt bislang keinen SDK-Client, sondern anonymes REST.
- Trainer-Startseite meldet ausschliesslich fehlende Trainingsaufgaben statt fälschlich alle Wettkämpfe als erledigt darzustellen.

## Tests und tatsächliche Evidenz

- `node tests/duels-v2-browser.cjs`: bestanden. JSDOM: Gast, fehlende Gastsitzung, Einladungsvorschau, ausdrückliches Senden, veränderte Regeln, Sitzungsverlust, verspätete Antwort nach Logout, Trainerwahl, Annahme/Ablehnung, Ablauf, bestehender Abschluss, XSS.
- `node tests/release-static-contracts.cjs`: 33/33 bestanden. Der bisherige native-confirm-Vertrag wurde durch den stärkeren Vorschau-/Signatur-/Sendevertrag ersetzt.
- `node tests/release-live-duels-browser.cjs`: echter Chromium-Browser mit synthetischen Supabase-Antworten; 375 und 1280 px bestanden.
- `$env:TL_BROWSER='webkit'; node tests/release-live-duels-browser.cjs`: echter WebKit-Browser, dieselben beiden Breiten bestanden.
- Browserfälle: Auswahl sendet nichts, Vorschau sendet nichts, ungeprüfte Änderung wird zurückgewiesen, ausdrücklicher Klick sendet genau die geprüften Daten einmal, neue Metriken gesperrt, Live-Ergebnis, offene Trainings, Fehler statt veralteter Zahlen, Annahme aktualisiert Ansicht, kein horizontaler Überlauf.
- Screenshots: `output/seven-hour/duel-review/{chromium,webkit}-{375,1280}.png`. Synthetische Boxer Alpha/Beta, keine echten Konten. Chromium-Mobilansicht visuell geprüft.

## Nicht fertig / keine Freigabe dafür

Die vollständige Wettkampf- und Archivstrecke ist nicht implementiert. Die vorgesehenen Backend-Verträge existieren noch nicht; siehe backend-status.md. Ein zuerst vorbereiteter v3-Frontendentwurf wurde entfernt, damit keine nicht vorhandenen API-Aktionen angezeigt werden.

1. Keine Kilometer- oder Trainingsart-Duelle: zuerst verbindliche Belohnungs-/Zeit-/Sichtbarkeitsregeln und geprüfte serverseitige Migration mit RLS, danach UI und Browserintegration.
2. Keine neue Vereinsansicht oder v3-Cursor-Paginierung. Altduelle bleiben in ihrer bestehenden Sichtbarkeit.
3. Keine neue Trainer-Abschlusswarteschlange. Der vorhandene Button «Ergebnis prüfen» ruft weiterhin die bestehende reconcile-RPC auf und kann serverseitig abschliessen. Er ist **keine** neue schreibfreie Abschlussvorschau. Vor einer Freigabe des neuen Workflows muss dies ersetzt und separat getestet werden.
4. Keine neue Monats-/Saisonarchivwahl. league-history.html lädt weiterhin bestehende Listen; der globale Ergebnismix ist noch nicht behoben. Keine rekonstruierte Oktoberwertung erstellt.
5. Keine erweiterten Coach-Rechte für Saison-/Monatsabschluss; league-manager.html wurde nur auf die gemeinsame Client-Factory umgestellt.
6. Keine DB-/RLS-/Idempotenzbeweise für die neuen Funktionen. Die UI-Mocks sind ausdrücklich kein solcher Nachweis.

## Konkreter nächster Auftrag

Zuerst serverseitig schreibfreie Duell-/Periodenabschlussvorschau, expliziten idempotenten Abschluss und zeilenweise belegte Prämien liefern. Danach die Trainerwarteschlange mit Status/Suche/Cursor und klar getrennten Vorschau-/Abschlussaktionen integrieren. Anschliessend periodengefiltertes Archiv samt Deep Links, eigenem Rang und Ausschüttungsnachweisen. Erst mit freigegebenen Belohnungen Kilometer-/Trainingsart-Duelle anschliessen. Jede Stufe mit isolierten DB-Tests und Browsertests für Boxer/Coach/Admin/Gast prüfen.
