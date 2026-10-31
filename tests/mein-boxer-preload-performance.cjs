'use strict';
// Real Promise lifecycle, without network or Chromium: at most three image
// requests simultaneously, duplicate selections reuse pending loads.
const assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm');
(async()=>{
 let open=0,maxOpen=0;
 const started=[];
 class ImageMock{
  set src(url){
   this.url=url;
   open++;
   maxOpen=Math.max(maxOpen,open);
   started.push(this);
  }
 }
 const ctx={window:{Image:ImageMock}};
 vm.createContext(ctx);
 vm.runInContext(fs.readFileSync('takeover-mein-boxer-artpack.js','utf8'),ctx);
 const API=ctx.window.TLBoxerArtPacks;
 const config={
  tone:6,eye:'braun',hair:'afro',hc:'schwarz',head:'none',headc:'schwarz',
  coat:'samurai',top:'shirt',topc:'schwarz',bottom:'boxer',bottomc:'schwarz',
  feet:'boots',feetc:'schwarz',hands:'wraps',hood:false,aura:'none',
  eyefx:'none',scene:'holo'
 };
 const names={
  coatBack:{samurai:'coats/back.webp'},body:{'6':'body/6.webp'},
  bottom:{'boxer/schwarz':'bottom/b.webp'},feet:{'boots/schwarz':'feet/f.webp'},
  top:{'shirt/schwarz':'top/s.webp'},eyes:{braun:'eyes/b.webp'},
  hair:{'afro/schwarz':'hair/a.webp'},coatFront:{samurai:'coats/front.webp'},
  hands:{wraps:'hands/w.webp'}
 };
 const manifest={approved:true,version:1,canvas:{width:768,height:1216},poses:{cool:names}};
 const first=API.create(manifest);
 let notified=0;
 assert.equal(first.prepare(config,'cool',()=>{notified++}),false);
 assert.equal(started.length,3,'mobile preload starts only three requests');
 assert.equal(first.prepare(config,'cool',()=>{notified++}),false);
 assert.equal(started.length,3,'duplicate selection does not duplicate image requests');
 assert.equal(first.inspect(config,'cool').loaded,0,'unloaded art never counts as ready');
 for(let i=0;i<9;i++){
  const img=started[i];
  assert.ok(img,'queued image '+i+' started as a slot freed up');
  open--;
  img.onload();
  assert.ok(open<=3,'never above concurrency budget');
 }
 for(let i=0;i<32;i++)await Promise.resolve();
 assert.equal(first.stats.started,9,'each unique art image loaded once');
 assert.equal(first.stats.maxActive,3,'bounded simultaneous image requests');
 assert.equal(maxOpen,3,'mock independently saw only three open image requests');
 assert.equal(first.inspect(config,'cool').state,'ready');
 assert.equal(first.prepare(config,'cool'),true,'ready outfit appears atomically');
 assert.equal(notified,1,'shared pending request notifies editor only once');
 assert.equal(started.length,9,'re-render never downloads loaded images again');

 const second=API.create(manifest);
 const offset=started.length;
 let failures=0;
 assert.equal(second.prepare(config,'cool',()=>{failures++}),false);
 for(let i=0;i<9;i++){
  const img=started[offset+i];
  assert.ok(img,'all sprite assets attempted');
  open--;
  if(i===4)img.onerror();else img.onload();
 }
 for(let i=0;i<32;i++)await Promise.resolve();
 assert.equal(second.inspect(config,'cool').state,'load-failed');
 assert.equal(second.prepare(config,'cool'),false,'failed asset never displays partial art');
 assert.equal(failures,1,'a failed image still notifies the SVG fallback');
 assert.equal(second.stats.maxActive,3,'errors never exceed concurrency budget');
 assert.equal(open,0,'all background image attempts settle');
 console.log('PASS: sprite preloads capped to three concurrent images, shared, cached and fail-safe');
})().catch(e=>{console.error(e);process.exitCode=1});
