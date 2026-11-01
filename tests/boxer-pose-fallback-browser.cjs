'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),http=require('node:http'),vm=require('node:vm');
const playwright=require('playwright'),build=require('./boxer-pages-build.cjs');
const ctx={window:{}};vm.runInNewContext(fs.readFileSync('takeover-holo.js','utf8'),ctx);
const poses=[...ctx.window.TLHolo.POSES];
const initial=ctx.window.TLHolo.normalize({tone:6,hair:'afro',hc:'schwarz',eye:'braun',hands:'gloves',glove:'schwarzgold',top:'none',bottom:'boxer',bottomc:'schwarz',feet:'boots',feetc:'schwarz',pose_profile:'cool',pose_card:'guard'});
function mock({initial,poses}){
 window.__calls=[];window.__holdSave=false;window.__finishSave=null;
 let saved=JSON.parse(sessionStorage.getItem('pose-test-config')||JSON.stringify(initial));
 const rpc=async(name,args)=>{
  window.__calls.push([name,args]);
  if(name==='get_my_holo')return {data:{enabled:true,shop:true,coins:123,config:saved,bundles:[],items:[...poses.map(value=>({key:'pose_'+value,slot:'pose',value,name:value,owned:true,unlock:'start'})),{key:'gloves',slot:'glove',value:'schwarzgold',owned:true,unlock:'start'},{key:'hair',slot:'hair',value:'afro',owned:true,unlock:'start'}]},error:null};
  if(name==='save_my_holo'){
   if(window.__holdSave)await new Promise(r=>window.__finishSave=r);
   saved=structuredClone(args.p_config);sessionStorage.setItem('pose-test-config',JSON.stringify(saved));return {data:saved,error:null};
  }
  return {data:null,error:null};
 };
 const q={select(){return q},eq(){return q},order(){return q},limit(){return q},in(){return q},gte(){return q},lte(){return q},maybeSingle:async()=>({data:{role:'boxer',is_active:true},error:null}),then:r=>Promise.resolve({data:[],error:null}).then(r)};
 window.__takeoverMockClient={auth:{getSession:async()=>({data:{session:{access_token:'fixture'}}}),getUser:async()=>({data:{user:{id:'fixture'}}}),onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}})},from:()=>q,rpc};
}
const fixture=build.fixture();build.verify(fixture);
const root=process.cwd();
const server=http.createServer((req,res)=>{
 const url=new URL(req.url,'http://localhost'),release=url.pathname.startsWith('/release/'),prefix=release?'/release/':'/source/';
 const dir=release?fixture.directory:root,file=path.resolve(dir,decodeURIComponent(url.pathname.slice(prefix.length)));
 if(!url.pathname.startsWith(prefix)||!file.startsWith(dir+path.sep)){res.writeHead(403);res.end();return}
 fs.readFile(file,(e,data)=>{if(e){res.writeHead(404);res.end();return}res.setHeader('Content-Type',({'.html':'text/html','.js':'text/javascript','.css':'text/css','.png':'image/png','.svg':'image/svg+xml'})[path.extname(file)]||'application/octet-stream');res.end(data)});
});
(async()=>{
 await new Promise(r=>server.listen(0,'127.0.0.1',r));const base='http://127.0.0.1:'+server.address().port;
 try{for(const engine of (process.env.BROWSER||'chromium,webkit').split(',')){
  const browser=await playwright[engine].launch();
  try{
   const open=async(release=false,query='?art=modular',desktop=false)=>{
    const context=await browser.newContext({viewport:desktop?{width:1440,height:900}:{width:390,height:844},reducedMotion:'reduce'});
    await context.addInitScript(mock,{initial,poses});
    await context.route('**/*',r=>{const url=r.request().url();if(url.startsWith(base))return r.continue();return r.fulfill({contentType:url.includes('+esm')?'text/javascript':'application/json',body:url.includes('@supabase/supabase-js@2/+esm')?'export const createClient=()=>window.__takeoverMockClient;':'[]'})});
    const page=await context.newPage(),errors=[],art=[];page.on('pageerror',e=>errors.push(e.message));page.on('request',r=>{if(r.url().includes('/assets/boxer-artpacks/'))art.push(r.url())});
    await page.goto(base+(release?'/release/':'/source/')+'mein-boxer.html'+query);
    await page.waitForSelector('.mb-preview');return {page,context,errors,art};
   };
   const select=async(p,pose,field='pose_profile')=>{await p.locator('.mb-tabs [data-tab="posen"]').click();await p.locator(`[data-set="${field}"][data-val="${pose}"]`).click()};
   const ready=p=>p.waitForFunction(()=>document.querySelector('.mb-art-debug')?.dataset.artState==='ready');
   const svgPose=async(p,pose)=>{
    await p.waitForSelector('.mb-preview svg.tlh');
    assert.equal(await p.locator('.mb-preview .mb-artpack-img').count(),0);
    assert.ok(await p.evaluate(({initial,pose})=>{
     const h=window.TLHolo,c={...initial,pose_profile:pose,pose_card:pose};
     const div=document.createElement('div');div.innerHTML=h.svg(c,{pose,label:'Dein Boxer-Holo',premium:true,holo:false,layered:true});
     const normalize=s=>s.replace(/tlh\d+/g,'tlhID');
     return normalize(document.querySelector('.mb-preview svg.tlh').outerHTML)===normalize(div.querySelector('svg').outerHTML);
    },{initial,pose}),'fallback renders the requested pose, not a frozen Cool/Guard');
    const bounds=await p.evaluate(()=>{
     const svg=document.querySelector('.mb-preview svg.tlh'),fig=svg.querySelector('.tlh-fig');
     const preview=svg.closest('.mb-preview'),f=fig.getBoundingClientRect(),s=svg.getBoundingClientRect(),a=preview.getBoundingClientRect();
     return {figure:f.toJSON(),arena:a.toJSON(),visible:getComputedStyle(svg).overflow==='visible',extends:f.left<s.left-1||f.right>s.right+1,
      contained:getComputedStyle(preview).overflow==='visible'||(f.left>=a.left-1&&f.right<=a.right+1&&f.top>=a.top-1&&f.bottom<=a.bottom+1)};
    });
    assert.ok(!bounds.extends||bounds.visible,'wide SVG arms must not be clipped by the inner viewBox');
    assert.ok(bounds.contained,'complete '+pose+' pose must fit inside the arena: '+JSON.stringify(bounds));
   };
   const shot=async(p,name)=>{if(process.env.SHOTS){fs.mkdirSync(process.env.SHOTS,{recursive:true});await p.screenshot({path:path.join(process.env.SHOTS,engine+'-'+name+'.png')})}};
   for(const desktop of [false,true]){
    const x=await open(false,'?art=modular',desktop),p=x.page;await ready(p);const requestedArt=[...new Set(x.art)].sort();
    for(const pose of poses.filter(x=>x!=='cool')){await select(p,pose);await svgPose(p,pose);assert.equal(await p.locator('.mb-art-debug').getAttribute('data-art-state'),'missing-pose')}
    assert.deepEqual([...new Set(x.art)].sort(),requestedArt,'unsupported poses do not request replacement raster files');
    await select(p,'jab','pose_card');await svgPose(p,'jab');
    await p.locator('#resetBtn').click();assert.equal(await p.locator('#saveBtn').isDisabled(),true);
    assert.equal(await p.locator('[data-set="pose_profile"][data-val="cool"]').getAttribute('aria-pressed'),'true');
    assert.equal(await p.locator('[data-set="pose_card"][data-val="guard"]').getAttribute('aria-pressed'),'true');
    assert.equal((await p.evaluate(()=>window.__calls.filter(([n])=>/^(save_|buy_)/.test(n)))).length,0,'pose preview/reset never writes');
    await select(p,'jab');await p.evaluate(()=>window.__holdSave=true);await p.locator('#saveBtn').click();
    await p.waitForFunction(()=>typeof window.__finishSave==='function');await select(p,'flex');await p.evaluate(()=>window.__finishSave());
    await p.waitForFunction(()=>!document.querySelector('#saveBtn').disabled);
    await svgPose(p,'flex');await p.locator('#resetBtn').click();await svgPose(p,'jab');
    await p.reload();await svgPose(p,'jab');assert.equal(await p.locator('#saveBtn').isDisabled(),true,'saved unsupported raster pose survives reload');
    const saved=await p.evaluate(()=>JSON.parse(sessionStorage.getItem('pose-test-config')));
    assert.deepEqual(saved,{...initial,pose_profile:'jab'},'saving preserves all equipment and independent card pose keys');
    await shot(p,'pose-jab-'+(desktop?'desktop':'mobile'));assert.deepEqual(x.errors,[]);await x.context.close();
   }
   // A late supported-outfit load must not replace a newly selected SVG pose.
   let x=await open(),p=x.page;await ready(p);let release,seen;
   const gate=new Promise(r=>release=r),requested=new Promise(r=>seen=r);
   await x.context.route('**/modular-cool/bottom-red.png',async r=>{seen();await gate;await r.continue()});
   await p.locator('.mb-tabs [data-tab="kleidung"]').click();await p.locator('[data-set="bottomc"][data-val="rot"]').click();await requested;
   await select(p,'jab');const response=p.waitForResponse(r=>r.url().endsWith('/bottom-red.png'));release();await response;
   await p.waitForFunction(()=>document.querySelector('.mb-art-debug')?.dataset.artState==='missing-pose');
   assert.equal(await p.locator('.mb-preview .mb-artpack-img').count(),0);await p.waitForSelector('.mb-preview svg.tlh');await x.context.close();
   // Test the actual release assembly, including the draft URL with absent PNGs.
   for(const query of ['','?art=modular']){
    x=await open(true,query);p=x.page;
    if(query)await p.waitForFunction(()=>document.querySelector('.mb-art-debug')?.dataset.artState==='load-failed');
    if(query)await svgPose(p,'cool');else await p.waitForSelector('[data-premium-character][data-artpack-pose="cool"]',{timeout:60000});
    if(!query)assert.equal(x.art.length,0,'normal release never requests draft art');
    for(const pose of poses.filter(x=>x!=='cool')){await select(p,pose);if(!query)await p.waitForSelector('[data-premium-character][data-artpack-pose="'+pose+'"]',{timeout:60000});else await svgPose(p,pose)}
    assert.equal((await p.evaluate(()=>window.__calls.filter(([n])=>/^(save_|buy_)/.test(n)))).length,0);
    assert.deepEqual(x.errors,[]);await shot(p,'release-svg'+(query?'-draft-url':''));await x.context.close();
   }
   console.log('PASS '+engine+': all six poses, independent profile/card keys, reset/save race/reload, late image completion, actual release SVG/default and absent-draft fallback');
  }finally{await browser.close()}
 }}finally{await new Promise(r=>server.close(r));fixture.cleanup()}
})().catch(e=>{console.error(e);process.exitCode=1});
