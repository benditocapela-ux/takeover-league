# Takeover League – Coach als Boxer mit Trainerrechten (19.10.2026)
## Freigabestatus
**NUR TEST UND REVIEW. Kein Produktions-Merge und keine Produktionsmigration ohne neues, ausdrückliches FREIGEBEN.**
- Produktion: `iqarjivcrddcixrvqbfb` – in dieser Aufgabe nur Read-only-Inspektion; keine Migration oder Datenänderung.
- Test: `cfgdvcccsqwfjajuizsr` – Migrationsanwendung und ROLLBACK-Fixtures geprüft.
- Migrationsquelle: `supabase/migrations/20261019040000_coach_role_permissions.sql`.
- Rückrollskript: `supabase/production-prep/rollback_20261019040000_coach_role_permissions.sql`.
- Test-Bootstrap: `tests/coach-role-test-bootstrap.sql` (an `league_test_boxers` gebunden, **niemals in PROD ausführen**).
- Test-Fixture: `tests/coach-role-transaction.sql` (sämtliche Test-Datenänderungen innerhalb `BEGIN ... ROLLBACK`).

## Rollen und Grenzen
- **Admin**: exakt ein Eigentümer. Verknüpft Konten, darf zukünftig Rollen setzen und Profile aktivieren/deaktivieren. `public.is_league_admin()` bleibt unverändert.
- **Coach**: aktiver Boxer mit Trainerrechten: Training selbst einreichen, bestätigen, ablehnen und korrigieren; Audit; aktive eigene Trainingsentwürfe, Benachrichtigungen und Avatar; Legacy-Challenges, Saisons und Duelle inklusive Abschluss. **Hall-of-Fame-Einträge, Palmarès und Achievement-Definitionen sind bewusst Coach-Rechte**.
- **Boxer**: eigene Trainings im Status pending einreichen, keine Review- oder Korrekturrechte, keine direkte Ledger-Schreibbefugnis.
- **Deaktiviert**: keine Trainer-RPCs; die drei Basis-SELECT-Policies für Profile, Trainings und Punkte enthalten nun eine Aktivitätsprüfung.
- **Profile lesen**: Coach erhält `id, display_name, role, is_active` nur über `coach_list_boxers()`. **Kein `auth_user_id`**. Der Admin nutzt für Kontoverknüpfungen weiterhin seinen alten getrennten Weg. Kontofunktionen `coach_list_unlinked_accounts` und `coach_link_boxer_account` bleiben admin-only.
- **Automatische Trainingsboni**: Der öffentlich vorhandene `recalculate_boxer_bonuses(uuid)` bleibt **admin-only**. Nur die autorisierten Trainings-Review-/Korrektur-RPCs verwenden für Coaches eine nicht exponierte, eng gesperrte interne Variante in `league_private`. Coaches können nicht beliebige globale Boni neu berechnen.
- **Keine Feature-Flags geändert**. Auch abgeschlossene Saisons, globale Challenges oder Hall-of-Fame-Einträge bleiben unter bestehenden Feature-Flag-Gates.

## Testprotokoll – isoliertes Supabase-Testprojekt
1. Test-Schema inventarisiert: Es fehlten produktive Legacy-Saison/Challenge-Tabellen sowie `review_training` und weitere Basishilfsfunktionen. Bootstrap klont nur für den Test benötigte Original-RPCs; es legt einen verifizierten Coach über eine bereits existierende, zu `auth.users` verknüpfte Test-Boxeridentität an.
2. `apply_migration` für Coach-Rollenrechte im Testprojekt erfolgreich. Die finale SQL wurde erneut angewendet (idempotente Wiederholung).
3. SQL-Fixture unter `SET LOCAL ROLE authenticated` und testweisen `request.jwt.claim.sub`-Werten erfolgreich: Coach-Zugriff, `coach_list_boxers()`, Review eines pending-Trainings, **passende Punkte und EXP in `point_transactions`**, `boxer_notifications` des Boxers.
4. Boxer-Identität: `review_training` verweigert; keine direkte Punktebuchung möglich.
5. Deaktivierter Coach: `is_league_coach=false`, Boxerliste und Trainingsfreigabe gesperrt.
6. `ROLLBACK` entfernt die temporären Trainings, Ledger-Einträge, Benachrichtigungen und die temporäre Aktivitäts-/Flag-Änderung. Das dauerhaft vorhandene, echte Test-Coach-Profil bleibt bestehen.
7. *Testgrenze*: SQL-Session emuliert eine authentifizierte Anfrage anhand existierender `auth.users`-IDs; kein echtes Browser-Login mit Coach-Passwort. Statische und Chromium-Checks über GitHub CI separat prüfen.


## Vertiefte Abnahme vom 19.10.2026
- Der Coach kann **ein eigenes pending-Training ohne Ledger-Eintrag** anlegen; eigenes Training bleibt Boxer-Arbeit, keine Selbstfreigabe.
- Coach darf die anderen Boxer-Stats über `get_boxer_exp_level_rank` und `get_boxer_performance_30d` lesen, während ein Boxer fremde Coach-Stats nicht sehen darf. Beide RPCs nutzen ein fest gepinntes leeres `search_path`, `SECURITY DEFINER`, eine aktive serverseitige Viewer-Prüfung und nur `authenticated` EXECUTE. Es wird **keine breite SELECT-Policy auf profiles** geschaffen.
- Trainerkorrektur mit `admin_edit_training_details` und Audit ist erfolgreich; jüngste eigene Ablehnung kann ohne Ledger-Buchung zurückgenommen werden.
- Direkter Aufruf der globalen Bonusberechnung durch Coach wurde aktiv verweigert. Deaktivierte Coaches können weder die Trainerliste lesen noch Trainings genehmigen.
- Gesamter Rollback der Rollenmigration auf dem **TEST-Projekt** erfolgreich. Die finale Hauptmigration danach erneut eingespielt, Fixture erneut erfolgreich. Zweites Einspielen der Hauptmigration ebenfalls erfolgreich (idempotent).
- Verifiziert nach dem Transaktions-Test: **0 verbliebene Fixture-Trainings, 0 verbotene Ledger-Einträge und 0 Fixture-Benachrichtigungen**. Das originale Coach-Testprofil bleibt aktiv und auth-verknüpft.
- Im Testprojekt fehlen weiterhin diverse Legacy-Saison- und Duelldatenbankobjekte. Diese Methoden stammen unverändert aus den **read-only verifizierten Produktionsdefinitionen**, wurden aber **nicht vollständig mit echten Coach-Saison-/Duelltransaktionen getestet**. Vor Produktivfreigabe bestehende Feature-Flags prüfen; keine Flag-Aktivierung ohne separaten Auftrag.
- Weder Production-Browserlogin mit Coach-Passwort noch eine Live-Session aller 19 Seiten durchgeführt; GitHub-CI liefert gemockte Browser- und SQL-Kompatibilitätsprüfungen.

## SQL-Editor (nach späterer FREIGABE für PROD)
1. Im **Testprojekt** vor Änderungen `tests/coach-role-test-bootstrap.sql` (nur dort) und dann die Hauptmigration über den regulären Migrationsweg anwenden. Testbootstrap und finale Migration wurden hier bereits testweise ausgeführt.
2. `tests/coach-role-transaction.sql` im **TEST** SQL-Editor ausführen. Das Ende ist `ROLLBACK`. Erfolg = keine SQL-Exception; `NOTICE PASS` in der Ausgabe.
3. Vor Produktion `supabase/production-prep/coach_role_preflight_read_only.sql` read-only ausführen, Ergebnis prüfen und Datenbanksicherung extern verifizieren.
4. Erst auf erneutes **FREIGEBEN** die versionierte Hauptmigration über Supabase-Migrationsweg in PROD anwenden; kein SQL-Editor-Schema-Hotfix. Danach `supabase/production-prep/coach_role_postflight_read_only.sql` read-only prüfen.
5. Rollback nur unter neuem, ausdrücklichem Auftrag und nach Prüfung laufender Traineraktionen ausführen. Rollback ändert keine Punkte oder Trainingsdaten und ersetzt Funktionen und Policies durch die ursprünglichen Definitionen. Er nimmt keine Profil-Rollenvergabe vor.

**Hinweis:** Trainerkonten-/Rollenverwaltung ist Teil 4 und **nicht** Bestandteil dieses Changesets. Auf Produktion bleibt vorerst jedes existierende Profil bei seiner aktuellen Rolle.
