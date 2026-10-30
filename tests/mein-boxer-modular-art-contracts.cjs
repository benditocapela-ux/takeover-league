'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const ctx={window:{location:{search:''}},URLSearchParams};
vm.createContext(ctx);
for(const file of ['takeover-holo.js','takeover-mein-boxer-artpack-manifest.js',
 'takeover-mein-boxer-modular-manifest.js','takeover-mein-boxer-artpack.js'])
 vm.runInContext(fs.readFileSync(file,'utf8'),ctx);
const {TLBoxerArtPacks:A,TLBoxerModularDraftManifest:m,TLHolo:H}=ctx.window;
const assetReport=require('../scripts/validate-boxer-artpack.cjs').validate(m);
assert.equal(assetReport.checked,12,'all twelve real files pass dimension, alpha and mobile size budgets');
const cfg=H.normalize({...H.DEF,tone:6,hair:'afro',hc:'schwarz',eye:'braun',
 top:'none',head:'none',coat:'none',hands:'gloves',glove:'schwarzgold',
 bottom:'boxer',bottomc:'schwarz',feet:'boots',feetc:'schwarz',
 aura:'none',eyefx:'none',scene:'holo'});
assert.equal(m.approved,false);assert.equal(m.enabled,false);
assert.equal(ctx.window.TLBoxerArtPackManifest.approved,false);
assert.equal(ctx.window.TLBoxerArtPackManifest.enabled,false);
assert.equal(new Set(Object.values(m.poses.cool).flatMap(Object.values)).size,12,
 'draft specifies twelve independent image files');
assert.equal(A.create(m).render(cfg,'cool'),null,'standard runtime never renders disabled draft');
assert.equal(A.createDraft(m).render(cfg,'cool'),null,'normal URL cannot opt into draft');
ctx.window.location.search='?art=preview';
assert.equal(A.createDraft(m).render(cfg,'cool'),null,'original preview is separate');
ctx.window.location.search='?art=modular';
assert.equal(A.createDraft({...m,approved:true}).render(cfg,'cool'),null);
assert.equal(A.createDraft({...m,enabled:true}).render(cfg,'cool'),null);
assert.equal(A.createDraft({...m,draft:'other'}).render(cfg,'cool'),null);
const draft=A.createDraft(m);
let count=0;
for(const coat of ['none','samurai'])for(const top of ['none','tank'])
 for(const glove of ['schwarzgold','weiss'])for(const bottomc of ['schwarz','rot'])
 for(const hair of ['afro','kurz_glatt']){
  const selected={...cfg,coat,top,topc:'schwarz',glove,bottomc,hair};
  const markup=draft.render(selected,'cool');
  assert.ok(markup,JSON.stringify(selected));
  assert.match(markup,/data-artpack-draft="modular-cool"/);
  const layers=draft.choose(selected,'cool');
  assert.ok(layers.every(x=>x.src.startsWith('./assets/boxer-artpacks/v1/modular-cool/')));
  assert.equal(layers.some(x=>x.slot==='coatFront'),coat!=='none');
  assert.equal(layers.some(x=>x.slot==='top'),top!=='none');
  assert.ok(layers.find(x=>x.slot==='hands').src.endsWith(glove==='weiss'?'hands-white.png':'hands-blackgold.png'));
  assert.ok(layers.find(x=>x.slot==='hair').src.endsWith(hair==='afro'?'hair-afro.png':'hair-short.png'));
  assert.ok(layers.find(x=>x.slot==='bottom').src.endsWith(bottomc==='rot'?'bottom-red.png':'bottom-black.png'));
  assert.equal(draft.prepare(selected,'cool'),false,'no Image loader means retain SVG');
  count++;
 }
assert.equal(count,32);
for(const patch of [{tone:3},{feet:'sneakers'},{top:'shirt'},{hair:'glatze'},{hands:'wraps'},
 {glove:'rot'},{bottomc:'weiss'},{aura:'flamme'},{eyefx:'glut'}])
 assert.equal(draft.render({...cfg,...patch},'cool'),null,'unsupported variant falls back: '+JSON.stringify(patch));
assert.equal(draft.render(cfg,'guard'),null);
draft.markFailed('./assets/boxer-artpacks/v1/modular-cool/body.png');
assert.equal(draft.render(cfg,'cool'),null,'failed base invalidates entire drawing');
assert.equal(m.approved,false);assert.equal(m.enabled,false);
console.log('PASS: modular draft isolated behind explicit URL; 32 selections, twelve file paths and safe SVG fallback');
(async()=>{
 const pending=[];
 ctx.window.Image=class{set src(url){this.url=url;pending.push(this)}};
 const ready=A.createDraft(m);
 let notifications=0;
 const changed={...cfg,coat:'samurai',top:'tank',topc:'schwarz',glove:'weiss',
  bottomc:'rot',hair:'kurz_glatt'};
 assert.equal(ready.prepare(cfg,'cool',()=>notifications++),false);
 assert.equal(ready.prepare(cfg,'cool',()=>notifications++),false);
 assert.equal(pending.length,3,'at most three concurrent image loads');
 assert.equal(ready.prepare(changed,'cool',()=>notifications++),false);
 for(let i=0;i<12;i++){
  assert.ok(pending[i],'all twelve union assets scheduled');
  assert.equal(ready.prepare(changed,'cool'),false,'never expose partial revised outfit');
  pending[i].onload();
 }
 for(let i=0;i<32;i++)await Promise.resolve();
 assert.equal(pending.length,12,'overlapping selections share requests');
 assert.equal(notifications,2,'each distinct outfit completion calls back once');
 assert.equal(ready.prepare(cfg,'cool'),true);
 assert.equal(ready.prepare(changed,'cool'),true);
 assert.equal(ready.stats.maxActive,3);
 const failed=A.createDraft(m),offset=pending.length;
 let fallback=0;
 failed.prepare(cfg,'cool',()=>fallback++);
 const total=failed.choose(cfg,'cool').length;
 for(let i=0;i<total;i++){
  const img=pending[offset+i];
  if(i===0)img.onerror();else img.onload();
 }
 for(let i=0;i<32;i++)await Promise.resolve();
 assert.equal(fallback,1,'failed draft load refreshes SVG fallback');
 assert.equal(failed.prepare(cfg,'cool'),false);
 assert.equal(failed.inspect(cfg,'cool').state,'load-failed');
 console.log('PASS: modular draft preloads atomically, deduplicates shared files and reports failed loads');
})().catch(e=>{console.error(e);process.exitCode=1});
