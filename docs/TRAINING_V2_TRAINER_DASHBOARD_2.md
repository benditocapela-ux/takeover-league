# Training 2.0 & Trainer-Dashboard 2.0

Stand 31.10.2026 · Branch `feature/training-and-coach-dashboard-v2` · **Kein Merge, kein Deployment, keine produktiven Datenänderungen.**

## 1. Ursache der 30-Punkte-Wertung

1. `league_private.training_insert_guard` setzt bei jeder Selbstmeldung `club_tier := NULL`. Das ist richtig, denn Boxer dürfen keine Stufe setzen.
2. `public.review_training` (Trainerbestätigung) bucht nur `training_types.points`. Seit der Aktivierung vom 28.10. sind das für «Reguläres Boxtraining» 30 Punkte. Eine Stufe setzt die Funktion nie.
3. Eine Stufe bekamen bisher nur Gym-Check-ins (`staff_confirm_gym_session`) und das nachträgliche Einstufen (`staff_set_training_tier`).

**Folge:** Ein selbst gemeldetes Vereinstraining wurde nach der Bestätigung immer wie ein Heimtraining gewertet: 30 statt 60 Punkte und EXP, 10 statt 15 Coins, 10 statt 15 Kampfpfad-Punkte.

## 2. Neues Modell

| Kategorie | Einheiten | Wertung nach Trainerbestätigung |
|---|---|---|
| Pflicht (Verein) | Mo, Mi, Sa – Reguläres Boxtraining (aus dem Stundenplan `club_schedule`, fester Wochentag) | 60 Punkte · 60 EXP · 15 Coins · 15 Kampfpfad |
| Ergänzung (Verein) | Sandsack, Athletik, Technik (`club_extra_trainings`, an jedem Tag) | 40 · 40 · 12 · 12 |
| Individuell | alle übrigen Trainingsarten | Wert der Trainingsart (z. B. 30) · Coins/Kampfpfad wie bisher |

Höhere Werte einer Trainingsart bleiben erhalten (`max(Stufe, Trainingsart)`, z. B. Wettkampfsparring 70). Für Buchung **und** Vorschau gilt eine einzige Regel: `league_private.training_reward(type, tier)`. Auch `training_value` nutzt sie; das Ergebnis ist identisch zur bisherigen Formel, was der Postflight prüft.

## 3. Sicherheit

- Der Boxer stellt nur einen **Antrag**: `training_location`, `requested_tier`, `requested_slot_id` und `requested_extra_key`.
  - Der Insert-Trigger prüft den Wochentag gegen die Pflichteinheit (Zeitzone Europe/Zurich) und blockiert Daten in der Zukunft.
  - Die Trainingsart übernimmt er aus der Einheit. Wer «Wettkampf» (100) als Pflicht beantragt, erhält trotzdem Reguläres Boxtraining.
  - `club_tier` bleibt für Boxer gesperrt. Ein neuer Update-Trigger sperrt Antrag und Stufe auch bei direkten Aufrufen.
- `public.staff_review_training` (nur aktive Trainer und Admins) bestätigt oder lehnt ab:
  - Die Zeile wird gesperrt (`FOR UPDATE`). Ein wiederholter Aufruf liefert `already=true` und bucht nichts.
  - Es gibt genau eine Punktebuchung, über die bestehende `review_training`.
  - Danach setzt die Funktion die Stufe und ruft `apply_training_value` auf. Coins und Kampfpfad folgen automatisch aus `club_tier`.
  - Eine Abweichung vom Antrag braucht eine Begründung, ebenso eine Pflichteinheit an einem anderen Tag (verschobenes Training).
  - Mögliche Duplikate, also Gym-Check-in am selben Tag oder gleiche Art am selben Tag, werden nur bewusst und mit Begründung zugelassen (Fehlercode 23505).
  - Eigene Trainings stuft immer ein anderer Trainer ein. Abgeschlossene Saisons sind gesperrt.
- `public.staff_correct_training` korrigiert bestätigte Trainings: Art, Datum, Dauer und Kategorie. Eine Begründung ist Pflicht, jede Änderung steht in `training_audit`.
- Schalter `training_v2` startet **aus**. Ohne Schalter werden Anträge ignoriert, Kategorien sind gesperrt und die Bestätigung bucht wie bisher.

## 4. Funktionsinventur Trainer-Dashboard (vorher → nachher)

| Bisherige Funktion (`coach.html`) | Jetzt |
|---|---|
| Rollenprüfung (aktiver Coach/Admin), Begrüssung, Abmelden, Liga/Account | unverändert (Kopf) |
| Kennzahlen: offene, aktive Boxer, bestätigte | Start: offene (gross), heute trainiert, heute bestätigt, aktive Boxer, bestätigt gesamt |
| Hinweis offene Selbsteinschätzungen | Start, ganz oben |
| Offene Trainings: Suche, Einzel-Bestätigen/-Ablehnen, Profil, Schnellansicht, zuletzt angesehene Boxer | Bereich «Prüfen»: Karten, Kategorie-Filter, Suche, 10 pro Seite + «Mehr anzeigen», zweimal tippen zum Bestätigen, Bottom Sheet zum Bearbeiten/Ablehnen |
| Sammelaktion (max. 20, Bestätigungsdialog) | Auswahl + Leiste; Zusammenfassung mit Wert pro Training; Meldungen mit Hinweis werden übersprungen; Ergebnis pro Eintrag |
| Alle Trainings bearbeiten (Filter, Seiten, Volleditor inkl. Boxer/Status/km/Technik) | Bereich «Historie»: gleicher Volleditor («Alle Felder»), zusätzlich Kategorie-Filter, «Korrigieren» (Bottom Sheet mit Begründung), 10 pro Seite |
| Ablehnung rückgängig (15 Min.) | unverändert (Historie) |
| Stufe einstellen (Etappe 6a) | ohne Training 2.0 wie bisher; mit Training 2.0 über «Korrigieren» (Begründung + Audit) |
| Änderungshistorie (letzte 5) | Historie |
| Coach-Feedback (senden, sichtbar bis, archivieren, zurückziehen, wiederherstellen) | Bereich «Boxer» |
| Boxer-Schnellansicht (letzte 5 bestätigte, Profil, Challenge) | unverändert, plus Boxer-Suche und «Alle Trainings in der Historie» |
| Gym heute, Link Check-in | Bereich «Gym» (+ Präsenz, Wochenplan) |
| Training eintragen (für Boxer, sofort bestätigt) | Bereich «Gym» |
| Challenges/Duelle-Hinweis, automatische Aktualisierung (2 Min. Ruhe) | unverändert |
| Sprungleiste, zuklappbare Abschnitte, Schnellaktionen-Knopf | ersetzt durch die Bereichsnavigation, damit es keine konkurrierenden Menüs gibt |
| neu: Admin-Prüfbericht (Dry-Run) | Historie, nur Admin |

## 5. Bestehende Trainings

Es gibt keine automatische Umbuchung. `public.admin_training_tier_review` (im Dashboard, nur für den Admin) und `supabase/production-prep/training_v2_dry_run_read_only.sql` zeigen:

- bestätigte Vereinstrainings ohne Stufe in offenen Saisons,
- mit Vorschlag, aktuellem Wert und Differenz.

Ein Vorschlag entsteht nur aus einem Antrag (Training 2.0), aus einer Vereinsart bzw. der Art der Pflichteinheit am Pflichttag oder aus einer Vereins-Ergänzungsart, also nie allein nach dem Wochentag. Nachbuchungen erfolgen einzeln über «Prüfen» → `staff_correct_training` mit Begründung und Audit, und erst nach ausdrücklicher Freigabe.

## 6. Freigabe, Aktivierung, Rücknahme

1. `preflight_20261031090000_training_v2.sql` (nur lesend)
2. Migration `20261031090000_training_v2_classification.sql` und danach `20261031100000_scheduled_club_training_quick_request.sql` (keine Bestandsdatenänderung, Schalter aus)
3. `postflight_20261031090000_training_v2.sql` (nur lesend)
4. Optional `training_v2_dry_run_read_only.sql`
5. **Nur mit Freigabe:** `activate_20261031090000_training_v2.sql`. Sie stellt den Stundenplan Mo/Mi/Sa auf «Reguläres Boxtraining» um, sichert ihn vorher in `league_private.training_v2_schedule_backup` und schaltet `training_v2` ein.
6. Frontend (GitHub Pages) erst nach Schritt 2 mergen. Ohne Migration fällt `coach.html` automatisch auf den bisherigen Datenweg (`review_training`) zurück.

Rücknahme:

- `deactivate_20261031090000_training_v2.sql`: Schalter aus, Stundenplan aus der Sicherung.
- `rollback_20261031100000_scheduled_club_training_quick_request.sql`: entfernt den gemeinsamen Ein-Klick-Server-RPC (vor dem Basis-Rollback).
- `rollback_20261031090000_training_v2_classification.sql`: stellt `training_insert_guard` und `training_value` wörtlich wieder her und entfernt die neuen Objekte.

Bestätigte Buchungen und das Audit bleiben in beiden Fällen erhalten. Vor jedem produktiven Schritt gilt: Backup gemäss `docs/BACKUP_RESTORE_RUNBOOK.md`.

## 7. Unabhängige Prüfung und offene Punkte

Eine separate Prüfung der Datenbanklogik fand keine kritischen Lücken. Diese Befunde sind behoben und getestet:

- Trainer konnten bei eigenen Trainings eine Stufe vorbelegen. Jetzt gelten eigene Meldungen auch für Trainer als Antrag, und die Bestätigung setzt die Stufe immer autoritativ.
- Trainer bestätigen oder korrigieren eigene Trainings nicht mehr selbst; das macht ein anderer Trainer oder der Admin.
- Bei Schalter aus bleibt eine bestehende Stufe (Gym-Check-in) bei Korrekturen erhalten.
- Der Saisonschutz prüft auch das ursprüngliche Datum.
- Gleichzeitige Freigaben desselben Boxers am selben Tag laufen nacheinander (Advisory Lock).
- Das Audit ist vollständig.
- Bei Artwechsel werden die Technikminuten nicht mehr übernommen.
- Der Rollback bricht ab, solange der aktivierte Stundenplan noch aktiv ist.

Bewusst offen (Entscheid Owner):

- Ist zusätzlich `club_checkin_only` eingeschaltet, kann Training 2.0 trotzdem aktiv sein: Der gemeinsame Ja-Button registriert die Anwesenheit **nur bei einer vom Trainer geöffneten passenden Pflicht-Gym-Einheit**. Ohne geöffnete Einheit gibt es keinen Selbstantrag und keine Gutschrift. Gym und Training 2.0 sind somit auf UX-Ebene kompatibel, die restriktive Vereinsregel bleibt erhalten.
- `staff_confirm_gym_session` (Etappe 6a) nimmt den neuen Tages-Lock noch nicht. Die bestehende Prüfung «gleiche Trainingsart am selben Tag» bleibt aktiv, und `staff_review_training` erkennt Gym-Check-ins als Hinweis.
- `staff_set_training_tier` (Etappe 6a) gibt es weiterhin. Das Dashboard nutzt es mit Training 2.0 nicht mehr; es kann nach der Aktivierung entfernt oder an eine Begründung gebunden werden.

## 8. Tests

| Test | Inhalt |
|---|---|
| `tests/training-v2-schema.sql` | PostgreSQL, die 20 Funktionsfälle inkl. Rollback |
| `tests/training-v2-concurrency.sh` | 6 parallele Bestätigungen → 1 Buchung |
| `tests/training-v2-contracts.cjs` | statische Sicherheitsverträge |
| `tests/training-v2-browser.cjs` | Chromium, in CI zusätzlich WebKit: alle Dashboard- und Formularabläufe, 320–1366 px, erzeugt die Screenshots in `docs/screenshots/training-v2/` |

## 15. Gemeinsamer Pflichttraining-Einstieg (PR #83 und PR #84)

**Ein einziger Ja-Button, zwei sichere Buchungswege:** Der Boxer wählt «Warst du heute im Vereinstraining?». Der Server verwendet den heutigen Tag in Europe/Zurich und die aktive `club_schedule`-Pflichteinheit; keine freien Trainingsarten oder Stufen vom Client.

1. Wenn für den Slot eine passende **geöffnete** `gym_sessions`-Einheit existiert (`training_type_id`, `club_tier='pflicht'`, passender `slot_id`), erzeugt der RPC genau **einen `gym_attendance`-Eintrag** (`checked_in`). Der Trainer bestätigt danach wie bisher gesammelt über `staff_confirm_gym_session`; **erst dann** werden Trainingspunkte/EXP/Coins gebucht.
2. Ohne offene Gym-Einheit und bei **erlaubter Selbstmeldung** erstellt derselbe RPC genau **einen `pending`-`training_submissions`-Antrag** (`submitted`). Der Trainer bestätigt diesen über `staff_review_training`.
3. Bei gleichzeitig `gym_training=true` und `club_checkin_only=true` wird ohne offene Gym-Einheit **kein** Antrag erzeugt (`gym_not_open`). Der Boxer erhält einen klaren Hinweis, dass der Trainer die Einheit zuerst starten muss. Kein Umgehen des Check-in-Zwangs.
4. Wenn mehrere passende Pflicht-Gym-Einheiten geöffnet sind, wählt der Boxer die richtige auf `checkin.html` (`choose_gym_session`); wenn mehrere Pflicht-Slots existieren, wird zunächst eine Slot-Auswahl verlangt (`choose_slot`).
5. Bei bestehendem Check-in (`already_checked_in`) oder bereits offenem/bestätigtem Training (`already_pending`/`already_approved`) wird **keine zweite Meldung** erstellt.

**Oberflächen:** `boxer.html`, `boxer-experience.html` und die feste Pflichttrainingsliste auf `checkin.html` verwenden denselben RPC `public.submit_scheduled_club_training_today(integer)`. Bei nur einer offenen Pflichteinheit zeigt `checkin.html` keinen zweiten redundanten Check-in-Button; sonst bleibt die Auswahl mehrerer Gym-Einheiten sowie der Zugang zu Ergänzungstrainings erhalten. «Nein» öffnet das individuelle Training; andere Vereinstrainings bleiben separat erreichbar. Der Erfolgswortlaut unterscheidet ausdrücklich `checked_in` (Anwesenheit registriert) von `submitted` (Training zur Freigabe beantragt).

**Datenintegrität:** Boxer-Authentifizierung/Rolle, aktiver Stundenplan, Wochentag, geschlossene Saisons, Advisory-Lock pro Boxer/Tag, bestehende Trainings und bestehende Gym-Anwesenheit werden vor jedem Schreibvorgang geprüft. Die Gym-Einheit wird `FOR UPDATE` gesperrt, wodurch gleichzeitig ablaufende Gym-Trainerbestätigungen serialisiert werden. Der RPC schreibt **niemals** direkt Punkte oder EXP. Der ältere, separate `gym_check_in` und `staff_confirm_gym_session` bleiben unverändert für nicht-Pflicht-Gym-Einheiten. Deren Race-Verhalten mit gleichzeitigen manuellen Traineraktionen ist vor produktiver Freigabe noch end-to-end zu prüfen.

**Freigabe:** zuerst Backup → Basis-Migration `20261031090000` → Quick-RPC-Migration `20261031100000` → Postflight → Gym-/Antrag-Integrations- und Parallelitätstests → nur mit ausdrücklicher Owner-Freigabe den `training_v2`-Schalter aktivieren. Rollback: `training_v2` deaktivieren, Quick-RPC entfernen, Basis-Migration zurückrollen. Bestehende Buchungen werden nie automatisch zurückgebucht.

**Tests:** `node --test tests/club-today-contracts.cjs` (in CI eingebunden) sowie die angepassten Boxer-Browser-Abläufe. Die komplette PostgreSQL-/reale Rollen-/Parallelitätsprüfung ist noch nicht nachgewiesen. Draft, kein Merge, kein Deployment.
