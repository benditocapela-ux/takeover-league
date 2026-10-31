# Boxer Experience – In-App-Navigation statt alter Vollseiten

## Befund (nach PRs #83, #84, #85)

Die neue \`boxer-experience.html\` besitzt fünf Tabs, ihre Aktionslinks führten aber auf ältere eigenständige Seiten. Besonders störend:
\`Nein, eigenes Training\` → \`boxer.html?individual=1#trainingFormCard\`,
\`Ergänzungstraining\` → \`boxer.html?club=1#trainingFormCard\`.
Weil dabei ein vollständiger Seitenwechsel stattfand, verschwanden die neue Kopfzeile und die fünf Tabs.

## Umsetzung

\`takeover-boxer-flow.js\` erkennt zulässige, gleichursprüngliche Funktionslinks im neuen Dashboard und öffnet sie in einem **eingebetteten Funktionsbereich innerhalb der Boxer Experience**. Die fünf Tabs bleiben stehen. Ein Zurück-Button schliesst den Bereich und aktualisiert die Trainingsübersicht.

- \`takeover-boxer-embedded-flow.css\` entfernt **nur im eingebetteten Kontext** doppelte ältere Navigationsleisten, Header und beim Training nicht benötigte Studio-Übersichtskarten.
- Bei Trainings meldet sich der Boxer weiterhin über die **bestehende** \`boxer.html\` mit unveränderter Formularlogik, denselben Auth-/RLS-Schranken, Training-2.0-Auswahlmöglichkeiten und serverseitiger Freigabe an. Nur das Darstellungs- und Navigationsgehäuse ist neu.
- Vor der Auth-Prüfung bleibt \`#content.hidden\` verborgen. Die neue Einbettung setzt keine Rollen- oder Feature-Flags.
- Der «Ja, im Verein»-Ein-Klick-RPC bleibt direkt im Trainingstab und nutzt unverändert PR #84.
- \`index.html#ranking\` wird ebenfalls als Liga-Unteransicht geladen, ohne die externe neue App zu verlassen.
- Unterseiten-Links innerhalb einer eingebetteten Seite bleiben im Funktionsbereich und werden nach jeder Navigation erneut gestaltet.
- Externe URLs sowie Anmeldung/Account bleiben absichtlich ausserhalb der Einbettung.
- Direkte Aufrufe einer alten URL (\`boxer.html\` ohne Boxer Experience) funktionieren unverändert.
- Wenn Styles nicht geladen werden können, zeigt die App eine Fehlermeldung und einen expliziten «Separat öffnen»-Ausweg.

## Verknüpfungsinventar

| Hauptbereich | Einbettung |
|---|---|
| Heute | Trainings-Einstieg bleibt im Trainingstab; sonstige interne Funktionslinks werden eingebettet |
| Training | «Nein»/Individuell und Ergänzung → kanonisches Boxer-Formular; Wochenplan, Ziele, Präsenz, Gym-Check-in → In-App |
| Kämpfe | Duelle, Live-Challenges, Challenges, Arena, Wochen-Quests → In-App |
| Liga | öffentliches Ranking (\`#ranking\`), Boxer-Vergleich, Awards, Hall of Fame → In-App |
| Mein Boxer | Boxstil-Test, Inventar/Holo-Editor, Shop, Spielerkarten, Bewertung, Kampfpfad → In-App |
| Menü | Studio, Ziele, Level-Roadmap, Feedback, Hilfe → In-App. «Account» öffnet bewusst den Login/Account |

Weitere zulässige interne Unterseiten sind ausdrücklich in \`takeover-boxer-flow.js\` erfasst; keine freihändige Weiterleitung auf Admin- oder Coach-Routen.

## Grenzen / zukünftige Verbesserung

**Die Funktionsseiten selbst sind nicht vollständig neu geschrieben.** Sie werden in der modernen Boxer-App als gleichursprünglicher, responsiv gestalteter, schreibberechtigungsseitig unveränderter Bereich dargestellt. Das ist die sichere Zwischenstufe zu vollständig nativen Takeover-Komponenten. Es bedeutet nicht, dass etwa Shop, Challenges und Wochenplan bereits komplett zu einer einzigen JavaScript-App refaktoriert wurden.

Eine vollständige native Migration aller 20+ bestehenden Funktionsseiten würde gesonderte Integrations- und Sicherheitstests benötigen; kein freier Nachbau der Geschäftslogik oder Punktetransaktionen.

## Tests und Freigabe

- \`node --test tests/boxer-experience-inapp-routing.cjs\`: vollständige Abdeckung der HTML- und JS-Linkziele, Login-/Rollen-/Origin-Schutz, Formularunveränderlichkeit.
- \`node --test tests/boxer-experience-contract.cjs\` und \`node --test tests/boxer-experience-routing.cjs\`: bestehende Boxer- und Login-Verträge.
- \`tests/boxer-experience-browser.cjs\`: Browserprüfung für individuelles Training, Ergänzung, Zurück, Tabwechsel, interne Shop→Ziele-Navigation und unveränderte fünf Tabs.
- \`tests/training-v2-browser.cjs\` bleibt zuständig für die echte alte Formularlogik.
- \`.github/workflows/boxer-experience-contracts.yml\` ist auf die neuen Quelldateien und Tests erweitert.

**Wichtiger separater Release-Blocker:** Der Stand von \`main\` enthält im GitHub-Pages-Workflow \`if: github.ref == 'refs/heads/main' && false\`. Damit sind automatische Produktivveröffentlichungen **bewusst deaktiviert**. Weder dieses Feature noch ein Merge dürfen diesen Schalter eigenmächtig aktivieren. Eine separate produktive Deployment-Freigabe ist nötig.

PR #86 (Trainer/Admin-Redesign) ist eine unabhängige parallele Arbeit; dieser Branch ändert dessen Dateien nicht.

**Kein Merge, kein Deployment, keine Datenbankänderung.**
