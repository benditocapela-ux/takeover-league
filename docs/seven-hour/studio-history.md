# Studio: vollständige Statistik und seitenweiser Trainingsverlauf

Vorher lud Studio bis zu 1.000 vollständige Trainings für Verlauf, Kalender und Erfolge. Die Statistik lud zusätzlich sämtliche bestätigten Trainings in 500er-Paketen. Dadurch fehlten ältere Trainings in manchen Fortschrittsanzeigen, während die Übertragung trotzdem mit dem gesamten Bestand wuchs.

Jetzt liefert `get_my_studio_training_history` jeweils höchstens 20 eigene Trainings mit einem Cursor aus `created_at` und `id`. Der Statusfilter wird auf dem Server angewandt. «Weitere Trainings laden» ruft genau die nächste Seite ab; ein Doppelklick erzeugt keinen zweiten Abruf. Notizen werden nur für diese eigene Seite übertragen.

`get_my_studio_training_summary` berechnet unabhängig davon den vollständigen Bestand: alle acht Achievement-Familien, Wochenquests und Wochenserie, Tagesserie, 7-/30-Tage-Zähler, 42 Tage für Diagramm/Kalender und Statistiken pro Trainingsart. Historische Trainings einer inzwischen inaktiven Art bleiben enthalten. Numeric-Summen entstehen in PostgreSQL; es werden keine Belohnungen oder Wirtschaftsdaten geändert. Der Kalender und die Wochenanker verwenden Europe/Zurich. Die bestehenden Obergrenzen der Serienanzeige (520 Wochen, 10.000 Tage) bleiben erhalten.

Beide RPCs ermitteln das eigene aktive, nicht archivierte Profil aus `auth.uid()`. Sie akzeptieren keine Boxer-ID. Ein eigener privater Namespace verhindert, dass die Berechtigung für bestehende interne Funktionen erweitert wird. Öffentliche Wrapper sind SECURITY INVOKER; die privaten, eigentumsgeprüften Aggregate haben einen leeren search_path. Anonyme Ausführung ist entzogen. Produktion wurde ausschließlich auf Spalten, Indizes und Schema-Berechtigungen gelesen.

Studio verwendet den optionalen `getSummary`-Adapter des Gamification-Moduls. Die ältere Boxer-Seite mit `getHistory` bleibt kompatibel. Bei Ladefehlern erscheinen unbekannte Werte statt Fortschritt aus unvollständigen Seiten. Veraltete Filterantworten und Antworten nach einem Kontowechsel werden verworfen; eine erneute Anmeldung desselben Kontos löscht dessen Darstellung nicht. Die vorhandenen Inbox-Wrapper wurden nicht verändert.

## Nachweis

- PostgreSQL 17.11, isolierte Datenbank `league21_replay_studio_history4`, Loopback Port 55481: 1.202 eigene Trainings, vollständige Cursoriteration bei gleichen Zeitstempeln, Filter, exakte 60 km und 6.000 Technikminuten, inaktive historische Art, Rollen-/Eigentumsgrenzen, leeres Profil und Wochenlücken. Hauptlesetests laufen in `BEGIN READ ONLY`.
- `tests/studio-history-parity.cjs` vergleicht die echten SQL-Ergebnisse mit den bestehenden Gamification-Funktionen über sämtliche 1.202 Ausgangszeilen: acht Fortschrittsfamilien, drei Wochenquests und Wochenserie. Die begrenzte Zusammenfassung enthält keine Trainingsnotizen.
- `tests/studio-history-browser.cjs`: Chromium und WebKit, echte Seitenintegration mit synthetischem SDK. Seitenwechsel, Doppelklick, schnelle Statuswechsel, Ausfall/Wiederherstellung, stabile Gesamtstatistiken und Erfolge, wiederholtes SIGNED_IN sowie Kontowechsel während einer Antwort; 320/360/390/430 Pixel ohne seitlichen Überlauf.
- `tests/studio-history-rollback.sql`: Rücknahme und erneutes Einspielen der Leser erhalten den Hash sämtlicher Trainingszeilen; anonyme Berechtigungen bleiben gesperrt.

Screenshots: `output/continuation/studio-history/`; keine echte Benutzerhistorie. Es gab keine produktiven Schreibzugriffe, keinen Merge und kein Deployment.

## Integration

Migration: `20261102103929_studio_training_history_summary.sql`, mit Supabase CLI 2.122.0 erzeugt. Vor Veröffentlichung muss diese Lesemigration verfügbar sein; bei fehlendem RPC zeigt der Client einen Ladefehler und startet keinen unbegrenzten Ersatzabruf. Die Änderung hängt nicht von `server_received_at` ab: Eingangsfristen bleiben Aufgabe des Duellsystems, während der Verlauf seine bisherige Sortierung und Trainingsdaten behält.

Lokale/CI-Prüfung in einer frischen `league21_replay_*`-Datenbank:

```text
psql -X -v ON_ERROR_STOP=1 -f tests/studio-history-schema.sql
node tests/studio-history-parity.cjs
psql -X -v ON_ERROR_STOP=1 -f tests/studio-history-rollback.sql
node tests/studio-history-browser.cjs
```

Vorbereitete Prüf- und Rücknahmeskripte liegen in `supabase/production-prep/`. Vor einer Rücknahme zuerst den abhängigen Studio-Client zurücknehmen. Aktuelle [Supabase-Änderungen](https://supabase.com/changelog) und [Funktionsberechtigungen](https://supabase.com/docs/guides/database/functions) wurden vor Implementierung geprüft; keine einschlägige neue API-Änderung erforderlich.
