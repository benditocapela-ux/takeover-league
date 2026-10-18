# Produktionsfreigabe – sicherheitsrelevante Voraussetzungen

Stand: 18.10.2026. **Noch keine Freigabe.** `challenges.html` ist standardmässig deaktiviert.

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
