# Art-Provenienz

Modus: integriertes Imagegen, vier begrenzte Generierungen/Edits. Exakte Prompts: [generation-prompts.json](generation-prompts.json). Keine weiteren Itemfamilien generiert.

Rohdateien wurden lokal nach `work/premium-v2/{body,coat,black,white}.png` kopiert. SHA-256 und Abmessungen stehen unter `sources` in `tools/premium-v2/pilot-assets.json`. Der Builder erwartet genau diese Dateien; Neugenerierung mit denselben Prompts ist nicht deterministisch.

Generierte Quelldateien (Sitzung `01a18ebd-731c-7a62-a237-05a11ea7d8fb`):

| Teil | Imagegen-Datei |
|---|---|
| Guard-Körper | exec-9b120c9a-00e5-4923-8c3d-ca5031ba30c3.png |
| Guard-Mantel | exec-0e3f5672-bef5-4821-b91b-069c7a848ba4.png |
| Handschuhe Schwarz-Gold | exec-3550f625-68d1-4e87-bf91-48cec5a8729a.png |
| Handschuhe Weiss-Gold | exec-06d5cd21-8df4-491e-a4b7-80444d71743b.png |

Finale Projektdateien liegen unter `tools/premium-v2/assets/`: `shared.png`, `guard.png`, `v1-body.png`, `v1-coat.png`, `v1-black.png`, `v1-white.png`. Registrierung, Ausschnitte und Alpha-Blends sind reproduzierbar in `scripts/build-premium-v2-pilot.cjs` festgelegt. Originale Cool-Dateien bleiben unverändert. `shared.png` enthält ausschließlich unveränderte Cool-Ausschnitte; `guard.png` enthält registrierte neue Ansichten. Die vier V1-Vergleichsbilder werden aus denselben Komponenten gebacken.

Die Browserbilder und Messwerte unter `evidence/` zeigen den tatsächlichen Entwurfsstand. Insbesondere der Mantelübergang und die Handschuh-Ornamentik sind keine freigegebene Endgrafik. Kein vollständiges Skelett-Rig, keine verborgene Anatomie und kein Nachweis für sechs frei retargetbare Posen.
