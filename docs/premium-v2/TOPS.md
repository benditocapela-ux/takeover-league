# Bounded tops production

All approved/enabled flags remain false. This is local art inspection, not release approval.

## Supported tank pilot

One newly generated Guard tank front, plus the unchanged existing Cool tank. Black only, Cool/Guard, no coat or hood. This adds **one** item/color/pose cell (Guard tank); Cool tank is existing reuse. The garment contains no skin or hands. Manifest boxes preserve native aspect ratio on the 768×1216 registration canvas.

Integration order: registered current body and lower clothing, top, restore foreground arms from the **current materialized body**, then gloves. Never restore raw source skin after skin recoloring. `TLPremiumTops.resolve(config, manifest)` is the default support gate. `draw` uses the same source/UV as the item tile. Guard restoration uses explicit polygons; Cool tank retains its original alpha gaps.

## Shirt: blocked artwork draft

One genuine shared shirt master was generated and corrected twice. All three raw sources are retained. It is **not supported** by the default resolver: selecting shirt returns full SVG. Only the isolated comparison gallery calls `resolve(...,{inspectDraft:true})` to expose failures honestly. This is zero supported shirt cells, despite two pose inspection examples.

Remaining visible defects: Guard shoulder skin crescents above the sleeve caps; Cool foreground mask exposes chest/abdomen strips. The neckline correction improved the open collar but did not solve pose occlusion. Next production request: redraw the shoulder cap outline against the actual registered Guard shoulder and author an exact Cool arm-only mask; inspect the complete contour at 1:1 before changing support status.

The experimental Cool mask is packed beneath the shirt sprite in the same PNG atlas. UVs exclude the mask from equipment thumbnails. This saves a network request but does not constitute an artistic solution or proven pose reuse.

## Evidence and validation

`node tests/premium-v2-tops.cjs` exercises Chromium and WebKit. It checks RGBA PNGs, hashes, registration aspect, identical tile/source pixels, sampled foreground arm centers, restoration of current skin material, full SVG for unsupported configurations and missing assets, local-only requests, three deduplicated art requests for the complete inspection gallery, and 390px layout. Sampling arm centers cannot prove a clean anatomical contour; the shirt fails visual inspection despite passing these technical checks.

Real browser captures and before/after detail canvases live in `tools/premium-v2/tops/evidence/`. The earlier `*-tank-contact.png` captures show the tank family; `*-tops-contact.png` also show the explicitly blocked shirt drafts. `*-shirt-*-detail.png` retain the visible defects. Source hashes and crop coordinates are in the manifest; generation prompts are in provenance files.

## Integrated production palette

The production resolver uses the black tank registration and applies the shared material system for all eight existing topc values. The standalone tops resolver remains black-master only. Shirt stays blocked in both paths; coat/hood restrictions remain.

## Next sprint correction
The inverse-tank mask is now replaced by a registered arm-only polygon and explicit covered-body clipping. Both shirt poses remain blocked after 200% review: Cool neckline/under-arm remnants and Guard elbow outline. See NEXT_CLOTHING.md; the old atlas mask is retained but no longer used.

