# White boxing wraps: bounded production

Two genuine transparent hand-pair masters were generated with the built-in image generator, one for Cool and one for Guard. Each is split into two alpha-bounded components and resized uniformly. The original PNGs, exact prompts, SHA256 hashes, crop rectangles and registration boxes are retained. No source character bitmap is used as a replacement figure.

The isolated gallery at `tools/premium-v2/wraps/index.html` composes the actual body, current clothing and new hands. Its item views use exactly the same image and UV as the equipped view. Existing Cool/Guard sources remain unchanged.

## Integration contract

Manifest pieces are `wrap-cool0`, `wrap-cool1`, `wrap-guard0`, `wrap-guard1`, with slot `hands` on a 768×1216 canvas. They replace the entire gloves pair; do not draw gloves beneath them. Place hands last after garment/foreground-arm restoration. The manifest uses catalog key `hands: wraps`. One item, two pose-specific pairs; no new shop item.

Current scope is white wraps and body tone 6, Cool and Guard. Tiny exposed thumb/finger skin regions can use the existing semantic warm-skin recolor process; white cotton must be excluded. The isolated package does **not** claim eight-tone validation. Other poses have no support. All approved/enabled flags stay false and personal art acceptance remains open.

## Inspection outcome

Real browser detail canvases show continuous Guard wrist/cuff joins and Cool diagonal cuff alignment over the crossed forearms. Each fist has one visible thumb and a coherent curled-knuckle mass. The pair masters use pose-specific orientations: no claim that the Guard hand can rotate into Cool without redraw. White woven bandage texture and small skin areas remain distinct. No forearms, face or foreign clothing are baked into the isolated source art.

This adds two candidate pose cells for the existing wraps item, subject to integration gates and artistic acceptance. It is not a full hand rig or proven cross-pose master reuse. The material palette can reuse the same pixels once explicitly validated.

## Tests and evidence

`node tests/premium-v2-wraps.cjs` passes in Chromium and WebKit. Checks include RGBA/hash/byte integrity, native aspect registration, exact tile/source pixel parity, actual full-figure compositions, local-only requests, four deduplicated component requests across both poses, zero page errors, and 390px mobile overflow. These tests cannot certify anatomical quality; the captured close views are the art evidence.

See `tools/premium-v2/wraps/evidence/*-wraps-contact.png`, `*-cool-detail.png`, `*-guard-detail.png`, and browser JSON reports. The contact sheets contain actual before (existing gloves) and after (wraps) renders, plus isolated equipment sources. Generation provenance is `tools/premium-v2/wraps/provenance.json`.

## Integrated production extension

The production laboratory additionally validates all eight skin tones through `TLPremiumMaterials.wrapSkin`. Only exposed warm skin is recolored; neutral cotton is unchanged. This extension is covered by material and integrated production tests, independently of the tone-6 standalone wrap gallery.
