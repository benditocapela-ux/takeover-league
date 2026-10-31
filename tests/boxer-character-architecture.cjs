'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const ctx={window:{location:{search:'?art=modular'}},URLSearchParams};vm.createContext(ctx);
for(const f of ['takeover-holo.js','takeover-mein-boxer-modular-manifest.js','takeover-mein-boxer-artpack.js'])vm.runInContext(fs.readFileSync(f,'utf8'),ctx);
const {TLHolo:H,TLBoxerArtPacks:A,TLBoxerModularDraftManifest:m}=ctx.window;
assert.deepEqual([...H.POSES],['guard','jab','sieg','cool','flex','ansage']);
assert.deepEqual(Object.keys(H.POSE_DEFINITIONS),[...H.POSES]);
for(const key of H.POSES){
 const definition=H.POSE_DEFINITIONS[key];assert.equal(definition.id,key);
 assert.equal(definition.coordinateSpace,'svg-240x380');assert.ok(Object.isFrozen(definition));
 for(const side of ['imageLeft','imageRight'])for(const joint of ['shoulder','elbow','wrist']){
  const p=definition[side][joint];assert.ok(Object.isFrozen(p));assert.ok(Number.isFinite(p.x)&&Number.isFinite(p.y));
 }
 assert.deepEqual([...definition.armDrawOrder],['imageRight','imageLeft']);
 assert.equal(H.normalize({pose_profile:key,pose_card:key}).pose_card,key,'existing stored pose keys survive normalization');
}
assert.deepEqual(JSON.parse(JSON.stringify(H.POSE_DEFINITIONS.cool.imageLeft.wrist)),{x:134,y:142});
assert.equal(H.normalize({pose_profile:'unknown'}).pose_profile,'guard');
const cfg=H.normalize({tone:6,hair:'afro',hc:'schwarz',eye:'braun',hands:'gloves',glove:'schwarzgold',top:'none',bottom:'boxer',bottomc:'schwarz',feet:'boots',feetc:'schwarz',pose_profile:'cool'});
const draft=A.createDraft(m),before=JSON.stringify(cfg);
for(const pose of H.POSES.filter(p=>p!=='cool')){
 assert.equal(draft.choose(cfg,pose),null);assert.equal(draft.inspect(cfg,pose).state,'missing-pose');
 assert.match(H.svg(cfg,{pose}),/<svg/);
}
assert.equal(JSON.stringify(cfg),before,'render selection never changes the saved configuration');
// Declarative multi-pose lookup already accepts shared paths. This is schema
// coverage only, not a claim that the Cool artwork fits the Jab pose.
const schemaOnly={...m,approved:true,poses:{cool:m.poses.cool,jab:m.poses.cool},configurations:{cool:m.configurations.cool,jab:m.configurations.cool}};
assert.ok(A.create(schemaOnly).choose(cfg,'jab'));
assert.equal(A.create({...schemaOnly,configurations:{cool:m.configurations.cool}}).choose(cfg,'jab'),null,'incomplete per-pose constraints fail closed');
console.log('PASS: six central immutable SVG pose definitions, preserved keys, five unsupported raster poses and declarative future pose lookup');
