> ⚠️ **ÜBERHOLT – historischer Entwicklungs- oder Release-Zwischenstand.** Frühere Aussagen wie «nicht veröffentlicht», «HOLD», «NICHT AUSGEFÜHRT» und «kein Live-Release» dürfen nicht mehr als aktueller Produktionsstatus gelesen werden.
> **Tatsächlich:** Takeover League 2.1 ist auf `main` (`4aae67e` → `4430bc4` → `0cd262e`) und mit der atomaren Migration `20261018231319` in Produktion. Echte Backup-/Restore-, Real-Login- und vollständige Security-Definer-Gates sind dadurch **NICHT** bestanden.
> **Verbindlicher aktueller Überblick:** [RELEASE_STATUS_2_1_2026-10-19.md](RELEASE_STATUS_2_1_2026-10-19.md). Der übrige Text bleibt unverändert als historische Momentaufnahme erhalten.

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


## UX-Erweiterung 21–45 – Priorität und Stand (2026-10-18)

**P0 – direkte tägliche Bedienung:** 22 Training wiederholen; 23 Voreinstellungen; 25 Eigene Position; 26 fixierte Navigation; 27 Statusanzeigen; 28 Zwischenspeichern; 31 Coach-Aktionszentrale; 32 Sammelaktionen; 35 Aufgabenfilter; 38 Prüfbestätigung; 41 Meldungen; 42 Doppeleingaben; 44 kurze Klickwege.

**P1 – nahtlose Abläufe:** 21 kontextbezogene Schnellaktionen; 24 einheitliche Menüs; 29 Scrollposition; 30 Leerseiten; 33 Boxer-Schnellansicht; 34 zuletzt bearbeitet; 37 Undo; 39 automatische Aktualisierung; 40 Direktzugriff; 43 mobile Bottom-Sheets; 45 konsistente Muster.

**P2 – Coach-Konfiguration:** 36 Vorlagen für Coach-Aktionen.

### Stand im UX-Prototyp `league2-preview.html`
- **Interaktiv (nur Vorschau):** 21 (Dashboard), 22, 23, 24 (teilweise), 25 (Demo-Benutzer), 26, 27 (erläuterte Statuswerte), 28 (lokale Formulardaten), 29 (Scrollspeicherung), 30 (Leerzustände), 31, 32 (Demo-Sammelaktion), 34 (zuletzt geöffnet), 35 (Demo-Filter), 37 (Demo-Undo), 38 (Bestätigungsdialog), 39 (lokale Aktualisierung), 40 (Direktprofil), 41 (UI-Meldungen), 43 (mobile Dialog-Position), 44 (verkürzte Wege), 45 (gemeinsame Buttons). 42 ist für die Produktiv-API ausdrücklich noch nicht erfüllt.
- **Weiter offen / Integration nötig:** 33 echtes seitenübergreifendes Coach-Sidepanel, 36 Vorlagen, echte rollenbasierte Aktionen, serverseitige Duplikats-/Idempotenzsperre für 42, langlebige Undo-Transaktionen, datengestützte Statusinformationen und echte Profilverknüpfung.
- **Sicherheit:** Das Trainer-Umschalten in der Vorschau ist niemals Authentifizierung. Demo-Aufgaben liegen ausschliesslich lokal im Browser. Kein Produktiv-SQL, kein Merge in `main`, kein Live-Deployment.

### Definition of Done
Ein Boxer kann Training schnell mit sinnvollen Voreinstellungen erfassen, Status jederzeit erkennen und ohne Datenverlust navigieren. Ein Coach kann mit echter Authentifizierung offene Trainings filtern, stapelweise bestätigen und Boxer-Kontext ohne unnötige Seitenwechsel prüfen. Testen: mobil, Tastatur, langsame Verbindung, doppelte Requests, abgelaufene Anmeldung, Rollenabgrenzung und sichere Rücknahme.
