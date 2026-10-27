# Fertigstellung bestehender Funktionen – Bestandsaufnahme und Abschlussbericht

Stand: 27.10.2026. Geprüft wurden `main` (`d2d37b7`), Produktion `iqarjivcrddcixrvqbfb` (nur lesend), Testprojekt `cfgdvcccsqwfjajuizsr` (nur lesend, Schreiben wartet auf Bestätigung), alle Migrationen, RPCs, Feature-Flags und RLS-Policies.

**Legende Nachweis:**
- **Prod** bedeutet: in der Produktion live und mit echten Daten geprüft.
- **DB-Test** bedeutet: in einer Wegwerf-PostgreSQL mit Rollback geprüft.
- **Mock** bedeutet: Browser-Test mit simulierten Daten.

Mock-Tests gelten **nicht** als Produktionsnachweis.

## 1. Bestandsaufnahme (Matrix)

| Bereich | Vorhandener Code | Backend | Produktionsstatus (27.10.) | Fehlende Bestandteile | Risiken | Änderung | Prio |
|---|---|---|---|---|---|---|---|
| **A** Arena | `arena.html` | `league_v21_arena_*` (create, respond, start, finish, live, list) | live, 0 Arenen | Absagen fehlte; nicht öffentliche Boxer einladbar, dann gesperrte Live-Wertung; keine Mitteilungen; **keine EXP-Regel** | tote Arenen, unklare EXP | #35 (Absagen, nur öffentliche Boxer, Mitteilungen) | hoch |
| **A** Duelle | `duels.html` | `duel_v2_*`, `duel_reconcile_ranked_core` (EXP) | live, 1 abgelaufene Einladung | Mitteilungen fehlten; Revanche und Bilanz seit #32 | Einladung bleibt unbemerkt | #40 (Mitteilungen) | mittel |
| **B** Liga-Challenges | `league-challenges.html`, League Manager | `global_*_core` | live; «Become a Jab Novice» abgelaufen, «Jab Master» als Entwurf | Entwurf weder bearbeitbar noch veröffentlichbar noch löschbar | Entwurf ist eine Sackgasse | #35 (bearbeiten, veröffentlichen, löschen ohne Spur) | hoch |
| **C** Ziele | `goals.html`, League Manager | `goal_*_core`, Ledger | live, 0 Ziele | Trainer ausgeschlossen; Trainerfreigabe prüfte keine Ziele; kein Archiv; Selbstbestätigung zugewiesener manueller Ziele möglich; Knopf «EXP-Regel» kaputt (JS-Fehler) | falsche Abschlüsse, kaputte Admin-UI | #36 | hoch |
| **D** Trainer-Dashboard | `coach.html` | `coach_list_training_history` (10 pro Seite), Schnellansicht mit 5 bestätigten Trainings, Feedback | live | Ziele für Trainer fehlten (jetzt im League Manager) | – | #36 | mittel |
| **E** Saisons | League Manager, `league-history.html` | `season_*_core` | «Herbst 2026» aktiv, «Winter 2026» als Entwurf | Server liess zwei aktive Saisons zu; Folgesaison nicht automatisch | Doppelsaison per API | #33 (UI, gemergt), #37 (Server, Folge-Entwurf) | hoch |
| **F** Hall of Fame | `league-history.html` | Snapshot beim Saisonabschluss | 0 Einträge | – (Fairness mit #32 gelöst) | – | #32 (gemergt, live) | – |
| **F** Palmarès | – | alte 2.0-RPC (Schalter aus) | fehlte | ganze Ansicht | – | #38 (aus belegten Erfolgen) | mittel |
| **G** Gamification | `takeover-gamification.js`, `duels.html` | Trigger aus #32 | live seit #32 | Duell-Mitteilungen fehlten | – | #32 (live), #40 | – |
| **H** Verwaltung | League Manager, Clubverwaltung | Profil- und Trainingsprotokoll | live | Protokoll für Saison, Challenge, Arena und Ziel fehlte | Nachvollziehbarkeit | #41 | mittel |
| **I** Bedienung | alle Seiten | – | Fight-Night-Design | englische Status- und Fehlertexte; fehlende Leer- und Fehlerzustände in einzelnen Bereichen | Verwirrung | #35 bis #38 (deutsche Texte, Zustände) | mittel |
| **J** Sicherheit | – | 81 SECURITY-DEFINER-Funktionen erreichbar | alle mit Prüfung | 16 ungenutzte 2.0-RPCs offen; kein Backup; Schutz vor geleakten Passwörtern aus | Angriffsfläche, Datenverlust | #39 (Audit, Sperre, Runbook), #34 (CI, gemergt) | hoch |

## 2. Abschlussstatus

**Vollständig umgesetzt (in Produktion nachgewiesen):**
- Gamification aus #32: Wochen-Quests ohne EXP, Wochenserie, Rivalenanzeige, Achievement-Fortschritt, Level-Up-Mitteilung, Revanche. Hinzu kommen Fairness der Hall of Fame und Saisonrangliste (nur Boxer, «Privates Profil»). Migration in Prod, Postflight grün.
- Saisonabschluss-Bedienung im League Manager (#33). Das Ende-Datum wird geprüft, ein Entwurf ist nicht aktivierbar, solange eine Saison läuft. «Winter 2026» liegt als Entwurf bereit.
- CI-Smoke-Test hängt nicht mehr (#34).

**Teilweise abgeschlossen (Code und DB-Tests fertig, Nachweis im Testprojekt und in Prod fehlt):**
- Liga-Challenge-Entwürfe bearbeiten, veröffentlichen und löschen; Arena absagen, nur öffentliche Boxer, Einladungs-Mitteilungen (#35)
- Ziele: Trainerrechte, Schutz vor Selbstbestätigung, Archiv, Verlauf, Reparatur der Belohnungsregel (#36)
- Saison: nur eine aktive Saison auf dem Server, Folgesaison automatisch als Entwurf (#37)
- Palmarès im Boxerprofil (#38, nur Frontend, Mock-geprüft)
- Sperre von 16 ungenutzten 2.0-RPCs (#39)
- Duell-Mitteilungen (#40)
- Änderungsprotokoll der Verwaltung (#41)

**Nicht umgesetzt:** siehe Abschnitt 6.

## 3. Pull Requests

| PR | Inhalt | Migration | Status |
|---|---|---|---|
| #33 | League Manager: Saisonabschluss verständlich | – | **gemergt, live** |
| #34 | CI: Chromium-Smoke-Test hängt nicht mehr | – | **gemergt** |
| #35 | Liga-Challenge-Entwürfe, Arena absagen, nur öffentliche Boxer, Mitteilungen | `20261028090000` | Draft |
| #36 | Ziele: Trainer, Schutz vor Selbstbestätigung, Archiv, Verlauf, Fix EXP-Regel | `20261028100000` | Draft, gestapelt auf #35 |
| #37 | Saison: eine aktive Saison, Folgesaison als Entwurf | `20261028110000` | Draft, gestapelt auf #36 |
| #38 | Palmarès im Boxerprofil | – | Draft, **sofort mergebar** |
| #39 | Sicherheitsaudit, 2.0-RPCs sperren, Backup-Runbook, dieser Bericht | `20261028120000` | Draft |
| #40 | Duell-Mitteilungen | `20261028130000` | Draft |
| #41 | Änderungsprotokoll Verwaltung | `20261028140000` | Draft, gestapelt auf #37 |

## 4. Notwendige Produktionsmigrationen (in dieser Reihenfolge)

1. `20261028090000_league_challenges_arena_admin.sql` (#35)
2. `20261028100000_goals_coach_archive.sql` (#36)
3. `20261028110000_season_single_active_next_draft.sql` (#37)
4. `20261028120000_revoke_unused_legacy_rpcs.sql` (#39)
5. `20261028130000_duel_notifications.sql` (#40)
6. `20261028140000_admin_change_log.sql` (#41)

Jede Migration hat in `supabase/production-prep/` einen Preflight (nur lesend, mit md5-Abgleich der ersetzten Funktionen), einen Postflight (nur lesend) und einen Rollback, der alle Daten behält.

## 5. Testergebnisse

- **DB-Test:** Jede Migration hat einen eigenen Wegwerf-PostgreSQL-Test mit Rollback und erneutem Anwenden. Lokal auf PG 16 sind alle grün, in der CI laufen sie auf PG 16 und 17.
- **Mock:** `tests/league-21-browser.cjs` (alle 2.1-Seiten, 375 und 1240 px) und `tests/release-browser-smoke.cjs` sind lokal grün. Dazu kommen Screenshots aller neuen Ansichten ohne JS-Fehler und ohne horizontalen Scroll.
- **Prod:** Live geprüft sind nur #32 und #33 (Pre- und Postflight, md5 identisch, Zahlen unverändert).
- **Testprojekt:** Die Anwendung von #35 bis #41 wartet auf deine Bestätigung der Supabase-Abfrage. Danach folgen die Abläufe über die echten RPCs mit Rücknahme.

## 6. Nicht umgesetzt (mit Grund)

- **EXP für Arena-Platzierungen:** Die Geschäftsregel fehlt. Nötig wäre eine Entscheidung: Gibt es EXP, für welche Plätze, und wie viele? Heute zahlt die Arena bewusst nichts aus.
- **Echter Login-Test** mit Boxer-, Trainer- und Admin-Konto: Dafür braucht es Testkonten. Der Owner muss sie bereitstellen.
- **Erstes echtes Backup mit Restore:** Dafür braucht es das DB-Passwort und die CLI auf dem Computer des Owners (siehe Runbook).
- **«Leaked password protection»:** Das ist eine Einstellung im Supabase Dashboard, Owner-Aufgabe.
- **Arena-Ergebnisse im Palmarès:** Die Arena-Ergebnistabelle ist absichtlich nicht öffentlich. Für eine Anzeige bräuchte es eine öffentliche Projektion, also eine neue Entscheidung.
- **Testprojekt angleichen** (Trainingsarten-IDs, fehlende Tabellen): Es fehlt die Bestätigung für Schreibvorgänge.

## 7. Verbleibende Risiken

- Kein Backup im Free Plan. Höchste Priorität (Runbook).
- Das Testprojekt weicht von der Produktion ab (fehlende Tabellen, andere IDs). Tests dort ersetzen keinen Produktions-Preflight.
- Gestapelte PRs #35, #36, #37 und #41 müssen in dieser Reihenfolge gemergt werden. Jede Migration muss **vor** dem Merge ihres PRs in der Produktion sein, weil die Seiten sonst neue RPCs aufrufen, die es noch nicht gibt.

## 8. Schritte zur Freigabe

1. Testprojekt freigeben: Ich wende die sechs Migrationen an. Du bestätigst dabei die Supabase-Abfragen. Danach spiele ich die Abläufe mit Rücknahme durch.
2. Backup nach dem Runbook erstellen.
3. Pro Migration in der Reihenfolge von Abschnitt 4: deine Freigabe, Preflight, Migration, Postflight. Danach den zugehörigen PR mergen.
4. #38 (Palmarès) kann jederzeit gemergt werden.
5. Danach einen Login-Test mit echten Testkonten.
