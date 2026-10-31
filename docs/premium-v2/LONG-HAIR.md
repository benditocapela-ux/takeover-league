# Shared two-depth hair family production

Five existing catalog hairstyles are completed in the isolated authoring package: **locs, bob, lang_glatt, zopf, box_braids**. Each uses two genuine hair-only source masters (front/back), one transparent atlas, two shared-head poses and eight material colors. No pose-specific redraw, face/skin/ear pixels, beads, metal or accessories belong to the final sources.

## Stable schema and API

Manifest: `tools/premium-v2/long-hair/manifest.json`, version2. `families[hairKey]` contains `pieces:[id,id]`, shared `src`, and candidate status. The top-level flat `pieces` array remains available. IDs use `hair-<key>-back/front`, both slot `hair`, explicit `depth:back/front`, source URL, UV, native-aspect registration box, SHA256 and bytes. `sources[hairKey][depth]` records originals/crops/hashes.

`families.json` is the authored registration input: each depth specifies width, top, and optional horizontal center. Locs original source, atlas and registration remain unchanged. Zopf's rear source has an asymmetric center because its ponytail is on viewer-right, matching the existing SVG key; no global figure offset is applied.

`TLPremiumLongHair.resolve(config,manifest)` validates the family, Cool/Guard, all eight palette keys, head none, hood false and coat none. It validates only hair scope. Parent outfit validation remains required. `draw(ctx,selection,images,depth)` uses existing `hair-*` semantic material handling.

Render order: background → back hair → body/clothes → front hair → foreground hands. Do not draw all hair at one depth. Item views combine both pieces in registered positions without a body. Hijab's explicit hide-all-hair policy must suppress both depths; other headwear/coat interactions are outside this package's support.

## Completed family inspections

| Key | Shape | Specific check |
| --- | --- | --- |
| locs | Thick textured loc ropes, short front ends and longer rear lengths | Fringe clears eyes, no beads |
| bob | Smooth chin-length bob and short rounded bangs | Hair ends fit jaw region; eyes remain visible |
| lang_glatt | Straight center-parted long hair | Fine front wisps and rear lengths join without scalp gap |
| zopf | Swept-back side ponytail | Hair-wrapped attachment is connected; no foreign tie material |
| box_braids | Many slender three-strand braids | Front root strip corrected to hair; discarded original retained |

All five compact eight-color/two-pose browser sheets were visually inspected. Bright colors preserve strand shape and alpha, front/back shading remains coherent, and Guard fists stay in front. Artistic acceptance remains pending.

## Coverage and evidence

Five hairstyles × eight colors × two poses = **80** technically inspected appearance cells. Ten final source masters become five atlas PNGs, with one image request per selected family. This proves reuse for the current Cool/Guard shared head camera, not a full rig or six-pose support.

`node tests/premium-v2-long-hair.cjs` runs every family in Chromium and WebKit. Optionally set `HAIR` to one family for focused verification. Checks include PNG/hash/bytes/native aspect, material alpha invariance, black original pixel identity, actual 80 compositions per engine, unsupported configurations rejected, unchanged eye centers, one deduplicated atlas request, zero page errors and 390px overflow. The existing body's alpha is253 in some face pixels; rear hair changes nose/mouth composite channels by at most3/255, explicitly bounded rather than falsely reported as exact whole-face identity.

Use `long-hair/index.html?family=bob` (or another key) for the actual gallery. Before views show the existing short hairstyle; after views are the new family. Evidence names include browser/family, with `*-eight-color-contact.png` for compact16-state sheets and `*-locs-contact.png` for complete figure galleries (legacy filename suffix retained).

Original sources, exact prompts and source hashes remain in the package. Box-braids front correction provenance is explicit. A redundant Locs extraction generation was discarded because the original already had alpha while the retry cropped strands.

All approved/enabled flags remain false. No production.js changes, commits, merge or deployment were performed by this package's agent.
