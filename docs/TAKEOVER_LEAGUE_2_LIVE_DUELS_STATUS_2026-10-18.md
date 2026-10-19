> ⚠️ **ÜBERHOLT – historischer Entwicklungs- oder Release-Zwischenstand.** Frühere Aussagen wie «nicht veröffentlicht», «HOLD», «NICHT AUSGEFÜHRT» und «kein Live-Release» dürfen nicht mehr als aktueller Produktionsstatus gelesen werden.
> **Tatsächlich:** Takeover League 2.1 ist auf `main` (`4aae67e` → `4430bc4` → `0cd262e`) und mit der atomaren Migration `20261018231319` in Produktion. Echte Backup-/Restore-, Real-Login- und vollständige Security-Definer-Gates sind dadurch **NICHT** bestanden.
> **Verbindlicher aktueller Überblick:** [RELEASE_STATUS_2_1_2026-10-19.md](RELEASE_STATUS_2_1_2026-10-19.md). Der übrige Text bleibt unverändert als historische Momentaufnahme erhalten.

# Takeover League 2.0 – Live-Duell Übergabe und Abnahme

**Datum:** 18.10.2026 · Branch: `release/takeover-league-2-ready`  
**Status:** FRONTEND & ISOLIERTES BACKEND GETESTET; **PRODUKTIVMIGRATION BLOCKIERT** – kein Live-Pages-Deploy.

## Fertig im echten Frontend
- `duels.html` zeigt einen Live-Überblick für aktive und zur Trainerprüfung ausstehende Duelle (einschliesslich 0:0).
- Je Duell: beide echten Boxernamen, vorläufige bestätigte Trainingspunkte, grafischer Punktevergleich, Anzahl offener Trainings und Restlaufzeit. Das Trainer-Endergebnis ist davon klar getrennt.
- Aktualisierung alle 90 Sekunden, manuelle Aktualisierung und Anzeige der letzten erfolgreichen Serverantwort.
- Punktestände werden nur aus der geschützten `duel_v2_live_scores(uuid)`-Antwort gelesen. Der Browser berechnet **keine privaten Punkte aus fremden Trainingsdaten**.
- Bei Aktualisierungen bleiben bisher verifizierte Punktestände bis zur neuen Antwort sichtbar. Fehlgeschlagene bzw. ungültige Antworten werden **nicht** als aktuelle Punkte weiter angezeigt. Veraltete Antworten nach Logout oder überlappenden Requests werden ignoriert.
- Fehlende Backendfunktion, verweigerte Berechtigung und ungültige Zahlen erhalten eigene verständliche UI-Zustände.
- Bestehende Duelleinladungen (7/14 Tage), Annahme, Ablehnung sowie Trainerabschluss bleiben im bisherigen sicheren RPC-Ablauf.

## Backend und Berechtigungen
`supabase/migrations/20261018211000_duel_v2_live_scores.sql` ist die vorgesehene, additive RPC-Migration mit `SECURITY DEFINER`, festem `search_path`, `auth.uid()`-Prüfung, Teilnahme-/Rollenprüfung, Aktivierungsflag und explizit gesperrtem anonymem EXECUTE. Abgelehnte und unbestätigte Trainings erhöhen die Live-Punkte nicht; offene Trainings werden nur gezählt; doppelte Ledger-Einträge lassen die Berechnung abbrechen.

Diese SQL-Migration ist im **isolierten Supabase-TEST** vorhanden. In `tests/live-duel-provisional-test-transaction.sql` wurde sie transaktional mit ROLLBACK geprüft:
- Zwei bestätigte Buchungen von 50 und 70 Punkten liefern **50:70**.
- Ein offenes Training erhöht nicht den Punktestand, aber die Warnzahl **1**.
- Der gleiche Zwischenstand ist mit Status `awaiting_reviews` noch als vorläufig abrufbar.
- Eine UUID ohne zugeordnetes aktives Profil ist nicht zum Abruf berechtigt.
- Die Testdaten wurden vollständig zurückgerollt.

**Einschränkung:** Ein dritter angemeldeter Boxer, der nicht am Duell beteiligt ist, konnte im isolierten Testprojekt mangels dritten Boxer-Testaccounts nicht über ein echtes signiertes Sessiontoken durchgespielt werden. Die Funktion enthält dafür eine explizite serverseitige Teilnehmerprüfung. Diese Pfadprüfung ist vor allgemeiner Freigabe mit realem Testlogin nachzuholen.

## Durchgeführte UI-/CI-Tests
- `tests/release-live-duels-browser.cjs` mit Chromium auf 375px und 1280px: 70:40 aktive Punkte, 100:110 bei Trainerprüfung, 80:40 Endstand, Null-Punkte-Duell nach Annahme, Restzeit/Status, mobile Breite.
- Fehlender Backend-RPC (`PGRST202`): nachvollziehbarer Hinweis statt ewigen Ladens.
- Ungültiger negativer Punktestand: kein irreführender Score.
- Nach erfolgreichem Refresh sind Punktestände erneut korrekt sichtbar.
- `tests/release-ux-staging.cjs` prüft DOM, Polling-/Session-Races und sichere Antwortvalidierung.
- GitHub Actions: `Takeover League V2 Integration Checks` und `Takeover League 2 - staging validation (no deploy)`.

## Unveränderte Produktionssperre
Der Versuch, `20261018211000_duel_v2_live_scores.sql` auf Supabase PRODUKTION anzuwenden, wurde zuvor durch die Sicherheitsprüfung des verbundenen Werkzeugs **vor Ausführung blockiert**. Die Ursache ist nicht als SQL-Fehler nachgewiesen. Diese Sperre wurde **nicht umgangen**, auch nicht durch alternative SQL-Ausführungswege.

Im Produktivsystem fehlen daher weiterhin Live-Zwischenstände. `main`, GitHub Pages, produktive Feature-Flags und die übrigen blockierten Migrationsschritte sind nicht als abgeschlossen zu betrachten. Die vier zuvor produktiv angewendeten additiven Migrationen bleiben bestehen. **Keine Live-Veröffentlichung behaupten, solange die gesperrte Operation nicht regulär freigegeben und die Postflight-Prüfung bestanden ist.**
