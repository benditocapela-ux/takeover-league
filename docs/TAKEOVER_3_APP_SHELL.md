# Takeover League 3.0 · App-Shell, Konto-Umschalter und integrierte Trainingsmeldung

Stand: 1.11.2026 · Branch `feature/takeover-3-app-shell` · Draft-PR (kein Merge, kein Deployment, keine Produktiv-Änderungen).

## 1. Architekturentscheidung

**Kein Framework-Wechsel.** Takeover besteht aus 33 Seiten mit jeweils eigener, geprüfter Geschäftslogik (RPCs, Validierung, Rechteprüfung, 130 Tests).

Diese Logik in eine Single-Page-App umzuschreiben, würde sie duplizieren. Das hat der Auftrag ausgeschlossen («keine duplizierte Business-Logik»), und es hätte die Freigabe um Wochen verzögert.

Gewählt wurde deshalb eine **gemeinsame App-Shell**. Jede Seite lädt dieselben zwei Bausteine:

| Baustein | Aufgabe |
|---|---|
| `takeover-app-shell.js` / `.css` | Kopfzeile (Bereich, Titel, Zurück, Hilfe, «Mein Account»), rollenbezogene Fussnavigation (Boxer 5 · Trainer 6 · Admin 4 · Gast 5), ein gemeinsames Menü mit allen Bereichen, Safe-Areas, Tastaturmodus fürs iPhone, zentrale Weiterleitung alter Links |
| `takeover-account.js` | wiederverwendbare Konto-Komponente für alle Rollen |
| `takeover-training-form.js` | integrierte Trainingsmeldung (ersetzt das eingebettete `boxer.html`-Formular) |
| `boxer-experience-studio.js` | Studio-Funktionen der alten `boxer.html` direkt in «Mein Takeover» |
| `takeover-experience.css` | Gestaltung von Formular, Historie, Mitteilungen und Profil |

**Wirkung der App-Shell auf alte Seiten:**
- Sobald die Shell läuft (`html.tla-on`), blendet sie die alten Kopfzeilen (`.tl-subnav`), die alte Fussleiste (`.tl-global-bottom`), das alte Menü, doppelte «Abmelden»-Knöpfe und alle «← Zurück»-Links aus.
- Die Hauptaktionen einer Seite bleiben als Chip-Leiste sichtbar.

**Kein iframe mehr:**
- `takeover-boxer-flow.js` und `takeover-boxer-embedded-flow.css` sind gelöscht.
- Funktionen, die nicht nativ in «Mein Takeover» liegen, öffnen als eigene Seite in derselben Shell: gleiche Kopfzeile, gleiche Fussnavigation, gleiches Konto-Menü. Das bedeutet einen normalen Seitenwechsel ohne Einbettung.
- View Transitions wurden getestet und wieder entfernt: Chromium meldet bei Weiterleitungen abgebrochene Übergänge als Seitenfehler.

**Ab Trainer- und Admin-Seiten:**
- Trainer-Dashboard und Clubverwaltung behalten ihre eigenen Bereichsleisten (6 bzw. 4 Bereiche) und bekommen dieselbe Kopfzeile samt «Mein Account».
- Beim Öffnen der installierten App landen Trainer und Admins direkt in ihrem Bereich, Boxer wie bisher in «Mein Takeover».

## 2. Konto-Umschalter («Mein Account», oben rechts auf jeder Seite)

**Funktionen:**
- aktives Konto mit Name, Rolle und E-Mail anzeigen;
- zu gespeicherten Konten wechseln;
- weiteres Konto hinzufügen;
- ein Konto aus dem Umschalter entfernen;
- abmelden.

**Ziel nach dem Wechsel:** Boxer → `boxer-experience.html`, Trainer → `coach.html`, Admin → `admin.html`. Die Rolle prüft dabei immer der Server.

| Vorher (`takeover-navigation.js`) | Jetzt (`takeover-account.js`) |
|---|---|
| `Storage.prototype.removeItem` global gepatcht | kein Eingriff in Browser-Prototypen; Abmelden läuft über `TLAccount.signOut` und `onAuthStateChange('SIGNED_OUT')` |
| Wechsel schrieb den Supabase-Sitzungsschlüssel direkt | Wechsel nur über die offizielle API `auth.setSession()`; supabase-js erneuert abgelaufene Zugriffstoken und lehnt widerrufene Refresh-Tokens ab |
| komplettes Sitzungs-JSON inkl. Benutzerobjekt gespeichert (`takeover_accounts_v1`) | nur Kennung, E-Mail, Name, Rolle und Token-Paar (`takeover_accounts_v2`), höchstens 5 Konten; v1 wird einmalig umgewandelt und gelöscht |
| keine Prüfung der Zielsitzung | widerrufene oder abgelaufene Sitzung: Konto wird als «Anmeldung abgelaufen» markiert, das bisherige Konto bleibt angemeldet, weiter geht es zur erneuten Anmeldung (`login.html?add=1&account=…`) |
| Boxer landeten nach dem Wechsel in `boxer.html` | rollenbezogene neue Oberfläche, Profil und Rolle frisch vom Server |
| Daten des vorherigen Kontos konnten im Speicher bleiben | nach jedem Wechsel lädt die Seite neu; Formularentwürfe und Anfrage-IDs der Sitzung werden gelöscht |
| Netzausfall beim Wechsel | Anmeldung bleibt gespeichert («Keine Verbindung»), nur endgültig ungültige Tokens führen zur erneuten Anmeldung; schlägt die Profilprüfung fehl, bleibt das bisherige Konto aktiv |
| andere Tabs / Zurück-Cache zeigten evtl. das alte Konto | Kontowechsel oder Abmeldung in einem anderen Tab sowie Rückkehr aus dem Zurück-Cache lädt die Seite neu |
| Abmelden widerrief alle Geräte des Kontos | Abmelden beendet die Sitzung auf diesem Gerät (`scope:'local'`, serverseitig widerrufen) |

**Verbleibender Kompromiss (bewusst, dokumentiert):**
- Für einen Wechsel ohne Passworteingabe muss das Refresh-Token der weiteren Konten auf dem Gerät liegen. Das ist dieselbe Vertrauensstufe wie die Sitzung, die supabase-js selbst im `localStorage` speichert.
- Passwörter werden nie gespeichert.
- «Entfernen» löscht die Tokens vom Gerät.
- Abmelden widerruft die Sitzung serverseitig.
- Der Hinweis «Nur auf deinem eigenen Gerät verwenden» steht im Menü.
- Die sichere Alternative ist immer verfügbar: Konto entfernen und bei Bedarf über «Weiteres Konto hinzufügen» neu anmelden.

## 3. Trainingsmeldung in «Mein Takeover»

**Ablauf:**
- **«Ja, im Verein»** ruft wie bisher `submit_scheduled_club_training_today` auf. Der Server entscheidet zwischen Check-in und Antrag.
- **«Nein, eigenes Training»** und **«Ergänzungstraining im Verein»** öffnen das integrierte Formular (`#training/eigenes` bzw. `#training/verein`). Es gibt kein iframe und keinen Seitenwechsel; Browser-Zurück schliesst das Formular.

**Funktionen des Formulars:**
- Training 2.0: Ort (Verein/individuell), Pflichttraining nach Wochentag (das Datum springt auf den richtigen Wochentag), Ergänzungstraining, Belohnungsvorschau aus `get_training_v2_config`;
- ohne Training 2.0: Trainingsart, Datum, Dauer, Distanz (nur bei Joggen) und Bemerkung, wie im bisherigen Formular;
- «Letztes Training übernehmen», Sitzungsentwurf und privater Online-Entwurf (`training_drafts_v2`) mit denselben Schlüsseln wie `boxer.html`;
- Statusmeldung nach dem Einreichen, Rückweg zur Übersicht; Historie und Zähler werden sofort aktualisiert.

**Sicherheit (unverändert serverseitig):**
- Der Browser schreibt nur einen Antrag (`status:'pending'`): keine Stufe, keine Punkte, keine EXP, keine Coins.
- `training_insert_guard` prüft Ort, Einheit, Wochentag und Datum erneut.
- Doppeltes Antippen ist doppelt abgesichert: Sperre während des Sendens plus `client_request_id` mit eindeutigem Index (`23505` → «bereits eingereicht»).

**Studio-Funktionen, die aus `boxer.html` übernommen wurden:**
- Trainingshistorie mit Filter und «Mehr anzeigen», Kalender und Wochenbalken, Änderungshistorie;
- Mitteilungen (mit «gelesen», Zähler und umgeleiteten Links), Profilbild;
- Trainingsstatistik, EXP/Level/Rang, 30-Tage-Performance, Coach-Feedback;
- Studio-Kacheln (Shop mit Coins, Kampfpfad, Quests, Wochenplan, Präsenz, Bewertung, Boxstil);
- Wochen-Quests, Rivale und Achievements;
- Einführungstour (jetzt in «Mein Takeover»).

## 4. Alte Links → neue Ansichten (`TLShell.legacyTarget`)

| Alter Aufruf (Boxer) | Neues Ziel |
|---|---|
| `boxer.html` | `boxer-experience.html#training` |
| `boxer.html?individual=1#trainingFormCard`, `#trainingFormCard` | `#training/eigenes` (Formular offen) |
| `boxer.html?club=1#trainingFormCard` | `#training/verein` |
| `#entriesCard`, `#trainingInsights`, `#boxerAuditSection` | `#training/historie` |
| `#boxerNotificationSection`, `#boxerTaskCenter` | `#heute/mitteilungen` |
| `#profileCard`, `#trainingStats`, `#expRankSection`, `#performance30Section`, `#achievementsV2`, `#boxerFeedbackSection` | `#boxer/profil` |

**Wie die Weiterleitung greift:**
- Ein früher Schutz in `boxer.html` zeigt die alte Oberfläche gar nicht erst, wenn das gespeicherte Konto ein Boxer ist.
- Die Shell leitet nach der Serverprüfung weiter.
- Klicks auf dynamisch erzeugte alte Links (z. B. Mitteilungen mit `target_path='/boxer.html'`) werden ebenfalls umgeleitet.
- Ohne Redirect-Schleifen: Ziel ist immer `boxer-experience.html`, und dort gibt es keine Weiterleitung zurück.
- Login: `next` akzeptiert nur Seiten aus dem eigenen Projekt (`*.html`, nie `login.html`/`boxer.html`). Nach dem Hinzufügen eines Kontos geht es zur Rollen-Startseite.
- Trainer behalten `boxer.html` als Formular für eigene Trainings.

## 5. Funktionsmatrix (Ist-Stand dieses PRs)

**Legende:**
- **nativ** = direkt in «Mein Takeover» umgesetzt.
- **Shell** = eigene Seite, aber in der gemeinsamen App-Shell: gleiche Kopfzeile, gleiche Navigation und gleiches Konto-Menü; alte Navigation, alte Kopfzeilen und Rücklinks ausgeblendet; kein iframe.

Alle Bereiche nutzen die bestehenden RPCs und RLS-Grenzen. «Mein Takeover» setzt Boxer-Rolle und aktives Profil voraus; die übrigen Seiten behalten ihre eigenen Prüfungen.

| Bereich | Funktion | Integration | Test |
|---|---|---|---|
| Heute | Holo, Level, Fortschritt, Studio-Kacheln, Mitteilungen, Rhythmus, Quests/Rivale | nativ | takeover3, boxer-experience, kampfgeist |
| Training | Ein-Klick Vereinstraining, eigenes Training, Ergänzung, Entwurf, letztes Training, Historie, Kalender, Änderungen | nativ | takeover3, boxer-experience |
| Training | Wochenplan, Ziele, Präsenz, Gym-Check-in | Shell | takeover3 (alle Breiten) |
| Kämpfe | Duelle, Live-Challenges, Challenges, Arena, Wochen-Quests | Shell | takeover3 |
| Liga | Podium, Rang, Monatspunkte | nativ | boxer-experience |
| Liga | Rangliste/Levels/Verlauf (index), Vergleich, Auszeichnungen, Hall of Fame, Boxerprofil | Shell | takeover3, release-browser-smoke |
| Mein Boxer | FUT-Card, Boxstil, Profilbild, Statistik, EXP/Rang, Performance, Coach-Feedback, Achievements | nativ | takeover3, boxer-experience |
| Mein Boxer | Holo-Editor, Shop/Inventar, Karten, Stil-Test, Bewertung, Kampfpfad, Roadmap | Shell | takeover3, kampfgeist |
| Weitere | Neuigkeiten (Punkt am Menü), Feedback (mit Herkunft), Hilfe/Tour, Account | Shell + Menü | news-feedback, help-tutorial |
| Trainer | 6 Bereiche, alle Aktionen | eigene Leiste + Shell-Kopfzeile | staff-experience, training-v2 |
| Admin | Profile, Zugänge, Protokoll, alle Aktionen | eigene Leiste + Shell-Kopfzeile | staff-experience, admin-registration |
| Gast | Podium, Ranking, Awards, Hilfe, Anmelden | Shell (Gast-Navigation) | takeover3, guest-showcase |

**Offen** (bewusst nicht in diesem PR, um keine Logik zu duplizieren):
- Die Shell-Seiten sind noch eigene Dokumente, d. h. ein normaler Seitenwechsel.
- Eine echte Einbettung ohne Seitenwechsel braucht pro Seite eine Modularisierung ihrer Skripte (eigener Folge-PR je Bereich: Kämpfe, Liga, Mein Boxer).

## 6. Tests

| Test | Inhalt |
|---|---|
| `tests/takeover3-browser.cjs` | Konto (hinzufügen, wechseln, zurück, drittes Konto, Rollenwechsel serverseitig, widerrufene Sitzung, entfernen, abmelden, PWA-Neustart, v1-Migration, kein Prototyp-Patch); Training (Ja/Nein, Validierung, Doppel-Tipp → 1 Insert, Pflicht mit Wochentag, Ergänzung, letztes Training, Historie, fremde Daten unsichtbar, Mitteilungen, alle alten Deep Links, Reload, Training 2.0 aus); Navigation (5 Tabs, 24 Seiten in der Shell, keine alte Leiste, kein iframe, 320/390/430/768/1366 px ohne Überlauf, Zurück, Gast, Trainer) |
| `tests/takeover3-contracts.cjs` | statische Verträge: Shell auf allen Seiten, kein Storage-Patch, `setSession`, Rollenziele, Legacy-Zuordnung, Formular schreibt nur Anträge, Validierung, Studio-Schreibrechte |
| `tests/takeover3-harness.cjs` | Supabase-Attrappe mit simuliertem Token-Server (Widerruf, Rotation) |
| bestehende Tests | an das neue Menü angepasst (`account-switch`, `boxer-experience-*`, `staff-experience-*`, `admin-registration`, `help-tutorial`, `news-feedback`, `release-browser-smoke`, `kampfgeist`, `redesign-contracts`); Studio-Tests für `boxer.html` laufen mit Trainerprofil |

CI (GitHub Actions, Commit `d3e97f9`): 92 von 92 Prüfungen grün, darunter alle Takeover-3.0-Wege in Chromium **und WebKit**.

## 7. Bekannte Risiken
- **WebKit-Absturz im Test:** Playwright-WebKit (Linux) stürzte reproduzierbar ab, wenn eine lange offene Boxer-Experience-Seite per `goto` auf `boxer.html` wechselte. Derselbe Weg in einem frischen Tab (Lesezeichen, Mitteilung) läuft fehlerfrei; der Test nutzt deshalb einen frischen Tab. Auf einem echten iPhone (Safari und installierte App) vor der Freigabe prüfen.
- **Nicht im Simulator geprüft:** Safe-Area, Dynamic Island und Tastatur sind per CSS (`env(safe-area-inset-*)`, ausgeblendete Navigation beim Tippen) und mit simuliertem Inset getestet, nicht auf einem Gerät.
- **Rollenhinweis kann veralten:** Der frühe Weiterleitungsschutz in `boxer.html` nutzt die zuletzt gespeicherte Rolle. Wurde ein Boxer kürzlich zum Trainer, landet er einmalig in der Boxer-Sperrseite; ab dem nächsten Laden stimmt es.
- **Testdatum:** `tests/admin-challenge-editing-browser.cjs` hatte feste Daten, die am 1.11.2026 abliefen (auch auf `main` rot); hier auf relative Daten umgestellt.
