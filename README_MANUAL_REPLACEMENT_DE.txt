TAKEOVER LEAGUE — integrierter lokaler Entwurf

Basis: PR #19, Commit e34859d; ausgewählte Funktionalität aus PR #18, Commit f829b67, in den wiederverwendbaren Auswahlkarten-Ansatz integriert.

Dieses Paket enthält nur die 19 geänderten bzw. neu hinzugefügten Dateien. Es enthält keine .git-Daten, Zugangsdaten, Abhängigkeiten oder Produktionsdaten. Es wurden keine Supabase-Schreibzugriffe, Commits, Pushes oder Deployments ausgeführt.

WICHTIG: Noch nicht auf main hochladen. Das Hochladen/Ersetzen auf einem GitHub-Branch erzeugt einen Commit. Gemäss Freigaberegel ist dafür zuerst das ausdrückliche Wort FREIGEBEN nötig.

Wenn freigegeben: Paket in einem separaten Branch auf Basis von PR #19 / e34859d entpacken und die enthaltenen Pfade relativ zum Repository-Stamm ersetzen bzw. hinzufügen. Nicht in /home/user/app kopieren; diese ursprüngliche Arbeitskopie ist separat. Danach die Tests erneut ausführen und den Branch prüfen. Es wurde kein Browser-/E2E-Test ausgeführt.

Prüfstatus dieses Entwurfs: 29/29 statische Vertragschecks sowie Auswahlkarten-, Trainingsauswahl-, Menü-, Design- und 18-Seiten-Prüfungen bestanden.

Dateien im Paket:
- .github/workflows/takeover-pages-deploy.yml
- arena.html
- boxer-compare.html
- boxer.html
- challenges.html
- duels.html
- goals.html
- league-manager.html
- takeover-choice-cards.js
- takeover-navigation.css
- takeover-navigation.js
- takeover-redesign.css
- takeover-training-choices.js
- tests/choice-cards-compat.cjs
- tests/coach-challenges-v2.cjs
- tests/menu-navigation-compat.cjs
- tests/redesign-contracts.cjs
- tests/release-static-contracts.cjs
- tests/training-choices-compat.cjs
