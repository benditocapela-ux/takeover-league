# Takeover League 2.1 – verifizierter Release- und Produktionsstand

**Stand:** 19.10.2026 · **Verbindliche Ist-Zustandsübersicht** · Repository: [benditocapela-ux/takeover-league](https://github.com/benditocapela-ux/takeover-league) · Produktivprojekt: `iqarjivcrddcixrvqbfb` · Testprojekt: `cfgdvcccsqwfjajuizsr`.

> **2.1 IST VERÖFFENTLICHT UND PRODUKTIV INSTALLIERT. Die zuvor verlangten Sicherheits- und Abnahme-Gates sind damit NICHT automatisch erledigt.**
> Dokumente mit «NO GO LIVE», «HOLD» oder «PR #11 Draft» sind historische Bewertungen **vor** dem real erfolgten 2.1-Release. Diese Dokumente werden nicht gelöscht, dürfen aber nicht mehr als aktueller Deploy-Status verwendet werden.

## 1. Tatsächlicher Release – belegt

| Ebene | Verifizierter Zustand am 19.10.2026 | Nachweis |
| --- | --- | --- |
| GitHub | Takeover League **2.1-Code liegt auf `main`**; Release-Folge `4aae67e` → `4430bc4` → `0cd262e`. Danach zusätzlich Frontend-Design-Merge `023d8ca` auf `main`. | [Release `4aae67e`](https://github.com/benditocapela-ux/takeover-league/commit/4aae67ef9daa6b459cfda6c4ceb1b7e1a4467af7), [Smoke `4430bc4`](https://github.com/benditocapela-ux/takeover-league/commit/4430bc4a9507ca325d3d20e452c82d9d17d089e7), [Pages-Paket `0cd262e`](https://github.com/benditocapela-ux/takeover-league/commit/0cd262e3ca16ed0ec8fd7304d865cdbdf33a59cb), [`main` `023d8ca`](https://github.com/benditocapela-ux/takeover-league/commit/023d8ca4eace4579f371d962b028d1a08e919ec3) |
| Supabase Produktion | Alle **25 V2.1-Migrationen** wurden als atomisches Paket produktiv angewendet. Eintrag in `supabase_migrations.schema_migrations`: **Version `20261018231319`**, Name `takeover_league_21_atomic_25_migrations_20261019`. | Read-only-Abfrage von `supabase_migrations.schema_migrations` am 19.10.2026; Commit `4aae67e` dokumentiert die produktive Ausführung |
| Hosting | Die fünf V2.1-Dateiseiten sind publiziert: [arena.html](https://benditocapela-ux.github.io/takeover-league/arena.html), [goals.html](https://benditocapela-ux.github.io/takeover-league/goals.html), [league-manager.html](https://benditocapela-ux.github.io/takeover-league/league-manager.html), [league-challenges.html](https://benditocapela-ux.github.io/takeover-league/league-challenges.html), [league-history.html](https://benditocapela-ux.github.io/takeover-league/league-history.html). **HTTP 200** war im Release-Nachweis bestätigt; diese Dokumentenkorrektur ist kein neuer authentifizierter Browser-Test. | [Pages-Workflow `39175855700` – success](https://github.com/benditocapela-ux/takeover-league/actions/runs/39175855700), Route-Smoke-Commit `4430bc4`, Deploy-Commit `0cd262e` |
| Dokumentation | Letzter vorliegender Docs-Commit `965d606` (vor `4aae67e`). Bis zum geprüften `main`-Stand wurde `docs/` nicht nachgezogen. | [Docs-Commit `965d606`](https://github.com/benditocapela-ux/takeover-league/commit/965d606aec4d13ea3f71667a47dfa8e704d369c1); GitHub-Docs-Commitverlauf, 19.10.2026 |

**Wichtig:** «Datei über HTTPS erreichbar» bedeutet **nicht**, dass die dazugehörige Datenbankfunktion aktiviert, der Benutzer berechtigt oder das Feature praktisch abgenommen ist. Der alte Text «kein Merge / keine produktive Migration / nur Draft #11» ist seit dem tatsächlichen Release falsch.

## 2. Produktivdatenbestand – READ ONLY

Read-only-Auszählung auf Projekt `iqarjivcrddcixrvqbfb` am 19.10.2026:

| Merkmal | Bestand |
| --- | ---: |
| Profile insgesamt | **14** |
| Admin | **1** |
| Boxer | **13** |
| Coach | **0** |
| Trainingsmeldungen | **67** |
| Davon bestätigt (`approved`) | **61** |
| Punktebuchungen (`point_transactions`) | **72** |
| Verliehene Abzeichen (`boxer_achievements`) | **0** |
| `league_*_v21`-Tabellen | **17 Tabellen, jeweils 0 Datensätze** |

Es handelt sich um **Ist-Bestände**, nicht um ein Backup. Die V2.1-Installation hat nach dem dokumentierten Release keine künstlichen Punkte oder EXP erzeugt. Es werden hier keine Trainings, Punkte oder Profile geändert.

## 3. V2.1-Feature-Flags – nach wie vor deaktiviert

Folgende Werte sind im produktiven `league_feature_flags` jeweils **`false`** (READ ONLY geprüft):

- `seasons`
- `league_challenges`
- `hall_of_fame`
- `palmares`
- `public_boxer_profiles`
- `boxer_duels`
- `coach_goals`

Die entsprechenden **statischen HTML-Seiten** können vom GitHub-Pages-Host trotzdem ausgeliefert werden (Datei erreichbar). Geschützte Operationen und Datenzugriffe unterliegen den bestehenden serverseitigen **RLS-/RPC-Rollen- und Feature-Flag-Prüfungen**; einzelne Webseiten-Buttons oder unsichtbare UI-Bereiche sind keine Berechtigungsinstanz. Eine tatsächlich deaktivierte Funktion wird durch den HTTP-Status 200 der HTML-Datei nicht aktiviert. **Diese Dokumentation schaltet keine Flags ein.**

## 4. Rollenmodell und Registrierung – Ist-Stand vs. Entwurf

- **`admin`**: genau ein Eigentümer; verwaltet Konten, Rollen, Aktivität und künftige öffentliche Profilfreigaben. `public.is_league_admin()` bleibt die eigentliche Admin-Identitätsgrenze.
- **`coach`**: ein Boxer **mit** Trainerrechten (eigenes Training plus autorisierte Freigabe, Korrektur und Liga-Arbeit). Am 19.10.2026 sind **null produktive Coach-Profile** vorhanden. Die vollständige Ermächtigung der betroffenen Trainer-RPCs ist **als Entwicklungsänderung in [Draft-PR #13](https://github.com/benditocapela-ux/takeover-league/pull/13)** vorbereitet, **nicht** auf `main`/Produktion angewendet.
- **`boxer`**: reicht eigene Trainings ein; genehmigt sich selbst keine Punkte und verwaltet keine Rollen.
- **Registrierung**: `login.html` enthält schon ein frei zugängliches Registrierungsformular. **In Produktion gibt es am Stichtag keinen `auth.users`-Trigger, der automatisch Profile erzeugt.** Die Eigentümerentscheidung lautet: Registrierung auf `login.html` → automatisches aktives, zunächst **nicht öffentlich gelistetes** Boxerprofil (oder Verknüpfung zum vorbereiteten Bestandsprofil per E-Mail) → ausschliesslich der Admin vergibt `boxer`/`coach`, aktiviert/deaktiviert und schaltet öffentliche Sichtbarkeit frei. Diese neue Logik und `admin.html` liegen **nur in [Draft-PR #14](https://github.com/benditocapela-ux/takeover-league/pull/14)** bzw. im Testprojekt, **noch nicht in Produktion**. Keine voreilige Behauptung einer bereits funktionierenden produktiven Auto-Registrierung.

Neue PRs #13/#14 sind **separate, zukünftige Releases** und erben keine frühere pauschale Go-Live-Freigabe. Diese Dokumentenkorrektur installiert sie nicht.

## 5. Formell offene Release-Gates – **NICHT ERLEDIGT**

| Gate | Formale Bewertung am 19.10.2026 | Warum offen |
| --- | --- | --- |
| Echtes Produktions-Backup **mit verifizierter Wiederherstellung** | **NICHT ERLEDIGT** | Wegwerf-PostgreSQL-/CI-Backup-Restore ist **kein** Restore der wirklichen produktiven DB mit Auth-/Storage-Abhängigkeiten. |
| Vollständige echte **Boxer-/Admin-/Coach-Login-Abnahme** | **NICHT ERLEDIGT** | Statische Checks, SQL-Session-Rollensimulation, CI-Chromium-Mocks oder HTTP-200-Seiten sind keine authentifizierten E2E-Login-Tests mit realen Konten. Insbesondere gab es zum Stichtag kein produktives Coach-Profil. |
| Vollständiger **SECURITY-DEFINER-/RLS-/RPC-Sicherheitsaudit** | **NICHT ERLEDIGT** | Bisherige Stichproben und Search-Path-/Grant-Prüfungen ersetzen keinen vollständigen Endpoint-, Rechte- und Datenfluss-Audit. |

**Nicht nachträglich auf «bestanden» setzen!** Die drei Gates waren bereits vor dem 2.1-Release als verbindlich/offen beschrieben, etwa in [TAKEOVER_LEAGUE_21_FINAL_RELEASE_GATES.md](TAKEOVER_LEAGUE_21_FINAL_RELEASE_GATES.md) und [TAKEOVER_LEAGUE_21_SECURITY_AUTH_GATES.md](TAKEOVER_LEAGUE_21_SECURITY_AUTH_GATES.md). Dass ein früherer Release trotzdem stattfand, beweist keine Erfüllung.

## 6. Was daraus folgt – Entscheidung des Eigentümers notwendig

Der Eigentümer muss für **jedes** der drei offenen Gates ausdrücklich dokumentieren, ob:

1. **Nachholen:** Den ausstehenden Backup-/Restore-, Real-Login- beziehungsweise Security-Definer-Audit kontrolliert durchführen und seine Ergebnisse datieren; oder
2. **Bewusstes Risiko / Waiver:** Die Nichtdurchführung als ausdrücklich akzeptiertes Restrisiko festhalten, inklusive Umfang, möglicher Auswirkungen, Datum, verantwortlicher Person und allfälliger späterer Nachprüfung.

Das Projekt kennt bereits einen expliziten Risiko-Verzicht beim **2.0-Release**, siehe [RELEASE_ABGESCHLOSSEN_2026-10-18.md](RELEASE_ABGESCHLOSSEN_2026-10-18.md). Dort wurde der Verzicht auf echtes Vorab-Backup und signierte Login-E2E-Tests dokumentiert; das waren **keine bestandenen Tests**. **Ein früherer Waiver ersetzt weder die eigenständige 2.1-Gateentscheidung noch eine neue Freigabe für zukünftige Schema-/Frontendänderungen.**

**Aktuelle operative Regel:** Bestehendes 2.1 ist tatsächlich live; keine erneute «Go-Live-Sperre» für bereits geschehene Vorgänge behaupten. Für noch ausstehende Arbeiten, insbesondere Draft-PR #13 und #14, gilt unverändert: **kein Merge, keine produktive SQL-Migration, kein Pages-Deploy und kein Feature-Flag-Wechsel ohne neues ausdrückliches `FREIGEBEN`**.

## 7. Dokumentenchronik

Die historischen Freigabeprüfungen bleiben unverändert in ihrer ursprünglichen Reihenfolge erhalten. Oben in betroffenen Dokumenten verweist ein Warnhinweis auf **diese** aktuelle Sachstandszusammenfassung. Das ist eine rein dokumentarische Korrektur; weder Code noch SQL, Workflows oder produktive Daten wurden dabei geändert.
