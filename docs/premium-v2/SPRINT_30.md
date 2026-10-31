# Premium V2 – production sprint

Basis: PR #82 b87f0bc. No merge, deployment, approval or database writes.

## Separation findings and correction

No supplied problem screenshot was available in this turn. Direct inspection found short crown-bearing overlapping side flaps in both inherited black/red Boxer sources, and a waistband/crotch-like fold in the rear coat sources. The long side panels belonged to coatBack, not to the pants slot: UVs and slots were correctly assigned. The issue was semantic source artwork, not CSS or an atlas leak.

A new isolated Boxer master removes the side flaps. All eight material variants use this same source; the legacy red/black files remain untouched for historical reference only. A new continuous rear lining has no waistband, trouser crotch or shorts leg hems. Basic reuses the same fabric silhouette with neutral silver trim. Kurz, Jogger, Track and the registered lower-body UV show no coat fabric; they are retained unchanged. Body legs remain body-owned.

Hero and tiles use the same resolved source, UV, box and material function. No coat sources are prepared for coat:none. Changing pants/material cannot recolour or change coat components; removing/changing coat cannot change the pants raster.

## Basic Cool and shirt

Basic Cool now has a registered hidden-body mask in the artwork manifest. This removes the shoulder/elbow skin fringe without moving the garment or changing Guard. New real browser figures show the corrected silhouette. Shirt remains blocked: the existing Cool arm mask exposes chest/abdomen and the shared sleeve cap does not yet match both anatomies. No shirt support is claimed. Next correction: author a pose-specific arm-only foreground matte and shoulder cap against the registered body at 1:1.

## Hoodie

New Guard cotton hoodie master: torso and two sleeves have disjoint pixel ownership in one atlas, plus a separate hood-up component. Eight existing material colors, hood-down and hood-up. No new catalogue items. Supported only with coat:none/head:none. Cool/coat combinations return SVG. Hidden body pixels are masked in registration, not CSS.

Hood up removes ALL hair pieces, including long rear layers, before source preparation; saved c.hair is retained. Hood down restores it. SVG suppresses front/back/strand and optional layered hair too. SVG item thumbnails now show the actual hood state. Tests round-trip the configuration through JSON; this is not a real account save/reload test, and production storage was not touched.

## Evidence

Dedicated Chromium/WebKit test: 192 pants/coat/pose/material cases per engine, 144 Premium hood/hair/tone cases, 288 SVG hood/hair/tone cases, 18 repeated saved-hair transitions and latest-selection race. Three-request limit preserved. Real contact sheets and 100%/200% detail images: evidence/sprint/. Main catalogue proof is regenerated separately and carries source fingerprints.

New source art is produced with built-in Imagegen; exact crop bounds, hashes and derivation are in separation/manifest.json, hoodie/manifest.json and production-art/manifest.json. Reproducible component builders are scripts/build-premium-separation.cjs and scripts/build-premium-hoodie.cjs (CANVAS_MODULE may point to an installed @napi-rs/canvas).

Artistically pending. Physical phone testing, actual profile persistence acceptance, Shirt, Cool Hoodie, jacket, Neon/Dragon and four other poses remain open.

## Final local counts

276 validated keys (+16), 536 pose cells (+17), 48/52 equipment entries (+1), 36 identical shared components across Cool/Guard. All 536 integrated cases pass in Chromium and WebKit. The first PNG-only CI candidate failed; the new shared-static-aura runtime is a fix candidate pending Linux CI.
