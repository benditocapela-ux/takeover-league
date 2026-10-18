# Takeover League 2.0 – Releaseprüfung (18. Oktober 2026)

**Status: NO-GO für Produktion bis ausdrücklichem «FREIGEBEN» und bestandenen technischen Gates.** Das produktive Supabase-Projekt wurde ausschließlich mit SELECT/Katalogabfragen geprüft. Keine Live-Migration, keine Änderung an Boxer-Konten, Einträgen oder EXP. Beide neuen Frontend-Funktionen bleiben standardmäßig deaktiviert. Der GitHub-PR bleibt Draft.

## Release-Entscheidung des Nutzers (18.10.2026): ohne Backup veröffentlichen

Der Nutzer hat ausdrücklich entschieden, den V2-Rollout **ohne vorheriges Backup** durchführen zu wollen. Die Datensicherung bleibt daher **eine dringende Empfehlung, aber kein automatischer Freigabe-Blocker**. Der Nutzer akzeptiert damit bewusst das Risiko, dass bei einer fehlgeschlagenen Produktionsmigration bestehende Trainingshistorien, EXP und Profile möglicherweise nicht wiederhergestellt werden können. Das Risiko wird durch Tests und atomare SQL-Migrationen **reduziert, nicht beseitigt**. Die Free-Plan-Einschränkungen gelten unverändert.

**Weiterhin verbindliche Freigabegates:** reale JWT-/PostgREST-Tests für Coach/Boxer/Admin, erfolgreiche CI/SQL-Preflight-Prüfungen, Nachweis eines funktionierenden GitHub-Pages-Deployments und **die explizite spätere Nachricht „FREIGEBEN“**. Bis dahin bleiben Live-Datenbank, Punkte, Produktions-Feature-Flags und Main-Branch unverändert. Auch nach Freigabe führt ein konkret entdecktes kritisches Sicherheits- oder Datenverlustproblem zu NO-GO.

## 1. Auth-/Rollen- und Integrationstests

### Auf gehostetem Supabase-Testprojekt ausgeführt
- Drei bestehende Auth-Benutzer und verknüpfte Testprofile gefunden: 1 Admin, 2 Boxer. Ein dauerhaftes Coach-Auth-Konto ist **nicht vorhanden**.
- Challenge-Rollentest: Coach erstellt und publiziert einen Entwurf, Boxer meldet sich an, Boxer darf nicht selbst Trainerfunktionen ausführen, Trainer aktiviert Challenge.
- Challenge-End-to-End: nach zeitlicher Simulation Bewertungen erfasst und **einmal 50 EXP** in Ledger und Transaktion gebucht.
- Duelltest: Boxer lädt zweiten Boxer ein; Selbstannahme verweigert, Gegner nimmt an, Admin darf ein abgelaufenes Duell abstimmen.
- Anonyme Datenbankrolle und unbekannte authentifizierte Identität dürfen weder geschützte V2-Tabellen noch privilegierte V2-RPCs einsehen.
- Tests fanden als **SQL-Transaktionen mit simulierten `auth.uid()`-Claims und `SET LOCAL ROLE`** statt und wurden ausnahmslos mit `ROLLBACK` beendet. Eine notwendige temporäre Coach-Rollen-Constraint-Anpassung wurde ebenfalls zurückgerollt.
- Nach den vollständig zurückgerollten Funktionstests wurde **gesondert** eine bewusst permanente Testprojekt-Migration `allow_coach_role_test_only` ausgeführt. Testprojekt erlaubt damit nun Boxer/Admin/Coach. Weiterhin nur 3 Auth-Benutzer/3 Profile, 1 bestehende Challenge, 0 Duelle, 1 Punktetransaktion, 0 aktive Coach-Profile; beide Test-Flags aus. **Produktion unverändert.**

**Grenze:** Datenbankrollen unter echten Supabase-Instanzen sind noch keine Auth-Passwortanmeldungen und keine authentischen HTTP/PostgREST-JWT-Tests. Das Testprojekt enthält momentan auch noch ältere RPC-Rückgabetypen. Echte temporäre Coach-/Boxer-/Admin-Login-Konten plus Testabläufe im Browser bleiben Freigabevoraussetzung.

### Auf isoliertem PostgreSQL (GitHub CI)
- 23 neu vorbereitete RPCs, 7 neue V2-Tabellen, RLS/Grants, Rollbacks, Migrationen, EXP-Buchung und Korrekturen überprüft.
- Zwei separate PostgreSQL-Versionen **16 und 17** (Produktionsserver: PostgreSQL 17.11).
- Gleichzeitige Challenge-Abrechnung, Teilnahme, Duell-Einladung und Duell-Abrechnung auf getrennten Verbindungen durchgespielt.
- Zusätzlich getestet: direkte Achievement-RPC-Ausführung für `anon`/`authenticated` blockiert, Besitzer-/Service-Rolle weiterhin berechtigt, Trigger einer legitimen Trainingsfreigabe gewährt weiter EXP.

## 2. Sicherheitsbefunde

**P0 (bestätigt in Produktion):** `public.recalculate_boxer_achievements_v2(uuid)` ist als SECURITY DEFINER direkt durch `anon` und `authenticated` ausführbar. Die Funktion verlangt keinen aufrufenden Benutzer und kann Achievement-EXP anpassen.

**Patch vorbereitet und testbar, NICHT PRODUKTIV ANGEWENDET:** `supabase/production-prep/20261018_restrict_achievement_recalculation.sql`. Der Patch prüft das Besitz-/Trigger-Modell und entzieht explizit die beiden Client-Zugriffe, ohne die Ausführung für Besitzer `postgres` oder `service_role` zu entziehen. Test in PostgreSQL 16 und 17 bestanden. **Nicht ohne Freigabe ausführen.**

Weitere Supabase-Sicherheitsadvisor-Hinweise (anonym ausführbare öffentliche Rankingfunktionen, authentifizierte SECURITY-DEFINER-Funktionen, RLS-Tabellen ohne Policies) müssen einzeln beurteilt werden; keine pauschalen GRANT-/RLS-Änderungen. Passwort-Leak-Schutz wird vom Advisor für Auth empfohlen; nicht ohne gesonderte Prüfung als behoben markieren.

## 3. Produktions-Baseline – anonymisierte Bestandsaufnahme

Abfrage: `supabase/production-prep/production_baseline_read_only.sql`.

| Messwert | 18.10.2026, 12:30 UTC |
|---|---:|
| PostgreSQL | 17.11 |
| Profile | 14 |
| Aktive Boxer | 13 |
| Aktive Administratoren | 1 |
| Aktive Coach-Profile | 0 |
| Verknüpfte Auth-Profile | 11 |
| Trainingsmeldungen | 61 |
| Davon genehmigt | 55 |
| Punktetransaktionen | 66 |
| Kumulierte Punkte | 2'230 |
| Kumulierte EXP | 2'230 |
| Neue V2-Tabellen in Produktion | 0 |
| Neue V2-RPCs in Produktion | 0 |
| Eingeschaltete V2-Flags | 0 |
| Archivierungsfehler in `pg_stat_archiver` | 0 |

Kategorie-Summen: `legacy_import` 35 Transaktionen (1410 Punkte/EXP), `training` 24 (730), `trainer_bonus` 2 (50), `automatic_bonus` 5 (40). Einzelne Boxer-Identitäten wurden für diese Freigabedokumentation nicht exportiert. Daten ändern sich natürlich; **vor jeder produktiven Ausführung neue Baseline erstellen und gegen die Nachher-Werte vergleichen.**

## 4. Backup- und Restore-Sperre (Free-Plan)

Die Supabase-Organisation ist laut `get_organization` auf **Free**. Supabase dokumentiert tägliche automatische Backups für Pro/Team/Enterprise, nicht für Free. `archive_mode=on` und `pg_stat_archiver.failed_count=0` belegen **keine wiederherstellbare Datensicherung**.

Ein gesicherter, überprüfter Datenbank-Dump bleibt dringend empfohlen; der Nutzer hat die Veröffentlichung ohne diesen Schutz ausdrücklich gewünscht. Der Dump **muss außerhalb von GitHub/ChatGPT** gespeichert werden; niemals Verbindungszeichenfolgen oder Passwörter in Repository, Tickets oder Chat veröffentlichen.

### Durchzuführende Backup-Aktion (noch NICHT durchgeführt)

Laut Supabase-Dokumentation zum Backup/Restore können beim passenden aktuellen CLI unter anderem Rollen, Schema und Daten exportiert werden. Unmittelbar vorher `supabase db dump --help` mit der tatsächlich installierten CLI-Version prüfen. Lokale Shell-Beispielbefehle (mit privat hinterlegtem `DATABASE_URL`):

```bash
umask 077
mkdir -p "$HOME/takeover-private-backup"
chmod 700 "$HOME/takeover-private-backup"
supabase db dump --db-url "$DATABASE_URL" -f "$HOME/takeover-private-backup/roles.sql" --role-only
supabase db dump --db-url "$DATABASE_URL" -f "$HOME/takeover-private-backup/schema.sql"
supabase db dump --db-url "$DATABASE_URL" -f "$HOME/takeover-private-backup/data.sql" --data-only --use-copy
shasum -a 256 "$HOME"/takeover-private-backup/*.sql > "$HOME/takeover-private-backup/SHA256SUMS"
```

**Erforderliche Nachweise:** fehlerfreier Dump, sicherer verschlüsselter Aufbewahrungsort, erfolgreiche Wiederherstellung in einer **frischen isolierten** PostgreSQL-/Supabase-Testinstanz, passende Profil-/Trainings-/EXP-Zählungen und ein realistisch dokumentierter Wiederanlauf. Ein SQL-Dump deckt nicht automatisch die eigentlichen Storage-Dateiobjekte ab (z. B. Avatare). Der geeignete Backup-/Restore-Weg muss auch diese gesondert berücksichtigen, sofern genutzt.

Dokumentation: https://supabase.com/docs/guides/platform/backups und https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore

## 5. Kontrollierte Migrationsreihenfolge (gesperrt)

1. Backup-Verzicht gemäss bewusster Nutzerentscheidung protokollieren, echte HTTP/Auth-Tests abschließen und aktuellen Read-only-Baseline-Report aufbewahren.
2. Sicherheitsfix `supabase/production-prep/20261018_restrict_achievement_recalculation.sql` als eigenen sicher geprüften Schritt ausführen und Achievement-Freigabetrigger überprüfen – **nur nach ausdrücklicher Produktionsfreigabe**.
3. Coach Challenges: `supabase/migrations/20261018131000_coach_challenges_v2.sql`.
4. Duels: `supabase/migrations/20261018133000_duels_v2.sql`.
5. RLS, RPC-Rechte, Besitzer, Punkte-/EXP-Summen und bestehende Datensätze mit neuer Read-only-Baseline prüfen; neue DB-Flags bleiben aus.
6. Frontend getrennt bereitstellen, mit realen Testkonten prüfen, Feature-Flags geplant aktivieren, Fehler und EXP-Differenzen überwachen.

**Keine Ausführung auf Produktion vor bestandenem JWT-/Deployment-Gate und ausdrücklichem «FREIGEBEN». Ein fehlendes Backup allein blockiert entsprechend der dokumentierten bewussten Entscheidung des Nutzers nicht.** Rollback-SQL, das Tabellen entfernt, ist ausdrücklich nur für *leere* V2-Tabellen vorgesehen; bei echten V2-Daten ist stattdessen ein datenbewahrender Reparaturweg nötig.
