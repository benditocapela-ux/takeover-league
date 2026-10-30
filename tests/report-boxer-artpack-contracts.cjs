'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const {requirements,report}=require('../scripts/report-boxer-artpack.cjs');
const ctx={window:{}};vm.createContext(ctx);
vm.runInContext(fs.readFileSync('takeover-holo.js','utf8'),ctx);
vm.runInContext(fs.readFileSync('takeover-mein-boxer-artpack-manifest.js','utf8'),ctx);
const H=ctx.window.TLHolo,manifest=ctx.window.TLBoxerArtPackManifest;
const r=requirements(H);
assert.equal(r.pose,'cool');
assert.equal(r.first.length,9,'reference has nine independent figure layers');
assert.equal(r.first.find(x=>x.slot==='hair').key,'afro/schwarz','original style uses dark afro');
assert.equal(r.first.find(x=>x.slot==='coatFront').key,'samurai');
assert.equal(r.first.find(x=>x.slot==='body').key,'6');
const keys=new Set(r.expansion.map(x=>x.slot+':'+x.key));
assert.equal(keys.size,r.expansion.length,'no duplicate layer requirements');
for(const k of ['body:0','body:7','hair:afro/schwarz','hair:locs/schwarz',
 'top:hoodie/schwarz/up','top:hoodie/schwarz/down',
 'head:hijab/schwarz','hands:gloves/schwarzgold'])
 assert.ok(keys.has(k),'first-wave art coverage includes '+k);
const initial=report(manifest,H);
assert.equal(initial.approved,false);
assert.equal(initial.reference.present,0,'no production graphics falsely claimed');
assert.equal(initial.reference.missing.length,9);
assert.equal(initial.catalogue.hairstyles,18);
assert.equal(initial.catalogue.skinTones,8);
const preview={approved:true,poses:{cool:{body:{'6':'body/skin6.webp'},hair:{'afro/schwarz':'hair/afro.webp'}}}};
const partial=report(preview,H);
assert.equal(partial.reference.present,2);
assert.equal(partial.reference.missing.length,7);
assert.equal(partial.expansion.present,2);
console.log('PASS: first reference outfit and expansion coverage derived from actual editor keys');
