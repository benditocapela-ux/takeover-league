# Takeover League 2.0 – Implementierungsplan

Stand: 2026-10-18. Ausschliesslich Entwicklung, KEIN Live-Release.

## Bereits geliefert
- `league2-preview.html`: responsive, eigenständig öffnbarer UX-Prototyp mit mobile Navigation, Dashboard, Ranking-Suche, Levelübersicht, Boxer-Profilaktionen, Duell- und Challenge-Fortschritt, Achievement-Übersicht, Trainingskalender, lokal gespeicherten Trainingsentwürfen, Löschbestätigung und Demo-Traineransicht.
- Daten innerhalb dieser Vorschau sind explizit Demo-/Beispieldaten. Speicherung lokaler Entwürfe ist kein Datenbank-Commit.
- Bestehende `index.html` und `main` bleiben unberührt.

## Prioritäten für produktive Integration
1. **Ist-Zustand absichern**: Bestehende produktive Ansichten, Tabellen, RLS-Policies, Auth-Flows und CI prüfen. Kein neues Schema blind auf Produktion anwenden.
2. **Navigation und Profile**: Vorhandene Ranking/Level-Profilaktionen in aktuelle Webseite übernehmen; einheitliche Aktion „Profil ansehen“, „Herausfordern“, Coach „Challenge zuweisen“.
3. **Training**: Echte Trainingseinträge über authentifizierte API; Entwürfe als privates Serverobjekt oder bewusst lokal; serverseitige Validierung, Coach-Freigabe, Idempotenz und Duplikatschutz.
4. **Auswertung**: Monatspunkte ausschliesslich aus bestätigten Trainings; EXP separat, historisch auditierbar; Achievements pro Stufe nur einmal vergeben.
5. **Progression**: Streaks, Kalender und Zeitreihen serverseitig berechnen; Zeitzone und Trainingstag definieren; private Gewichtsangaben niemals öffentlich ausgeben.
6. **Duelle und Challenges**: Begrenzung auf drei aktive Duelle pro Boxer, 7/14 Tage; Trainer-Challenges 7/14/30 Tage; Teilnahme, Ablauf, Belohnungen transaktional und idempotent.
7. **Coach**: Rollen via Supabase RLS/Auth prüfen, nicht mit einem Browser-Toggle; Freigaben, Bonusvergabe und Änderungen protokollieren.
8. **Sicherheit**: Kein privater Sheet-Zugriff oder Service-Role-Key im Client; kritische Änderungen serverseitig; destructive Aktionen mit Bestätigung.
9. **Qualität**: Mobile-A11y, Performance, Tastatur, echte Daten, Berechtigungstests, Tests für Punkte/EXP/Monatswechsel; GitHub Actions Fehler separat untersuchen.
10. **Release-Gate**: Kein Merge in main, kein produktives SQL, keine Deployment-Änderungen ohne ausdrückliche Freigabe.

## UX-Abdeckung: 20 vereinbarte Punkte
1 Dashboard, 2 Schnelle Trainingserfassung, 3 Aufgaben/Benachrichtigungen, 4 Einheitliche Profile, 5 Suche/Filter, 6 Direkte Duellaktionen, 7 Coach-Schnellfreigaben, 8 Rücknavigation, 9 Kalender, 10 Streaks, 11 Fortschrittsgrafiken, 12 Challenge-Fortschritt, 13 Duellübersicht, 14 Favoriten/Vergleich, 15 Entwürfe, 16 Sichere Bestätigungen, 17 Änderungshistorie, 18 Coach-Gesamtübersicht, 19 Hilfetexte, 20 Mobiloptimierung.

Aktueller Status: Die Vorschau deckt viele Punkte visuell oder interaktiv ab; mehrere Punkte (Benachrichtigungen, Favoriten/Vergleich, echte Freigaben, Historie, Backend, Auth) bleiben für die Produktivintegration offen. Die Checkliste bedeutet NICHT, dass alle 20 implementiert sind.
