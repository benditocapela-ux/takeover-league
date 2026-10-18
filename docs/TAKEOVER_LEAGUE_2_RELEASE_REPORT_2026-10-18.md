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
