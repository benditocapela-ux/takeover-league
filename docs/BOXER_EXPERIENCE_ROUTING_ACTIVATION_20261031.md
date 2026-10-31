# Boxer Experience: Einstieg nach Merge von #83 und #84 aktivieren

## Ursache
Die PRs #84 und #83 sind gemergt. `boxer-experience.html` ist im Repository, aber `login.html` und `takeover-navigation.js` verlinkten Boxer weiterhin mit `boxer.html` (Legacy-Studio). Das neue Redesign wurde deshalb nicht als Standardansicht angezeigt.

## Fix
- Nach normaler Boxer-Anmeldung und über «Dashboard öffnen» -> `boxer-experience.html`.
- Rollenbasiertes Dashboard im gemeinsamen Menü -> `boxer-experience.html` («Mein Takeover»).
- Beim Öffnen der App-Startseite `index.html` oder `/` ohne Hash leitet das Menü nur **aktive authentifizierte Boxer** auf `boxer-experience.html` weiter. Gäste, Coaches und Admins bleiben auf den bisherigen Seiten.
- Explizite Liga-Links mit `#podium`, `#ranking`, `#levels` oder `#history` bleiben unverändert.
- Die alte Trainingsseite `boxer.html` bleibt für echte Trainingseinreichungen, `?club=1`, `?individual=1` und `#trainingFormCard` verfügbar. Ein sichtbarer Rücklink führt Boxer aus dem Studio zum Redesign; Coaches bekommen ihn nicht.
- Das bestehende Mein-Boxer-Holo-Editor-Ziel `mein-boxer.html` bleibt unverändert.
- Keine Supabase-SQL-Änderungen, keine Punkte- oder Feature-Flag-Änderungen.

## Prüfung / Rollout
`node --test tests/boxer-experience-routing.cjs`

Zusätzlich nach dem Merge auf der veröffentlichten Seite kontrollieren:
1. Boxer Login -> neue Oberfläche (Heute, Training, Kämpfe, Liga, Mein Boxer).
2. Logout / Gast -> öffentliche Liga.
3. PWA/Home (ohne Hash) mit Boxer-Session -> neue Ansicht.
4. Liga-Link mit #ranking -> öffentliches Ranking ohne Weiterleitung.
5. Training -> bestehendes Formular und erfolgreiche normale Einreichung (nicht testen mit echtem Punkte-Gutschrift-Experiment ohne Testkonto).
6. Coach/Admin Login -> bisheriges Dashboard.
7. Vorhandenes `boxer.html` -> Link «Neue Boxeransicht öffnen».
8. Bei staler Ansicht neu laden und Pages-Deployment-Status prüfen.

Die neue Ansicht wird durch diesen Fix zur Standardansicht; die Funktionsintegration von Training 2.0 und die produktive Freischaltung bleiben separat von den Routing-Änderungen zu prüfen. Der Fix selbst aktiviert keine Trainings-Flags.
