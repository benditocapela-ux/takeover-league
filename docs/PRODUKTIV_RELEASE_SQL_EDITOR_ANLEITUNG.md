# Freigegebener Takeover-League-V2-Release: manuelle Supabase-Ausführung bei Connector-Sperre

**Status 18.10.2026: FREIGEGEBEN, ABER NOCH NICHT INSTALLIERT.** Die GitHub-/Supabase-Integration hat den Produktions-DDL-Aufruf trotz expliziter Nutzerfreigabe mit einer Sicherheitsprüfung blockiert. Keine Umgehung dieser Sperre durch den Assistenten. Als regulärer, durch den Projektinhaber kontrollierter Weg steht das offizielle Supabase SQL Editor Interface zur Verfügung. Alle nachstehenden Dateien sind versionierte, im CI auf PostgreSQL 16 und 17 geprüfte SQL-Skripte; sie wurden bisher **nicht** auf Produktion ausgeführt.

## Voraussetzungen

- Projekt in Supabase muss exakt **Takeover Project** mit Referenz `iqarjivcrddcixrvqbfb` sein. **Nicht** auf `cfgdvcccsqwfjajuizsr` ausführen.
- Nutzer hat bewusst **auf Backup** verzichtet. Datenverlust kann daher bei unerwarteten Fehlern irreversibel sein. Ein Backup wird weiterhin dringend empfohlen.
- Vorab-Anmeldeprüfung entfällt auf Nutzerwunsch. Echte Boxer bekommen zuerst einen kleinen, überwachten Pilot-Test.
- [CI](https://github.com/benditocapela-ux/takeover-league/actions) muss weiterhin grün sein.
- Die Skripte sind nicht als Vorschlag zum Herumprobieren gedacht. Bei jedem Fehler **anhalten**, Fehlermeldung dokumentieren und keine weiteren Skripte ausführen.

## Vier geordnete SQL-Editor-Aktionen

In [Supabase SQL Editor](https://supabase.com/dashboard/project/iqarjivcrddcixrvqbfb/sql) für **jedes Skript einen neuen Query-Tab** öffnen, die **gesamte Datei** kopieren und ausführen, jede Fehlermeldung vor der nächsten Aktion behandeln.

**1. Achievement-EXP-Recht korrigieren**  
[20261018_restrict_achievement_recalculation.sql](https://github.com/benditocapela-ux/takeover-league/blob/feature/coach-challenges-v2-ui/supabase/production-prep/20261018_restrict_achievement_recalculation.sql)

**2. Coach-Challenges-V2 installieren (4 Tabellen / 17 RPCs)**  
[20261018131000_coach_challenges_v2.sql](https://github.com/benditocapela-ux/takeover-league/blob/feature/coach-challenges-v2-ui/supabase/migrations/20261018131000_coach_challenges_v2.sql)

**3. Boxer-Duelle-V2 installieren (3 Tabellen / 6 RPCs)**  
[20261018133000_duels_v2.sql](https://github.com/benditocapela-ux/takeover-league/blob/feature/coach-challenges-v2-ui/supabase/migrations/20261018133000_duels_v2.sql)

**Vor Aktivierung:**  
[release_postflight_read_only.sql](https://github.com/benditocapela-ux/takeover-league/blob/feature/coach-challenges-v2-ui/supabase/production-prep/release_postflight_read_only.sql) im SQL Editor ausführen. `release_integrity_passed` muss **true** sein. Profilzahl, Trainingszahl, EXP und Punktesumme anhand des [Baseline-Skripts](https://github.com/benditocapela-ux/takeover-league/blob/feature/coach-challenges-v2-ui/supabase/production-prep/production_baseline_read_only.sql) mit dem Zustand vor der Migration vergleichen. Zwei neue Feature-Flags sind noch **false**.

**4. Erst danach beide neuen Backend-Funktionen aktivieren**  
[activate_v2_only_after_freigeben.sql](https://github.com/benditocapela-ux/takeover-league/blob/feature/coach-challenges-v2-ui/supabase/production-prep/activate_v2_only_after_freigeben.sql)

Die Aktivierung prüft unmittelbar im selben Commit alle 23 RPCs, RLS für alle sieben Tabellen, Achievement-Berechtigungen, Feature-Flag-Zustand und EXP-Ledger. Sobald sie **erfolgreich** ist, im Chat nur `SQL ERLEDIGT` schreiben. Der Assistent prüft dann read-only den aktuellen Produktionsstand, aktualisiert/merged GitHub PR #3 und aktiviert die beiden **Frontend**-Flags im GitHub-Pages-Hauptbranch. Erst wenn danach ein echter HTTP-Test der veröffentlichten Seiten erfolgreich ist, ist das Update offiziell online.

## Fehlerfall oder Abbruch

- Bei Fehler in **1, 2 oder 3**: **keine weitere SQL-Datei** starten. Der betreffende SQL-Block ist transaktional und soll bei Fehler keine teilinstallierten Tabellen hinterlassen. Bereits **vorher** erfolgreich angewendete Schritte können jedoch erhalten bleiben.
- Bei fehlerhafter Aktivierung: nicht von Hand Tabellen oder EXP-Buchungen löschen; die Freischaltung darf nur nach bestandener Integritätsprüfung erfolgen.
- Falls die vierte Datei bereits erfolgreich aktiviert wurde und V2 deaktiviert werden muss: [emergency_disable_v2_flags_only.sql](https://github.com/benditocapela-ux/takeover-league/blob/feature/coach-challenges-v2-ui/supabase/production-prep/emergency_disable_v2_flags_only.sql) deaktiviert beide Backend-Flags, **ohne** Boxer-Daten, Trainings oder EXP zu löschen. Danach müssen auch die Frontend-Flags wieder deaktiviert werden.
- Ohne Backup ist eine vollständige Wiederherstellung der alten Daten **nicht garantiert**.

**WICHTIG:** Die bisherige Nachricht `FREIGEBEN` wurde bereits erteilt und ist in PR #3 dokumentiert. Es fehlt jetzt eine **manuelle Aktion im eigenen Supabase-Projekt**, weil der verbundene Produktions-Migrationszugriff gesperrt ist. Diese Dokumentation autorisiert keine Umgehung von Plattform-Kontrollen durch den Assistenten.
