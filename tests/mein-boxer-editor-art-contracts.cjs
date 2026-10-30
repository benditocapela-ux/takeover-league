'use strict';
// Dynamic premium artwork must never become a fixed image that breaks selections.
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const holo=fs.readFileSync('takeover-holo.js','utf8');
const html=fs.readFileSync('mein-boxer.html','utf8');
const css=fs.readFileSync('takeover-mein-boxer.css','utf8');
const itemsJS=fs.readFileSync('takeover-mein-boxer-items.js','utf8');
const layersJS=fs.readFileSync('takeover-mein-boxer-layers.js','utf8');
const ctx={window:{}};
vm.createContext(ctx);
vm.runInContext(holo,ctx);
vm.runInContext(itemsJS,ctx);
vm.runInContext(layersJS,ctx);
const H=ctx.window.TLHolo,G=ctx.window.TLGearArt;
assert.match(html,/await import\('\.\/takeover-mein-boxer-items\.js'\)/);
assert.match(html,/G\.svg\(field,v,look\)/);
const types=[
 ['head','cap'],['head','band'],['head','hijab'],
 ['top','tank'],['top','shirt'],['top','hoodie'],['top','jacke'],
 ['bottom','boxer'],['bottom','kurz'],['bottom','jogger'],['bottom','track'],
 ['hands','wraps'],['hands','gloves'],['feet','boots'],['feet','sneaker'],
 ['glove','schwarzgold'],['coatPick','basic'],['coatPick','samurai']
];
for(const [slot,value] of types){
 assert.ok(G.supports(slot,value),'supported item '+slot+':'+value);
 const art=G.svg(slot,value,{topc:'schwarz',bottomc:'schwarz',headc:'schwarz',feetc:'schwarz',glove:'schwarzgold'});
 assert.match(art,/class="mb-item-svg"/);
 assert.match(art,/<linearGradient/);
 assert.doesNotMatch(art,/<image\b|data:image\//);
}
assert.notEqual(G.svg('top','hoodie',{topc:'schwarz'}).replace(/mbi\d+/g,'mbi'),G.svg('top','hoodie',{topc:'rot'}).replace(/mbi\d+/g,'mbi'),'colour selected in UI changes real art');
assert.notEqual(G.svg('top','tank',{}).replace(/mbi\d+/g,'mbi'),G.svg('top','hoodie',{}).replace(/mbi\d+/g,'mbi'),'different top geometries');
assert.equal(G.supports('glove','<script>'),false,'unknown item cannot be interpreted as HTML');
assert.equal(G.svg('glove','<script>',{}),'','unknown item cannot be rendered');

assert.ok(html.includes("await import('./takeover-mein-boxer-layers.js')"));
assert.ok(html.includes("H.svg(cfg,{pose,label:'Dein Boxer-Holo',premium:true,holo:false,layered:true})"));
assert.match(css,/\.mb-gear-chip\[aria-pressed="true"\]/);
assert.match(css,/\.mb-preview/);
const def={...H.DEF,top:'shirt',topc:'schwarz',bottom:'boxer',bottomc:'schwarz'};
const config={...def,coat:'basic',hair:'afro',tone:6};
const premium=H.svg(config,{pose:'cool',premium:true,scene:'holo'});
const basic=H.svg(config,{pose:'cool',scene:'holo'});
const layered=H.svg(config,{pose:'cool',premium:true,layered:true,holo:false});
for(const slot of ['outfit','coat','shirt','bottom','shoes','hair'])
 assert.ok(layered.includes('class="tl-layer-'+slot+'"'),'layer present: '+slot);
assert.ok(!layered.includes('<image')&&!layered.includes('data:image/'),'no raster embeddings');
assert.ok(!basic.includes('tl-layer-'),'public Holo unaffected');
const withoutCoat=H.svg({...config,coat:'none',hair:'locs',top:'tank'},{premium:true,layered:true});
assert.ok(!withoutCoat.includes('class="tl-layer-coat"'),'unworn coat has no overlay');
const withHijab=H.svg({...config,head:'hijab'},{premium:true,layered:true});
assert.ok(!withHijab.includes('class="tl-layer-hair"'),'headwear covers hair overlay');
const changedColours=H.svg({...config,topc:'weiss',bottomc:'rot'},{premium:true,layered:true});
assert.notEqual(layered.replace(/tlh\d+/g,'tlh'),changedColours.replace(/tlh\d+/g,'tlh'),'layer colours follow configured items');
let layerVariants=0;
for(const hair of H.HAIR_KEYS)for(let tone=0;tone<8;tone++)for(const top of ['none','shirt','hoodie']){
 const dynamic=H.svg({...config,hair,tone,top},{premium:true,layered:true,holo:false});
 assert.ok(dynamic.includes('class="tl-layer-bottom"'),'bottom layer for '+hair+'/'+tone+'/'+top);
 assert.ok(dynamic.includes('class="tl-layer-shoes"'),'shoe layer for '+hair+'/'+tone+'/'+top);
 assert.equal((dynamic.match(/<svg /g)||[]).length,1,'single root SVG for '+hair+'/'+tone+'/'+top);
 layerVariants++;
}
assert.equal(layerVariants,432,'full combination matrix coverage');
assert.match(premium,/class="tlh-premium-coat"/);
assert.match(premium,/class="tlh-premium-fabric"/);
assert.match(premium,/class="tlh-premium-gear"/);
assert.match(premium,/radialGradient/);
assert.match(premium,/class="tlh-premium-signature"/,'embroidery must render in premium mode');
assert.ok(premium.includes('>TAKEOVER</text>'),'waistband typography on premium boxer');
assert.match(premium,/class="tlh-premium-hair"/,'afro has separate detailed hair layer');
assert.equal((premium.match(/class="tlh-premium-arm"/g)||[]).length,2,
 'premium coat draws both individually shaded shoulder pieces');
const uncovered=H.svg({...config,coat:'none',top:'shirt'},{premium:true});
assert.equal((uncovered.match(/class="tlh-premium-sleeve"/g)||[]).length,2,
 'shirt sleeves remain dynamic without coat');
const bare=H.svg({...config,coat:'none',top:'none'},{premium:true});
assert.equal((bare.match(/class="tlh-premium-muscle"/g)||[]).length,2,
 'bare arms retain skin detail instead of forced sleeves');
assert.doesNotMatch(basic,/tlh-premium-arm/,'public figure arm geometry remains unchanged');

assert.doesNotMatch(basic,/tlh-premium-signature/,'public profile unaffected by premium embroidery');
const noCoat=H.svg({...config,coat:'none',hair:'locs'},{premium:true});
assert.doesNotMatch(noCoat,/class="tlh-premium-hair"/,'afro highlights hidden with other hairstyles');
assert.match(css,/\.mb-preview svg\.tlh \.tlh-fig/,'wider hero stays editor-only');

assert.equal((premium.match(/class="tlh-premium-eyes"/g)||[]).length,2,'premium face renders 2 anime eyes');
assert.doesNotMatch(basic,/tlh-premium-eyes/,'standard profile keeps its current eye style');
const green=H.svg({...config,eye:'gruen'},{pose:'cool',premium:true,holo:false});
assert.match(green,/tlh-premium-eyes/);
assert.doesNotMatch(green,/class="tlh-scan"/,'editor does not scan over premium fighter');
assert.doesNotMatch(basic,/tlh-premium-coat/);
assert.doesNotMatch(basic,/tlh-premium-fabric/);
for(const item of [
 {hair:'locs',tone:2,coat:'none',top:'hoodie',hood:true},
 {head:'hijab',coat:'samurai',hands:'gloves',glove:'glut'},
 {pose_profile:'jab',bottom:'track',feet:'sneaker',top:'tank'}
]){
 const changed=H.svg({...def,...item},{pose:item.pose_profile||'guard',premium:true,scene:'holo'});
 assert.match(changed,/class="tlh"/);
 assert.match(changed,/tlh-premium-gear/);
 assert.notEqual(changed.replace(/tlh\d+/g,'tlh'),premium.replace(/tlh\d+/g,'tlh'));
}
for(const key of ['get_my_holo','save_my_holo','buy_holo_item','buy_holo_bundle']){
 assert.ok(html.includes("'"+key+"'"),'preserved RPC '+key);
}
assert.doesNotMatch([css,html,holo].join('\n'),/data:image\/|<image\b|sb_secret_|service_role/);
assert.match(css,/\.mb-tabbody/);
assert.match(css,/overflow-y:auto/);
assert.match(css,/env\(safe-area-inset-bottom/);
console.log('PASS: premium boxer detail stays dynamic; mobile editor and RPC hooks preserved');
