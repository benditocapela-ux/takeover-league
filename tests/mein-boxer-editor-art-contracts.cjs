'use strict';
// Dynamic premium artwork must never become a fixed image that breaks selections.
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const holo=fs.readFileSync('takeover-holo.js','utf8');
const html=fs.readFileSync('mein-boxer.html','utf8');
const css=fs.readFileSync('takeover-mein-boxer.css','utf8');
const ctx={window:{}};
vm.createContext(ctx);
vm.runInContext(holo,ctx);
const H=ctx.window.TLHolo;
assert.match(html,/H\.svg\(cfg,\{pose,label:'Dein Boxer-Holo',premium:true\}\)/);
assert.match(css,/\.mb-gear-chip\[aria-pressed="true"\]/);
assert.match(css,/\.mb-preview/);
const def={...H.DEF,top:'shirt',topc:'schwarz',bottom:'boxer',bottomc:'schwarz'};
const config={...def,coat:'basic',hair:'afro',tone:6};
const premium=H.svg(config,{pose:'cool',premium:true,scene:'holo'});
const basic=H.svg(config,{pose:'cool',scene:'holo'});
assert.match(premium,/class="tlh-premium-coat"/);
assert.match(premium,/class="tlh-premium-fabric"/);
assert.match(premium,/class="tlh-premium-gear"/);
assert.match(premium,/radialGradient/);
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
