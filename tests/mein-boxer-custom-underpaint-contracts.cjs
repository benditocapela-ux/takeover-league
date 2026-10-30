'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
(async()=>{
 const created=[],revoked=[];
 class Img{
  set src(url){
   this._src=url;
   queueMicrotask(()=>{
    if(url.includes('invalid')){this.naturalWidth=1;this.naturalHeight=1}
    else {this.naturalWidth=768;this.naturalHeight=1216}
    this.onload?.();
   });
  }
 }
 const win={Image:Img,URL:{
  createObjectURL:file=>{const url='blob:local/'+file.name;created.push(url);return url},
  revokeObjectURL:url=>revoked.push(url)
 }};
 const ctx={window:win};vm.createContext(ctx);
 vm.runInContext(fs.readFileSync('takeover-mein-boxer-anatomy-blockout.js','utf8'),ctx);
 vm.runInContext(fs.readFileSync('takeover-mein-boxer-draft-layers.js','utf8'),ctx);
 const kit=win.TLBoxerDraftPreview.create(win),cfg=kit.reference;
 const named=Array.from(win.TLBoxerDraftPreview.NAMES,name=>({
  name:name+'.png',size:800,type:'image/png'
 }));
 await kit.load(named);
 assert.equal(kit.status().customUnderpaint,false,'real pixel masks load without a custom body');
 assert.ok(kit.render(cfg,'cool',[],true).includes('mb-draft-underpaint'),
  'original vector tracing remains default optional underpaint');
 const draft={name:'underpaint-v1.png',type:'image/png',size:29000};
 const r=await kit.loadUnderpaint(draft);
 assert.equal(r.customUnderpaint,true);
 const preview=kit.render(cfg,'cool',[],true);
 assert.ok(preview.includes('mb-draft-underpaint-file'),'selected PNG replaces rough vector sketch');
 assert.ok(preview.includes('blob:local/underpaint-v1.png'));
 assert.ok(!preview.includes('<svg'),'PNG should not contain the earlier vector trace');
 assert.equal(kit.render(cfg,'cool',[]).includes('mb-draft-underpaint'),false,
  'new body remains hidden until explicit anatomy opt-in');
 assert.equal(kit.render({...cfg,coat:'none'},'cool',[],true),null,
  'custom PNG never overrides incompatible outfits');
 await assert.rejects(kit.loadUnderpaint({name:'invalid.png',size:110,type:'image/png'}),
  /768 × 1216/,'incorrect canvas resolution rejected');
 assert.equal(kit.status().customUnderpaint,true,'failed replacement does not erase valid image');
 await assert.rejects(kit.loadUnderpaint({name:'body.svg',size:900,type:'image/svg+xml'}),
  /PNG/,'no SVG upload or scriptable image content');
 await assert.rejects(kit.loadUnderpaint({name:'huge.png',size:3*1024*1024,type:'image/png'}),
  /2 MiB/,'limit local artwork memory usage');
 assert.ok(revoked.includes('blob:local/invalid.png'),'bad image URLs are revoked');
 await kit.loadUnderpaint({name:'underpaint-v2.png',size:50000,type:'image/png'});
 assert.ok(revoked.includes('blob:local/underpaint-v1.png'),
  'replacing a valid body revokes the old image URL');
 kit.clearUnderpaint();
 assert.equal(kit.status().customUnderpaint,false);
 assert.ok(revoked.includes('blob:local/underpaint-v2.png'));
 assert.ok(kit.render(cfg,'cool',[],true).includes('<svg'),
  'removing the custom PNG restores original draft geometry');
 await kit.loadUnderpaint(draft);
 kit.clear();
 assert.equal(kit.status().customUnderpaint,false);
 assert.ok(revoked.filter(x=>x==='blob:local/underpaint-v1.png').length>=2,
  'leaving the editor revokes the custom artwork too');
 const html=fs.readFileSync('mein-boxer.html','utf8');
 assert.ok(html.includes('id="mb-underpaint-file"')&&html.includes('data-clear-underpaint'));
 assert.ok(html.includes('draftPack.loadUnderpaint(file)'));
 assert.ok(html.includes('if(!draftReview)return'),'file controls are not shown publicly');
 console.log('PASS: local body art is validated, replaceable, revocable and never used for unsupported outfits');
})().catch(e=>{console.error(e);process.exitCode=1});