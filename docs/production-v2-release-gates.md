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
