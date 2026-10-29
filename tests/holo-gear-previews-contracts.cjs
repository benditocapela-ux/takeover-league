'use strict';
// Echte Holo-Item-Grafiken statt reiner Textchips; keine neuen Daten- oder Berechtigungspfade.
const fs=require('node:fs'),assert=require('node:assert/strict'),vm=require('node:vm');
const html=fs.readFileSync('mein-boxer.html','utf8'),css=fs.readFileSync('takeover-redesign.css','utf8');
const holo=fs.readFileSync('takeover-holo.js','utf8'),kg=fs.readFileSync('takeover-kampfgeist.js','utf8');
const ctx={window:{}};vm.createContext(ctx);vm.runInContext(holo,ctx);vm.runInContext(kg,ctx);
const H=ctx.window.TLHolo,K=ctx.window.TLKG;
for(const k of ['head','top','bottom','hands','feet','coat','glove','aura','eyefx','scene']){
 assert.match(html,new RegExp("(?:slot===|field===)'"+k+"'"),'item look previews slot '+k);
}
assert.match(html,/function gearChip\(field,v,label,on,extra\)/);
assert.match(html,/H\.svg\(look,\{pose:'guard',scene,holo:false\}\)/);
assert.match(html,/class="mb-chip mb-gear-chip" data-set="\$\{field\}" data-val="\$\{esc\(v\)\}"/);
assert.match(html,/class="mb-shop-item-art" aria-hidden="true"/);
assert.match(css,/\.mb-gear-chip\{/);
assert.match(css,/\.mb-gear-head svg\.tlh/);
assert.match(css,/\.mb-gear-bottom svg\.tlh/);
assert.match(css,/\.mb-shop-item-art svg\.tlh/);
assert.match(css,/@media\(max-width:390px\)/);
const def=H.DEF;
for(const [slot,val] of [['top','hoodie'],['bottom','jogger'],['head','cap'],['hands','gloves'],['feet','sneaker'],['coat','samurai']]){
 const a=H.svg(def,{scene:'none',holo:false,pose:'guard'});
 const b=H.svg(Object.assign({},def,{[slot]:val}),{scene:'none',holo:false,pose:'guard'});
 // Generated internal SVG ids always differ; require the garment geometry to change too.
 assert.notEqual(a.replace(/tlh\d+/g,'tlhX'),b.replace(/tlh\d+/g,'tlhX'),'different geometry: '+slot);
}
const glove=K.gloveSVG({base:'#151923',acc:'#f1c94e',cuff:'#303947',pat:'star'});
assert.match(glove,/viewBox="0 0 180 130"/);
assert.equal((glove.match(/translate\(/g)||[]).length>=2,true,'two gloves visible in item preview');
assert.doesNotMatch([html,css,kg,holo].join('\n'),/sb_secret_|service_role/);
console.log('PASS: Mein Boxer – echte SVG-Kleidervorschauen, Shop-Itembilder, verschiedene Renderings, keine neuen RPCs oder Datenpfade');
