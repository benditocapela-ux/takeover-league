# Next clothing sprint — isolated drafts

Baseline: PR #82 at c11e527b6eb1fe8a3ffe107f3b3bbe27ff6cfc7f. Its production run 41227323379, pilot 41227323380 and integration 41227323465 all completed successfully. The former Linux-WebKit aura issue is closed for that baseline; subsequent commits require their own CI result.

## Implemented

- Cool hoodie: new crossed-sleeve cotton master registered at [190,210,390,345]. Existing raised Guard hood reused with exactly the same source, UV, box and material function. Eight material colours and both hood states; only without coat/headwear. No original Cool files changed.
- Guard training jacket: genuinely separate navy/gold sports garment, standing collar, central zipper, ribbing and zip pockets. Eight material colours, no coat/headwear/hood. Cool jacket remains SVG. The black material key retains the authored dark navy baseline; the seven other existing keys use the existing calibrated luminance ramp.
- Shirt inspection: replaced inverse-tank alpha with an explicit crossed-arm contour. Added registered body visibility to remove shoulder crescents. At 200%, Cool retains a neck triangle and questionable under-arm wedge; Guard elbow contour is still imperfect. **Both remain SVG; zero new supported shirt cells.** Passing centre-pixel tests does not override visual rejection.
- Figure and item tile use the same registered components. No separate thumbnails were generated. Pants/coat ownership is unchanged. Long-hair compatibility is unchanged; hood-up removes all hair pieces before loading and preserves the saved selection.

## Evidence

`premium-next-clothing.cjs`: 24 real garment/pants/glove combinations per engine, four pants, black/gold and white gloves; six explicit fallback gates. Actual 100%/200% browser crops in `evidence/next-clothing/`. Old shirt crops in that directory are rejected inspection candidates, never proof of supported artwork.

`premium-sprint.cjs`: 192 pants/coat cases, 288 premium hood/hair/tone cases, 288 SVG cases and 36 up/down/up transitions per engine. Counts increased because Cool now joins Guard; no previous case was removed. Exact per-pixel assertions remain unchanged.

`premium-v2-materials.cjs` now includes the actual new garment components, testing alpha, protected gold/non-material pixels and eight distinct materials. Streaming/effects and the full catalogue suite remain mandatory. Authoring gallery canvases now materialize their readback before being used as comparison surfaces, preventing intermittent empty WebKit snapshots; no tolerances or assertions were relaxed.

## Sources and reproduction

Generated with the built-in Imagegen skill; retained source PNGs and SHA-256/crop metadata accompany each registered piece. `scripts/build-premium-next-clothing.cjs` reproduces both exports from these sources and checks their exact hashes. Set CANVAS_MODULE to an installed @napi-rs/canvas module; default execution verifies, --write writes the verified exports. Original Guard hoodie/hood-up sources and approved Cool originals remain unchanged.

Cool prompt: use the Guard hoodie as the material reference and the original Cool body as the exact crossed-arm reference; output only the black cotton hoodie, hood down, kangaroo pocket, gold crown/drawstring ends, with no skin, hands, gloves, head or pants. Match shoulder/waist proportions, frontal view and upper-left lighting, transparent neck and background.

Jacket prompt: use Guard hoodie solely for raised-wrist Guard pose and scale; replace it with a distinct navy/gold boxing track jacket, short standing collar, straight gold central zipper, zipped side pockets, raglan piping, ribbed cuffs/hem, small gold crown, technical woven material, upper-left lighting, transparent neck/wrists/background. No hood, drawstrings, kangaroo pocket, body parts or other clothing.

## Boundaries and next concrete correction

No Neon/Dragon artwork, extra pose, or additional hair/headwear compatibility was enabled in this package. No shop, ownership, profile, database or trainer-dashboard change. PR #82 stays Draft; approved/enabled remain false. No merge/deployment; PR #79/#80/#81 are untouched.

Next: trace the remaining Cool neckline against the shared head component and remove the under-arm torso wedge from the arm-only contour; trace Guard's full elbow edge without clipping it. Reinspect both at 200% before adding any supported shirt pose. Artistic approval remains outstanding for every variant.

Measured reuse for the new hoodie package: the raised hood has identical source path, UV rectangle, world box, SHA-256 and encoded bytes for Cool and Guard; the reproducible builder asserts all five fields. New Cool sleeve/torso raster and new Guard jacket each decode to 390×345×4 = 538,200 bytes. No second hood source or pose-specific recolour PNGs were generated.


Final full-catalogue proof: 284 technically validated keys (+8), 560 pose/item cells (+24), 49/52 technical equipment entries (+1), 50/52 with artwork. Both engines passed all 560 cells. Two partial poses, zero artistic approvals and zero productive activation. The ID-sensitive reuse table counts 36 identical components; the shared raised hood additionally has different pose IDs but identical source pixels/registration, verified separately above.


The expanded contact-sheet test initially closed its browser while transferring the combined base64 gallery through the automation protocol. The gallery now stays within the page; only the finished contact PNG crosses that boundary. No cases, comparisons or tolerances were removed.


## Subsequent CI and shirt correction
The shirt blockage described above is historical. The subsequent registered correction is documented in TOPS.md and CI_AND_SHIRT_FIX.md; artistic approval and productive activation remain off.

