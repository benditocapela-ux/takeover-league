> **RELEASE-NACHTRAG 19.10.2026:** Die untenstehende TEST-/STAGING-Dokumentation ist historisch. Die Eigentümerfreigabe wurde danach erteilt: PR #13 (`b86da16`) und PR #14 (`b9417cb`) sind auf `main`, die zugehörigen Migrationen in Produktion angewendet. **Echte Login-/Signup-E2E-, Produktionsbackup/Restore- und vollständige Sicherheitsabnahmen sind weiterhin nicht erledigt.** Verbindlicher aktueller Stand: [RELEASE_STATUS_2_1_2026-10-19.md](RELEASE_STATUS_2_1_2026-10-19.md).

# Takeover League – Registrierung und Adminverwaltung (19.10.2026)

## Release-Gate
Status: **STAGED / TEST**, NICHT produktiv. Kein Merge, keine GitHub-Pages-Veröffentlichung, keine SQL-Ausführung in Produktion ohne ein NEUES ausdrückliches FREIGEBEN. Diese Änderung baut auf dem Coach-Rollenmodell aus PR #13 auf. Reihenfolge der SQL-Dateien: zuerst Coach-Rollenrechte aus 20261019040000, danach 20261019072000_admin_registration_profiles.sql.

## Datenmodell und Sicherheit
Die vorhandene Profile-ID wird nie ersetzt. profiles.auth_user_id ist ausschliesslich die Auth-Verknüpfung, profiles.email eine normalisierte, case-insensitiv eindeutige Vorabzuordnung. is_listed ist für Neuanmeldungen FALSE. Bestehende Profile sind ausschliesslich beim ERSTMALIGEN Anlegen der Spalte auf TRUE gesetzt. Eine erneute Migration macht neu angemeldete private Boxer nicht öffentlich.

Der Trigger public.handle_new_user() auf auth.users legt nach dem Signup ein aktives nicht öffentliches Boxerprofil an oder verknüpft ein passendes vorbereitetes Profil mit auth_user_id IS NULL. Die alten Trainings, Punkte, EXP, Rolle, Profil-ID und Sichtbarkeit bleiben beim Vorabprofil erhalten. raw_user_meta_data.display_name dient nur als Anzeigename, niemals für Rechte. Andere Profilverknüpfungen werden nicht überschrieben.

Alle Mutationen sind aktive ADMIN-only SECURITY-DEFINER-RPCs. Vier RPCs setzen Rolle (boxer oder coach), Aktivität, Sichtbarkeit und die vorbereitete E-Mail. Die Rolle admin kann weder vergeben noch beim Eigentümer entfernt werden, und der letzte aktive Admin kann nicht deaktiviert werden. Adminaktionen erhalten einen Audit-Eintrag in profile_admin_audit (RLS und keinerlei Client-Schreibrechte). admin_list_profiles() liefert keine Auth-User-ID und keinerlei Trainingsdaten. Bestehende public.is_league_admin()- und recalculate_boxer_bonuses()-Definitionen werden nicht geändert.

Die vier öffentlichen Projektions-RPCs (Rangliste, Levels, Monats-Awards, Avatar) verlangen ab sofort is_listed=true. Die privaten Legacy-Duell- und V2.1-Arena-Scores verweigern nicht freigegebene/inaktive Teilnehmer, damit diese keine Namen/IDs offenlegen. Bereits bestehende Feature-Flags bleiben unverändert.

## Separate Verwaltungsseite
admin.html ist absichtlich nicht Teil des Coach-Dashboards: Nur Eigentümer dürfen Konten verwalten. Auf Handy werden Tabellenzeilen als Karten angezeigt. Die Navigation zeigt den Admin-Eintrag erst nach Prüfung des aktuell authentifizierten aktiven Adminprofils; der Server kontrolliert unabhängig nochmals. Die vollständige Auth-Login-Sperre wird nur als kopierbarer SQL-Hinweis gezeigt; keine ausführbare Schaltfläche und kein service_role-Key.

In coach.html wurden die veralteten Client-Aufrufe auf coach_list_unlinked_accounts und coach_link_boxer_account entfernt. Die RPCs bleiben datenbankseitig unangetastet.

## Judy, Vaarun und Wiran
- Judy: 6 Trainings / 6 Punktebuchungen. Admin trägt die korrekte E-Mail im existierenden, noch nicht verknüpften Profil ein. Die Person registriert sich mit exakt dieser Adresse. Trigger verknüpft dieselbe Profil-ID, Punkte bleiben.
- Vaarun: 2 Trainings / 2 Punktebuchungen. Genauso; NIE ein zweites Profil anlegen.
- Wiran: 0 Trainings / 0 Buchungen. Empfohlen derselbe Pfad. Falls schon ein neues Profil existiert, das alte leere Profil deaktivieren und die öffentliche Sichtbarkeit abschalten. Dadurch bleibt nur ein aktiver Eintrag, die verwaiste ID wird ohne Löschen beibehalten. **Dies ist kein allgemeiner Daten-Merge**: Sobald auf BEIDEN Profilen historische Buchungen existieren, ist eine separate auditierte Merge-Funktion erforderlich; keine manuelle Umschreibung von Punkten/IDs.

## Testprotokoll – Testprojekt cfgdvcccsqwfjajuizsr
1. Read-only-Metadatenprüfung: Testprojekt hat einen echten mit auth.users verbundenen Admin, Coach und Boxer. Auth-Trigger vorher nicht vorhanden; produktive Legacy-Public-Statistik-RPCs im isolierten Testprojekt fehlten.
2. tests/admin-registration-test-baseline.sql installiert nur im TEST die vier unveränderten produktiven Statistikdefinitionen (mit league_test_boxers-Sentinel). Keine Production-Änderung.
3. Migration supabase/migrations/20261019072000_admin_registration_profiles.sql wurde im TEST erfolgreich installiert und idempotent nochmals ausgeführt.
4. tests/admin-registration-roles-fixture.sql wurde in EINER Transaktion (BEGIN, SET LOCAL ROLE authenticated, nachgewiesene Auth-User-IDs und ROLLBACK) erfolgreich ausgeführt. Bestanden: nicht gelisteter Boxer mit Trainings/400 Punkten erscheint in keiner der vier öffentlichen RPCs; nach Admin-Freigabe in Rangliste/Levels/Avataren sichtbar; Admin-Rolle und Sichtbarkeit; Aktivierung/Deaktivierung; Vorbereitung/Normalisierung der E-Mail; Audit; letzter Admin geschützt; Boxer darf keine Rolle vergeben; deaktivierter Coach darf die Boxerliste nicht lesen. Es bleiben keine Testpunkte bestehen.
5. **Offen:** Der Tool-Aufruf zur testweisen künstlichen Erstellung eines auth.users-Datensatzes wurde von einer Sicherheitskontrolle blockiert. Er wurde nicht umgangen. Deswegen sind echter Supabase Auth signUp → DB-Trigger → vorbereitete E-Mail-Verknüpfung und Passwort-Login bisher NICHT end-to-end verifiziert. Die Triggerinstallation und Definition wurden nur indirekt/statisch geprüft, nicht mit einem neuen Auth-Event. Keine irreführende Abnahmebehauptung.
6. Keine Veränderungen an der Produktionsdatenbank iqarjivcrddcixrvqbfb, keine Löschung oder Änderung von echten Punkten oder Feature-Flags.

## SQL-Editor und nächste Abnahme
1. Vor jeder Freigabe auf Produktion zunächst supabase/production-prep/admin_registration_preflight_read_only.sql ausführen und alle 14 Profile, vorhandenen 3 unverknüpften Boxer und den fehlenden Auth-Trigger prüfen.
2. Auf dem TEST-Projekt die Migration ist bereits installiert. Dort tests/admin-registration-roles-fixture.sql im SQL-Editor aufrufen (ROLLBACK am Schluss); anschliessend admin_registration_postflight_read_only.sql.
3. Echten Signup nachholen: einen NICHT produktiven Testnutzer über die Auth-Registrierung des Testprojekts erstellen und E-Mail bestätigen, falls benötigt. Anschliessend testen, ob genau ein aktives, privates Profil entstanden ist, Anmeldung plus Trainingseinreichung geht, und nichts öffentlich erscheint. Für den Vorbereitungsfall eine Testprofil-E-Mail VOR Registrierung setzen und prüfen, ob die Profil-ID/Punktehistorie erhalten bleiben. Test-Accounts niemals an die Produktions-URL senden.
4. Erst nach diesem Test und erneutem **FREIGEBEN** die beiden versionierten Migrationen nacheinander über den regulären Supabase-Migrationsweg in Produktion anwenden. Danach read-only Postflight und authentifizierte Browser-Abnahme.
5. Rückrollskript: supabase/production-prep/rollback_20261019072000_admin_registration.sql. Es ist bewusst NICHT destruktiv: schaltet neuen Trigger und Admin-RPCs ab, bewahrt E-Mails, Profile, Audit und öffentliche is_listed-Filter. Ein vollständiges Zurücksetzen der öffentlichen RPCs auf die vorherigen ungefilterten Versionen würde private Registrierungen veröffentlichen und wird ausdrücklich NICHT vorgenommen.

**Abnahmeentscheidung: NO-GO für Produktion bis der echte Auth-Registrierungstest bestanden ist und der Eigentümer FREIGEBEN erteilt.**

## Release-Review: Coach bleibt Boxer und öffentliche Privatsphäre
Vor der Freigabe wurde ein Defekt in den öffentlichen Auswertungen entdeckt:
die alten Funktionen filterten ausschliesslich `role='boxer'`, wodurch ein zum Coach
beförderter Boxer aus dem öffentlichen Ranking verschwunden wäre. Die anonyme
Auswertung `get_award_leaderboard` berücksichtigte ausserdem die neue
`is_listed`-Freigabe noch nicht.

Nach der Registrierungsmigration folgt deshalb die additive,
idempotente `supabase/migrations/20261019080000_coach_public_listed_projection.sql`.
Sie schützt **alle fünf** öffentlich lesbaren Rang-/Award-RPCs mit
`is_listed=true` und zählt `role in ('boxer','coach')` gleichermassen.
Die Funktion `public.is_league_admin()` und die Trainings-/Punktebuchungen
werden nicht geändert.

Transaktionaler Test `tests/coach-public-listed-rollback.sql`: Test-Coach wird
bei `is_listed=false` in allen fünf RPCs ausgeblendet. Bei aktiver öffentlicher
Freigabe erscheint er mit bestätigtem Training in Rangliste, Levels und Awards.
**Im Supabase-Testprojekt bestanden, endet mit ROLLBACK.**

**Produktionsreihenfolge ergänzt:** 20261019040000 → 20261019072000 →
20261019080000. Echte Auth-SignUp-End-to-End-Abnahme bleibt ausdrücklich offen.

**Safe rollback for public coach ranking:** `supabase/production-prep/rollback_20261019080000_coach_public_listed_projection.sql` setzt die fünf Public-RPCs auf Boxer-only zurück, erhält jedoch zwingend `is_listed=true` als Datenschutzfilter. Erfolgreich auf TEST zurück- und wieder ausgerollt; kein Produktiv-Rollback ohne eigene Freigabe.
