'use strict';
// Build the real Pages payload and exercise it with local-only RPC fixtures.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os'),http=require('node:http');
const {assemble}=require('../tools/assemble-pages-site.cjs');
const engine=process.env.BROWSER||'chromium';
const root=process.cwd(),temp=fs.mkdtempSync(path.join(os.tmpdir(),'release-a-')),site=path.join(temp,'site');
const forbidden=['assets/boxer-artpacks','docs/review/PR79-Abnahme.zip','takeover-mein-boxer-artpack-manifest.js','takeover-mein-boxer-artpack.js','takeover-mein-boxer-modular-manifest.js','takeover-mein-boxer-draft-layers.js','takeover-mein-boxer-anatomy-blockout.js','tools/boxer-art-review.html'];
for(const f of forbidden)assert.equal(fs.existsSync(path.join(root,f)),false,'excluded from Release A: '+f);
const result=assemble(root,site);assert.ok(result.rootFiles>50&&result.avatarFiles>0);
assert.throws(()=>assemble(root,site),/empty/,'refuse stale build destinations');
for(const f of forbidden)assert.equal(fs.existsSync(path.join(site,f)),false,'excluded from Pages: '+f);
assert.equal(fs.existsSync(path.join(site,'docs')),false);
for(const f of ['mein-boxer.html','takeover-holo.js','takeover-mein-boxer.css','takeover-mein-boxer-items.js','takeover-mein-boxer-layers.js'])assert.ok(fs.statSync(path.join(site,f)).size);
assert.match(fs.readFileSync('.github/workflows/takeover-pages-deploy.yml','utf8'),/node tools\/assemble-pages-site.cjs _site/);
fs.writeFileSync(path.join(site,'news.json'),'{"entries":[]}');
const poses=['guard','jab','sieg','cool','flex','ansage'];
function mock(poses){
 let saved={pose_profile:'guard',pose_card:'guard'};
 window.__calls=[];
 const q={select(){return q},eq(){return q},maybeSingle:async()=>({data:{role:'boxer',is_active:true,display_name:'Release A'},error:null})};
 window.__client={auth:{getSession:async()=>({data:{session:{access_token:'fixture'}}}),getUser:async()=>({data:{user:{id:'fixture'}}}),onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}})},from:()=>q,rpc:async(name,args)=>{
  window.__calls.push([name,args]);
  if(name==='get_my_holo')return {data:{enabled:true,shop:true,coins:5000,saved:true,config:saved,items:poses.map(p=>({key:'pose_'+p,slot:'pose',value:p,name:p,owned:true})),bundles:[]},error:null};
  if(name==='save_my_holo'){saved=args.p_config;return {data:saved,error:null}}
  return {data:null,error:null};
 }};
}
(async()=>{
 const server=http.createServer((req,res)=>{
  const file=path.resolve(site,decodeURIComponent(new URL(req.url,'http://localhost').pathname.slice(1)));
  if(!file.startsWith(site+path.sep)){res.writeHead(403);res.end();return}
  fs.readFile(file,(err,data)=>{if(err){res.writeHead(404);res.end();return}res.setHeader('Content-Type',({'.html':'text/html','.js':'text/javascript','.css':'text/css','.json':'application/json','.svg':'image/svg+xml','.woff':'font/woff'})[path.extname(file)]||'application/octet-stream');res.end(data)});
 });
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const base='http://127.0.0.1:'+server.address().port;
 let browser;
 try{
  browser=await require('playwright')[engine].launch();
  const context=await browser.newContext({viewport:{width:390,height:844},reducedMotion:'reduce'});
  await context.addInitScript(mock,poses);
  await context.route('**/*',r=>{
   const url=r.request().url();
   if(url.startsWith(base+'/'))return r.continue();
   if(url==='https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm')return r.fulfill({contentType:'text/javascript',body:'export const createClient=()=>window.__client;'});
   return r.fulfill({contentType:'application/json',body:'[]'});
  });
  const page=await context.newPage(),errors=[],failures=[],premium=[];
  page.on('pageerror',e=>errors.push(e.message));
  page.on('request',r=>{if(/artpack|modular-manifest|draft-layers|anatomy-blockout/.test(r.url()))premium.push(r.url())});
  page.on('requestfailed',r=>failures.push(r.url()));
  page.on('response',r=>{if(r.status()>=400)failures.push(r.status()+': '+r.url())});
  for(const mode of ['', '?art=preview','?art=reference','?art=layers','?art=modular']){
   await page.goto(base+'/mein-boxer.html'+mode,{waitUntil:'networkidle'});
   await page.waitForSelector('.mb-preview svg.tlh');
   assert.equal(await page.locator('.mb-preview img,.mb-draft-tools,.mb-reference-tools,.mb-art-compare').count(),0);
   await page.click('[data-tab="posen"]');
   for(const pose of poses){
    for(const slot of ['pose_profile','pose_card']){
     await page.click(`[data-set="${slot}"][data-val="${pose}"]`);
     assert.equal(await page.locator(`[data-set="${slot}"][data-val="${pose}"]`).getAttribute('aria-pressed'),'true');
     assert.equal(await page.locator('.mb-preview svg.tlh').count(),1);
    }
    if(!await page.locator('#saveBtn').isDisabled()){
     await page.click('#saveBtn');await page.waitForSelector('#saveBtn:disabled');
     const config=await page.evaluate(()=>window.__calls.filter(c=>c[0]==='save_my_holo').at(-1)[1].p_config);
     assert.equal(config.pose_profile,pose);assert.equal(config.pose_card,pose);
    }
   }
   await page.click('[data-set="pose_profile"][data-val="jab"]');
   await page.click('#resetBtn');
   assert.equal(await page.locator('[data-set="pose_profile"][data-val="ansage"]').getAttribute('aria-pressed'),'true');
  }
  assert.deepEqual(errors,[],'no JS errors from isolated Pages payload');
  assert.deepEqual(failures,[],'no failed or missing resources');
  assert.deepEqual(premium,[],'no premium requests, including legacy preview URLs');
  console.log('PASS Release A '+engine+': actual Pages assembly, excluded assets, six poses/profile/card/save/reset, five URL modes, zero resource failures or premium requests');
 }finally{if(browser)await browser.close();await new Promise(r=>server.close(r));fs.rmSync(temp,{recursive:true,force:true})}
})().catch(e=>{console.error(e);process.exitCode=1});
