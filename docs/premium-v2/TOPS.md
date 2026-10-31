# Registered tank and shirt production

All approved/enabled flags remain false. Technical support in the isolated laboratory is not artistic approval or release activation.

## Current support

Tank retains the original Cool garment and existing Guard garment. Shirt uses the existing transparent source, registered separately for Cool and Guard. Both families use eight colours in the production material renderer. Shirt requires no coat, headwear or raised hood. Unsupported poses/configurations use the complete SVG fallback. The standalone tops page deliberately tests the black source; the production page supplies all eight colours.

## Corrected causes

The Cool collar was registered ten world pixels too low. Its Y position is now 221.64939024390245, with unchanged source pixels and proportions. The original head is preserved; there is no CSS translation or rectangular neck cutout. Integer UV heights end at the waistband, so the tile no longer includes a longer hidden hem than the actual figure.

The inverse-tank-alpha experiment restored chest and abdomen together with the arms. A dedicated Cool foreground contour now restores only the crossed arms. Guard has a separate shirt contour preserving the complete elbow outline; the existing Guard tank contour remains separate.

Visibility behind the garment and restoration in front are separate registrations. The former retains upper arms beneath the short sleeves while hiding covered shoulders and torso fringes. The latter follows the actual foreground arms. No coat/pants pixels are edited or incorporated into the shirt.

Clipped clear followed by clipped draw applied antialias coverage twice, producing a dark seam where the same skin was already behind the mask. Polygon and bitmap mattes now use one coverage-weighted composite. A regression requires byte-for-byte preservation when the original semi-transparent skin already occupies the target, including every polygon edge. Restoration uses the currently materialized body, preserving the chosen skin tone.

## Sources and validation

The shirt PNG and its source hash are unchanged. Figure and tile use the same registered UV/box and material function. No new thumbnails or colour PNGs were generated; no additional artwork requests were introduced.

premium-v2-tops.cjs checks both poses, original arm pixels, current skin material, exact source/tile pixels, missing-asset and unsupported-configuration fallbacks, three deduplicated source requests and mobile layout.

premium-shirts.cjs checks Chromium and WebKit: 128 pose/colour/skin cases, 16 pants/glove combinations, 36 hairstyle/pose combinations and two full-raster mask-edge regressions per engine. Actual 100%/200% crops and contact sheets are in docs/premium-v2/evidence/shirts/.

premium-production-browser.cjs remains the full catalogue integration and exact item-parity gate. premium-v2-hair-expansion.cjs deliberately omits the Tops module: hair-only rendering must not acquire a mandatory clothing dependency.

Artist acceptance of anatomy, cloth style and fit remains outstanding. Premium remains disabled and PR #82 remains Draft.
