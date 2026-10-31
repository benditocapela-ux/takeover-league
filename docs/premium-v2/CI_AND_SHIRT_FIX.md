# CI dependency and registered shirt correction

Baseline: PR #82 at 52417178140efef1ede9c0242c197b7c45bb28f8. Production CI run 41231027103 failed with `ReferenceError: TLPremiumTops is not defined` in the deliberately clothing-free hair fixture; the later catalogue steps did not execute. Pilot and integration passed. Local browser success was never a substitute for this failed CI run.

## Dependency repair

Commit 4b0366f6069d4f37dfebd10145b274710c26e029 calls the shirt visibility helper only when a selection actually carries a shirt visibility mask. The hair-only fixture still excludes the optional Tops module and now asserts that fact. The original failure was reproduced locally; hair and tops tests then passed in Chromium/WebKit, followed by all 560 catalogue cells. CI run 41233895137 was queued when this note was prepared; do not infer success from the fix or local results.

## Shirt correction

See TOPS.md and the registered manifest for the separate Cool collar, shoulder visibility and foreground-arm changes. The original PNGs, head, corrected hands, pants and coats remain unchanged. Guard's shirt uses its own full-elbow outline; the existing tank registration is preserved. Figure and tile now share the same visible waistband crop.

Single-coverage arm restoration removes the dark boundary caused by applying a clipped clear and a clipped draw to the same antialiased edge. A strict full-raster regression rejects any changed pixel when restoring the skin already present. No pixel tolerance was raised and no test was removed.

Before/after evidence distinguishes the old rejected shirt inspection from current technically supported drafts. Artist approval remains outstanding. All productive activation flags remain false.

## Scope

Only the existing Premium V2 branch is changed. PR #79/#80/#81, original Cool artwork, trainer/training work, catalog keys, profile poses, ownership, coins and database remain untouched. No merge or deployment. Remaining premium item sources are Neon/Dragon; the other four poses and unverified coat/headwear combinations are still outside this package.

## Final local evidence

Chromium and WebKit each passed all 576 registered pose/item cells (292 variant keys). Inventory source hashes are valid: 50/52 technical entries, two partially supported poses, zero artistic approvals. Focused shirt coverage per engine: 128 material combinations, 16 pants/glove combinations, 36 hairstyle combinations and two exact full-raster edge regressions. Physical-device acceptance and successful CI on the final head remain release gates.
