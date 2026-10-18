# Takeover League 2.0 – Boxerprofil-Aktionen (Entwurf, nicht veröffentlicht)

**Integration:** Diese Erweiterung baut auf PR #4 (durchgehendes Menü) und PR #5 (Boxer-Dashboard) auf. Keine Änderungen an bestehender Produktion vor erneuter ausdrücklicher Freigabe. Keine künstlichen EXP-/Punktetransaktionen auf Boxerprofilen auslösen.

## Nutzerablauf

- In `index.html` im Ranking und in den Levels ist die **gesamte Boxerzeile** mit Tastatur und Touch anklickbar.
- `boxer-profile.html?name=...` zeigt **nur bereits öffentliche** Ligadaten: Boxername, Avatar, Monatspunkte, Gesamt-EXP, Level, Monatsplatz. Keine E-Mail, Gewicht, Kontaktdaten, Trainerfeedback oder Trainingsnotizen.
- `Herausfordern` öffnet `duels.html?opponent=...`, wählt einen **eindeutig passenden aktiven Boxer** aus der durch V2 abgesicherten Duell-RPC vor und benötigt danach explizites Abschicken der Einladung. Eigene Namen, unbekannte oder doppelte Namen führen **nicht** zu einer willkürlichen Einladung.
- `Persönliche Challenge vergeben` erscheint im Profil nur nach erfolgreicher Supabase-Session und bestätigter Rolle `coach` oder `admin`. Die Challenge-Seite überprüft die Trainerrolle nochmals über die bestehende Datenbank-Actor-RPC und eine gesicherte, aktive Boxer-Liste.
- Trainer bestimmen Titel, individuelles Ziel, 7/14/30 Tage, 25/50/100/150/200 EXP; erst nach ausdrücklicher Bestätigung wird **atomar genau ein Boxer** zugeordnet und die Challenge gestartet. Keine EXP vor Abschluss einer manuellen Coach-Bewertung. Abbruch nur vor Bewertung und Auszahlung.

## Sicherheitsarchitektur

Neue vorbereitete Migration: `supabase/migrations/20261018170000_private_boxer_challenge_assignment.sql`.

- Zusätzliche RLS-Tabelle `league_coach_challenge_targets`, **ohne SELECT/INSERT/UPDATE/DELETE** für `anon` und `authenticated`.
- Coach-/Admin-berechtigte RPCs `league_personal_challenge_roster`, `league_assign_personal_challenge` und `league_cancel_personal_challenge`; `PUBLIC`/`anon` dürfen sie nicht ausführen. Rollenprüfung geschieht **serverseitig über auth.uid() und aktives Profil**, nicht durch ein Query-Argument oder einen versteckten Button.
- Bestehende `coach_challenge_v2_list`, `coach_challenge_v2_join`, `coach_challenge_v2_goal_details` und `coach_challenge_v2_progress` wahren zusätzliche Zielprivatsphäre. Öffentliche Bestands-Challenges funktionieren unverändert.
- Anonyme Benutzer dürfen weiterhin öffentliche Profilwerte sehen. Namen werden **nicht** als autoritative Profil-ID benutzt: Duell-/Traineraktionen lösen sie über rollenbewachte Boxer-RPCs auf und lehnen Namensduplikate ab.
- **Kein eigener EXP-Schreibweg:** Die bereits getestete V2-Bewertungs- und Abrechnungslogik bleibt zuständig, mit idempotentem Ledger.

## Prüfung und künftiger Release

1. GitHub CI für PR #6: Node/JSDOM-Profil-, Menü-, Duell-/Challenge- und Security-Tests sowie frische disposable PostgreSQL 16/17 Datenbanken. Stand bei Erstellung: alle drei Jobs erfolgreich.
2. Vor der Veröffentlichung die genaue Produktionsmigration (eine Transaktion) **separat ausdrücklich freigeben**, vorher existierende Daten read-only zählen und Sicherheit/Versionsstand neu prüfen.
3. SQL auf Produktion anwenden; danach `EXECUTE`-Rechte aller drei neuen RPCs, RLS und Tabellensperren sowie bestehende Flags kontrollieren.
4. PRs in korrekter Abhängigkeitsreihenfolge #4 → #5 → #6 nach `main` integrieren. `boxer-profile.html` und `boxer-profile.js` sind im GitHub-Pages-Artifact-Workflow ausdrücklich eingeschlossen. Produktionsstatus direkt per HTTP sowie echte Boxer-/Coach-Konten stichprobenartig prüfen.
5. Bei einem Fehler vor Publikation Frontend unverändert lassen. Wenn die Migration bereits veröffentlicht ist, DB nicht ohne Prüfung mit beliebigen DROP-Anweisungen „zurücksetzen“, da es persönliche Challenges und spätere EXP-Ledger geben könnte.

**Wichtige Entscheidung:** Für diese zusätzliche persönliche Trainer-Challenge wurde in diesem Entwurf bewusst **keine** produktive SQL-Änderung ausgeführt. Die bestehenden 14 Profile und Transaktionen bleiben unberührt.
