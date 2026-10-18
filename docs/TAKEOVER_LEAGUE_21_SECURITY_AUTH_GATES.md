# Takeover League 2.1 – Sicherheits-, Auth- und Backup-Gates

Stand 19.10.2026. PR #11 bleibt DRAFT. Kein Merge, keine Produktionsmigration, kein Deployment.

## Verifizierte Leseprüfung

- Produktivprojekt: iqarjivcrddcixrvqbfb; TEST-Projekt: cfgdvcccsqwfjajuizsr. Keine Änderungen in PROD.
- Supabase TEST: 3 Auth-Konten, 2 verknüpfte Boxer, 1 Admin, kein Coach und 0 Ziel-Fixtures. Das reicht noch nicht für echte Vier-Rollen-E2E-Abnahme.
- PROD: 11 Auth-Nutzer, 1 Storage-Bucket, 1 Storage-Objekt, 13 aktive Boxer, 61 genehmigte Trainings, 72 Punktebuchungen. Eine Bestandszählung ist **kein Backup**.
- Supabase Advisor PROD: 6 anonym ausführbare, 60 authentifiziert ausführbare SECURITY-DEFINER-Funktionen; Leaked Password Protection deaktiviert; 11 RLS-ohne-Policy-Hinweise.

## Sichtung der 60 Auth-RPCs

| Pfad | Anzahl | Ergebnis |
| --- | ---: | --- |
| Direkte auth.uid()-Referenz | 34 | Identitätsbezug vorhanden; vollständige Rollen-/Besitzprüfung je RPC steht aus |
| Zentraler league_private.coach_v2_actor() | 20 | Helper prüft Anmeldung, aktives Profil, Rolle und Feature-Flag; einzelne Endpoint-Rechte weiter prüfen |
| Delegation an admin_edit_training | 1 | Der aufgerufene RPC prüft die aktive Admin-Rolle; vollständige Geschäftslogikprüfung steht aus |
| Öffentlich lesende Auswertungen | 5 | Nur öffentlich vorgesehene Rückgabespalten; Datenschutzfreigabe steht aus |

Die fünf öffentlichen Auswertungen sind get_award_leaderboard, get_monthly_awards, get_public_boxer_avatars, get_public_leaderboard und get_public_levels. Die sechste anonym ausführbare Funktion is_league_admin gibt nur einen anhand auth.uid() serverseitig berechneten Boolean zurück.

Stichproben am vollständigen Funktionskörper: coach_v2_actor, coach_challenge_v2_activate, coach_challenge_v2_join, league_assign_personal_challenge, league_cancel_personal_challenge, admin_edit_training, admin_edit_training_details, coach_link_boxer_account, get_league_challenge_progress und öffentliche Auswertungen. Keine konkrete Rollen-Umgehung in diesen Stichproben nachgewiesen. **Nicht gleichbedeutend mit einer vollständigen Sicherheitsfreigabe.**

## Neuer echter, strikt lesender Test

Neue Datei: tests/league-21-auth-staging-readonly.cjs

- Login über echte Supabase-Auth für Boxer A, Boxer B, Coach und Admin, mit aktiven Rollenprofilen.
- Anonymer Zugriff auf private Tabellen verboten; bereinigte öffentliche Badge-/Duellprojections lesbar.
- Fremdzugriff auf Boxer-Ziele und manuellen Zielfortschritt blockiert; Admin-Sicht auf vorhandenes Testziel erlaubt.
- Erfordert ein bereits vorhandenes TEST-Ziel für Boxer A; andernfalls gilt die Abnahme ausdrücklich als nicht bestanden.
- Nur Auth-Login und GET-Leseabfragen, **keine** Trainings-, Ledger-, Ziel-, Saison- oder Duellmutationen.
- Festes Sicherheitslimit auf https://cfgdvcccsqwfjajuizsr.supabase.co; Produktionszugriffe werden abgebrochen.

Node 22, Ausführung: node tests/league-21-auth-staging-readonly.cjs

Die Zugangsdaten werden nur über vertrauliche lokale Umgebungsvariablen übergeben (nicht ins Repository, PR-Kommentare oder Chat einfügen):

- LEAGUE21_TEST_URL und LEAGUE21_TEST_PUBLISHABLE_KEY
- LEAGUE21_BOXER_A_EMAIL / LEAGUE21_BOXER_A_PASSWORD
- LEAGUE21_BOXER_B_EMAIL / LEAGUE21_BOXER_B_PASSWORD
- LEAGUE21_COACH_EMAIL / LEAGUE21_COACH_PASSWORD
- LEAGUE21_ADMIN_EMAIL / LEAGUE21_ADMIN_PASSWORD

Der vollständige E2E-Test ist **noch nicht ausgeführt**, weil insbesondere Coach-Zugang und Testziel fehlen. Echte Accounts dürfen nicht durch simulierte Playwright-Accounts ersetzt werden.

## Echtes Produktionsbackup – weiterhin BLOCKER

Der bestehende pg_dump/pg_restore-Beweis betrifft nur isolierte Wegwerf-Datenbanken. Er ersetzt nicht:

1. Verschlüsseltes, vollständiges und aktuell datiertes Backup der echten Produktivdatenbank mit Auth-Schema, Rollen-/Funktionseinstellungen und Ledger.
2. Separates Backup der **Storage-Objektinhalte** und der zugehörigen Policies (DB-Dump enthält nicht automatisch Objektdateien).
3. Sicheres Inventar extern erforderlicher Auth-, E-Mail- und Secret-Konfiguration, ohne Credentials im Git zu sichern.
4. Wiederherstellung in einem getrennten, geschützten Ziel und Kontrolle von Zählern, Ledger, Auth und Storage.
5. Nachgewiesene Restore-Abnahme mit Protokoll vor einer Migration oder Freigabe.

Ein vollständiger produktiver Backup-/Restore-Lauf wurde weder gestartet noch behauptet. Dafür ist eine autorisierte, speziell dafür geeignete Backup-/Restore-Schnittstelle erforderlich.

## Release-Gates

- [ ] Echte Boxer-A, Boxer-B, Coach- und Admin-Test-Logins und private Ziel-Fixture
- [ ] Vollständiger RPC-/RLS-/Fremdzugriffs-Audit und Passwortschutz
- [ ] Vollständiger anonymisierter Produktionsklon samt relevanter Funktionen und Auth-/Storage-Abhängigkeiten
- [ ] Echtes, wiederhergestelltes Produktionsbackup
- [ ] Neueste GitHub-CI grün und separate ausdrückliche GO-LIVE-Freigabe

**NO MERGE / NO PROD SQL / NO DEPLOY.**
