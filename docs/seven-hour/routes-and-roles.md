# Routen und Rollen: vorhandene Prüfnachweise

Stand: 2. November 2026, Übergabe des Arbeitsbranches. Diese Matrix inventarisiert vorhandene Quellen, ausgeführte Tests und deren dokumentierte Ergebnisse; für die Matrix wurden **keine neuen Browser-, Cloud- oder Geräteabnahmen** durchgeführt. Sie ist keine pauschale Freigabe aller Seiten.

Der Root enthält 36 HTML-Dateien. Die folgenden **33 Produktiveinstiege** schließen `challenges-v2-preview.html`, `duels-v2-preview.html` und `league2-preview.html` aus. Entwicklungsansichten unter `tools/` sind nicht Teil dieser Zählung. „Produktivroute“ bezeichnet die Route im bestehenden Veröffentlichungsumfang, nicht eine Veröffentlichung der Änderungen dieses Branches.

## Leseschlüssel und Belege

- **Q – Quellprüfung:** `takeover3-contracts.cjs` prüft die gemeinsame Shell-/Account-Einbindung aller 33 Dateien; Design-, JS-/CSS- und gezielte Release-Verträge ergänzen dies. Das beweist keine Bedienbarkeit aller Formulare oder Serverrechte. **33/33 Release-Assertions sind nicht 33 vollständig abgenommene Seiten.**
- **S – Shell-Browserprüfung:** `takeover3-browser.cjs`, tatsächlich Chromium und WebKit mit vollständig simuliertem Supabase-SDK. Für 24 Boxer-Routen: Navigation, aktive Tabs, keine doppelte Navigation/iframes, kein Seitenüberlauf und keine Skriptfehler bei 390 px. **S+** bedeutet zusätzlich 320/430/768/1366 px für die ersten sechs Routen der Suite. Die Fachaktionen der jeweiligen Seite sind damit nicht automatisch geprüft. Log: [account-browser.log](account-browser.log); Suite: [takeover3-browser.cjs](../../tests/takeover3-browser.cjs).
- **K – Konten/Training:** dieselbe Suite bedient Anmeldung, Konto hinzufügen/wechseln/entfernen, abgelaufene Sitzung, Netzwerkfehler, simulierten Rollenwechsel sowie Trainingsmeldung und alte Studio-Links. Alle Konten und Schreibantworten sind Testdaten.
- **E – Echter SDK-Gast:** [auth-singleton-browser.cjs](../../tests/auth-singleton-browser.cjs), sechs ausgeführte Chromium-/WebKit-Läufe auf exakt drei lokalen Routen mit echtem Supabase-SDK, ohne Sitzung. Nachweis: [auth-after.json](auth-after.json). Geprüft sind eine SDK-Instanz, Gastsession, kein GoTrue-Duplikat und keine erfassten Skriptfehler. Kein echter Login, kein angemeldeter Rechte-/Schreibdurchlauf.
- **D – Duelle:** ausgeführte `duel-close-browser.cjs`, `duel-queue-browser.cjs`, `duel-metrics-browser.cjs` und `release-live-duels-browser.cjs`; echte Browser mit synthetischen Antworten. JSDOM-/Quelltests sind separat benannt. Details: [workflow-status.md](workflow-status.md), [duel-metrics-ui.md](duel-metrics-ui.md), [duel-queue.md](duel-queue.md).
- **P – Perioden:** ausgeführte `period-archive-browser.cjs`, `period-close-browser.cjs`, `period-notices-browser.cjs`, Chromium/WebKit mit synthetischen APIs, relevante Ansichten bei 320/390/1280 px. `period-close-races.cjs` ist ein DOM-Test, kein Browser-/Cloudlauf. Details: [archive-and-closures.md](archive-and-closures.md).
- **I/H – Inbox/Studio-Historie:** `inbox-browser.cjs` (beide Engines, 45 Mitteilungen/35 ungelesen, 20er-Seiten, Fehler/Kontowechsel) und `studio-history-browser.cjs` (beide Engines, 320/360/390/430 px, echte Seitenintegration mit SDK-Attrappe). Siehe [workflow-status.md](workflow-status.md) und [studio-history.md](studio-history.md).
- **G – Grafik:** ausgeführte Podium-, Boxer-Experience-, Editor-, Holo-, Look-/Karten- und Kampfgeist-Suiten laut [graphics-status.md](graphics-status.md). Echte Assets/Compositor und echte Browser, aber simulierte Konten/RPCs. Podium und Editor wurden in beiden Engines bei 320/360/390/430 px und Desktop geprüft. Kein Nachweis einer vollständigen Shop- oder künstlerischen Abnahme aller Kombinationen.
- **T – Staff:** `staff-experience-browser.cjs`, tatsächlich Chromium bei 320/390/1366 px mit simulierten Coach-/Admin-Daten: Bereiche, Navigation, Profilsuche/Paginierung, Menü, Wettbewerbshinweis und Coach-Sperre der Adminseite. Kein entsprechender vollständiger WebKit-Staff-Durchlauf behauptet.

Rollenabkürzungen: **B** Boxer, **C** Coach, **A** Admin, **Gast** ohne Sitzung. Außer **E** sind alle nachfolgend genannten Browserrollen **gemockt**. Nicht genannte Rollen sind auf der jeweiligen Route nicht fachlich nachgewiesen; die Tabelle beschreibt beobachtete Tests, nicht die beabsichtigte Berechtigungsmatrix.

## 33 Routen nach Bereich

**Q gilt für jede Zeile.** Weitere Kürzel bezeichnen nur den oben definierten Umfang.

| Nr. | Bereich | Route | Ausgeführter Browser-/Sondernachweis | Rollenbeleg und verbleibende Grenze |
| --- | --- | --- | --- | --- |
| 1 | Zugang/Information | `login.html` | K | B/C/A und Gast-Einstieg über simulierte Auth; echter angemeldeter SDK-/Cloudlauf offen. |
| 2 | Zugang/Information | `guest.html` | Kein gesonderter ausgeführter Browsernachweis in den herangezogenen Logs | Q; Gast-Fachablauf und andere Rollen nicht abgenommen. |
| 3 | Zugang/Information | `coming-soon.html` | Kein gesonderter ausgeführter Browsernachweis in den herangezogenen Logs | Q; keine Rollen-/Funktionsabnahme. |
| 4 | Zugang/Information | `features.html` | S; `features-live-directory.cjs`; berechneter LIVE-Kontrast in Chromium, [feature-contrast.json](feature-contrast.json) | B-Shell; Kontrast 6,89:1 ist ein gezielter CSS-Nachweis, keine vollständige Funktionsprüfung aller verlinkten Features. |
| 5 | Zugang/Information | `hilfe.html` | S | B-Shell; Inhalte/Links und weitere Rollen nicht vollständig bedient. |
| 6 | Zugang/Information | `news.html` | S | B-Shell; keine vollständige Nachrichten-/Redaktionsprüfung. |
| 7 | Zugang/Information | `roadmap.html` | S | B-Shell; keine darüber hinausgehende Rollen-/Fachabnahme. |
| 8 | Zugang/Information | `feedback.html` | S | B-Shell; Feedbackversand und Staff-Bearbeitung nicht als vollständig geprüft ausgewiesen. |
| 9 | Mein Takeover/Training | `boxer-experience.html` | K, G, I/H; fünf Haupttabs in S bei fünf Breiten | B-Navigation/Training/Holo/FUT/Inbox/Historie; Gast- und Coach-Gate in `boxer-experience-browser.cjs`. Periodenhinweismodul separat über P geprüft, keine vollständige echte Cloud-Integration. |
| 10 | Mein Takeover/Training | `boxer.html` | K, I, G | Boxer-Weiterleitung/alte Deep Links; C-Studio und Inbox tatsächlich bedient. Keine neue Aussage zu vollständiger Admin-/Gast-Funktion auf dieser Altseite. |
| 11 | Mein Takeover/Training | `wochenplan.html` | S+ | B-Shell; Wochenplan-Fachaktionen/Staff-Änderungen nicht vollständig abgenommen. |
| 12 | Mein Takeover/Training | `checkin.html` | S+ | B-Shell; kein physischer Gym-/QR-/Standort- oder Cloud-Check-in-Nachweis. |
| 13 | Mein Takeover/Training | `praesenz.html` | S+ | B-Shell; keine vollständige Anwesenheits-/Staff-Fachprüfung. |
| 14 | Mein Takeover/Training | `goals.html` | S+; Rücklink in neue Boxer-Ansicht | B-Shell; kein vollständiger Ziel-Erstellungs-/Abschlussdurchlauf aller Rollen. |
| 15 | Mein Takeover/Training | `quests.html` | S; H prüft separat vollständige Quest-/Achievement-Aggregate im Studio | B-Shell; die Studio-Aggregatprüfung ist keine vollständige Bedienprüfung dieser Route. |
| 16 | Mein Takeover/Training | `bewertung.html` | S; `looks-everywhere-browser.cjs` | B-Shell/Look-Einbindung; keine neue vollständige Selbstbewertungs-/Belohnungsabnahme. |
| 17 | Liga/Wettkämpfe | `index.html` | S-Gastnavigation, E, G, P-Hinweise | Gast mit echtem SDK; Gast/B/C-Darstellungen mit Testdaten. Öffentliche Podiumsdaten und profilgebundene Hinweise gezielt geprüft; keine echte angemeldete Cloud-Abnahme. |
| 18 | Liga/Wettkämpfe | `duels.html` | S+, E, D; neue SQL→UI-Vertragsbridge | B/C/A/Gast gezielt mit Testdaten; E nur Gast. Fremde/inaktive/archivierte Nutzer zusätzlich in lokalen SQL-Rollentests, nicht als echte Cloud-Konten. |
| 19 | Liga/Wettkämpfe | `arena.html` | S | B-Shell; neue Trainerlinks zeigen die vorhandene Route. Kein vollständig bedienter Arena-Abschluss aller Rollen in diesem Paket. |
| 20 | Liga/Wettkämpfe | `challenges.html` | S; vorhandene RPC-/Quellverträge | B-Shell; keine neue vollständige Challenge-Erstellungs-/Auszahlungsabnahme. |
| 21 | Liga/Wettkämpfe | `league-challenges.html` | S+; vorhandene RPC-/Quellverträge | B-Shell; bestehende Flag-/Rollengrenzen nicht durch eine komplette Cloud-Abnahme ersetzt. |
| 22 | Liga/Wettkämpfe | `league-history.html` | S, P | B-Shell, Gast-/Archivantworten und C-Abschluss mit Testdaten. Eigener Rang und Logout simuliert; A-/Boxer-/Gast-Rechte zusätzlich lokal in SQL, kein echter Cloudabschluss. |
| 23 | Liga/Wettkämpfe | `awards.html` | S, Gastnavigation/Account-Drawer in S | B und Gast als Mock; keine rückwirkende Titel-/Bonusvergabe durchgeführt. |
| 24 | Liga/Wettkämpfe | `boxer-compare.html` | S | B-Shell; keine vollständige Vergleichs-/Datensichtbarkeitsmatrix. |
| 25 | Boxer/Profil/Ausrüstung | `boxer-profile.html` | S (`?name=Ben`), E, G-Looks/Karten | Gast mit echtem SDK; eigenes/fremdes Boxerprofil und Gastansicht mit Grafik-Testdaten. Private Cloud-Profile nicht als angemeldet abgenommen. |
| 26 | Boxer/Profil/Ausrüstung | `mein-boxer.html` | S, G-Editor/Holo/Premium | B-Fixtures; echte PNG-/Compositor-, Fallback-, Anprobe-/Speicher-/Kaufbestätigungsprüfungen. Keine echte Besitz-/Coin-Änderung; Flex-Shirt-Kunstkorrektur bleibt offen. |
| 27 | Boxer/Profil/Ausrüstung | `shop.html` | S inklusive Zurück-Navigation; `kampfgeist5-browser.cjs`; neuer `shop-preview-audit-browser.cjs` in beiden Engines | B mit Testdaten; sechs SVG-Kategorien mit Kachel-/Detail-/angewandter-Look-Parität und Katalogpreisen, Transportfehler, bestätigte Belege bei Offline-Nachlese, schnelle Auswahl und mobile Details/200-%-Zoom. [Shop-Audit](shop-audit.md); echte Cloud-Käufe und vollständige Kunstabnahme bleiben offen. |
| 28 | Boxer/Profil/Ausrüstung | `karten.html` | S | B-Shell; Grafiktests anderer Routen beweisen keine vollständige Bedien-/Kaufprüfung dieser Kartenseite. |
| 29 | Boxer/Profil/Ausrüstung | `stil-test.html` | S | B-Shell; kein vollständig bewerteter Stiltest aller Pfade/Rollen ausgewiesen. |
| 30 | Boxer/Profil/Ausrüstung | `kampfpfad.html` | S; `kampfgeist5-browser.cjs` | B-Testdaten, unter anderem aktiver/deaktivierter Pfad; kein echter Cloud-Fortschritts-/Belohnungsdurchlauf. |
| 31 | Trainer/Verwaltung | `coach.html` | K, T; `coach-competition-status.cjs` als DOM-Test | C-Seite tatsächlich in Chromium bedient, Kontorouting zusätzlich in beiden Engines; aktive C/A/Boxer-/Gast-Statusfälle des neuen Widgets sind DOM-/API-Fixtures, keine vollständige Rollenabnahme der ganzen Seite. |
| 32 | Trainer/Verwaltung | `admin.html` | K, T | A mit simulierten Profilen/Suche/Paging; C-Zugriffssperre geprüft. Keine echten Profil-/Rollenänderungen, keine vollständige Cloud-Admin-Abnahme. |
| 33 | Trainer/Verwaltung | `league-manager.html` | S/K-Coach-Navigation; Quellvertrag des neuen Archivlinks | C-Navigation, gezielter Abschlusslink im Quelltext; Admin-Aktivierung/Regeländerung nicht als vollständiger Browserdurchlauf nachgewiesen. Enger Abschluss wird auf `league-history.html` separat geprüft. |

## Aussagegrenzen für die Freigabe

1. **Echter Browser ist nicht echte Backend-Integration.** Die umfangreichen Chromium-/WebKit-Läufe verwenden synthetische SDK-/RPC-Antworten. Sie belegen Bedienung, Darstellung, Parameter, Fehler- und Kontowechselverhalten, nicht reale Supabase-Login-/PostgREST-/RLS-Integration.
2. **Lokales SQL ist ein eigener starker, aber anderer Nachweis.** Echte PostgreSQL-17.11-Rollen, Sperren, Transaktionen, Duell-/Perioden-/Studio-Grenzen und Rollback wurden getestet. `duel-metrics-api-contracts.cjs` verbindet echte SQL-Antworten mit den UI-Validatoren. Das ist kein Browserlogin im gemeinsamen Supabase-Testprojekt. Siehe [backend-status.md](backend-status.md), [archive-and-closures.md](archive-and-closures.md), [studio-history.md](studio-history.md).
3. **Produktion blieb lesend.** HTTP-Erreichbarkeit der 33 Einstiege und der frühere Releasebezug stammen aus der Auditgrundlage; sie beweisen weder einen neuen Release noch eine vollständige angemeldete Funktionsprüfung. Die nachgewiesenen echten SDK-Gastläufe betreffen nur die drei mit E markierten Routen. Kein angemeldeter Cloud-End-to-End-Durchlauf aller Rollen wurde ausgeführt, weder in Produktion noch im gemeinsamen Testprojekt.
4. **Keine physischen Geräte.** Viewport-, Touch- und WebKit-Tests ersetzen kein echtes iPhone/Safari oder Android/Chrome. Eine physische Geräteabnahme ist für keine der 33 Routen behauptet.
5. **CI ist commitbezogen.** Die jeweiligen Suite-/Handoff-Nachweise sind hier verlinkt. Aktuelle Remote-Checks und freigegebener Commit werden im zentralen [STATUS.md](STATUS.md) geführt; diese Matrix macht daraus keine ungeprüfte Gesamtfreigabe.

Offen bleiben insbesondere echte angemeldete Cloud-Rollenpfade, physische Geräte, Fachaktionen der nur mit S/Q belegten Routen, die vollständige Shop-/Outfit-Kunstabnahme und der dokumentierte Flex-Shirt-Übergang. Dafür wird keine Prozentzahl erfunden.

## Ergänzung aus der entfernten Staging-CI

Am Integrationscommit `15c317f21fc712d8fceb08b17ac757ab4c287687` lief der Chromium-Smoke-Job zusätzlich erfolgreich durch die nachfolgenden Fachsuiten, bevor er die gesondert korrigierte Duell-Moderationsintegration in `kampfgeist5-browser.cjs` erreichte. Diese Ergebnisse erweitern die konservative obige Shell-Matrix; sie bleiben synthetische API-/Kontenprüfungen. Log: [Staging-CI](https://github.com/benditocapela-ux/takeover-league/actions/runs/41465697799/job/125345866841). Am finalen PR-Head müssen die Checks erneut bestehen.

| Bereich / Routen | Tatsächlich bestandene zusätzliche Fachprüfung |
| --- | --- |
| `news.html`, `feedback.html` | Nachrichten/Ungelesenstatus, eigener Screenshot-Uploadpfad, eigene Antworten, Admin-Eingang, Gast-Sperre (`news-feedback-browser`) |
| `hilfe.html` | Tour, Rollen-/Flagfilter, Suche, Admin-FAQ, Gastlesen (`help-tutorial-browser`) |
| `bewertung.html`, `boxer-compare.html`, `stil-test.html` | Bewertung, Coach-Regler, Vergleich/Stil-Overlay, Monatssperre, Freigabe und Profilkarte (`performance-browser`, `self-rating-browser`) |
| `karten.html`, `awards.html`, `boxer-profile.html` | Karten wählen/kaufen/gesperrt, persönliche und zeitlich begrenzte Designs, begründete Rücknahme, Vergleichs-/Profilverknüpfungen (`card-designs-browser`, `card-designs-personal-browser`, `award-designs-limited-browser`, `award-skip-revoke-browser`, `card-arena-browser`) |
| `checkin.html`, `praesenz.html`, `wochenplan.html` | Gym-Check-in für Coach/Boxer, Präsenz für Boxer/Coach, Wochenplan für Boxer/Coach/Admin (`gym-browser`) |
| `quests.html` | Boxer-Abholung/Truhe, deaktivierter Zustand, Coach-Übersicht und Admin-Vorschau ohne Abholung (`quests-browser`) |
| `shop.html`, `roadmap.html` | 93 bestehende Kampfgeist-Items, Kauf/Ausrüsten, Rang-/Coin-Sperren, Inventar/Verlauf, deaktivierter Zustand und Admin-Vorschau (`kampfgeist-browser`) |
| `admin.html`, `coach.html` | Admin-Rename-Test, Bonus-EXP-Vorschau und begründete Rücknahme, Selbsteinschätzungsprüfung (`admin-registration-browser`, `admin-bonus-exp-browser`, `self-rating-browser`) |

Weder Käufe, Profiländerungen noch Abholungen dieses Jobs wurden an reale Konten oder eine reale Datenbank gesendet. Der Lauf ist kein Ersatz für die weiterhin offene Cloud- und Geräteabnahme.
