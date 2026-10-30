'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
(async()=>{
 const created=[],revoked=[];
 class MockImg{
  set src(value){this._src=value;queueMicrotask(()=>{this.naturalWidth=768;this.naturalHeight=1216;this.onload?.()})}
 }
 const win={Image:MockImg,URL:{createObjectURL:file=>{const u='blob:test/'+file.name;created.push(u);return u},revokeObjectURL:u=>revoked.push(u)}};
 const ctx={window:win};vm.createContext(ctx);
 vm.runInContext(fs.readFileSync('takeover-mein-boxer-draft-layers.js','utf8'),ctx);
 const kit=win.TLBoxerDraftPreview;
 assert.equal(kit.NAMES.length,8);
 const cfg={tone:6,hair:'afro',hc:'schwarz',eye:'braun',head:'none',top:'none',
  coat:'samurai',bottom:'boxer',bottomc:'schwarz',feet:'boots',feetc:'schwarz',
  hands:'wraps',aura:'none',eyefx:'none',scene:'holo'};
 assert.equal(kit.compatible(cfg,'cool'),true);
 assert.equal(kit.compatible({...cfg,top:'hoodie'},'cool'),false,'other outfits lack actual anatomical underlayers');
 assert.equal(kit.compatible({...cfg,tone:5},'cool'),false,'skin recolour remains real Holo');
 assert.equal(kit.compatible({...cfg,hair:'locs'},'cool'),false,'other hairstyles remain Holo');
 assert.equal(kit.compatible(cfg,'guard'),false,'other poses are not painted');
 const kitInstance=kit.create(win);
 const files=Array.from(kit.NAMES,name=>({name:name+'.png',size:1200,type:'image/png'}));
 await assert.rejects(kitInstance.load(files.slice(0,7)),/genau acht/);
 await assert.rejects(kitInstance.load([...files.slice(0,7),files[0]]),/doppelter/);
 await assert.rejects(kitInstance.load([...files.slice(0,7),{name:'top.png',size:1000,type:'image/png'}]),/Ebenenname/);
 await assert.rejects(kitInstance.load([...files.slice(0,7),{name:'hands.png',size:3*1024*1024,type:'image/png'}]),/Ungültige/);
 await kitInstance.load(files);
 assert.equal(kitInstance.status().ready,true);
 assert.equal(kitInstance.status().layers,8);
 const markup=kitInstance.render(cfg,'cool');
 assert.equal((markup.match(/class="mb-artpack-img"/g)||[]).length,8);
 assert.equal((markup.match(/blob:test\//g)||[]).length,8);
 assert.equal(kitInstance.render({...cfg,coat:'none'},'cool'),null);
 assert.equal(kitInstance.render(cfg,'jab'),null);
 const onlyHair=kitInstance.render(cfg,'cool',['hair']);
 assert.equal((onlyHair.match(/mb-artpack-img/g)||[]).length,1,'mask inspector can isolate a single layer');
 assert.equal(onlyHair.includes('blob:test/hair.png'),true);
 assert.equal(onlyHair.includes('blob:test/body.png'),false,'hidden body cannot leak through mask inspector');
 assert.equal(kitInstance.render(cfg,'cool',[]).includes('mb-artpack-img'),false,
  'all layers can be hidden without changing config or downloads');
 assert.equal(kitInstance.render(kitInstance.reference,'cool')!==null,true,
  'approved reference look can be viewed independently of the player configuration');
 assert.equal(kitInstance.render({...cfg,hair:'locs'},'cool',['hair']),null,
  'inspecting layers does not bypass the outfit compatibility gate');
 await kitInstance.load(files);
 assert.equal(revoked.length,8,'reload removes eight prior object URLs');
 kitInstance.clear();
 assert.equal(revoked.length,16,'closing page removes all local object URLs');
 assert.equal(kitInstance.render(cfg,'cool'),null);
 const html=fs.readFileSync('mein-boxer.html','utf8');
 assert.ok(html.includes("get('art')==='layers'")&&html.includes('draftPack.render(normalized,pose,draftLayers,draftAnatomy)'));
 assert.ok(html.includes("draftPack.render(draftPack.reference,'cool',draftLayers)"),
  'the explicit reference view never saves another boxer configuration');
 assert.ok(html.includes('data-draft-layer')&&html.includes('data-draft-sample'),
  'local graphic inspector exposes layer masks and safe reference override');
 assert.ok(html.includes('if(draftReview&&draftPack&&draftVisible)'));
 assert.ok(html.includes('URL.revokeObjectURL(referenceSrc)'),'single-file review keeps its existing cleanup');
 console.log('PASS: local eight-layer preview is atomic, bounded, private and one-outfit-only');
})().catch(e=>{console.error(e);process.exitCode=1});
