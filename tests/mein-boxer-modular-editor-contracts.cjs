'use strict';
// Exercise the editor's real hero/diagnostic functions with the real draft
// runtime. No network, saved profile mutations or artistic approval implied.
const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const html=fs.readFileSync('mein-boxer.html','utf8');
assert.match(html,/if\(new URLSearchParams\(location.search\)\.get\('art'\)==='modular'\)\{\s*try\{await import\('\.\/takeover-mein-boxer-modular-manifest\.js'\)/,
 'normal editor does not import the experimental manifest');
assert.match(html,/const modularPack=modularReview&&A\?\.createDraft/,'draft runtime is explicitly gated');
const hero=html.slice(html.indexOf('const heroArt='),html.indexOf("const COIN="));
const errorHandler=html.slice(html.indexOf("app.addEventListener('error'"),html.indexOf('// Roving tab focus:'));
function setup(mode){
 const pending=[],requests=[],preview={innerHTML:''},listeners={};
 const window={location:{search:mode==='modular'?'?art=modular':''},Image:class{
  set src(url){requests.push(url);pending.push(this)}
 }};
 const context=vm.createContext({window,URLSearchParams,console,preview,app:{querySelector:()=>preview,addEventListener:(type,fn)=>listeners[type]=fn}});
 for(const file of ['takeover-holo.js','takeover-mein-boxer-modular-manifest.js','takeover-mein-boxer-artpack.js'])
  vm.runInContext(fs.readFileSync(file,'utf8'),context);
 vm.runInContext(`
 const H=window.TLHolo,A=window.TLBoxerArtPacks;
 const modularReview=${mode==='modular'},modularPack=modularReview?A.createDraft(window.TLBoxerModularDraftManifest):null;
 const draftReview=false,draftPack=null,draftVisible=false,referenceReview=false,referenceVisible=false,referenceSrc=null;
 const liveCharacter=null; // This fixture exercises the isolated legacy draft renderer.
 const usePremiumArt=false,compareSvg=false,tryPremiumArt=false;
 const esc=s=>String(s).replace(/[&<>"']/g,'_');
 let cfg=H.normalize({}),previewPose='profile';
 `+hero+errorHandler,context);
 return {context,pending,requests,preview,listeners,run:code=>vm.runInContext(code,context)};
}
const matching={tone:6,eye:'braun',hc:'schwarz',head:'none',hands:'gloves',glove:'schwarzgold',hair:'afro',coat:'samurai',top:'none',bottom:'boxer',bottomc:'schwarz',feet:'boots',feetc:'schwarz',aura:'none',eyefx:'none',scene:'holo',pose_profile:'cool'};
async function drain(x){
 while(x.pending.length){x.pending.shift().onload();await Promise.resolve()}
 await Promise.resolve();await Promise.resolve();
}
(async()=>{
 const normal=setup('normal');
 normal.run('cfg=H.normalize('+JSON.stringify(matching)+')');
 assert.match(normal.run("heroArt(cfg,'cool')"),/<svg/,'normal URL retains SVG even with matching outfit');
 assert.equal(normal.requests.length,0,'normal editor does not download experimental art');
 assert.equal(normal.run("artDebugLabel(cfg,'cool')"),'','normal editor has no draft UI');

 const draft=setup('modular');
 const before=draft.run('JSON.stringify(cfg)');
 assert.match(draft.run("heroArt(cfg,cfg.pose_profile)"),/<svg/,'unsupported saved outfit stays SVG');
 assert.equal(draft.run('JSON.stringify(cfg)'),before,'opening draft never overwrites the saved outfit');
 assert.equal(draft.requests.length,0,'unsupported saved configuration does not download variants');
 assert.match(draft.run('artDebugLabel(cfg,cfg.pose_profile)'),/Entwurf – nicht freigegeben/,'fallback is visibly labelled as a draft');
 draft.run('cfg=H.normalize('+JSON.stringify(matching)+')');
 assert.match(draft.run("heroArt(cfg,'cool')"),/<svg/,'atomic preview retains SVG while any layer is pending');
 assert.equal(draft.requests.length,3,'shared loader limits initial concurrency');
 await drain(draft);
 assert.match(draft.preview.innerHTML,/data-artpack-draft="modular-cool"/,'loaded layer set replaces the SVG');
 assert.match(draft.preview.innerHTML,/Entwurf – nicht freigegeben/,'rendered artwork keeps the visible disclaimer');
 const count=draft.requests.length;
 draft.run('refreshHero();refreshHero()');
 assert.equal(draft.requests.length,count,'rerender reuses loaded image requests');
 assert.equal(draft.run('window.TLBoxerModularDraftManifest.approved'),false);
 assert.equal(draft.run('window.TLBoxerModularDraftManifest.enabled'),false);

 // Change configuration before asynchronous completion: only the current outfit
 // may appear, never an old selection from an image callback.
 draft.run("cfg.bottomc='rot';refreshHero();cfg.pose_profile='guard';refreshHero()");
 await drain(draft);
 assert.match(draft.preview.innerHTML,/<svg/,'stale completion cannot replace current unsupported pose');
 assert.doesNotMatch(draft.preview.innerHTML,/data-artpack-draft/);
 draft.run("cfg.pose_profile='cool';refreshHero()");
 assert.match(draft.preview.innerHTML,/data-artpack-draft/);
 draft.listeners.error({target:{matches:()=>true,getAttribute:()=> './assets/boxer-artpacks/v1/modular-cool/body.png'}});
 assert.match(draft.preview.innerHTML,/<svg/,'render-time image failure restores whole SVG');
 assert.match(draft.preview.innerHTML,/data-art-state="load-failed"/,'failure is recorded in the modular runtime');
 console.log('PASS: explicit modular editor gating, unchanged saved outfit, atomic loading, current-selection callbacks, caching, visible draft status and complete SVG fallback');
})().catch(e=>{console.error(e);process.exitCode=1});
