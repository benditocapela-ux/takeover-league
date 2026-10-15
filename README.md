# Takeover League — GitHub Pages

Mobile öffentliche Rangliste. Nur Daten aus dem **öffentlichen** Google-Sheets-Leaderboard, keine private Trainerdatei.

## Installation

1. Die Dateien aus dem ZIP **entpacken**.
2. Auf GitHub im Repository `takeover-league` auf **Add file → Upload files** klicken.
3. Alle Dateien aus diesem Paket auswählen, dann **Commit changes**.
4. Unter **Settings → Pages**: `Deploy from a branch`, Branch `main`, Folder `/ (root)`, **Save**.
5. Auf die Veröffentlichung warten und die dort angezeigte URL auf dem iPhone in Safari öffnen.
6. **Teilen → Zum Home-Bildschirm**.

## Datenquelle

Die Website fragt die drei öffentlichen Sheets-Tabs über den Google-Visualization-Endpunkt ab. Falls die Daten nicht geladen werden, kann es nötig sein, die **öffentliche Ranglisten-Arbeitsmappe** unter **Datei → Freigeben → Im Web veröffentlichen** zu veröffentlichen. **Niemals die private Trainerdatei veröffentlichen.** Bei Veröffentlichung im Web prüfen, dass keine privaten Daten in der öffentlichen Arbeitsmappe stehen.

Google-Sheets-Zugriff und GitHub-Pages-Hosting müssen nach Upload auf dem Handy getestet werden; eine erfolgreiche Live-Anbindung ist vorab nicht bestätigt.
