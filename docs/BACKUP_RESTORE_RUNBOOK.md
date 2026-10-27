# Backup und Restore – Takeover League (Supabase Free Plan)

Stand: 27.10.2026 · Produktion `iqarjivcrddcixrvqbfb` · Testprojekt `cfgdvcccsqwfjajuizsr`

## Ausgangslage

- Der Free Plan hat **keine automatischen Backups** und kein Point-in-Time-Recovery.
- Punkte, EXP, Trainings, Profile und Saisonergebnisse existieren nur in der Produktionsdatenbank.
- Das GitHub-Repository ist **öffentlich**. Dumps dürfen deshalb **nie** ins Repository, in GitHub-Actions-Artefakte oder in öffentliche Speicher. Artefakte öffentlicher Repositories können angemeldete GitHub-Nutzer herunterladen.

## 1. Backup erstellen (auf dem eigenen Computer)

Du brauchst die [Supabase CLI](https://supabase.com/docs/guides/cli) und das Datenbank-Passwort. Das Passwort findest du im Supabase Dashboard unter *Project Settings → Database*. Es gehört nicht in den Chat und nicht ins Repository.

```bash
# einmalig: anmelden und Projekt verknüpfen (fragt nach dem DB-Passwort)
supabase login
supabase link --project-ref iqarjivcrddcixrvqbfb

# Schema, Daten und Rollen getrennt sichern
STAMP=$(date +%Y-%m-%d)
supabase db dump --linked -f takeover_${STAMP}_schema.sql
supabase db dump --linked --data-only -f takeover_${STAMP}_data.sql
supabase db dump --linked --role-only -f takeover_${STAMP}_roles.sql
```

Danach:

1. Die drei Dateien verschlüsselt ablegen, zum Beispiel in einem passwortgeschützten ZIP mit AES oder auf einer verschlüsselten Disk. Zusätzlich eine Kopie ausserhalb des Computers aufbewahren, etwa auf einem USB-Stick oder in einem privaten Cloud-Ordner.
2. Die **Kontrollzahlen** notieren, siehe Abschnitt 3.
3. **Rhythmus:** wöchentlich, und **immer vor einer Produktionsmigration** (Teil jeder Freigabe).

## 2. Restore testen (nie in die Produktion)

Für den Test brauchst du ein **eigenes, leeres** Supabase-Projekt, zum Beispiel «takeover-restore-test». Das bestehende Testprojekt eignet sich nicht, weil es eigene Testdaten hat.

```bash
# Verbindungs-URL des leeren Restore-Projekts (Dashboard → Connect → URI)
RESTORE_URL='postgresql://postgres:<passwort>@db.<restore-ref>.supabase.co:5432/postgres'
psql --single-transaction --variable ON_ERROR_STOP=1 \
  --file takeover_${STAMP}_roles.sql \
  --file takeover_${STAMP}_schema.sql \
  --command 'SET session_replication_role = replica' \
  --file takeover_${STAMP}_data.sql \
  --dbname "$RESTORE_URL"
```

Danach führst du die Kontrollzahlen (Abschnitt 3) im Restore-Projekt aus und vergleichst sie mit der Produktion. Wenn alles stimmt, löschst du das Restore-Projekt, weil es Personendaten enthält.

## 3. Kontrollzahlen (nur lesend, in Produktion und Restore gleich)

```sql
SELECT (SELECT count(*) FROM public.profiles) AS profiles,
       (SELECT count(*) FROM public.training_submissions) AS trainings,
       (SELECT count(*) FROM public.point_transactions) AS point_transactions,
       (SELECT coalesce(sum(points),0) FROM public.point_transactions) AS points_sum,
       (SELECT coalesce(sum(exp),0) FROM public.point_transactions) AS exp_sum,
       (SELECT count(*) FROM public.boxer_achievements) AS achievements,
       (SELECT count(*) FROM public.league_seasons_v21) AS seasons,
       (SELECT count(*) FROM public.league_season_results_v21) AS season_results,
       (SELECT count(*) FROM public.league_hall_of_fame_v21) AS hall_of_fame,
       (SELECT count(*) FROM public.league_global_challenges_v21) AS league_challenges,
       (SELECT count(*) FROM public.boxer_notifications) AS notifications;
```

Referenzwerte vom 27.10.2026 nach der Gamification-Migration: 16 Profile, 139 Trainings, 162 Buchungen, 5370 Punkte, 5720 EXP.

## 4. Im Notfall

1. Keine weiteren Schreibvorgänge zulassen. Wenn nötig, den League Manager und die Trainerseite meiden, bis der Stand geklärt ist.
2. Kontrollzahlen der Produktion sichern, damit klar ist, was fehlt.
3. Nur gezielt wiederherstellen, also einzelne Tabellen oder Zeilen aus dem Dump. Ein Komplett-Restore über die laufende Produktion gibt es nur nach ausdrücklicher Entscheidung.
4. Jede Migration hat in `supabase/production-prep/` einen eigenen Rollback. Er stellt Funktionen wieder her und behält alle Daten.

## Status

- [ ] Erstes echtes Backup erstellt, Owner-Aufgabe (DB-Passwort nötig)
- [ ] Restore in ein leeres Projekt getestet und Kontrollzahlen verglichen
- [x] Kontrollzahlen und Ablauf dokumentiert
