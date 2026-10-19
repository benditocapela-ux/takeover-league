> ⚠️ **ÜBERHOLT – historischer Prüfstand vor dem tatsächlich erfolgten Release.** Alte Aussagen wie «VERÖFFENTLICHUNG GESPERRT», «NO GO LIVE», «PR #11 Draft» und «kein produktives Schema» beschreiben eine vergangene Momentaufnahme, nicht den aktuellen Produktionsstand.
> **Tatsächlich:** Takeover League 2.1 liegt auf `main` (Release `4aae67e`, Folge `4430bc4` → `0cd262e`); die atomare V2.1-Migration `20261018231319` ist in Produktion angewendet. Die im historischen Text genannten echten Backup-, Login- und Sicherheits-Gates bleiben **NICHT ERLEDIGT**.
> **Aktueller, verifizierter Stand:** [RELEASE_STATUS_2_1_2026-10-19.md](RELEASE_STATUS_2_1_2026-10-19.md). Der folgende Originaltext bleibt unverändert als historische Gate-Bewertung.

# Takeover League 2.1 – Produktions-Releaseplan (NICHT AUSGEFÜHRT)

Stand: 19. Oktober 2026. Branch: `develop/takeover-league-2.1-all-features`, Draft-PR #11. **Keine Freigabe zum Merge oder zur produktiven SQL-Ausführung durch diesen Plan.**

## Verifizierte technische Grundlagen

- 25 chronologisch sortierte 2.1-Migrationen in isolierten PostgreSQL-16/17-Datenbanken replayed, inklusive SQL-Integrationstests und Wegwerf-DB-Restore.
- Produktions-Preflight `supabase/production-prep/league_21_preflight_read_only.sql` erneut erfolgreich, ausschliesslich lesend.
- Zusätzlicher Produktionskompatibilitäts-Preflight `supabase/production-prep/league_21_prod_compatibility_read_only.sql`: **12/12 Checks wahr**. Insbesondere: ursprüngliche Duell-EXP-Constraint wird gefunden und in der Migration explizit erweitert; existierende Trainingsbenachrichtigungs-/Achievement-Trigger existieren und sind aktiviert; RLS und Punktbuchungen konsistent.
- TEST-Postflight `supabase/production-prep/league_21_postflight_read_only.sql` grün, nun inklusive Prüfung der anonym gesperrten privaten RPCs, gepinnten `search_path`-Einstellungen sowie öffentlich lesbaren Spalten ohne E-Mail, Auth-ID, Gewicht oder Notizen.
- PROD SECURITY DEFINER: 6 anonym + 60 authentifiziert ausführbare **bestehende** öffentliche Funktionen. Static-Audit: alle 60 gepinnter `search_path`; keine verwendet veränderbare User-Metadaten; `anon` und `authenticated` haben kein `CREATE` in `public`; alle öffentlichen Tabellen haben RLS. Die 6 anonymen Funktionen wurden anhand ihrer Definitionen als öffentliche Datenprojektionen beziehungsweise serverseitiger Admin-Boolean eingestuft. Das ist keine formale Penetrationstest-Zertifizierung.

## Explizit vom Betreiber akzeptierte Risiken (nicht bestanden)

- **Kein nachgewiesenes Produktionsbackup samt Restore** von DB, Auth und Storage. Bisher existiert nur der bestandene Restore einer isolierten Testdatenbank.
- **Keine vollständige E2E-Abnahme mit echten Testkonten** für Boxer, Coach und Admin. Das TEST-Projekt hat derzeit kein verknüpftes Coach-Login.
- Das Test-Basisschema ist weiterhin **kein vollständiger Produktionsklon**. Der zusätzliche read-only 12-Punkte-Kompatibilitätscheck reduziert, beseitigt aber nicht dieses Risiko.

## Verbleibende explizite Governance-Punkte

- Öffentlich sichtbare Boxer-Namen, Ranglisten, erreichte Abzeichen, Rekorde und bestätigte Duellergebnisse müssen für die betroffene Liga freigegeben und den Boxern klar kommuniziert sein. Die öffentliche 2.1-RLS-Projektion enthält keine Auth-IDs, E-Mails, Gewichte oder Trainingsnotizen.
- Supabase Auth Advisor: **Leaked Password Protection deaktiviert** (PROD und TEST). Aktivierung unter [Supabase Auth Password Security](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection) empfohlen; über die aktuell verbundene Schnittstelle nicht umstellbar.
- Keine Behauptung, sämtliche Risiken seien null; eine menschliche Go-Live-Entscheidung bleibt erforderlich.

## Vorbereiteter transaktionaler Release (nur nach ausdrücklichem GO LIVE)

`tests/build-league-21-release.cjs` erstellt aus den **25 Originalmigrationen** eine einzelne, transaktionale SQL-Datei. Die Erstellung allein verbindet sich mit keiner Datenbank:

```bash
node tests/build-league-21-release.cjs --check
node tests/build-league-21-release.cjs --output /sicherer/pfad/takeover-league-21.sql
```

Der Builder prüft die exakte Dateianzahl, chronologische Reihenfolge, nichtleere Quellen und verbietet verschachtelte Transaktionsbefehle und psql-only-Include-Anweisungen. Das erzeugte Skript öffnet `BEGIN`, setzt ein Lock-Timeout, prüft kritische Bestandsinvarianten, enthält die 25 Migrationen, führt eine transaktionale Sicherheitskontrolle aus und endet erst danach mit `COMMIT`.

**Vor tatsächlicher Freigabe:** erneut GitHub CI 3/3 grün, PROD-Preflight und 12-Punkte-Kompatibilitäts-SQL lesend ausführen, Erwartungswerte prüfen. Nicht einzelne Migrationen unkoordiniert als getrennte Sitzungen ausführen.

**Erst nach expliziter Nutzerfreigabe:**
1. Generierte SQL-Datei unter einer einzigen Transaktion in einer kontrollierten, autorisierten PostgreSQL-Sitzung anwenden. Bei einem Fehler gesamte Transaktion abbrechen; nicht teilweise fortfahren.
2. Direkt danach den erweiterten `league_21_postflight_read_only.sql` in PROD ausführen. Bei Fehlschlag **kein Frontend-Merge**.
3. Nur bei bestandenem Postflight PR #11 mergen und den eigentlichen Frontend-Deploy durchführen.
4. Öffentliches Ranking, Profile, Challenge-/Arena-Seiten und Admin-Steuerung unmittelbar nach Deploy prüfen, Auffälligkeiten protokollieren.

## Fehlerfall

- Vor `COMMIT`: ROLLBACK im selben DB-Session-Kontext.
- Nach `COMMIT`: **kein verifizierter Datenbank-Restore vorhanden**. Ein GitHub-Revert allein stellt Datenbankfunktionen, Zahlungen oder Ledger nicht zurück. Bei Fehlern neue 2.1-Aufrufe stoppen, Frontend notfalls auf den vorherigen Stand setzen, Datenbankzustand und EXP-Transaktionen manuell prüfen. Keine blinde DROP-TABLE-Routine.
- Solange keine Nutzerfreigabe erfolgt: **kein Merge, kein Produktions-DDL/DML, kein Deploy.**
