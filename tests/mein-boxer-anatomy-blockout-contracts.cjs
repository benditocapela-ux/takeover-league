'use strict';
// Tests the first editable anatomy blocking layer in isolation.
// This is an illustrator's trace, not a completed or publishable premium body.
const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
(async()=>{
 let revoked=0;
 class MockImage {
  set src(url){queueMicrotask(()=>{this.naturalWidth=768;this.naturalHeight=1216;this.onload?.()})}
 }
 const win={Image:MockImage,URL:{
  createObjectURL:f=>'blob:art/'+f.name,revokeObjectURL:()=>{revoked++}
 }};
 const ctx={window:win};vm.createContext(ctx);
 vm.runInContext(fs.readFileSync('takeover-mein-boxer-anatomy-blockout.js','utf8'),ctx);
 vm.runInContext(fs.readFileSync('takeover-mein-boxer-draft-layers.js','utf8'),ctx);
 const underpaint=win.TLBoxerAnatomyBlockout;
 assert.equal(underpaint.approved,false,'a sketch must never qualify as approved artwork');
 assert.equal(underpaint.version,0,'draft is versioned separately from production sprites');
 const sketch=underpaint.markup();
 assert.ok(sketch.includes('viewBox="0 0 768 1216"'),'identical pixel canvas');
 assert.ok(sketch.includes('mb-draft-underpaint'));
 assert.ok(sketch.includes('NOT')||sketch.includes('BLOCKOUT'),'embedded markup clearly identifies sketch');
 assert.ok(!/<script|<foreignObject|<image/i.test(sketch),'no script or external image content');
 assert.ok((sketch.match(/<path\b/g)||[]).length>=8,'actual editable anatomy paths');
 const kit=win.TLBoxerDraftPreview.create(win);
 const files=Array.from(win.TLBoxerDraftPreview.NAMES,name=>({
  name:name+'.png',type:'image/png',size:1012
 }));
 await kit.load(files);
 const cfg=kit.reference;
 const normal=kit.render(cfg,'cool');
 assert.ok(!normal.includes('mb-draft-underpaint'),'normal layer review remains pixel-exact');
 assert.equal((normal.match(/class="mb-artpack-img"/g)||[]).length,8);
 const traced=kit.render(cfg,'cool',win.TLBoxerDraftPreview.NAMES,true);
 assert.ok(traced.includes('mb-draft-underpaint'),'anatomy sketch appears only with opt-in');
 assert.equal((traced.match(/class="mb-artpack-img"/g)||[]).length,8,
  'actual reference art stays above the tracing sketch');
 assert.ok(traced.indexOf('mb-draft-underpaint')<traced.indexOf('mb-artpack-img'),
  'anatomy sketch must be behind original image layers');
 const stripped=kit.render(cfg,'cool',[],true);
 assert.ok(stripped.includes('mb-draft-underpaint'),'artist can isolate complete base sketch');
 assert.ok(!stripped.includes('mb-artpack-img'),'all existing masks can be hidden');
 assert.equal(kit.render({...cfg,coat:'none'},'cool',[],true),null,
  'tracing sketch cannot secretly replace an unsupported clothing variant');
 assert.equal(kit.render(cfg,'guard',[],true),null);
 kit.clear();assert.equal(revoked,8);
 const html=fs.readFileSync('mein-boxer.html','utf8');
 assert.ok(html.includes("import('./takeover-mein-boxer-anatomy-blockout.js')"));
 assert.ok(html.includes("data-draft-anatomy"));
 assert.ok(html.includes('draftAnatomy=false'),'draft stays off by default');
 assert.ok(html.includes("get('art')==='layers'"),'non-production URL gate exists');
 console.log('PASS: editable anatomy blockout is opt-in, behind 8 reference layers and non-production');
})().catch(e=>{console.error(e);process.exitCode=1});
