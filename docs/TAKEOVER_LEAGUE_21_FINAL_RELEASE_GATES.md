# Takeover League 2.1 – Release-Abnahme / 10-Minuten-Durchlauf
Stand: 18. Oktober 2026 (Schweizer Zeit), Entwicklung ausschließlich auf `develop/takeover-league-2.1-all-features`, Draft-PR #11.

## VERÖFFENTLICHUNG GESPERRT – NO GO LIVE
Keine GitHub-Merge-Freigabe und **keine** produktiven Schema-, Flag- oder Datenmutationen vorgenommen.
Die fehlenden echten Boxer/Admin/Coach-Login-Tests und ein getestetes Produktions-Backup inklusive Wiederherstellung sind verbindliche Release-Gates.

## Nachgewiesene Ergebnisse
- GitHub PR-Workflows: `Takeover League V2 Integration Checks` und `Takeover League 2 - staging validation (no deploy)` waren vor dieser Runde grün. Statische und PostgreSQL 16/17-Checks grün, Chromium-Tests erfolgreich. Neue Commits müssen erneut vollständig grün werden.
- Produktionsdatenbestand – **nur SELECT**: 13 aktive Boxer, 67 Trainings (61 approved, 0 pending), 72 Punktebuchungen, 1 offenes Duell (`pending`), 0 Duell-EXP-Buchungen, 32 aktive Achievement-Definitionen und 0 verliehene Abzeichen. Keine fehlenden oder doppelten bestätigten Trainingsbuchungen.
- Supabase TEST: Neuer Head-to-Head-Projektionstrigger mit INSERT, Korrektur, idempotenter Folgekorrektur, anonymem SELECT ohne DELETE und Stornierung, alles in ROLLBACK geprüft.
- Supabase TEST: Saisonabschluss blockiert bis alle Trainings bewertet; gemeinsame Platzierung bei Gleichstand, Vermeidung doppelter Abschlussläufe; Rollenprüfung, ROLLBACK.
- Supabase TEST: Abschluss-Transaktionen von Saison, Mehrgegner-Arena und globaler Liga-Challenge wurden mit Sperrung der betroffenen Trainingseinträge gegen parallel laufende Freigaben gehärtet.
- Supabase TEST: Die vorhandenen transaktionalen Saison-, Arena- und Underdog-Duelltests wurden nach dem Locking erneut erfolgreich durchlaufen. Globale Liga-Challenge mit zwei gleichplatzierten Gewinnern und genau einmaligen 50-EXP-Zahlungen ebenfalls erneut erfolgreich. Alle Tests ROLLBACK.
- Head-to-Head Browserprüfung über öffentliche anonym lesbare, bereinigte Duellergebnisdaten; responsive Tests vorhanden.
- Liga-Challenge-Client nutzt die gleiche Zeitlogik wie die DB (Training nach Beitritt und vor Ende eingereicht) und Schweizer CET/CEST statt festem +02:00.
- Produktions-/Test-Profil der gemeinsamen Basistabellen: 75 Spalten in beiden Datenbanken. Unterschied ausschließlich bei `point_transactions.description` und `training_submissions.notes`: in Produktion NOT NULL, in TEST NULL-fähig. Anwendungs- und Migration-SQL auf reale Produktions-Constraints prüfen.
- Neue `league_v21_*` Privilegien: Öffentliche API-Wrapper als SECURITY INVOKER; anonyme EXECUTE-Rechte für neue Administrator-/Boxer-RPCs nicht vorhanden. Private Funktionen liegen in separatem Schema, jede vom Client ausgelöste Mutation prüft den Akteur serverseitig.

## Weitere nachgewiesene Arbeit (19.10.2026)
- Produktions-Preflight **grün und ausschliesslich lesend**: `supabase/production-prep/league_21_preflight_read_only.sql`. Prüft notwendige V2-Basistabellen und Funktionen, aktive Boxer/Admins, Original-Flags, 61 genehmigte Trainings ohne fehlende/doppelte Punkteleger sowie effektive RLS-Isolation.
- Staging-Postflight **grün**: `supabase/production-prep/league_21_postflight_read_only.sql`. Alle 17 V2.1-Tabellen, RLS, öffentliche vs. private Lese-/Schreibrechte, API-Wrapper-Sicherheit, H2H-/Ziel-Trigger und EXP-Ledger erfolgreich geprüft.
- Grundberechtigungen in PROD sind historisch sehr weit gefasst. RLS verhindert derzeit anonyme Ledger-Abfragen und authentifizierte Ledger-Inserts. Diese Konfiguration muss beim Freigabe-Audit ausdrücklich mitgeprüft werden; reine GRANT-Checks reichen nicht aus.
- Korrigierte automatische Ziel-EXP nach nachträglichem Wechsel des Boxers, Änderung des Trainingsdatums sowie von Jogging-/Technikmengen. SQL-Rollback-Test erfolgreich: 75 → 0 EXP beim vorherigen Boxer, 50 → 0 → 50 beim neuen Boxer und 40 → 0 → 40 bei Jogging-km-Korrekturen; bestehende Transaktions-IDs bleiben erhalten.
- Abgelehnte oder wieder geöffnete Ziele melden korrekt `exp_awarded: 0` in der API; zuvor wurde irreführend der konfigurierte Reward gemeldet.
- **Nicht durchgeführt:** echter produktiver Backup-/Restore-Test, echte Nutzerkonten-Abnahme, Replay sämtlicher Migrationen in neu erstellter produktionsgleicher Umgebung. Deshalb bleibt der Merge gesperrt.

## Automatisierte Migrationsabnahme und Wiederherstellung (19.10.2026)
- Neuer GitHub-Workflow `.github/workflows/league-21-migration-replay.yml`, Ergebnis **erfolgreich** für PostgreSQL **16 und 17**.
- Führt **alle 24** chronologisch sortierten V2.1-Migrationen auf separaten Wegwerf-Datenbanken aus; bestätigt 17 RLS-geschützte V2.1-Tabellen und zulässige RPC-Grants. Der erste Durchlauf erfolgt in einer einzigen Transaktion mit **ROLLBACK** und geprüftem unveränderten Altbestand.
- Zweiter Durchlauf installiert 2.1 vollständig auf demselben Wegwerf-V2-Schema; anschliessend `pg_dump` → `pg_restore` in eine frische Datenbank. Schema-/Datenzähler sowie der vollständige 2.1-Postflight sind vor und nach Restore konsistent. **Beide PostgreSQL-Versionen grün.**
- Das lokale Basisschema `tests/league-21-productionlike-baseline.sql` deckt die verwendeten V2-Schnittstellen und produktiven `NOT NULL`-Felder ab, ist jedoch **kein vollständiger Supabase-Produktionsklon**.
- **Immer noch offen und Freigabeblocker:** Backup und verifizierte Wiederherstellung der **echten** Produktionsdaten und Auth-/Storage-Abhängigkeiten; echter Boxer-/Admin-/Trainer-Login-Test; vollständiger Definer-Funktions-Audit. Deshalb GO-LIVE weiterhin gesperrt.

## Sicherheitsadvisor – offene Warnungen
**Keine Warnungen dieser Art pauschal ignorieren.**
- Produktiv **6 anon** + **60 authenticated** ausführbare SECURITY DEFINER-Funktionen im öffentlichen API-Schema (vorbestehende Anwendung), weitere darunter 34 im Testprojekt. Viele haben beabsichtigte serverseitige Rollenprüfungen, aber die tatsächlichen Checks aller kritischen Funktionen müssen noch explizit auditiert werden.
- Supabase Auth **Leaked Password Protection deaktiviert** / Sicherheitswarnung in TEST und PROD.
- `rls_enabled_no_policy`: 28 INFO-Treffer TEST bzw. 11 PROD; bei absichtlich ausschließlich serverseitig kontrollierten Tabellen ist dies oft korrekt, erfordert Privilegprüfung.
- Vor Aktivierung von 2.1 produktiv Supabase Security Advisor erneuern, PUBLIC/anon/authenticated Grants, RLS und AUTH-Testfälle einzeln bewerten.

## Voraussetzungen / Freigabe-Gates vor 2.1 GO LIVE
- [ ] Neue Branch-Commits mit **grünen beiden GitHub-Workflows** und Chromium-/Mobile-Tests, einschließlich neuer H2H- und Datumslogik.
- [ ] Echte Supabase-Testkonten: Boxer, Trainer/Coach, Admin; Fremdzugriff, Einladungen, Duellabschluss, EXP-Rücknahme, individuelle Ziele, Liga-Challenge-EXP, öffentliche Profile.
- [ ] Vollständiger Test **aller** SQL-Migrationen in chronologischer Reihenfolge auf einer leeren produktionsgleichen Umgebung. Im bisherigen TEST-Projekt wurden SQL-Blöcke interaktiv, nicht als rekonstruierte `supabase_migrations.schema_migrations`-Historie installiert; dieses Gate ist NOCH OFFEN.
- [ ] Autorisierte Prüfung der vorbestehenden PUBLIC SECURITY DEFINER RPCs sowie Supabase-Auth-Schutzeinstellungen.
- [ ] Vor Migration: aktuelles Produktionsbackup inkl. vollständiger Ledger-, Auth- und Storage-Sicherung; Wiederherstellbarkeit verifizieren. **Bisher weder Backup noch Restore durchgeführt.**
- [ ] Dry-run der vollständigen Produktionsmigration mit kontrolliertem Rollback für die ersetzte Funktion `public.duel_v2_reconcile`; keine Änderung auf Live vor explizitem GO LIVE.
- [ ] PROD Vor-/Nachher-Invarianten: keine fehlenden/doppelten Trainingsledger; Duellledger korrekte Referenzen; Achievement-Ledger idempotent; öffentliche Badge-Projektion; private Goal-Ledger ohne Fremdgrants.
- [ ] Einwilligung für bewusst öffentliche Boxer-/Achievement-/H2H-Daten klären und Datenschutzhinweis anpassen.
- [ ] 2.1-Merge nur nach **erneuter ausdrücklicher Freigabe** des Nutzers; Flags und produktive Migrationen zuletzt, smoke tests direkt danach.

## Rollback-Vorgehen – vorbereitet, nicht getestet
1. Sofort neue V2.1-Pfade per Feature-Gate sperren, betroffene Admin-Operationen pausieren, keine EXP-Reconcile-RPCs während des Rollbacks.
2. Falls neues Frontend live: auf vorherigen GitHub `main`-Commit zurücksetzen.
3. Database Rollback ist **nicht** bloß DROP TABLE: V2.1 schreibt in `point_transactions` und ersetzt `public.duel_v2_reconcile`. Vor Migration originale Funktionsdefinition und Restore-Point sichern.
4. Bei fehlerhaften Auszahlungen vor Restore sämtliche `league_goal_exp_ledger_v21`, `league_global_exp_ledger_v21` und `league_duel_exp_ledger` gegen Originaltransaktionen abgleichen, mit Auditorentscheidung gezielte Rücknahme oder kompletten verifizierten DB-Restore durchführen.
5. Erst nach erneutem Durchlauf der Ledger-, RLS- und Login-Tests wieder aktivieren.

**Fazit:** Umfangreiche Feature-Implementierung und isolierte SQL-Tests bestanden, aber noch **nicht endgültig release-ready**. Das Vermeiden ungesicherter produktiver Änderungen hat Vorrang.
