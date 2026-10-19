> ⚠️ **ÜBERHOLT – historischer Entwicklungs- oder Release-Zwischenstand.** Frühere Aussagen wie «nicht veröffentlicht», «HOLD», «NICHT AUSGEFÜHRT» und «kein Live-Release» dürfen nicht mehr als aktueller Produktionsstatus gelesen werden.
> **Tatsächlich:** Takeover League 2.1 ist auf `main` (`4aae67e` → `4430bc4` → `0cd262e`) und mit der atomaren Migration `20261018231319` in Produktion. Echte Backup-/Restore-, Real-Login- und vollständige Security-Definer-Gates sind dadurch **NICHT** bestanden.
> **Verbindlicher aktueller Überblick:** [RELEASE_STATUS_2_1_2026-10-19.md](RELEASE_STATUS_2_1_2026-10-19.md). Der übrige Text bleibt unverändert als historische Momentaufnahme erhalten.

# Takeover League V2 – Vorgehen nach «FREIGEBEN»

**VORBEREITET; nicht ausgeführt.** Dieser Ablauf ist als konkrete Anweisung für die **nächste** ChatGPT-Arbeitssitzung nach einem ausdrücklichen «FREIGEBEN» bestimmt. Nicht automatisch und nicht im Hintergrund ausführen. Die Produktionsdatenbank liegt in Supabase-Projekt `iqarjivcrddcixrvqbfb`; das Testprojekt ist `cfgdvcccsqwfjajuizsr`. GitHub: `benditocapela-ux/takeover-league`, Draft-PR **#3** auf `feature/coach-challenges-v2-ui`.

## 0. Sicherheitsbedingungen unmittelbar vor der Ausführung

- Die Nutzerentscheidung **ohne Backup** ist ausdrücklich bekannt und dokumentiert: mögliche unwiederbringliche Schäden an Profilen, Historie und EXP. **Backup ist empfohlen, aber wird nicht als automatisches Gate verwendet.**
- **Keine Migration ohne exakt die spätere Nachricht «FREIGEBEN».** Eine frühere «GO»-Nachricht oder die Zustimmung zum Backup-Verzicht ist nicht die SQL-/Deploy-Freigabe.
- Alle aktuellen GitHub CI-Jobs müssen grün sein (statische Tests, PostgreSQL 16 und 17, tatsächliches anonymes HTTPS-Verhalten). Der [öffentliche Pages-Status](https://benditocapela-ux.github.io/takeover-league/) wurde zuletzt mit HTTP 200 geprüft.
- **Bewusster Testverzicht (Nutzerentscheidung, 18.10.2026):** Die vollständigen Vorab-Login-Tests mit getrennten Boxer-/Coach-/Admin-Konten werden übersprungen. Sie gelten ausdrücklich **nicht als bestanden**. Stattdessen nach dem Release mit wenigen echten Boxern einen gestuften Live-Piloten durchführen; bereits bestätigte Rollen-/RPC-/SQL-/anonyme HTTPS-Sicherheitstests bleiben Pflicht. Kritische neue Befunde führen weiterhin zu NO-GO.
- Read-only-Baseline frisch aus `supabase/production-prep/production_baseline_read_only.sql` abfragen. **Zusätzlich** `supabase/production-prep/release_preflight_read_only.sql` ausführen: Feld `ready_for_controlled_release` muss explizit `true` sein. Bei `false` keine produktive SQL-Ausführung.
- Die GitHub-PR-Änderungen und Release-SQL-Dateien erneut exakt gegen aktuellen Head lesen; keine älteren SHA-Werte blind verwenden.
- Sicherheitsadvisor vor dem Release prüfen und neue kritische Warnungen klären. Feature-Flags sollen noch ausgeschaltet sein.
- Bei neuer SQL-/Schema-Abweichung, beschädigtem Datenbestand, fehlender Website, fehlenden Connector-Rechten oder fehlerhaften CI-Tests: **NO-GO**, keine riskanten Änderungen.

## 1. Backend-Sicherheitsfix (nur nach Freigabe)

**Zuerst**, wenn die Read-only-Owner-/Trigger-Prüfungen übereinstimmen, die vorbereitete Datei
`supabase/production-prep/20261018_restrict_achievement_recalculation.sql`
über Supabase `apply_migration` mit einem eigenen, eindeutigen Namen auf **Produktion** anwenden. Sie widerruft `EXECUTE` für `PUBLIC`, `anon`, `authenticated`; der legitime postgres-eigene Approval-Trigger bleibt berechtigt.

Danach ausschließlich autorisierte Datenbankrollen kontrollieren: `anon` und `authenticated` müssen `has_function_privilege(...,'EXECUTE')=false` haben, `postgres` und `service_role` weiterhin `true`. Trigger existiert noch. Trainingsfreigabe/EXP nur mit kontrollierten Testdaten prüfen; niemals einen realen Boxer zum Test manipulieren.

## 2. Beide atomaren Backend-Migrationen (nur nach Freigabe)

1. GitHub-Datei `supabase/migrations/20261018131000_coach_challenges_v2.sql` laden und gegen Quellen in `supabase/production-prep/` prüfen. Auf `iqarjivcrddcixrvqbfb` anwenden (Migration: `release_coach_challenges_v2`). Diese erstellt 4 Tabellen und 17 RPCs; `coach_challenges` und `duels` Flags bleiben **false**.
2. Mit Read-only-SQL Tabellen, RLS, alle 17 Signaturen, anonymen Berechtigungsentzug, coach-Profilrolle, `challenge_exp` Kategorie und bestehende Profil-/Punkt-/EXP-Zählungen verifizieren. Bei Fehler **stoppen** (das zweite Modul und das UI noch nicht deployen).
3. GitHub-Datei `supabase/migrations/20261018133000_duels_v2.sql` auf **dasselbe Produktionsprojekt** anwenden (Migration: `release_duels_v2`). Es folgen 3 Tabellen und 6 RPCs; duels-Flag bleibt **false**.
4. `supabase/production-prep/release_postflight_read_only.sql` **nach den beiden Migrationen und dem Achievement-Patch** ausführen. `release_integrity_passed` muss `true` sein (23 geschützte RPCs, 7 RLS-Tabellen, EXP-Ledger und Flags). Die bestehenden Profile, alten Turniere/Trainings, EXP und Punkte erneut mit der vor dem Release erfassten Baseline vergleichen. Eventuelle PostgREST-Schema-Cache-Verzögerungen durch in den Migrationen enthaltenes `NOTIFY pgrst, 'reload schema'` berücksichtigen.
5. **Noch keine echte Teilnahme oder EXP-Auszahlung auf Produktion auslösen.**

## 3. Web-Update zunächst deaktiviert bereitstellen (nur nach Freigabe)

1. Draft-PR #3 überprüfen, auf `Ready for review` setzen, nach bestandenen Tests in `main` mergen. Es wird damit über das bereits existierende GitHub Pages [Takeover League](https://benditocapela-ux.github.io/takeover-league/) veröffentlicht. **Beide V2-Frontend-Flags sind im gemergten Stand noch ausdrücklich false.**
2. Neue Seiten `/challenges.html` und `/duels.html` über HTTP 200 prüfen; auf den Seiten steht noch „Freischaltung ausstehend“. Homepage, Login, Boxer und Admin-Dashboard müssen weiter funktionieren.
3. **Nur wenn alle Backend-/Web-Prüfungen erfolgreich waren:** die bereitgestellte atomare Datei `supabase/production-prep/activate_v2_only_after_freigeben.sql` auf dem **Produktivprojekt** ausführen. Sie verweigert die Aktivierung, wenn Sicherheits-Patch, 23 RPC-Rechte, 7 RLS-Tabellen, Flags oder EXP-Ledger nicht stimmen. Danach die beiden Produktionsdateien **auf main** ändern: `window.TAKEOVER_CHALLENGES_V2_ENABLED=true` und `window.TAKEOVER_DUELS_V2_ENABLED=true`. Keine Test-Supabase-Schlüssel in Live-HTML übertragen.
4. Pages-Deployment abwarten und über echtes HTTPS prüfen, dass die aktualisierten Produktionsseiten mit aktiviertem Code ausgeliefert werden. Dafür `node tests/hosted-v2-live-release-check.cjs` ausführen; der Test prüft beide aktivierten Flags, korrektes produktives Supabase-Ziel und den Fortbestand der alten Dashboard-Seiten, ohne Datenbank-Schreiboperationen. Wenn nötig Cache/Refresh prüfen, aber keinen erfolgreichen Rollout behaupten, bevor der sichtbare Live-Stand stimmt.
5. Nach dem kontrollierten Start zuerst **mit wenigen freiwilligen echten Boxern** Login, Navigation, Trainingsanzeige, Teilnahme an Challenges und Duell-Einladungen prüfen; danach den Teilnehmerkreis erweitern. Vorab-Logintests wurden auf Nutzerwunsch übersprungen. Keine künstlichen EXP-Buchungen auf echte Profile zum blossen Test, keine abgeschlossenen Challenges oder Duelle vorschnell abrechnen. Auftretende Fehler vor einer Ausweitung untersuchen und gegebenenfalls beide V2-Flags zurücksetzen.

## 4. Kontrollierter Rollback (Daten erhalten!)

Bei Fehlern **zuerst** die atomare Datei `supabase/production-prep/emergency_disable_v2_flags_only.sql` auf Produktion ausführen; sie deaktiviert beide Feature-Flags datenbewahrend. Danach beide Frontend-V2-Flags auf `false` setzen und den neuen Seitenzugriff erneut prüfen. Die existierenden Trainingseinträge und Punktetransaktionen keinesfalls verändern.

Die Dateien `rollback_*empty_only.sql` dürfen nur bei **nachweislich leeren** V2-Tabellen verwendet werden. Nach der tatsächlichen Freischaltung nicht blind Datenbanktabellen, RPCs oder EXP-Transaktionen löschen; bei bereits vergebenen EXP ist ein gesonderter datenbewahrender Reparaturplan erforderlich.

**Ohne Backup ist eine vollständige Datenwiederherstellung nicht garantiert möglich.** Bei Problemen sofort stoppen und offen über die Grenzen informieren.

## 5. Akzeptanzkriterien für «Update online»

- GitHub Pages stellt die neuen Seiten öffentlich erreichbar mit aktiviertem Produktionscode bereit.
- Backend-RPCs existieren mit korrekten Signaturen, V2-Tables besitzen RLS, Feature-Flags sind kontrolliert aktiv.
- Nichtberechtigte Rollen haben keinen direkten Zugriff; Achievements sind nicht mehr anonym neu berechenbar.
- Alte Trainings-, Profil-, Punkt- und EXP-Daten sind erhalten (mit frischer Baseline abgeglichen).
- Mindestens Login und autorisierte Challenge-/Duellabfragen funktionieren in der tatsächlichen Web-Anwendung.
- Keine Fehler in CI und bei Smoke Checks. Verbleibende Sicherheits-/Funktionsrisiken ausdrücklich nennen, nicht schönrechnen.

**Kein Deploy vor «FREIGEBEN».** Keine Aussage „online“, solange diese Kriterien nicht verifiziert sind.
