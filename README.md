# Takeover League

Boxing Performance League: öffentliche Monatsrangliste, Mein Studio für Boxer, Trainerbereich, Challenges, Duelle, Arena, Awards und Saisonhistorie. Mobile first, als Web-App auf dem iPhone-Home-Bildschirm nutzbar.

## Aufbau

- **Frontend:** statische Seiten im Hauptverzeichnis (`*.html`, `*.css`, `*.js`), ohne Build-Schritt.
  - Gemeinsames Design: `takeover-theme.css` (Farben, Schriften, Abstände) und `takeover-redesign.css` (Fight-Night-Gestaltung aller Seiten).
  - Gemeinsames Menü: `takeover-navigation.js` / `takeover-navigation.css`.
  - Schriften (Barlow Condensed, Inter) liegen selbst gehostet im Repo, Lizenzen in `docs/fonts/`.
- **Backend:** Supabase (Auth, Postgres, RLS, RPC-Funktionen).
  - Produktion: **Takeover Project** `iqarjivcrddcixrvqbfb`
  - Test: **Takeover league test** `cfgdvcccsqwfjajuizsr`. Die `*-preview.html`-Seiten zeigen auf das Testprojekt und werden nie veröffentlicht.
- **Datenbank-Änderungen:** `supabase/migrations/`. Pre-/Postflight- und Rollback-Skripte je Migration in `supabase/production-prep/`.

## Veröffentlichung

Jeder Push auf `main` veröffentlicht die Seite automatisch über GitHub Pages (`.github/workflows/takeover-pages-deploy.yml`). Der Deploy:

1. kopiert nur die Seiten-Dateien und lässt die Vorschauseiten weg,
2. prüft CSS-Syntax (`tests/css-structure.cjs`) und fehlerhafte Regex-Muster (`tests/js-regex-guard.cjs`),
3. versioniert alle CSS-/JS-Links mit dem Commit (`?v=…`), damit Browser nach einem Deploy keine veralteten Dateien aus dem Cache verwenden,
4. prüft nach der Veröffentlichung die Live-Seite nur lesend.

Änderungen deshalb immer über einen Pull Request, nie direkt auf `main`.

## Datenbank-Migrationen

Migrationen laufen **zuerst im Testprojekt** und erst nach ausdrücklicher Freigabe in Produktion. Ablauf und Prüfskripte: `docs/PRODUKTIV_RELEASE_SQL_EDITOR_ANLEITUNG.md` und `supabase/production-prep/`. Produktionsdaten (Punkte, EXP, Trainings) werden nie zurückgesetzt.

## Tests

- Statische Node-Tests: `node tests/<name>.cjs` (einige brauchen `jsdom`, Browser-Tests `playwright`).
- Schema-Tests laufen in GitHub Actions auf frischen PostgreSQL-16/17-Datenbanken.
- `redesign-contracts.cjs` stellt sicher, dass Designänderungen keine DOM-IDs oder RPC-Aufrufe verändern.

## Offene Punkte

Siehe `docs/RELEASE_STATUS_2_1_2026-10-19.md`: echtes Produktions-Backup mit Restore, echte Login-Abnahme mit Boxer-/Coach-/Admin-Konto und vollständiger Sicherheits-Audit der SECURITY-DEFINER-Funktionen sind noch nicht erledigt.
