> ⚠️ **ÜBERHOLT – historischer Prüfstand vor dem tatsächlich erfolgten Release.** Alte Aussagen wie «VERÖFFENTLICHUNG GESPERRT», «NO GO LIVE», «PR #11 Draft» und «kein produktives Schema» beschreiben eine vergangene Momentaufnahme, nicht den aktuellen Produktionsstand.
> **Tatsächlich:** Takeover League 2.1 liegt auf `main` (Release `4aae67e`, Folge `4430bc4` → `0cd262e`); die atomare V2.1-Migration `20261018231319` ist in Produktion angewendet. Die im historischen Text genannten echten Backup-, Login- und Sicherheits-Gates bleiben **NICHT ERLEDIGT**.
> **Aktueller, verifizierter Stand:** [RELEASE_STATUS_2_1_2026-10-19.md](RELEASE_STATUS_2_1_2026-10-19.md). Der folgende Originaltext bleibt unverändert als historische Gate-Bewertung.

# Takeover League 2.1 – Release-Abnahme und technische Sicherheitsgates
Stand: 19. Oktober 2026 (Schweizer Zeit), Entwicklung ausschließlich auf `develop/takeover-league-2.1-all-features`, Draft-PR #11.

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
- **Nicht durchgeführt:** echter produktiver Backup-/Restore-Test und echte Nutzerkonten-Abnahme. Der vollständige Replay in einer produktionsähnlichen Wegwerf-Umgebung wurde inzwischen automatisiert erfolgreich getestet; ein vollständiger PROD-Klon bleibt offen. Deshalb bleibt der Merge gesperrt.

## Automatisierte Migrationsabnahme und Wiederherstellung (19.10.2026)
- Neuer GitHub-Workflow `.github/workflows/league-21-migration-replay.yml`, Ergebnis **erfolgreich** für PostgreSQL **16 und 17**.
- Führt **alle 25** chronologisch sortierten V2.1-Migrationen auf separaten Wegwerf-Datenbanken aus; bestätigt 17 RLS-geschützte V2.1-Tabellen und zulässige RPC-Grants. Der erste Durchlauf erfolgt in einer einzigen Transaktion mit **ROLLBACK** und geprüftem unveränderten Altbestand.
- Zweiter Durchlauf installiert 2.1 vollständig auf demselben Wegwerf-V2-Schema; anschliessend `pg_dump` → `pg_restore` in eine frische Datenbank. Schema-/Datenzähler sowie der vollständige 2.1-Postflight sind vor und nach Restore konsistent. **Beide PostgreSQL-Versionen grün.**
- Das lokale Basisschema `tests/league-21-productionlike-baseline.sql` deckt die verwendeten V2-Schnittstellen und produktiven `NOT NULL`-Felder ab, ist jedoch **kein vollständiger Supabase-Produktionsklon**.
- **Immer noch offen und Freigabeblocker:** Backup und verifizierte Wiederherstellung der **echten** Produktionsdaten und Auth-/Storage-Abhängigkeiten; echter Boxer-/Admin-/Trainer-Login-Test; vollständiger Definer-Funktions-Audit. Deshalb GO-LIVE weiterhin gesperrt.

## Zusätzliche Integritätstests (19.10.2026)
- **Falsche Sieger bei fehlendem Training-Ledger verhindert:** Saison-/Duell-/Arena-Endpunkte hatten bereits Duplikatsschutz; der 2.1-Duell- und Arena-Abschluss sperrt jetzt auch Abschlüsse, wenn ein genehmigtes Training **keine gültige Punktebuchung** besitzt. Es gibt keine stillschweigende Wertung mit 0 Punkten.
- Zwei neue SQL-ROLLBACK-Fixtures prüfen: Fehlende Transaktion führt zu Abbruch ohne Sieger/EXP, nach Ledger-Reparatur korrekter Abschluss und idempotenter zweiter Aufruf.
- Alle **sechs** relevanten Staging-SQL-Fixtures werden nach dem vollständigen 2.1-Migration-Replay automatisch auf **PostgreSQL 16 und 17** ausgeführt. GitHub-Workflow `league-21-migration-replay.yml` war auf Commit `fd276a5836f7c6593a56b54cc86245b9d1501518` erfolgreich (beide Versionen).
- **Trainerhinweis korrigiert:** Die bisher falsche Zusicherung «keine EXP» beim Abschluss einer Liga-Challenge wurde durch eine explizite Anzeige der sofortigen realen EXP-Belohnungen und eine vorsichtige Bestätigung ersetzt.
- **Challenge-Fortschritt korrigiert:** Teilnahme- und Fristgrenzen werden mit `Date.parse` nach tatsächlichen Zeitpunkten statt durch lexikografischen Vergleich verschieden formatierter ISO-Zeitstempel geprüft.
- Kein produktives GO LIVE ohne echten Produktionsbackup- und Login-Test.

## Sicherheitsadvisor – offene Warnungen
**Keine Warnungen dieser Art pauschal ignorieren.**
- Produktiv **6 anon** + **60 authenticated** ausführbare SECURITY DEFINER-Funktionen im öffentlichen API-Schema (vorbestehende Anwendung), weitere darunter 34 im Testprojekt. Viele haben beabsichtigte serverseitige Rollenprüfungen, aber die tatsächlichen Checks aller kritischen Funktionen müssen noch explizit auditiert werden.
- Supabase Auth **Leaked Password Protection deaktiviert** / Sicherheitswarnung in TEST und PROD.
- `rls_enabled_no_policy`: 28 INFO-Treffer TEST bzw. 11 PROD; bei absichtlich ausschließlich serverseitig kontrollierten Tabellen ist dies oft korrekt, erfordert Privilegprüfung.
- Vor Aktivierung von 2.1 produktiv Supabase Security Advisor erneuern, PUBLIC/anon/authenticated Grants, RLS und AUTH-Testfälle einzeln bewerten.

## Voraussetzungen / Freigabe-Gates vor 2.1 GO LIVE
- [ ] Neue Branch-Commits mit **grünen beiden GitHub-Workflows** und Chromium-/Mobile-Tests, einschließlich neuer H2H- und Datumslogik.
- [ ] Echte Supabase-Testkonten: Boxer, Trainer/Coach, Admin; Fremdzugriff, Einladungen, Duellabschluss, EXP-Rücknahme, individuelle Ziele, Liga-Challenge-EXP, öffentliche Profile.
- [x] Alle **25** SQL-Migrationen in chronologischer Reihenfolge in separaten produktionsähnlichen Wegwerf-Datenbanken auf PostgreSQL 16 und 17 mit Rollback und Backup-/Restore-Rehearsal erfolgreich ausgeführt.
- [ ] Ein echtes **vollständiges produktionsgleiches** Testabbild inklusive aller Auth-/Storage-Abhängigkeiten und Original-Funktionsdefinitionen ist noch nicht validiert. Im bisherigen Supabase-TEST-Projekt wurden ältere Migrationen teilweise direkt angewendet; die Migration-History ist nicht vollständig der SQL-Dateiliste gleichgestellt.
- [ ] Autorisierte Prüfung der vorbestehenden PUBLIC SECURITY DEFINER RPCs sowie Supabase-Auth-Schutzeinstellungen.
- [ ] Vor Migration: aktuelles Produktionsbackup inkl. vollständiger Ledger-, Auth- und Storage-Sicherung; Wiederherstellbarkeit verifizieren. **Bisher weder Backup noch Restore durchgeführt.**
- [x] Technischer Replay mit kontrolliertem ROLLBACK für alle 2.1-Migrationen inklusive ersetzter `public.duel_v2_reconcile`-Funktion auf Wegwerf-PG16/17 bestanden. Ein erneuter Dry-run mit allen echten Produktions-Definitionen bleibt vor produktiver Freigabe erforderlich.
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
