# Independent production-lab visual QA

Actual Chromium snapshots on localhost:41782, six states: Basiccoat / track trousers / wraps × Cool / Guard. Full-page screenshots include item tiles; figure PNGs are exported from the actual browser canvas.

- Basic Guard: coherent shoulder/sleeve/cuff silhouette in inspected render. No visible exposed-arm strip outside sleeve.
- Basic Cool: failed outer sleeve coverage. Two targeted Imagegen source edits substantially reduced the original bare-arm strip but left a shoulder crescent and thin outer elbow rim. Recommended to block this pose/item combination. Final defect remains approximately x210–252,y259–309 on the registered 768×1216 figure. No blanket CSS or registration shift applied.
- Track trousers: widened silhouette covers both leg profiles in Cool and Guard. Cuffs pass behind boots plausibly. No obvious side-skin strip.
- Wraps: hands selector yields the actual new equipment. Both pose-specific pairs meet forearms at the cuffs; matching item graphics use the same source design. Artistic acceptance remains open.

Original Basic Cool source and first correction are preserved here. Before-correction figure is `production-cool-basic-before-correction.png`; final figure is `production-cool-basic-figure.png`. Guard source was not edited. Root builder was rerun, with all activation flags false.

Next bounded family recommendation: one shared hijab headwear master for Cool/Guard, initially no coat/hood and with explicit full hair suppression. Both poses share the same head, so a genuine reused source is feasible. Restrict collar interactions until verified. A new full-sleeve hoodie/jacket family would repeat the unresolved silhouette/arm-occlusion problem and needs a longer dedicated pass.
