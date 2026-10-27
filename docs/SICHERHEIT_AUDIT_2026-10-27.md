# Sicherheitsprüfung – 27.10.2026

Grundlage: Supabase Security Advisor (Produktion), Funktionsdefinitionen in `public`, `league_v21_private` und `league_private`, RLS-Policies. Ausgeführt **nur lesend** mit `supabase/production-prep/security_definer_audit_read_only.sql`.

## Ergebnis in Kürze

| Befund | Bewertung | Massnahme |
|---|---|---|
| 75 SECURITY-DEFINER-Funktionen sind für angemeldete Nutzer aufrufbar (Advisor-Warnung 0029) | **Beabsichtigt.** Jede prüft die Rolle über `auth.uid()`, `league_private.coach_v2_actor()` oder `is_league_admin/coach()`. Eine Funktion delegiert an die geprüfte `admin_edit_training`. **Keine Funktion ohne Prüfung gefunden.** | 16 ungenutzte 2.0-Funktionen sind seit 27.10.2026 gesperrt (Migration `20261028120000`, Prod-Postflight: 0 aufrufbar). |
| 6 Funktionen für `anon` aufrufbar (Warnung 0028) | **Beabsichtigt:** öffentliche Rangliste, Levels, Avatare, Monats-Awards, Award-Rangliste (alle nur `is_active AND is_listed`), dazu `is_league_admin()`. Diese liefert nur «bin ich Admin?» für den eigenen Login und ist für Anonyme immer `false`. | keine |
| 17 Tabellen mit RLS ohne Policy (Info 0008) | **Beabsichtigt:** private Ledger und interne Tabellen (EXP-Ledger, Duelle, Arena, Coach-Challenges, Training-Audit). Direkter Zugriff ist komplett gesperrt, gelesen und geschrieben wird nur über geprüfte Funktionen. | keine |
| Schutz vor geleakten Passwörtern ist ausgeschaltet (Auth) | **Empfohlen einzuschalten.** | Owner: Supabase Dashboard → *Authentication → Policies/Passwords* → «Leaked password protection» aktivieren. |
| Private Kernfunktionen (`league_v21_private.*`) | Das Schema ist nicht über die API exponiert. Ausführbar nur für `authenticated` über die öffentlichen Wrapper. Prüfung im Kern. | keine |

## Rollen und Rechte (geprüft)

- **Admin:** Profilverwaltung (Archiv, Rollen, Sichtbarkeit), Saisons, Liga-Challenges, Arena, EXP-Regeln, Nachberechnungen.
- **Trainer (coach):** Trainingsprüfung, Feedback, Coach-Challenges, persönliche Challenges. Mit #36 neu auch Boxerziele. EXP-Regeln bleiben Admin-only.
- **Boxer:** eigene Trainings, Ziele, Teilnahme an Challenges, Duellen und Arena. Kein Zugriff auf fremde private Daten (RLS).
- **Anonym:** nur öffentliche Projektionen (Rangliste, Badges, Rekorde, Saisonergebnisse, Hall of Fame, Duell-Historie). Seit #32 enthalten sie keine nicht öffentlichen Boxer mehr.

## Ungenutzte 2.0-Funktionen (gesperrt mit `20261028120000`)

`boxer_join_league_challenge`, `boxer_respond_duel_invite`, `coach_add_boxer_palmares`, `coach_add_hall_of_fame_entry`, `coach_award_season_hall_of_fame`, `coach_create_boxer_duel`, `coach_create_league_challenge`, `coach_create_league_season`, `coach_finalize_boxer_duel`, `coach_finalize_league_season`, `coach_set_boxer_duel_status`, `coach_set_goal_status`, `coach_set_league_challenge_status`, `coach_set_league_season_status`, `get_boxer_duel_score`, `get_league_challenge_progress`.

- Keine wird vom Frontend aufgerufen.
- Alle hängen an ausgeschalteten Feature-Flags.
- Keine RLS-Policy und keine aktive Funktion nutzt sie.
- Sie werden **nicht gelöscht**, nur `EXECUTE` wird entzogen. Der Rollback stellt die Rechte wieder her.

## Migrationshistorie

- In der Produktion ist 2.1 als eine atomare Migration erfasst (`takeover_league_21_atomic_25_migrations_20261019`). Im Repository liegen die 25 Einzeldateien `20261019010000` bis `20261019035000`.
- Ab dem 21.10. stimmen Repository und Produktion eins zu eins überein. Die Versionsnummern in der Produktion sind Anwendungszeitpunkte, die Namen entsprechen den Dateinamen.
- Das Testprojekt hat eine längere, abweichende Historie mit Test-Fixtures und Rollback-Zyklen. Ihm fehlen einzelne Produktionstabellen, etwa `boxer_coach_feedback`, und die IDs der Trainingsarten weichen ab. Es eignet sich darum für Funktionstests, aber nicht als 1:1-Abbild der Produktion.

## Offene Sicherheits-Gates

- [x] Ungenutzte 2.0-Funktionen gesperrt (27.10.2026, Migration `20261028120000`).
- [x] Neue Funktionen aus #35 bis #41 ohne Anmeldung nicht aufrufbar (Prod-Postflight 27.10.2026).
- [ ] Echter Login-Test mit Boxer-, Trainer- und Admin-Konto in der Produktion. Dafür braucht es Testkonten vom Owner.
- [ ] Echtes Backup mit getestetem Restore (siehe `docs/BACKUP_RESTORE_RUNBOOK.md`). Vor der Migration vom 27.10.2026 auf Owner-Entscheid übersprungen.
- [ ] «Leaked password protection» aktivieren.
