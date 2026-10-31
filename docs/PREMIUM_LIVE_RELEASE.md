# Premium activation and deployment

Owner explicitly authorized Premium activation and deployment after waiving manual acceptance. This does not claim an artistic or physical-device acceptance.

The live Mein Boxer editor now uses the existing tested V2 renderer for supported Cool/Guard outfits. The original masked Cool reference stays disabled. Unsupported full configurations and failed assets fall back to the complete SVG figure; no saved configuration, ownership or purchase behavior changes.

The Pages assembler publishes only referenced runtime PNGs, nine runtime manifests and a bundled renderer, under a content-hashed directory. Authoring pages, sources, evidence and tools remain excluded. The adapter uses the same selection and draw functions for the hero and prospective item tiles. Image loading remains limited to three simultaneous requests; completed image and material caches remain bounded; hero encodings are limited to four.

Production activation: tools/premium-character-release.json. Set enabled=false to remove the live runtime from the next Pages build. Explicit art/debug query modes remain isolated legacy authoring previews.

Tests: premium-live-browser.cjs against the real assembled site in Chromium/WebKit. Guard/Cool, red pants, shirt and exact item renderer, unsupported pose/coat fallback, restored anime, missing-image fallback and no persistence. Existing six-pose/card/save/race tests retained and updated to the released renderer. Live verification uses real published HTML/JS/PNG assets with synthetic account responses, without production account writes.

Deployment: restore Pages publish and its dependent after-deploy check. No database changes or new catalogue items. Profiles and FUT-card rendering are outside this editor activation.
