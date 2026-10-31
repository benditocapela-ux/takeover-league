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
   - Bei gleichzeitigem `club_checkin_only` und `gym_training` prüft der **gemeinsame Ja-Button**, ob der Trainer eine passende Pflichteinheit geöffnet hat: dann Check-in über denselben RPC, sonst klare Meldung `gym_not_open`. Eine Selbstmeldung ist in diesem Modus weiterhin gesperrt.
   - **Keine Vorauswahl** aus dem neuen Dashboard, weil Claudes Formular derzeit keinen unterstützten Deep-Link zur Kategorie bereitstellt. Die Auswahl erfolgt dort.
   - Mit PR #84 wurden keine gemeinsamen Dateien geändert: PR #83 kann nach Erfüllung der Gates eigenständig reviewed werden.
4. Echte Integration/Feature-Flag-/Gym-Check-in-Tests mit PR #84 und nach dessen produktiver Migration sind erforderlich, bevor die neue Route aktiv verlinkt wird.
5. Nach Abschluss der laufenden Premium-Holo-/Mein-Boxer-PRs visuelles Rendering und Layout abgleichen.
6. Erst anschliessend Boxer-Dashboard-Routing (login.html, takeover-navigation.js und ggf. Links) sicher umstellen.
7. Review / Freigabe / Merge / Deployment getrennt entscheiden.

## Automatische Smoke-Tests

    node --test tests/boxer-experience-contract.cjs

Tests prüfen Syntax, Tabs, Sections, IDs, echte RPCs, Auth-Guard, keine direkten Datenbank-Schreibaufrufe und die servergesteuerte Training-2.0-Anzeige (mit dem ausdrücklich erlaubten Quick-Request-RPC). Browser-/DB-Tests mit beiden Branches stehen weiterhin aus.

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

**Wichtig:** Die optische Zusammenführung in ein einziges eingebettetes Formular ist noch nicht fertig. Bis dahin öffnet der Training-Tab die kanonische Trainingsseite, damit genau eine serverseitige Validierungs- und Buchungslogik existiert. Der frühere Check-in-only-Redirect wurde durch einen gemeinsamen serverseitigen RPC ersetzt. Weitere Tests für gleichzeitige Traineraktionen und Gym-Buchungen bleiben vor dem Merge erforderlich.

## Ein-Klick-Vereinstraining – Abstimmung mit PR #84

- Die Startseiten-Aktion «Training einreichen» wechselt jetzt zum Trainingstab, statt die Ja/Nein-Frage zu überspringen.
- Bei `get_training_v2_config.enabled=true` erscheint die Frage «Warst du heute im Vereinstraining?». «Ja» nutzt ausschliesslich den serverseitigen RPC `submit_scheduled_club_training_today` von PR #84. Es werden weder Trainingsart noch Stufe, Punkte, EXP oder Coins vom Boxer gesetzt.
- «Nein» öffnet `boxer.html?individual=1#trainingFormCard` mit individueller Vorauswahl. Für Ergänzungstrainings im Verein ist `?club=1` vorgesehen.
- Der RPC unterscheidet `submitted` (ein neuer offener Antrag), `checked_in` (neuer Gym-Anwesenheitseintrag), `already_pending`, `already_approved`, `already_checked_in`, `gym_not_open`, `choose_gym_session`, `no_slot`, `choose_slot` und `disabled`. Nur bei `submitted` bzw. `checked_in` wird die jeweils passende Erfolgsmeldung angezeigt.
- Mit deaktiviertem `training_v2` oder fehlender Migration fällt das UI auf das alte Formular zurück. Bei verpflichtendem Gym-Check-in wird keine zusätzliche Selbstmeldung erzwungen.
- Check-in-Seite und Server-RPC werden ausschliesslich in PR #84 bearbeitet. PR #83 verwendet sie nur nach dessen Integration.

**Gate:** Beide PRs müssen zusammen gegen die Basis-Migration und die zusätzliche `20261031100000_scheduled_club_training_quick_request.sql` getestet werden, bevor sie produktiv verlinkt oder aktiviert werden. Die jetzige Umsetzung ist weiterhin Draft und hat weder Merge noch Deployment ausgelöst.

## Vereinheitlichung (31.10.2026)

`submit_scheduled_club_training_today` aus PR #84 entscheidet anhand der tatsächlichen offenen Gym-Einheit und der Vereins-Flags zwischen `checked_in` (Gym-Anwesenheit, Trainer bestätigt später) und `submitted` (ausstehender Trainingsantrag, Trainer prüft später). Auch bei Check-in-only bleibt im neuen Dashboard der **Ja**-Button sichtbar; ohne geöffnete Gym-Einheit erscheint `gym_not_open` statt einer falschen Erfolgsnachricht. Separate Punkte- oder EXP-Buchungen durch das Dashboard gibt es nicht. Mehrere passende Gym-Einheiten werden in der Check-in-Seite auswählbar angezeigt. Beide Draft-PRs sind weiterhin voneinander abhängig und dürfen erst nach gemeinsamem Test freigegeben werden.
