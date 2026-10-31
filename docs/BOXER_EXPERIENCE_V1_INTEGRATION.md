# Boxer Experience – parallel zu Claude / Design-PRs

Branch: feature/boxer-experience-redesign (based on main @ 8176e8014d134136ba210ced37b230cd61190ac8)

## Implementiert

- Neue, eigenständige Route: boxer-experience.html.
- Fünf Bereiche: Heute, Training, Kämpfe, Liga, Mein Boxer.
- Persönlicher Holo nur auf «Heute»; fixierte FUT-Card nur auf «Mein Boxer».
- Sechsachsiges Boxstil-Diagramm unter der fixierten FUT-Card.
- Liga-Podium mit aktuellen drei besten Boxern und ihren echten Holo-Looks, sofern vorhanden.
- Daten aus bestehenden geprüften Auth-/Profil-/Performance-/Ranglisten-RPCs und RLS-geschützter Trainingshistorie.
- Keine Änderungen an Supabase, Coach-UI, Punktevergabe, Trainingsarten, bestehendem Login oder bestehendem Boxer-Studio.
- Bei nicht verfügbaren Daten werden neutrale Zustände statt Demo-Punkten oder erfundener Boxer angezeigt.

## Noch vor produktivem Merge

1. Review der Auth- und Feature-Flag-Anzeige mit echtem Testkonto. Die Loginseite leitet neue Loginvorgänge derzeit weiter zum bestehenden Studio; die neue Route ist daher aktuell nur über einen direkten Link nach dem Login erreichbar.
2. Mobile Touch-/Responsiveness-/Accessibility-/Leistungstests mit verbundenem Supabase und realen nicht freigeschalteten Profileinstellungen.
3. **PR #84 abgeglichen:** `get_training_v2_config` wird vom Boxer-Redesign nur gelesen. Sobald `enabled=true`, zeigt der Tab «Training» die durch den Server definierten Pflicht- und Ergänzungseinheiten und die voraussichtliche Belohnung aus `reward`. Ist die Funktion deaktiviert oder fehlt die Migration, bleibt ein einziger Zugang zum bisherigen Formular.
   - Der eigentliche Antrag (training_location, requested_slot_id, requested_extra_key), der Kategorie-/Wochentagscheck und die Punkte-/EXP-/Coins-Buchung bleiben vollständig in Claudes `boxer.html` + `takeover-training-v2.js` + Server.
   - Bei `club_checkin_only=true` führt der Vereinsweg zu `checkin.html`, nicht zur Selbstmeldung.
   - **Keine Vorauswahl** aus dem neuen Dashboard, weil Claudes Formular derzeit keinen unterstützten Deep-Link zur Kategorie bereitstellt. Die Auswahl erfolgt dort.
   - Mit PR #84 wurden keine gemeinsamen Dateien geändert: PR #83 kann nach Erfüllung der Gates eigenständig reviewed werden.
4. Echte Integration/Feature-Flag-/Gym-Check-in-Tests mit PR #84 und nach dessen produktiver Migration sind erforderlich, bevor die neue Route aktiv verlinkt wird.
5. Nach Abschluss der laufenden Premium-Holo-/Mein-Boxer-PRs visuelles Rendering und Layout abgleichen.
6. Erst anschliessend Boxer-Dashboard-Routing (login.html, takeover-navigation.js und ggf. Links) sicher umstellen.
7. Review / Freigabe / Merge / Deployment getrennt entscheiden.

## Automatische Smoke-Tests

    node --test tests/boxer-experience-contract.cjs

Tests prüfen Syntax, Tabs, Sections, IDs, echte RPCs, Auth-Guard, Read-only-Regeln und die kompatible servergesteuerte Training-2.0-Anzeige. Browser-/DB-Tests mit beiden Branches stehen weiterhin aus.

## Rollback

Keine produktive Route wurde ersetzt. Ein nicht gemergter PR kann ohne Auswirkungen geschlossen werden.

## Abgleich mit Claude-PR #84 (31.10.2026)

| Thema | PR #83 | PR #84 | Ergebnis |
|---|---|---|---|
| Gemeinsame Dateien | nur neue `boxer-experience.*`, Tests/Doku | `boxer.html`, `coach.html`, Migration, neue V2-Skripte/Tests | keine direkten Dateikonflikte |
| Trainingseinstieg | bestehende Route `boxer.html#trainingFormCard` | V2-Formular in `boxer.html` | wiederverwendet |
| Trainingskategorien | reines Lesen von `get_training_v2_config` | servergesteuerte Pflicht-/Ergänzung-/Individual-Auswahl | abgestimmt |
| Belohnungen | Anzeige von `reward.points`, `reward.exp`, `reward.coins` | `league_private.training_reward` | keine Duplikate/Festwerte |
| Freigabe | keine Mutation | Schalter `training_v2` initial aus | Legacy-Fallback |
| Gym | erkennt `club_checkin_only` für Zielroute | bei aktivem Check-in-Only keine Vereins-Selbstmeldungen | berücksichtigt |
| Aktivierung | noch nicht als Boxer-Standard verlinkt | Migration und Aktivierung durch Owner | keine produktiven Eingriffe |

**Wichtig:** Die optische Zusammenführung in ein einziges eingebettetes Formular ist noch nicht fertig. Bis dahin öffnet der Training-Tab die kanonische Trainingsseite, damit genau eine serverseitige Validierungs- und Buchungslogik existiert. Die Doku von PR #84 nennt zudem offene Risiken bei `club_checkin_only` und Gym-Duplikaten; diese werden durch das Redesign nicht behoben.
