# Takeover League – zusätzlicher Redesign-Testbericht (19.10.2026)

**Prüfobjekt:** lokale, nicht committete Arbeitskopie auf `main` aus dem Nutzer-ZIP. **Keine Produktivänderung, kein GitHub-Push/Commit, kein Supabase-Zugriff.** Risiko echter Login-End-to-End-Abnahme wird vom Eigentümer bewusst akzeptiert – der Test gilt dadurch **nicht als bestanden**.

## Erneut tatsächlich ausgeführte Tests

| Umfang | Ergebnis | Ausführung und Abgrenzung |
|---|---|---|
| Zehn unabhängige Node-Test-Suites | **10/10 PASS** | `admin-registration-static`, `coach-challenges-v2`, `design-foundation-check`, `production-v2-manual-release-guide`, `production-v2-migration-bundle`, `production-v2-release-safety`, `redesign-accessibility`, `redesign-all-pages`, `redesign-contracts`, `release-static-contracts` |
| V2.1-Migrationsdatei-Vertrag | **PASS** | `node tests/build-league-21-release.cjs --check`: 25 Migrationen nachgewiesen, **keine Ausführung** |
| Statische Release-Verträge | **24/24 PASS** | Bestandteil von `release-static-contracts.cjs`, kein echter Auth-/Transaktionstest |
| Chromium-Layout/Interaktion | **72/72 PASS** | `python tests/redesign-browser-offline.py`, 18 Seiten × 320/390/768/1440 px; inklusive Gast-Tastatur-Tabs, Menü öffnen/Escape/schliessen/erneut öffnen, simuliertem Registrierungs-Fehler und aufgeklappten mobilen Containern |
| Chromium-Gastfunktionen mit API-Mocks | **3/3 PASS** | `python tests/redesign-guest-public-browser.py`: vier simulierte Ranking-Datensätze, Empty State, HTTP-500-Fallback; ausschliesslich öffentliche RPCs/Tabellen, keine private E-Mail in Ausgabe, XSS-Namen sicher gerendert; API-Antworten lokal ersetzt, keinerlei Anfrage an echte Supabase-Server |
| Root- und HTML-Inline-JavaScript | **32/32 PASS** | `node --check` durch `verify-redesign.py` |
| Syntax des neuen Python-Browsertests | **PASS** | `python -m py_compile` |
| Diff/Quellschutz | **PASS** | `git diff --check`; zwei Design-Referenzen und Deployment-Workflow bytegleich zum Ursprungs-ZIP; **0 geänderte SQL-Dateien**; Git-Branch weiterhin `main` |

Alle Tests wurden am 19.10.2026 in der bereitgestellten Arbeitskopie ausgeführt. Die Mock-Namen und -Zahlen sind **nur im Testskript**, nicht im produktiven Anwendungs-HTML oder der Datenbank.

## Nicht ausgeführt / nicht bestanden behauptet

Die npm-Registry `registry.npmjs.org` war für eine isolierte Installation von `jsdom@26.1.0` über DNS nicht erreichbar: **`getaddrinfo EAI_AGAIN`**. Daher konnten die **fünf im ursprünglichen Redesign-Abnahmeauftrag genannten** jsdom-Suites nicht gestartet werden:

- `boxer-dashboard-polish.cjs`
- `boxer-profile-actions.cjs`
- `menu-navigation-compat.cjs`
- `guest-showcase.cjs`
- `release-ux-staging.cjs`

Weitere nicht ausgeführte jsdom-Suites: `coach-challenges-v2-browser.cjs`, `duels-v2-browser.cjs`, `features-live-directory.cjs`, `league-21-foundations.cjs`, `ux-roadmap-phase0.cjs`. Node-Playwright-Suites sind aus demselben Grund (Node-Paket nicht verfügbar) **nicht** ausführbar. Die vorhandene **Python-Playwright-Chromium-Prüfung** ist eine ergänzende echte Browserprüfung, aber **kein Ersatz für die nicht gestarteten Original-Suites**.

**Mit dem ausdrücklich akzeptierten Restrisiko:** Echte Boxer-, Coach- und Admin-Logins, Neuregistrierung mit Supabase Auth, signierte Rollen-/RPC-Aufrufe und produktive Trainings-/Punktevergabe bleiben **nicht getestet**. Die vorherigen sicherheitsbezogenen Release-Gates (insbesondere produktiver Backup-Restore und vollständiger Security-Definer-Audit) werden dadurch **nicht geschlossen**.

## Reproduktion, sobald Test-Pakete erreichbar sind

Die Test-Abhängigkeiten dürfen nur **ausserhalb des Repositorys** installiert werden (kein `package.json`, kein `node_modules` ins ZIP oder Git):

```bash
mkdir -p /tmp/takeover-test-deps
cd /tmp/takeover-test-deps
npm install --no-save --package-lock=false jsdom@26.1.0
cd /pfad/zum/takeover-league/app
NODE_PATH=/tmp/takeover-test-deps/node_modules node tests/boxer-dashboard-polish.cjs
NODE_PATH=/tmp/takeover-test-deps/node_modules node tests/boxer-profile-actions.cjs
NODE_PATH=/tmp/takeover-test-deps/node_modules node tests/menu-navigation-compat.cjs
NODE_PATH=/tmp/takeover-test-deps/node_modules node tests/guest-showcase.cjs
NODE_PATH=/tmp/takeover-test-deps/node_modules node tests/release-ux-staging.cjs
```

**Freigabegrenze:** Keine Dateien committet, nichts gepusht oder auf Pages deployed; keine produktive SQL ausgeführt und keine Feature-Flags verändert.
