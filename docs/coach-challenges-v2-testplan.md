# Coach Challenges V2 – Testfreigabe (nur Testprojekt)

## Voraussetzungen
- Testprojekt: cfgdvcccsqwfjajuizsr; Produktionsprojekt niemals für diese Tests verwenden.
- Zwei echte Auth-Testkonten: aktiver Coach und aktiver Boxer, jeweils korrektes `profiles.auth_user_id` und `is_active=true`.
- Preview: `challenges-v2-preview.html` auf Branch `feature/coach-challenges-v2-ui`.
- Login mit Testkonto direkt in der Preview; Produktion-Login zählt nicht.

## E2E-Prüfungen (noch offen)
1. Unangemeldet: keine Challenge-Liste, kein Coach-Formular; Login sichtbar.
2. Boxer: kann offene Challenge sehen, beitreten und vor Start zurückziehen; kein Coach-Formular.
3. Coach: erstellt Entwurf; speichert manuelles Ziel mit 25/50/100/150/200 EXP; öffnet Entwurf.
4. Mindestens ein Boxer tritt bei; Coach aktiviert; erneute Aktivierung wird abgewiesen.
5. Nach Enddatum startet Coach die Bewertung; begründet bestanden/nicht bestanden; Doppelbewertung wird abgewiesen.
6. Abschluss vor vollständiger Bewertung scheitert serverseitig; nach vollständiger Bewertung genau eine Auszahlung je bestandenem Boxer.
7. Zweiter Abschluss führt nicht zu doppelten EXP/Transaktionen; Ablehnung gibt 0 EXP.
8. Boxer versucht Coach-RPC direkt: serverseitig verweigert; Coach versucht Boxer-RPC: serverseitig verweigert.
9. Abmelden entfernt personenbezogene Inhalte; Neuladen ohne Session zeigt Login.
10. Datenbank-Ledger und Punktetransaktionen stimmen mit Review-Entscheidungen überein.

## Vor Freigabe
- `SECURITY DEFINER`-RPCs einzeln auf `auth.uid()`, Rollen- und Eigentümerprüfungen untersuchen.
- Test- und Produktions-Migrationsstände vergleichen; keine produktiven Daten überschreiben.
- GitHub CI und Browser-Tests nachweislich erfolgreich; PR #3 erst danach reviewen/mergen.
- Kein produktives SQL ohne ausdrückliche Freigabe des Nutzers.

**Status:** Diese Checkliste ist ein Testplan, kein Nachweis bestandener E2E-Tests.
