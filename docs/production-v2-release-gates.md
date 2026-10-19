> ⚠️ **ÜBERHOLT – historischer Entwicklungs- oder Release-Zwischenstand.** Frühere Aussagen wie «nicht veröffentlicht», «HOLD», «NICHT AUSGEFÜHRT» und «kein Live-Release» dürfen nicht mehr als aktueller Produktionsstatus gelesen werden.
> **Tatsächlich:** Takeover League 2.1 ist auf `main` (`4aae67e` → `4430bc4` → `0cd262e`) und mit der atomaren Migration `20261018231319` in Produktion. Echte Backup-/Restore-, Real-Login- und vollständige Security-Definer-Gates sind dadurch **NICHT** bestanden.
> **Verbindlicher aktueller Überblick:** [RELEASE_STATUS_2_1_2026-10-19.md](RELEASE_STATUS_2_1_2026-10-19.md). Der übrige Text bleibt unverändert als historische Momentaufnahme erhalten.

# Produktionsfreigabe – sicherheitsrelevante Voraussetzungen

Stand: 18.10.2026. **Noch keine Freigabe.** `challenges.html` ist standardmässig deaktiviert.

## Aktueller Release-Stand – nach den Integrationstests am 18.10.2026

**Beide V2-Module sind im Entwicklungsbranch vorbereitet, nicht veröffentlicht.** Die frühere Stichproben-/Migrationsprüfung in den folgenden Abschnitten ist als Prüfchronik zu lesen; seitdem wurden die produktionsorientierten Versionen erstellt und umfangreich getestet.

- Versionierte, atomare Release-SQL-Dateien: `supabase/migrations/20261018131000_coach_challenges_v2.sql` (4 Tabellen, 17 RPCs) und danach `supabase/migrations/20261018133000_duels_v2.sql` (3 Tabellen, 6 RPCs). Beide kollisionsgeschützt; Datenbank-Flags bleiben deaktiviert.
- GitHub CI prüft produktionsorientierte Migrationen auf temporärem PostgreSQL 16, Rollen-/Zugriffsrechte, Challenge- und Duell-Abläufe, Rücknahmen, Wiederholungsversuche und EXP-Korrekturen. Zusätzlich erfolgreich: echte parallele DB-Verbindungen für Challenge-Abrechnung, Boxer-Anmeldung, Duell-Einladung **und gleichzeitige Duell-Abrechnung**.
- Mock-Browser-Tests decken Frontend-Rollen, Anzeigen, XSS, deaktivierte Produktionsschalter und das sichere Ausblenden privater Daten bei verzögerten Serverantworten oder Sitzungsabmeldung in einem anderen Tab ab.
- Letzte lesende Produktions-Bestandsaufnahme: 14 Profile, 61 Trainingsmeldungen, 66 Punktetransaktionen, Summe 2230 Punkte und 2230 EXP. Diese Werte sind nur eine Momentaufnahme, **kein eingefrorener Release-Stand**.
- Die beiden gehosteten Testprojekt-Feature-Flags sind derzeit ebenfalls deaktiviert. Die bereits vorhandenen testseitigen Coach-Challenge-RPCs haben teils **andere Rückgabetypen** (TABLE/TEXT/UUID) als die neu vorbereiteten produktionsorientierten JSONB-RPCs. Damit ersetzen Testprojekt-Vorschauen und gemockte Browser-Tests **nicht** den finalen echten Hosted-Supabase/PostgREST-Vertragstest.
- Offene Freigabegates: gehostete Login-/Rollen-Tests mit getrennten temporären Accounts, letzte Trigger-/EXP-Sicherheitsprüfung (insbesondere direkter Aufruf von `recalculate_boxer_achievements_v2`), Backup und aktueller Datenabgleich sowie kontrollierte Veröffentlichung und Freischaltung. **Keine produktive SQL-Migration, kein Merge und keine Freigabe erfolgt.**

## Verifizierter Zustand
- Produktion: `iqarjivcrddcixrvqbfb`, 22 RLS-geschützte Tabellen, keine registrierten V2-Migrationen.
- Test: `cfgdvcccsqwfjajuizsr`, 25 V2-Migrationen, separate Tabellen für Duelle und Coach Challenges.
- Produktions-Sicherheitsadvisor: acht anonym aufrufbare SECURITY-DEFINER-Funktionen. Nicht jede ist zwingend ein Fehler; öffentliche Leaderboards können absichtlich öffentlich sein.
- **Konkreter kritischer Befund:** `public.recalculate_boxer_achievements_v2(p_boxer_id uuid)` ist für `anon` und `authenticated` ausführbar. Die Funktion enthält keine eigene `auth.uid()`-Prüfung und kann Achievement-EXP sowie `point_transactions` für einen frei übergebenen Boxer verändern. Sie ist daher **nicht** für direkten anonymen RPC-Zugriff geeignet.
- `public.update_my_boxer_avatar` ist ebenfalls anonym ausführbar, prüft intern aber `auth.uid()` und das eigene aktive Boxerprofil. Risiken sind individuell zu beurteilen.

## Release-Blocker
1. Öffentliche Ausführbarkeit der Achievement-Reconciliation entfernen, ohne bestehende Trigger- oder Service-Aufrufe zu beschädigen; abhängige Aufrufer zuerst inventarisieren.
2. Test-V2-Migrationen mit realem Produktionsschema vergleichen. **Nicht** `test_only_missing_base_tables` auf Produktion übertragen.
3. V2-Funktionen auf Rollenprüfung, Besitzprüfung, sichere `search_path` und idempotente EXP-Buchungen überprüfen.
4. Vollständige produktive Migration versioniert vorbereiten, Datenbank-Backup/Restore-Weg bestätigen und auf isolierter Kopie prüfen.
5. Nach erfolgreichen Prüfungen `TAKEOVER_CHALLENGES_V2_ENABLED` gezielt aktivieren, Release deployen und unmittelbar Basis-Smoketests durchführen.

**Keine automatische Änderung an produktiven Boxer-Punkten oder Berechtigungen in diesem Branch.**

## CI-Schutz für den Rollout
- Die Produktionsseite bleibt per `TAKEOVER_CHALLENGES_V2_ENABLED=false` deaktiviert.
- Ein Mock-Browsertest prüft, dass beim deaktivierten Rollout **kein** Supabase-Client initialisiert wird.
- Die produktiven Dashboards verlinken auf die deaktivierte Produktionsseite, nicht auf die Testdatenbank.
- Der isolierte Preview-Browsertest und die statischen Prüfungen laufen in GitHub Actions.

## Beobachtung zur Funktionsberechtigung
- Eine read-only Prüfung bestätigte, dass `recalculate_boxer_achievements_v2(uuid)` für `anon` und `authenticated` ausführbar ist.
- Der Funktionskörper enthält keine eigene Prüfung des aufrufenden Benutzers. Der Funktionscode verändert Achievement- und Transaktionsdaten. **Freigabeblocker.**
- Die einfache Katalogprüfung über `pg_depend` ergab keine direkten Funktionsabhängigkeiten. Das schliesst dynamische Aufrufe nicht aus.

## Abhängigkeit geprüft (18.10.2026)

Die produktive Trigger-Funktion `public._award_achievements_on_approval()` ruft `public.recalculate_boxer_achievements_v2(uuid)` für neue und gegebenenfalls alte Boxer-IDs auf. Beide Funktionen gehören `postgres` und sind `SECURITY DEFINER`. Die Achievement-Funktion hat aktuell explizite `EXECUTE`-Rechte für `PUBLIC`, `anon`, `authenticated`, `service_role` und `postgres`. Die Trigger-Funktion hat nur `postgres` und `service_role` in der expliziten ACL. Das spricht dafür, dass eine gezielte Sperre der direkten Aufrufe für `PUBLIC`, `anon` und `authenticated` den internen Aufruf erhalten sollte; vor Umsetzung trotzdem prüfen.

**Geplante Änderung, nicht ausgeführt:** `REVOKE EXECUTE ON FUNCTION public.recalculate_boxer_achievements_v2(uuid) FROM PUBLIC, anon, authenticated;` Die Rechte für `postgres` und `service_role` bleiben unverändert. Danach Berechtigungen und einen legitimen Trainingsfreigabe-Workflow verifizieren. Die öffentliche Leaderboard-RPCs nicht pauschal sperren.

## Coach-Challenge-RPC-Stichprobe

Aus dem Testprojekt wurden die SQL-Definitionen von `coach_challenge_v2_create_draft`, `join`, `review_manual`, `settle_manual` und `list` geprüft. Diese Funktionen nutzen `SECURITY DEFINER` mit leerem `search_path`, prüfen aktive Profile über `auth.uid()`, verlangen das Feature-Flag und beschränken Aktionen nach Rolle bzw. Challenge-Eigentümer. `settle_manual` sperrt den Challenge-Datensatz für die Transaktion, verlangt vollständige Reviews und verhindert doppelte Erstbuchungen. Eine Stichprobe ersetzt keine vollständige Prüfung aller 17 Funktionen.

**Behobene UI/Backend-Abweichung:** Das Backend akzeptiert Challenge-Arten `individual`, `competition`, `coach_goal` und Laufzeiten **7, 14, 30** Tage. Beide Oberflächen und ein Regressionstest wurden entsprechend angepasst.

## Vollständiger statischer RPC-Berechtigungsscan (17/17)

Am 18.10.2026 wurden alle 17 `coach_challenge_v2_*`-Funktionen direkt im Testprojekt abgefragt. **Jede** ist `SECURITY DEFINER`, verweigert `anon` das `EXECUTE`-Recht und enthält im SQL-Funktionskörper eine `auth.uid()`-Prüfung, eine `is_active`-Prüfung und eine Abfrage des `league_feature_flags`-Gates. Das ist eine **statische Vollständigkeitsprüfung**, keine Laufzeitprüfung mit verschiedenen JWT-Rollen; Rollen-, Eigentümer- und Race-Condition-Tests bleiben vor Produktion notwendig.

Der GitHub-CI-Lauf für Commit `1c2635c` ist erfolgreich abgeschlossen (statische und Mock-Browser-Tests).

## Datenbankschema Coach Challenges (Testprojekt)

Vier V2-Tabellen vollständig nach Spalten und Constraints inventarisiert: `league_coach_challenges`, `league_coach_challenge_entries`, `league_coach_challenge_reviews`, `league_coach_challenge_exp_ledger`. Die Challenge-Tabelle begrenzt Typen auf `individual/competition/coach_goal`, Dauer auf `7/14/30`, Status auf `draft/open/active/awaiting_reviews/settled/cancelled` und Titel auf 3–120 Zeichen. Einträge und Reviews haben eindeutige Paare aus Challenge und Boxer; das EXP-Ledger hat zusätzlich einen eindeutigen Transaktionsbezug und erlaubt nur 0/25/50/100/150/200 EXP. Alle vier Tabellen haben referenzielle Fremdschlüssel zu `profiles` und/oder Challenges; Ledger-Transaktionen referenzieren `point_transactions`.

**Migrationsvorbereitung:** Vor Übernahme ins Produktivprojekt auch Indizes, Policies, Grants, Trigger und Funktionsdefinitionen versioniert exportieren; die 25 Testmigrationen dürfen wegen der test-spezifischen Basistabellen-Migration nicht blind übernommen werden. Produktionsseitige Alt-Tabellen `league_challenges` und `boxer_duels` sind eigenständig und müssen erhalten bleiben.

## RLS-Bestätigung für Coach-Challenge-Tabellen

Eine direkte Abfrage von `pg_class` und `pg_policies` im Testprojekt bestätigte am 18.10.2026: Für `league_coach_challenges`, `league_coach_challenge_entries`, `league_coach_challenge_reviews` und `league_coach_challenge_exp_ledger` ist RLS eingeschaltet (`relrowsecurity=true`), `FORCE ROW LEVEL SECURITY` ist aus und es gibt **keine** Tabellen-Policies. Normale Rollen erhalten damit keine direkten Zeilen-Zugriffe über RLS; die autorisierten `SECURITY DEFINER`-RPCs sind die beabsichtigte Schnittstelle. Vor Produktivfreigabe trotzdem tatsächliche Tabellen-Grants und direkte API-Abfragen mit echten Rollen testen.

## SQL-Grants bestätigt (18.10.2026)

Die expliziten Tabellen-Grants der vier V2-Coach-Challenge-Tabellen enthalten **ausschliesslich** `postgres` und `service_role`; `anon` und `authenticated` haben dort keine direkten Grants. Die 17 V2-RPCs gewähren `EXECUTE` ausschliesslich an `postgres`, `authenticated` und `service_role`. Die tatsächlichen ACLs bestätigen das beabsichtigte Muster: authentifizierte Nutzer arbeiten über geprüfte RPCs, nicht per direkten Tabellenoperationen. Die RPCs müssen auch in Produktion ihre `auth.uid()`-/Rollenprüfungen behalten.

Der GitHub-Actions-Lauf zu Commit `ff49e8a` ist erfolgreich.

## Kritischer Produktionsschema-Unterschied: Transaktionskategorien

Das Produktivprojekt akzeptiert bei `point_transactions.category` derzeit ausschliesslich `training`, `trainer_bonus`, `adjustment`, `legacy_import`, `automatic_bonus`, `achievement_exp`. Das Testprojekt erlaubt zusätzlich `duel_exp` und `challenge_exp`. Ohne Erweiterung scheitern V2-EXP-Auszahlungen in Produktion. Eine **noch nicht ausgeführte**, transaktionale und mit Vorprüfungen abgesicherte Migrationsdatei liegt unter `supabase/production-prep/20261018_extend_transaction_categories.sql`. Vor Ausführung bestehende Constraints, Trigger und Funktionsabhängigkeiten prüfen. **Nicht mit Testmigration `test_only_missing_base_tables` verwechseln.**

## Feature-Flag-Differenz zwischen Test und Produktion

Im Testprojekt existieren die V2-Schlüssel `coach_challenges` und `duels`, beide deaktiviert. In Produktion fehlen beide; dort existieren ältere, ebenfalls deaktivierte Schlüssel `league_challenges` und `boxer_duels`. Die V2-RPCs prüfen die **neuen** Schlüssel, daher ist die Unterscheidung wichtig. Die vorbereitete Datei `supabase/production-prep/20261018_v2_feature_flags_disabled.sql` legt die beiden neuen Flags ausschliesslich als **deaktiviert** an, ohne bestehende Legacy-Flags anzutasten. Nicht ausgeführt.

## Produktionsrolle Coach fehlt im Schema

Produktion enthält derzeit 13 Boxer-Profile und ein Admin-Profil, aber **kein** Coach-Profil. Die `profiles.role`-Constraint erlaubt aktuell nur `boxer` und `admin`; die V2-RPCs erlauben Coach-Aktionen für `coach` oder `admin`. Eine dritte vorbereitete Migration `supabase/production-prep/20261018_allow_coach_role.sql` erweitert nur die zulässigen Rollen, ohne Profile oder bestehende Rollen umzuschreiben. Vor Ausführung Constraint-Namen und Abhängigkeiten prüfen; die vorhandene Admin-Rolle kann weiterhin Coach-Aufgaben wahrnehmen.
