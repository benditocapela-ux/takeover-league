# Six-pose premium catalogue

Branch: `feature/premium-complete-six-poses-20261101`. Based on main including PR #92 (`54ba745`). This change has not been merged or deployed.

The completion renderer composes equipment independently, then applies explicit occlusion. Cool and Guard now support the missing neon/dragon coats and Cool training jacket, as well as combinations previously rejected by the full-outfit resolver. Jab, Sieg, Flex and Ansage use registered pose-specific body silhouettes, common head/legs, shared garment torsos and articulated sleeve pieces. Existing shop keys, ownership, prices and database remain unchanged.

## Scope and evidence

- 52 existing equipment items. Six poses, 294 real catalogue/material rows per pose: 1,764 rendered individual variants per engine.
- Geometry matrix: 6 poses × 18 hairstyles × 4 headwear states × 6 top/hood states × 5 coat states × 4 bottoms × 2 footwear states × 2 hand states = 207,360 configurations. This checks resolver coverage, not artistic approval of 207,360 pictures.
- Selected coat/top matrix: 30 combinations per pose, 180 per engine. Isolated bottom pixels must remain identical with/without a coat.
- Chromium and WebKit cover the built editor, item thumbnails, all six poses, outfit changes, missing-image SVG fallback and absence of account writes. The PR #92 integration is also tested on Today, podium and FUT card.
- `completion/variants-*.json` records rendered pixels, variant digests, actual PNG usage and source SHA-256. `premium-completion-contracts.cjs` rejects stale evidence, empty variants, identical colour variants or invalid registrations.
- Baseline production reports still describe the original two-pose renderer. They are intentionally separate from completion coverage.

## Reuse and registration

65 distinct PNG files are consumed across the individual-variant matrix. 47 files (72.3%) serve multiple poses; 30 (46.2%) serve all six. These are file reuse counts, not an estimate of production hours saved. Four new body silhouettes resolve the anatomical limits of rotating the original Guard torso. Head, eyes, hair, headwear, bottoms and footwear remain shared. Seven sleeve segments and one robe torso serve all four new poses. Five additional exports complete the missing Cool/Guard items. Total new runtime exports: 17 PNGs, about 4.06 MB; raw artist sources are excluded from the website build.

Coordinate space remains 768 × 1216. Body registration records shoulder, elbow and wrist anchors. Sleeves map source proximal/distal anchors onto those joints using affine transforms; gloves/wraps follow the wrist axis. Source garment components are isolated by alpha-connected component before export, preventing neighbouring sleeve pixels from entering the crop. Sleeves are exported at twice their registered dimensions for 200% inspection, rather than shipping oversized source illustrations.

Layer order: coat back, back hair, body/legs, inner top, coat front, sleeves, front hair/headwear and hands. Hood-up and hijab hide stored hair without changing configuration. Coat front/back never become part of a bottom source. A shared head also preserves the existing eye-effect registration; procedural effects reuse the Guard coordinate frame. There is no independently drawn thumbnail artwork. Top tiles isolate the top without an overlying coat so its sleeves remain visible.

## Operational limits

Image loader retains its three-request concurrency and bounded cache. The additional material cache is capped at 24 entries / 8 MiB. SVG remains available for load failures and invalid future equipment. These are anime-style raster assets with procedural effects, not a new skeletal animation engine. Browser automation does not certify physical iPhone/Android rendering or every artistic/material cross-product.

## Reproduction

Run the four `scripts/build-premium-*.cjs` completion/sleeves/pose-base/pose-bodies exporters to rebuild from retained sources. Then run `premium-combinations-browser.cjs` with `CANDIDATE=1`, `premium-completion-variants.cjs`, `premium-completion-contracts.cjs`, `premium-completion-visual.cjs`, `premium-pose-outfits-browser.cjs`, `premium-live-browser.cjs`, and `anime-everywhere-browser.cjs`. The completion lab at `tools/premium-v2/completion.html` shows the old and new renderer with the same selection.
