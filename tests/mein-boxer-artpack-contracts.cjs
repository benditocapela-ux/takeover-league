'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const read=p=>fs.readFileSync(p,'utf8');
const ctx={window:{}};
vm.createContext(ctx);
vm.runInContext(read('takeover-holo.js'),ctx);
vm.runInContext(read('takeover-mein-boxer-artpack-manifest.js'),ctx);
vm.runInContext(read('takeover-mein-boxer-artpack.js'),ctx);
const H=ctx.window.TLHolo,AP=ctx.window.TLBoxerArtPacks;
const html=read('mein-boxer.html'),css=read('takeover-mein-boxer.css');
assert.equal(ctx.window.TLBoxerArtPackManifest.approved,false,'production art is not approved yet');
assert.equal(ctx.window.TLBoxerArtPackManifest.enabled,false,'live artwork defaults to disabled');
assert.ok(html.includes('artManifest?.approved===true&&artManifest?.enabled===true'),
 'live artwork requires separate approval and enablement flags');
assert.ok(html.includes('const usePremiumArt=tryPremiumArt||livePremiumArt'),
 'approved artwork can be released independently of preview mode');
assert.ok(html.includes('if(usePremiumArt&&!compareSvg'),
 'live and preview share one safe rendering path');
assert.equal(AP.active.render(H.normalize(H.DEF),'guard'),null,'default editor still uses proven SVG');
assert.ok(html.includes("new URLSearchParams(location.search).get('art')==='preview'"));
assert.ok(html.includes("import('./takeover-mein-boxer-artpack.js')"));
assert.ok(html.includes("import('./takeover-mein-boxer-artpack-manifest.js')"));
assert.ok(html.includes("A.active.markFailed(img.getAttribute('src'))"));
assert.match(css,/\.mb-preview \.mb-artpack-img/);
const cfg=H.normalize({...H.DEF,tone:6,hair:'afro',hc:'schwarz',eye:'braun',top:'shirt',topc:'schwarz',
 bottom:'boxer',bottomc:'schwarz',feet:'boots',feetc:'schwarz',coat:'samurai',
 hands:'wraps',aura:'none',eyefx:'none',scene:'holo',pose_profile:'cool'});
const garmentLayers={
 coatBack:{samurai:'coats/samurai-back.webp'},
 body:{'6':'body/tone-6.webp'},
 bottom:{'boxer/schwarz':'bottom/boxer-black.webp'},
 feet:{'boots/schwarz':'feet/boots-black.webp'},
 top:{'shirt/schwarz':'top/shirt-black.webp'},
 eyes:{braun:'eyes/brown.webp'},
 hair:{'afro/schwarz':'hair/afro-black.webp'},
 coatFront:{samurai:'coats/samurai-front.webp'},
 hands:{wraps:'hands/wraps.webp'}
};
const manifest={version:1,approved:true,canvas:{width:768,height:1216},poses:{cool:garmentLayers}};
const build=AP.create(manifest);
const markup=build.render(cfg,'cool');
assert.equal(build.prepare(cfg,'cool'),false,'art remains SVG when preload cannot run');
assert.equal(build.inspect(cfg,'cool').state,'loading','preview describes unloaded approved layers');
assert.equal(build.inspect({...cfg,top:'hoodie'},'cool').state,'missing-layer','preview identifies missing outfit');
assert.match(build.inspect({...cfg,top:'hoodie'},'cool').detail,/top:hoodie/);
assert.equal(build.inspect(cfg,'guard').state,'missing-pose','preview identifies missing pose');
assert.equal(build.inspect({...cfg,scene:'arena'},'cool').state,'unsupported-effect');
assert.equal(AP.active.inspect(cfg,'cool').state,'unapproved','default manifest explains inactive art');
assert.ok(html.includes('artDebugLabel(cfg,pose)'),'preview diagnostics are coupled to the hero');
assert.ok(html.includes('data-art-compare="1"'),'approved preview supports SVG artwork comparison');
assert.ok(html.includes("if(compare&&canCompareArt)"),'comparison must be opt-in and approved');
assert.ok(html.includes("refreshHero();"),'comparison swaps the figure without rebuilding menus');
assert.ok(html.includes('if(!tryPremiumArt)return'), 'normal editor hides debugging details');
assert.ok(markup,'complete pack can be rendered');
assert.ok(markup.includes('data-artpack-version="1"'));
assert.equal((markup.match(/class="mb-artpack-img"/g)||[]).length,9);
assert.ok(!markup.includes('http:')&&!markup.includes('https:')&&!markup.includes('data:'));
assert.ok(!markup.includes('<svg')&&!markup.includes('<image'),'art must load external, correctly aligned files');
assert.equal(build.render({...cfg,top:'hoodie'},'cool'),null,'no mismatched shirt for hoodie selection');
assert.equal(build.render({...cfg,topc:'rot'},'cool'),null,'no silent colour substitution');
assert.ok(build.render({...cfg,coat:'none'},'cool'),'no coat is a valid outfit without coat images');
assert.equal(build.render({...cfg,aura:'flamme'},'cool'),null,'unsupported aura falls back to SVG');
assert.equal(build.render({...cfg,eyefx:'glut'},'cool'),null,'unsupported eye effect falls back to SVG');
assert.equal(build.render({...cfg,scene:'arena'},'cool'),null,'unsupported scene falls back to SVG');
assert.equal(build.render(cfg,'guard'),null,'missing crossed-arms pose falls back to SVG');
assert.equal(AP.create({...manifest,approved:false}).render(cfg,'cool'),null,'asset approval required');
assert.equal(AP.create({...manifest,canvas:{width:640,height:640}}).render(cfg,'cool'),null,'canvas must match exact coordinates');
assert.equal(AP.create({...manifest,poses:{cool:{...garmentLayers,top:{'shirt/schwarz':'../escape.webp'}}}}).render(cfg,'cool'),null,'parent traversal is refused');
assert.equal(AP.create({...manifest,poses:{cool:{...garmentLayers,top:{'shirt/schwarz':'https://evil.invalid/a.webp'}}}}).render(cfg,'cool'),null,'remote URLs are refused');
assert.equal(AP.create({...manifest,poses:{cool:{...garmentLayers,top:{'shirt/schwarz':'top/shirt.svg'}}}}).render(cfg,'cool'),null,'unreviewed SVG path refused');
assert.equal(build.markFailed('./assets/boxer-artpacks/v1/top/shirt-black.webp'),true);
assert.equal(build.render(cfg,'cool'),null,'failed layer causes entire figure to use SVG');
assert.equal(build.inspect(cfg,'cool').state,'load-failed','a missing image is diagnosed, not hidden');
assert.equal(build.markFailed('https://example.org/a.png'),false,'external URL cannot disable assets');
const hijab={...cfg,head:'hijab',headc:'schwarz'};
const hijabManifest={...manifest,poses:{cool:{...garmentLayers,head:{'hijab/schwarz':'head/hijab-black.webp'}}}};
const hijabHtml=AP.create(hijabManifest).render(hijab,'cool');
assert.ok(hijabHtml&&hijabHtml.includes('head/hijab-black.webp'));
assert.ok(!hijabHtml.includes('hair/afro-black.webp'),'hijab hides hair');
const withoutMantle={...cfg,coat:'none'};
const noCoatHtml=AP.create(manifest).render(withoutMantle,'cool');
assert.ok(noCoatHtml,'coat none does not need coat asset');
assert.ok(!noCoatHtml.includes('samurai-back.webp'));
assert.ok(!noCoatHtml.includes('samurai-front.webp'));
const withHood={...cfg,coat:'none',top:'hoodie',hood:true,head:'none'};
const hoodManifest={...manifest,poses:{cool:{...garmentLayers,top:{'hoodie/schwarz/up':'top/hoodie-up.webp'}}}};
const hoodHtml=AP.create(hoodManifest).render(withHood,'cool');
assert.ok(hoodHtml&&hoodHtml.includes('hoodie-up.webp'));
assert.ok(!hoodHtml.includes('hair/afro-black.webp'),'hood covers hair');
console.log('PASS: opt-in artpack selection, complete outfits, no mismatched art, safe paths, load-error fallback and SVG default');
