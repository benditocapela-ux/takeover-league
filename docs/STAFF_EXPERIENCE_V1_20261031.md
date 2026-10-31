# Staff Experience V1 – echtes Coach- und Admin-Redesign

Branch: \`design/staff-experience-v1-20261031\` (basierend auf \`main\` nach PR #85).

## Ziel
Das neue Boxer-Dashboard ist die visuelle Referenz. **Keine Trainer-/Admin-Vorschau.**
Die echten Seiten \`coach.html\` und \`admin.html\` erhalten dieselbe Navy-/Gold-Designsprache mit mobilem Dock, starken Headern und reduzierter Ablenkung. Keine neuen Datenquellen oder Berechtigungen.

## Trainer: coach.html

- Bestehende sechs Ansichten (Start, Prüfen, Gym, Boxer, Historie, Mehr) bleiben vollständig mit allen Funktionen erhalten.
- Die bestehende \`#cv2Tabs\`-Navigation wird mobil als **fixierte untere Leiste** wie bei der Boxer Experience angezeigt; auf Desktop als kompaktes oberes Segment.
- Premium-Kopf, hochwertigere KPIs, bessere Trainings-/Bestätigungskarten und Touch-Ziele.
- Bestehende Bestätigungen, Ablehnungen, Sammelaktionen, Korrekturen, Gym, Coach-Feedback und Historie behalten ihre Original-IDs, RPCs und Berechtigungen.
- Die Website-Navigation bleibt über die neue sichtbare Menü-Schaltfläche erreichbar. Das ursprüngliche globale Bottom-Menü ist ausgeblendet, damit nicht zwei Leisten konkurrieren. Liga und Account sind auch in der Unterleiste erhalten.

## Clubverwaltung: admin.html

- Drei echte Verwaltungsbereiche via neue Dock-Navigation: **Boxerprofile**, **Zugänge**, **Protokoll** plus **globales Menü**. Das bestehende Coach-Dashboard ist per Kopfzeile direkt erreichbar.
- Suche über die bereits berechtigt geladenen Boxerprofile (Name/E-Mail/ID), ohne neuen RPC.
- Zehn Profile initial; «Weitere 10» erweitert die Liste. Bestehende Rollen-, Aktivitäts-, E-Mail-, Archivierungs- und Sichtbarkeitsaktionen funktionieren unverändert.
- Admin-Berechtigung wird **vor** dem Anzeigen der Verwaltung und vor jeder Änderung geprüft; für Boxer und Coaches bleibt \`#adminContent\` versteckt.
- Login-Sperren-SQL wird weiterhin ausschliesslich kopiert, **nie** ausgeführt.
- Änderungen an Datenbank, Points/EXP/Coins, Feature-Flags oder bestehenden Rollen-Policies: **keine**.

## Qualität / Freigabe

- Neue Statiktests: \`node --test tests/staff-experience-contracts.cjs\`.
- Browser-Test: \`node tests/staff-experience-browser.cjs\` (Mock Auth/Supabase, 320/390/1366 px, echte Seiten, Screenshots, Berechtigungsprüfung).
- Regression: \`node tests/admin-registration-browser.cjs\` und bestehende Training-2.0-Tests.
- GitHub Workflow: \`.github/workflows/staff-experience.yml\`.
- Bestehende CI und echte Coach-/Admin-Testkonten vor Merge prüfen.
- Screenshots in Actions-Artifakt \`staff-v1-screenshots\` nach erfolgreichem CI.

## Release
Dieser PR ändert **die echten Seiten**, nicht neue Preview-Routen. Nach Merge nach \`main\` und erfolgreichem Pages-Deployment erscheinen die Änderungen in der Trainer- und Adminansicht ohne neuen Login-Pfad. Der öffentliche Ligabereich und das Boxer-Dashboard bleiben wie bisher.
