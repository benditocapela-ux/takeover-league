# Shared Hijab master: bounded headwear family

One genuine transparent black sports-hijab PNG is shared unchanged between Cool and Guard. No face, skin or foreign clothing is baked into the source. Exact built-in image generation prompt and original source remain in `tools/premium-v2/headwear-hijab/`; the manifest records hashes, bytes, crop, UV and aspect-preserving registration.

## Integration

Load `headwear-hijab/hijab.js` and its manifest. `TLPremiumHijab.resolve(config,manifest)` supports `head:hijab`, `headc:schwarz`, Cool/Guard, `top:none`, `coat:none`, `hood:false`. It validates this headwear scope only; the parent outfit resolver must validate everything else. It returns one piece, `head-hijab-schwarz`, plus two explicit occlusion rules.

- `includeLayer(slot,selection)` returns false for every hair layer. No hair request is required. `maskHair(registeredHair,selection)` alternatively returns an empty 768×1216 canvas. This covers every catalog hairstyle by full suppression, not by claiming new hair art.
- `maskBody(currentRegisteredBody,selection)` removes only two ear regions, `[315,130,14,48]` and `[433,130,14,48]`, that otherwise leave a thin original outline outside the cloth. Pass the current materialized body so skin colors remain intact. Face and neck are not recolored or replaced.
- Draw masked body, other outfit layers, then hijab, then foreground hands. In Guard the fists must remain in front of the headwear. The source itself covers the neck; no second/back piece is necessary in this restricted configuration.

The same `draw` source/UV powers equipment tiles. One PNG supports two pose cells for one item/color. Other colors, tops, coats, hoods and poses return null. No production resolver changes were made. All approved/enabled flags stay false; personal artistic acceptance is pending. The existing Afro layer also contributes pixels around the eyes; suppressing that layer changes those pixels relative to the before-Afro view. The ear mask itself preserves eye pixels, while nose/mouth pixels match the real before render exactly.

## Evidence

`node tests/premium-v2-hijab.cjs` passes Chromium and WebKit: genuine RGBA/hash/byte checks, registration aspect, exact tile/source pixels, face landmark pixels preserved, ear regions masked, all catalog hairstyles suppressed, incompatible configs rejected, one deduplicated art request for both poses, local-only traffic and 390px layout. These checks complement visual inspection rather than certifying anatomy.

Real before/after browser sheets and face/neck detail canvases are in `headwear-hijab/evidence/`. After the ear-mask and hand-order corrections, brows, eyes, nose, mouth and chin remain visible; no scalp, hair or ear edge protrudes. The neck cloth joins the upper chest naturally in the bare-torso restriction. The source is reused byte-for-byte across poses: **one master, two pose compositions**, zero pose-specific redraw.

## Integrated material extension

The production laboratory resolves this black master and applies the shared eight-color head material palette under hijabMaterials:true. No extra PNG variants are downloaded. Material tests cover all eight colors in both poses; the standalone Hijab API retains its deliberately narrow black-source contract. All hair remains suppressed, including two-layer long-hair families.
