> **STATUS-UPDATE: überarbeitete Migration am 18.10.2026 regulär auf Produktion angewendet.** Nach der Trennung in einen privaten privilegierten Kern und einen öffentlichen Security-Invoker-Wrapper akzeptierte `Supabase.apply_migration` die neue Fassung. Produktionsrechte und Datenintegrität wurden danach geprüft. Die ältere Sperr-/Reviewbeschreibung darunter ist ein historisches Dokument und nicht der aktuelle Live-Status.

# Privilegierte Live-Duell-Funktion – Sicherheitsreview / Freigabevorlage

**Status:** Isolierte TEST-Abnahme abgeschlossen. Produktive Ausführung weiterhin gesperrt; **kein Umgehen der Werkzeugsperre**.

**Projekt:** Takeover League 2.0  
**Repository / Branch:** `benditocapela-ux/takeover-league` / `release/takeover-league-2-ready`  
**Betroffene Migration:** `supabase/migrations/20261018211000_duel_v2_live_scores.sql`.

## Ausgangslage / zuvor blockierte Operation
Die ursprünglich geplante `public.duel_v2_live_scores(uuid)` lag als `SECURITY DEFINER`-Funktion direkt im exponierten `public`-Schema. Der Produktions-Aufruf von `apply_migration` wurde **vor der SQL-Ausführung von einer Sicherheitsprüfung der Integration abgewiesen**. Die genaue Erkennungsregel bzw. die vollständige Tool-Fehlermeldung liegt hier nicht vor. Deshalb ist nicht sicher belegt, welcher Teil des SQL die Sperre ausgelöst hat.

## Sicherheitsgerechte Überarbeitung (kein Ersatz-Ausführungsweg)
1. Ein neues, nicht für die Data API vorgesehenes Schema `league_duel_private` enthält `duel_v2_live_scores_core(uuid)` mit `SECURITY DEFINER` und festem leerem `search_path`.
2. `public.duel_v2_live_scores(uuid)` ist nur ein schmaler `SECURITY INVOKER`-Wrapper mit unveränderter Rückgabe `jsonb` (kompakt aggregierte Punkte/Status, keine Rohdaten oder privaten Trainingsnotizen).
3. `EXECUTE` ist für `PUBLIC` und `anon` auf beiden Funktionen entzogen; nur `authenticated` darf sie aufrufen. Das private Schema hat kein `USAGE` für `anon`. **Die API-Konfiguration muss vor Freigabe bestätigen, dass das private Schema nicht zu den exponierten Schemas gehört.**
4. Der privilegierte Kern prüft das aktive, serverseitige Boxer-/Coach-/Adminprofil anhand von `auth.uid()` und das `duels`-Feature-Flag. Ein Boxer sieht nur seine eigenen Duelle. Die Berechnung verwendet bestätigte Trainingseinträge und verknüpfte Punktbuchungen, zählt ungeprüfte Einträge separat, und verweigert Ergebnisse bei mehrfachen verknüpften Punktbuchungen.
5. Keine Berechtigungserweiterung auf Tabellen, keine Service-Rolle im Browser, keine produktive Flag-Änderung.

## Tatsächlich geprüfte Nachweise
- Die überarbeitete Migration wurde erfolgreich **nur** auf dem getrennten Supabase-TEST-Projekt angewendet.
- `pg_proc` und `has_function_privilege` bestätigen: öffentlicher Wrapper `security_definer=false`, privater Kern `security_definer=true`, beides `anon_execute=false`, beides `authenticated_execute=true`; Schema-`USAGE` für `anon=false`.
- `tests/live-duel-provisional-test-transaction.sql`: 50:70 bestätigte Punkte, ein ungeprüftes Training im Zähler, Statuswechsel `awaiting_reviews`, abgewiesene nicht verknüpfte Identität. Testtransaktion endet mit `ROLLBACK`.
- `tests/release-live-duels-browser.cjs`: reale Chromium-Oberfläche mit simulierten Supabase-Daten, aktiver Zwischenstand/Prüfstatus, Fehlerrückgaben, mobile Breite und Annahme eines Duells.
- `tests/release-static-contracts.cjs`: statischer Sicherheitsvertrag für die private Funktionsgrenze.

## Noch erforderliche reguläre Freigabe
1. Bei der Integrations- bzw. Plattformunterstützung die **genaue Fehlermeldung/Policy zur ursprünglich blockierten Operation** und die vorliegende, überprüfte Neufassung vorlegen. Um eine explizite Sicherheitsüberprüfung/Freigabe bitten. Ohne diese Freigabe nicht über `execute_sql`, externen SQL-Editor oder andere Wege versuchen, dieselbe blockierte Änderung durchzusetzen.
2. Prüfen, ob `league_duel_private` im Supabase-Data-API-Setup ausgeschlossen ist. Zusätzlich idealerweise einen unbeteiligten, **signierten** Boxer-Testaccount prüfen (bisher nur durch serverseitige Bedingung und nicht verknüpften Testactor abgedeckt).
3. Erst nach regulärer Freigabe und bestandenem Produktions-Preflight Migration anwenden, Funktion und Rechte verifizieren, dann Postflight durchführen. Erst danach Folge-Migrationen, Feature-Flags und GitHub-Deployment prüfen.
4. Bis dahin PR #8 als Draft halten, keine Veröffentlichung als abgeschlossen deklarieren.

**Weder das TEST-Ergebnis noch diese Vorlage heben eine Plattform-Sicherheitsblockade auf.**
