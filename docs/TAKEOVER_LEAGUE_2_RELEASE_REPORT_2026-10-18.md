# Takeover League 2.0 – Staging Release-Bericht
Stand: 18.10.2026. Repository: benditocapela-ux/takeover-league
Branch: `release/takeover-league-2-ready`
**Status: NICHT RELEASE-READY. Kein Merge/Pages-Deployment/Produktions-SQL.**

## Prüfumfang
Verglichen mit `main`: `develop/takeover-league-2-foundation`, `feature/ux-roadmap-20-foundations`, `feature/boxer-dashboard-polish-preview`, `feature/ranking-boxer-profile-actions`, `feature/coach-challenges-v2-ui`, `feature/minimal-arena-menu` und `release/exp-v2-website`.
Die alten Foundation- und Coach-Branches sind divergiert; sie wurden aus Gründen der Migrations- und Dateikonflikte nicht blind gemerged. Neuer Release-Branch basiert auf `feature/ranking-boxer-profile-actions`. Aus UX und Foundation wurden kompatible Vorschau-, Roadmap-, Test- und Referenzdateien integriert.

## Tatsächlich in den produktionsnahen Quelldateien umgesetzt
- `boxer.html`: bestehender echter Supabase-Login/Trainingseinreichung erhalten; Typ-Voreinstellungen pro Boxer, „letztes Training übernehmen“, verständliche Hilfe, sitzungsbasierte Formulardaten, freiwilliges Speichern/Laden eines privaten Supabase-Entwurfs bei verfügbarer Tabelle, Status-/Fehlerhinweise, Schutz vor parallelen Formular-Requests, Rücksetzen der Messwerte nach erfolgreicher Einreichung.
- `coach.html`: echte ausstehende Datensätze filtern, max. 20 markieren, vor Freigabe/Ablehnung bestätigen, sequentiell `review_training` aufrufen, beim ersten Fehler abbrechen, Übersicht nachbearbeiten/aktualisieren, Boxer direkt öffnen, zuletzt angesehene Boxer als Shortcuts (nur Sitzung).
- `challenges.html`: drei editierbare Vorlagen, keine automatische Veröffentlichung; bisherige echte Challenges-RPCs unverändert.
- `boxer-profile.*`, `duels.html`, `challenges.html`: vorhandene echte Profil-/Duell-/Challenge-UI aus dem gewählten Branch erhalten.
- `league2-preview.html`: interaktiver Demo-Prototyp aus UX-Branch übernommen; explizit **keine** echten Daten/privilegierten Aktionen. Im Pages-Workflow aus dem künftigen öffentlichen Build ausgeschlossen.
- `achievements-v2.js` und `coach-challenge-progress.js`: nichtdestruktive Grundlagen übernommen, keine implizite Produktivaktivierung.

## UX Nr. 1–45 – nachvollziehbare Abdeckung
- **Vorhanden oder im Release-Branch verbessert:** 1,2,4,5,6 (Profil-UI),7 (Coach-Admin),8,15 (Sitzung + optional Cloud),16,18,19,20,21,22,23,24 (teilweise),26,27,28,30,31,32,34,35,36 (Formularvorlagen),38,39 (manueller Refresh),40,41,44,45.
- **Nur Demo/teilweise oder noch backend-/rolloutabhängig:** 3 Benachrichtigungen, 9 Kalender, 10 Streaks, 11 Fortschrittsgrafiken (Feature-Flag), 12 Challengefortschritt, 13 echte Live-Duelle, 14 Favoriten/Vergleich, 17 vollständiges Audit, 25 eigene Rankingposition im echten Login, 29 Scrollposition in allen Ansichten, 33 echtes Coach-Sidepanel, 37 sicheres Undo echter Freigaben, 42 serverseitige Idempotenz der Einreichung, 43 mobile Bottom-Sheets.
- Ein UX-Prototyp oder vorhandener Code ist kein Nachweis für E2E-Reife. **Nicht alle 45 Punkte sind vollständig produktiv integriert.**

## Supabase – Fakten
- Projekt `iqarjivcrddcixrvqbfb`: produktiv, **nur READ-ONLY inspiziert**.
- Projekt `cfgdvcccsqwfjajuizsr`: isoliertes TEST-Projekt.
- Versionierte neue Migration `20261018190000_training_drafts_v2.sql` nur auf TEST ausgeführt. Private RLS-Tabelle mit Besitzerkontrolle per `profiles.auth_user_id=auth.uid()`, GRANT ausschliesslich `authenticated`, anonymer SELECT gesperrt. Struktur-/Rechteprüfung und transaktionaler Smoke-Versuch durchgeführt; keine signierten HTTP-E2E-Tests. TEST nach Rollback: 0 Entwürfe.
- Trainingswerte aus TEST validiert: Boxen 50, Sparring 70, Technik 40, Kraft 30, Sprint 40, Joggen 20.
- Frühere Migration `20261018170000_private_boxer_challenge_assignment.sql` auf TEST **abgebrochen** (Postgres 42P13): TEST `coach_challenge_v2_list()` und `coach_challenge_v2_progress(uuid)` liefern TABLE; Produktionsprojekt liefert JSONB. Ein blindes DROP/REPLACE wäre unsicher und wurde nicht ausgeführt. Schema-kompatibler Testaufbau oder harmonisierte Migration ist erforderlich.
- Produktion: 56 bestätigte Trainings = 35 `legacy_import` + 21 reguläre Training-Ledger. Vier widerrufene Trainings besitzen 0-Punkte-/0-EXP-Ledger. Keine Duplikate über `submission_id`; die zunächst auffälligen 35 fehlenden **regulären** Buchungen sind durch Legacy-Kategorie erklärt.
- Bereits in Produktion aktiviert: `coach_challenges`, `duels`. Unter anderem `achievements`, `performance_dashboard`, `coach_feedback`, `notifications` derzeit deaktiviert. Keine Flags geändert.
- Bestehende Reviewer-RPC `review_training` lässt in Produktion nur `role='admin'` zu. Eine reine Frontend-Erweiterung auf `coach` würde die serverseitige Berechtigung **nicht** ersetzen; dieser Rollenentscheid ist vor Release zu klären.

## Tests – präzise Evidenz
- JS-Parsing der angepassten Modul-Skripte (ohne Ausführung in realem Browser): **bestanden**.
- 13/13 eigene statische Quellcode-Contract-Checks im Entwicklungsdurchlauf: **bestanden** (kein Browser-/API-End-to-End-Test).
- SQL-Struktur/GRANT/RLS im TEST geprüft: **bestanden**.
- TEST-Migration für persönliche Challenges: **fehlgeschlagen** mit SQLSTATE 42P13 (keine Löschung vorhandener Funktionen).
- `.github/workflows/release-2-validation.yml` eingerichtet: statische Verträge und bestehende JSDOM-Tests auf dem Release-Branch, ohne Deploy; **keine bestätigten grünen GitHub-Actions-Runs für finalen SHA**. Daher CI-Gate offen.
- Nicht durchgeführt: echte signierte Boxer/Coach-HTTP-E2E-Tests, responsive Browsergeräte, vollständiger Regressionstest aller 45 UX-Punkte, Performance/Concurrency bei Doppelklick & wiederholtem Netzwerkrequest, rollback-fähige Integration sämtlicher Migrationsversionen.
- Keine nachweisbare vollständige unabhängige Produktionsbackup-/Restore-Probe.

## Sicherheitsreview
Supabase Security Advisor meldet in Produktion u.a. 7 anonym aufrufbare SECURITY-DEFINER-RPCs, 54 für angemeldete Benutzer ausführbare SECURITY-DEFINER-RPCs sowie fehlenden geleakten-Passwort-Schutz. Ein Teil der PUBLIC-RPCs dient bewusst nur zur Anzeige; **nicht pauschal widerrufen**, sondern jede Funktion auf Auth/Rollenprüfung und Datenminimierung prüfen.
Informationen: https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable und https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection

## Blocker vor GO LIVE
1. Produktionsschema und TEST-Schema für private Challenge-Zuweisung abgleichen; Migration ohne destruktiven DROP verifizieren.
2. Produktive private Entwurfs-Migration nach Backup/Review und ausdrücklich separater Freigabe.
3. Echte Auth/Role/RLS-Tests für Boxer, Admin, Coach und anonyme Anfragen.
4. Server-Idempotenz bzw. Duplikatvertrag für Trainingseinreichungen über Netzwerk-Retries; sequentielle Coach-Sammelaktionen sind **nicht atomar**.
5. UX-Gaps aus Nr. 1–45 schließen oder ausdrücklich als spätere Features einstufen.
6. Endgültige CI auf Release-SHA erfolgreich; GitHub Actions Fehlerruns prüfen; reale Browser- und Mobile-Tests.
7. Produktionsbackup und getesteter Restore, Migrationsreihenfolge, Feature-Flag-Abgleich, Zugangsrechte, Audit und Monitoring.
8. Releaseoperator benennen und explizites GO-LIVE erst nach bestandenem Preflight.

## Vorgesehene, aber nicht ausgeführte Release-Reihenfolge
1. Commit fixieren, Backups/Restore sicherstellen, read-only Preflight aus `supabase/preflight/release_2_read_only_integrity.sql` und Security Advisors erneut ausführen.
2. Änderungen inklusive privater Challenge- und Entwurfsmigration auf schemaäquivalenter Staging-DB testen.
3. Gezielt nötige produktive SQL-Migrationen nach Freigabe anwenden und unabhängig nachprüfen.
4. Signierte HTTP-Tests, danach UI-Smoke-Tests (Boxer und Coach).
5. Erst nach positivem Gate `main` mergen und Pages deployen, danach Postflight mit Rollbackplan. Kein GO LIVE ohne dokumentiertes PASS.

**Keine Produktivänderung ist Teil dieses Berichts.**


---
## Nachtrag: Final-Completion-Durchlauf (18.10.2026)

**Freigabestatus unverändert: NICHT RELEASE-READY. Hauptbranch, Produktiv-SQL und öffentliche Webseite unverändert.**

### Neu im Release-Branch
- `boxer.html`: echter Kalender der bestätigten Trainings, Streaks (mit Zürcher Trainingstag), Wochenchart, serverseitig gesperrte erneute Request-ID bei verfügbarer Migration, privater Benachrichtigungsbereich unter bestehendem Feature-Flag, rollenbegrenzte Änderungsübersicht.
- `coach.html`: echte Schnellansicht als Dialog/Bottom-Sheet, direkt aus der Freigabe- und Trainingsliste; Aktivitätsfilter, zuletzt angesehene Boxer, idle-schonender Refresh und Audit-Panel.
- `index-my-position.js`: eigener Ranking-Sprung nach authentifizierter Profilauflösung; Namensmehrdeutigkeiten blockieren die automatische Auswahl.
- `boxer-compare.html`: echte öffentliche Monatsrang- und Lifetime-EXP-Werte; auf diesem Gerät gespeicherte Favoriten ohne private Attribute.
- `takeover-ux-scroll.js`: Rücknavigations-/Tabscrollpositionen je Sitzung.
- `challenges.html`: frei editierbare Trainer-Vorlagen, echte aggregierte Bewertungsfortschrittsabfrage und Polling bei aktiver Ansicht.
- `duels.html`: read-only Zwischenstände aus einer geschützten Duel-RPC, wo die Migration verfügbar ist; kein erfundener Score bei deaktiviertem Backend.
- Rangberechnung auf öffentlichen Levels, Boxer-Dashboard, Profilansicht und Vergleich auf **10 Levels pro Rang** vereinheitlicht.
- `docs/TAKEOVER_LEAGUE_2_UX_45_RELEASE_MATRIX.md`: alle 45 UX-Punkte einzeln erfasst. **34/45 im Branch quellenbasiert integriert, 11/45 teilweise/offen; 0/45 abschliessend im echten Produktionsbrowser freigegeben.**

### Supabase TEST – ausgeführte Nachweise
- `20261018200000_training_submission_idempotency.sql`: Spalte `client_request_id` und eindeutiger Index `(boxer_id,client_request_id)` erfolgreich angelegt. Transaktionaler Duplicate-Insert-Test hat genau einen Datensatz akzeptiert; Rollback, keine Testreste.
- `20261018210000_duel_v2_live_scores.sql`: Berechtigungsgeprüfte RPC erfolgreich auf TEST angelegt. Unter simulierter Boxer-JWT-Rolle Testduell mit realer Funktion abgefragt (0:0 bei leeren Trainingstransaktionen), danach rollback. Anonymes EXECUTE verboten; keine persistierten Testduelle.
- `20261018220000_training_audit_reader.sql`: begrenzte RLS-/Rollenfunktion angelegt; unter simulierter JWT-Rolle eigene Historie lesbar, fremder Boxer explizit verboten. Keine Audit-JSON-Binärdaten an öffentliche Clients ausgegeben.
- Frühere `training_drafts_v2` RLS-Tests weiterhin gültig; `training_drafts_v2` und `client_request_id` bleiben in Produktion **nicht vorhanden**.
- Private persönliche Challenge-Zuweisung auf TEST mittels Test-only-kompatibler RPC-Aliasse `supabase/test-only/personal_assignment_compat_stage.sql` installiert, ohne bestehende TABLE-Rückgabesignaturen zu löschen. Produktionsgetreue interne Rollenprüfung nur im isolierten TEST ergänzt (`supabase/test-only/production_actor_contract_test_fixture.sql`). Transaktional nachgewiesen: Coach kann Ziel zuweisen, betroffener Boxer sieht es, anderer Boxer nicht, fremder Boxer kann Coach-Roster nicht lesen. Flags und Daten danach zurückgerollt; keine Testzuweisungen persistiert.
- **Wichtig:** Diese Testaliases ersetzen nicht den Test der originalen Produktivmigration `20261018170000_private_boxer_challenge_assignment.sql` auf einer DB mit vollständig identischen JSONB-RPC-Signaturen. Der zuvor gefundene 42P13-Unterschied im unabhängigen Testprojekt besteht in den ORIGINALEN Signaturen weiter.

### Nachprüfung produktiver Datenbank (nur SELECT)
- 13 aktive Boxer, 56 bestätigte Trainings, davon 35 durch `legacy_import` und 21 durch reguläre Trainings-Ledger erklärt; weitere 4 storniert mit 0 Punkten/0 EXP.
- Alle vier neuen Migrationselemente (private Drafts, Request-ID, Zwischenstands-RPC, Audit-RPC) und privates Challenge-Zuordnungsobjekt sind in Produktion **noch nicht vorhanden**. Keine produktiven Features/Flags geändert.
- Security Advisor: 7 Warnungen für anonym aufrufbare SECURITY-DEFINER-Funktionen, 54 für authentifizierte Rollen sowie geleakter-Passwort-Schutz deaktiviert. Diese sind Review-Einträge, nicht automatisch bestätigte Exploits; keine pauschale Änderung vorgenommen.

### Nachweis GitHub Actions
- Pull Request [#8](https://github.com/benditocapela-ux/takeover-league/pull/8) **besteht bereits als WIP/DRAFT**, kein Merge.
- Auf Commit `0f84614e56ce49766d534c00b2c63e448833f4e8`: [PR Integration Run 39151107876](https://github.com/benditocapela-ux/takeover-league/actions/runs/39151107876) **erfolgreich**: `static-checks`, `schema-integration (16)` und `schema-integration (17)` waren grün. JSDOM-/Public-HTTP-, lokale PostgreSQL-Integrations- und Transaktionsprüfungen wurden dort ausgeführt. Live-Pages-Schritt korrekt übersprungen.
- Neue zusätzliche `tests/release-ux-staging.cjs` und `release-2-validation.yml`: **am Commit `a3e06f2e721c95110825313ca794285caec70751` beide Workflows erfolgreich** – [staging validation 39151490153](https://github.com/benditocapela-ux/takeover-league/actions/runs/39151490153) und [V2 integration 39151490159](https://github.com/benditocapela-ux/takeover-league/actions/runs/39151490159). Staging lief mit 6 erfolgreich ausgeführten Node/JSDOM-Prüfungen; V2 Integration mit erfolgreich abgeschlossenen PostgreSQL-16-, PostgreSQL-17- und Static/HTTP-Jobs. Ein grüner CI-Lauf ist kein Ersatz für produktive RLS-, Login- und Browser-End-to-End-Tests.

### Verbleibende harte Gates vor GO LIVE
1. TEST- und Produktivschema/Versionen inklusive Original-42P13-Migration auf gleichartiger Staging-DB vollständig nachstellen; Änderungsreihenfolge und Rollback sichern.
2. Produktives Backup/Restore und verantwortliche Person für Produktion bestätigen; erst danach explizite SQL-Freigabe einholen.
3. Rollenunterschied `coach` vs `admin` bei `review_training` und Admin-Dashboard sicher lösen; coach darf nicht stillschweigend andere Admin-Rechte erhalten.
4. Signierte echte HTTP-Login-/Benutzerrollen-E2E-Tests sowie Mobile-Browsertests für Boxer/Coach durchführen; kein Zugangspasswort im Repository.
5. Audit bei Metrikkorrekturen, echte sichere Rücknahmen, vollständige automatische Zielfortschritte und konsistente Bedienmuster abschliessen; siehe 11 offene UX-Punkte.
6. Security-Advisor-Meldungen gezielt einzeln prüfen, gegebenenfalls Testfixes, erneute Advisors, finale CI für exakten Release-SHA.
7. Release-Freeze, DDL und Flag-Gates nach eigener Abnahme, dann **separates ausdrückliches GO LIVE**.


---

# Abschlussnachtrag – 18.10.2026, Release-Branch nach UX-Runde 2

**Aktueller Beschluss: NICHT RELEASE-READY.** Frühere offene Punkte gelten nur dort als geklärt, wo unten eine konkrete Prüfung genannt ist. Keine Live-Änderungen.

## Neu integrierte reale Ansichten
- Boxer: Trainingskalender (30 Tage), Wochenstatistik, Trainingstage-Streak aus bestätigten Supabase-Einträgen, eigene private Mitteilungen nur bei freigeschaltetem Feature-Flag, Unterstützung von Client-Request-IDs bei Trainingseinreichungen.
- Coach: Boxer-Schnellansicht als Dialog/mobile Bottom-Sheet, kürzere Direktaktionen, automatische Aktualisierung bei Inaktivität, Admin-Audit-Anzeige über dedizierte RPC (zurzeit in Produktion noch nicht installiert).
- Liga: `boxer-compare.html` mit öffentlichen Live-RPC-Daten und lokalen Favoriten, `index-my-position.js` für eigenes Ranking, gemeinsames `takeover-ux-scroll.js` für Zurück-Navigation, einheitliche Berechnung von zehn Levels pro Rang.
- Duelle: Eindeutige Bestätigung von Gegner/Dauer vor Einladung; `duels.html` bezieht Provisorium von `duel_v2_live_scores` (noch nicht produktiv migriert); automatischer Refresh bei aktiver Sitzung.

## UX-45-Status
Siehe `docs/TAKEOVER_LEAGUE_2_UX_45_MATRIX_2026-10-18.md`: **34/45 als Code im Release-Branch**, **5/45 Staging/Flag**, **5/45 teilweise**, **1/45 offen**. Dies ist ausdrücklich **keine** vollumfängliche Live- oder End-to-End-Abnahme. Ein umfassender Rollout aller 45 UX-Punkte ist noch nicht technisch bestätigt.

## Neue TEST-Datenbankprüfungen
- `20261018190000_training_drafts_v2.sql`: sichere, private RLS-Entwürfe im isolierten Supabase-Testprojekt, anonyme Rechte gesperrt.
- `20261018200000_training_submission_idempotency.sql`: einzigartige Kombination von Boxer und Request-ID; Transaktion mit Doppelversuch abgewiesen, danach Rollback.
- `20261018210000_coach_training_audit_read.sql`: geschützte Audit-RPC im TEST installiert; signierten JWT-Kontext unter `SET LOCAL ROLE authenticated` simuliert. Boxer abgewiesen, Admin zugelassen.
- `20261018211000_duel_v2_live_scores.sql`: geschützte Live-Score-RPC im TEST installiert. Teilnehmer mit gültigem Auth-Kontext erhält vorläufige Werte; nicht verknüpfter Benutzer abgewiesen; keine Detaildaten ausgegeben; kein produktiver SQL-Lauf.
- Die TEST-Datenbank enthielt die Rollenkontraktfunktion `league_private.coach_v2_actor` nicht. Eine isolierte, an Produktion angelehnte Test-Funktion wurde angelegt. Die persönliche Challenge-Zuweisung liess sich über TEST-Aliasfunktionen ohne destruktiven Ersatz inkompatibler `TABLE`-Rückgabetypen installieren. Transaktionaler Test: beauftragter Boxer sieht die Challenge, fremder Boxer nicht, Boxer hat keinen Coach-Roster-Zugang; Rollback ohne Testdatenspuren. **Echte identische produktionsnahe Migration aller Versionen weiterhin offen.**

## CI nach aktivierter Draft-PR
- [Draft Pull Request #8](https://github.com/benditocapela-ux/takeover-league/pull/8) gegen `main`, ausdrücklich WIP, nicht gemerged, nicht deployed.
- `Takeover League V2 Integration Checks`: Statische Browser-/Source-Tests und PostgreSQL 16/17-Schema-Integration bestanden (PR-Run 39151451007; danach erneut erfolgreich für Commit `109f4aa`).
- `Takeover League 2 - staging validation (no deploy)`: Ein Testfehler bei der fehlenden Duell-Bestätigungsfunktion wurde aus realem Log (Run 39151280614) reproduziert und am Code behoben; spätere Runs 39151450976 und 39151585694 waren erfolgreich.
- **Eine grüne CI ist keine reale Boxer-/Admin-Anmeldung und kein Test auf iOS/Android.** Ergebnisse nach diesem Bericht müssen jeweils dem letzten Release-Commit zugeordnet sein.

## Noch offene Release-Gates (zwingend)
1. Produktive Backups und getesteter Restore; nach expliziter Freigabe geprüfte additive Migrationen in Produktionsreihenfolge anwenden; TEST- und Produktions-Rückgabetypen harmonisieren bzw. schemaidentisches Staging herstellen.
2. Verbindlich entscheiden, ob nur `admin` oder auch `coach` Trainings bestätigen darf. Aktuelle Produktions-RPC `review_training` prüft bewusst nur aktive Admins. Keine ungetestete Rollenerweiterung.
3. Vollständiger, authentifizierter Browser-/HTTP-E2E-Test mit echten Testbenutzern für Boxer, Coach und Admin; prüfen, dass RLS und Statuswechsel unter realen JWTs korrekt funktionieren.
4. Nach Migration der zusätzlichen RPCs Live-Duellstände, Audit-Anzeige, Entwürfe und Request-ID-Retry-End-to-End testen. Feature-Flags nach Freigabe einzeln aktivieren.
5. Sicheres Rückgängig bestätigter Transaktionen (#37) benötigt eine transaktionale und auditierbare Korrekturlogik. Keine unkontrollierte Löschung oder rückwirkende Punkteveränderung.
6. Mobile Tests auf echten Geräten, Accessibility, 45-UX-Akzeptanzliste, Leistungs-/Ausfalltests und Prüfung der Supabase Security Advisor Warnungen inklusive Leaked Password Protection.
7. Nach den finalen Änderungen müssen alle CI-Workflows erfolgreich sein; erst danach können Betreiber-Review, manuelle Go-Live-Freigabe und `main`-Merge stattfinden.

**Verifiziert:** Hauptbranch und produktives Supabase-Projekt wurden in diesem Durchlauf nicht verändert; nur isoliertes TEST-Projekt und Release-Branch wurden bearbeitet.
