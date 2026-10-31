# Boxer Experience – parallel zu Claude / Design-PRs

Branch: feature/boxer-experience-redesign (based on main @ 8176e8014d134136ba210ced37b230cd61190ac8)

## Implementiert

- Neue, eigenständige Route: boxer-experience.html.
- Fünf Bereiche: Heute, Training, Kämpfe, Liga, Mein Boxer.
- Persönlicher Holo nur auf «Heute»; fixierte FUT-Card nur auf «Mein Boxer».
- Sechsachsiges Boxstil-Diagramm unter der fixierten FUT-Card.
- Liga-Podium mit aktuellen drei besten Boxern und ihren echten Holo-Looks, sofern vorhanden.
- Daten aus bestehenden geprüften Auth-/Profil-/Performance-/Ranglisten-RPCs und RLS-geschützter Trainingshistorie.
- Keine Änderungen an Supabase, Coach-UI, Punktevergabe, Trainingsarten, bestehendem Login oder bestehendem Boxer-Studio.
- Bei nicht verfügbaren Daten werden neutrale Zustände statt Demo-Punkten oder erfundener Boxer angezeigt.

## Noch vor produktivem Merge

1. Review der Auth- und Feature-Flag-Anzeige mit echtem Testkonto. Die Loginseite leitet neue Loginvorgänge derzeit weiter zum bestehenden Studio; die neue Route ist daher aktuell nur über einen direkten Link nach dem Login erreichbar.
2. Mobile Touch-/Responsiveness-/Accessibility-/Leistungstests mit verbundenem Supabase und realen nicht freigeschalteten Profileinstellungen.
3. Nach Claude: echte neue Trainingseinreichung und aktuelle Pflicht-/Ergänzungstraining-Kategorien in den Tab «Training» integrieren, ohne die vorhandenen Punkte zu verdoppeln.
4. Nach Abschluss der laufenden Premium-Holo-/Mein-Boxer-PRs visuelles Rendering und Layout abgleichen.
5. Erst anschliessend Boxer-Dashboard-Routing (login.html, takeover-navigation.js und ggf. Links) sicher umstellen.
6. Review / Freigabe / Merge / Deployment getrennt entscheiden.

## Automatische Smoke-Tests

    node --test tests/boxer-experience-contract.cjs

Tests prüfen Syntax, Tabs, Sections, IDs, echte RPCs, Auth-Guard und Read-only-Regeln.

## Rollback

Keine produktive Route wurde ersetzt. Ein nicht gemergter PR kann ohne Auswirkungen geschlossen werden.
