# Merge integration and PR #80 reconciliation

The user authorized merging #79, #81 and #82 into current main, with manual acceptance after merge. Premium stays disabled; no deployment is authorized.

- Main baseline: 56668d90019ac4417df9c892b9394903d65e582e. Existing Training V2, Boxer Experience and routing changes are preserved.
- The release validation conflict is resolved by retaining both modular-art-browser and training-v2-browser jobs.
- Pages publication is explicitly paused with a false job condition. The dependent live-after-deploy verification is also paused; all local, staging and schema checks remain enabled. A separate deployment approval is needed before restoring these two conditions.
- #80 is a deliberately SVG-only alternative, not a required parent. Its holo renderer, layer module and transaction tests are already identical to #79. HTML/CSS differences remove premium/debug features rather than add missing editor behavior.
- Ported the useful #80 test improvements: selectable Chromium/WebKit engine, isolated external requests and explicit keyboard focus tests. Both editor and responsive tests now run in the existing two-engine matrix. Original raster and anatomy tests remain intact.
- The #80-only release-a-svg test assumes all premium modules are absent, including opt-in preview URLs; that is incompatible with the retained premium development branch. Existing Pages-build and pose-fallback tests enforce disabled production artwork without deleting the laboratory.
- #80 remains unmerged; no changes to ownership, coins, database data or activation flags are introduced.
