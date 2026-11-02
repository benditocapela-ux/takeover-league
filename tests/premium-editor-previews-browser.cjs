'use strict';
// Published editor + actual premium renderer. Only account responses are mocked; PNGs and composition are real.
const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),os=require('node:os'),assert=require('node:assert/strict');
const source=fs.readFileSync('tests/boxer-holo-browser.cjs','utf8').replace(/\r\n/g,'\n');
const injected=source.slice(source.indexOf('function injected(cfg){'),source.indexOf('\n(async()=>'));
const sql=fs.readFileSync('supabase/migrations/20261029140000_boxer_holo.sql','utf8'),ins=sql.slice(sql.indexOf('INSERT INTO public.holo_items'),sql.indexOf('ON CONFLICT (key) DO NOTHING;'));
const items=[...ins.matchAll(/\('([a-z_]+)','([a-z]+)','((?:[^']|'')*)','([a-z]+)','([a-z]+)',(NULL|\d+),(NULL|'(\{[^']*\})'),(\d+)\)/g)].map(m=>({key:m[1],slot:m[2],value:m[1].slice(m[2].length+1),name:m[3],rarity:m[4],unlock:m[5],price:m[6]==='NULL'?null:Number(m[6])}));
const defaults={tone:6,hair:'afro',hc:'schwarz',eye:'braun',head:'none',top:'none',topc:'schwarz',hood:false,bottom:'boxer',bottomc:'schwarz',hands:'gloves',glove:'schwarzgold',feet:'boots',feetc:'schwarz',coat:'samurai',aura:'none',eyefx:'none',scene:'holo',pose_profile:'guard',pose_card:'jab'};
const output=path.resolve(process.env.SHOTS||'../../outputs/seven-hour/graphics');fs.mkdirSync(output,{recursive:true});
const mime={'.js':'text/javascript','.html':'text/html','.json':'application/json','.css':'text/css','.png':'image/png','.svg':'image/svg+xml','.webp':'image/webp','.woff':'font/woff'};
async function parity(page,configs){return page.evaluate(async configs=>{
 const checks=[];
 for(const {selector,look,pose,transparent}of configs){
  const actual=document.querySelector(selector);if(!actual)throw Error('Missing preview '+selector);await actual.decode();
  const c=TLHolo.normalize({...look,pose_profile:pose}),r=await TLPremiumCompletion.prepare(c);if(r.renderer!=='anime-draft')throw Error('Unexpected fallback');
  const selection=transparent?{...r.selection,effectsConfig:{...(r.selection.effectsConfig||r.selection.config),transparentScene:true}}:r.selection;
  const full=document.createElement('canvas');full.width=768;full.height=1216;TLPremiumCompletion.draw(full.getContext('2d'),selection,r.images);
  const a=document.createElement('canvas'),b=document.createElement('canvas');a.width=b.width=actual.naturalWidth;a.height=b.height=actual.naturalHeight;
  a.getContext('2d').drawImage(actual,0,0);b.getContext('2d').drawImage(full,0,0,768,1216,0,0,b.width,b.height);
  // The delivered preview is a PNG. Round-trip the reference through the same lossless format;
  // otherwise WebKit's canvas unpremultiplication compares hidden near-transparent RGB differently.
  const encoded=new Image();encoded.src=b.toDataURL('image/png');await encoded.decode();b.getContext('2d').clearRect(0,0,b.width,b.height);b.getContext('2d').drawImage(encoded,0,0);
  const ad=a.getContext('2d').getImageData(0,0,a.width,a.height).data,bd=b.getContext('2d').getImageData(0,0,b.width,b.height).data;let max=0;for(let i=0;i<ad.length;i++)max=Math.max(max,Math.abs(ad[i]-bd[i]));checks.push({selector,pose,max,width:a.width,height:a.height});
 }return checks;
},configs)}
(async()=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'editor-previews-'));require('../tools/assemble-pages-site.cjs').assemble(process.cwd(),dir);
 const server=http.createServer((req,res)=>{const file=path.resolve(dir,'.'+new URL(req.url,'http://x').pathname);if(!file.startsWith(dir+path.sep)){res.writeHead(403);return res.end()}fs.readFile(file,(e,data)=>{if(e){res.writeHead(404);return res.end()}res.setHeader('Content-Type',mime[path.extname(file)]||'application/octet-stream');res.end(data)})});
 await new Promise(r=>server.listen(0,'127.0.0.1',r));const base='http://127.0.0.1:'+server.address().port+'/';
 const all=[];
 try{for(const engine of (process.env.BROWSER||'chromium,webkit').split(',')){
  const browser=await require('playwright')[engine].launch();
  try{
   async function context(){const ctx=await browser.newContext({viewport:{width:390,height:844},reducedMotion:'reduce'});await ctx.addInitScript({content:'('+injected+')('+JSON.stringify({items,saved:defaults})+')'});await ctx.route('**/*',r=>{const u=r.request().url();if(u.startsWith(base)||/^(data:|blob:)/.test(u))return r.continue();if(u.includes('@supabase/supabase-js'))return r.fulfill({contentType:'text/javascript',body:'export const createClient=()=>window.__takeoverMockClient;'});return r.fulfill({contentType:'application/json',body:'[]'})});return ctx}
   const ctx=await context(),page=await ctx.newPage(),errors=[];page.on('pageerror',e=>errors.push(e.message));
   await page.goto(base+'mein-boxer.html?tab=posen');await page.waitForFunction(()=>document.querySelectorAll('[data-pose-preview] .mb-premium-figure').length===12&&document.querySelector('.mb-cardprev .mb-premium-figure'),null,{timeout:90000});
   assert.equal(await page.locator('[data-pose-preview] .mb-item-status[data-renderer="anime"]').count(),12);
   assert.ok(await page.locator('[data-pose-preview] .mb-lock').count()>0,'owned/locked state remains visible');
   const poses=['guard','jab','cool','sieg','flex','ansage'];
   const cases=['pose_profile','pose_card'].flatMap(field=>poses.map(pose=>({selector:`[data-set="${field}"][data-val="${pose}"] .mb-premium-figure`,look:{...defaults,[field]:pose},pose,transparent:true})));
   cases.push({selector:'.mb-cardprev .mb-premium-figure',look:defaults,pose:'jab',transparent:true});
   const poseChecks=await parity(page,cases);assert.ok(poseChecks.every(c=>c.max===0),'all 12 pose thumbnails + FUT picture equal the actual renderer: '+JSON.stringify(poseChecks));all.push({engine,poseChecks});
   for(const width of [320,360,390,430,1100]){await page.setViewportSize({width,height:900});assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),'editor viewport '+width)}
   await page.setViewportSize({width:390,height:844});await page.screenshot({path:path.join(output,engine+'-editor-premium-poses.png'),fullPage:true});
   // Rapid selections keep current artwork and keyboard focus, while profile/card fields stay independent.
   for(const pose of ['flex','cool','sieg','ansage']){await page.locator(`[data-set="pose_profile"][data-val="${pose}"]`).focus();await page.keyboard.press('Enter');}
   await page.waitForSelector('.mb-preview [data-premium-character][data-artpack-pose="ansage"]',{timeout:90000});
   await page.waitForFunction(()=>document.querySelectorAll('[data-pose-preview] .mb-premium-figure').length===12,null,{timeout:90000});
   assert.equal(await page.locator('[data-set="pose_card"][aria-pressed="true"]').getAttribute('data-val'),'jab');
   assert.equal(await page.evaluate(()=>document.activeElement?.dataset.val),'ansage');
   await page.locator('[data-set="pose_card"][data-val="jab"]').click();
   await page.locator('.mb-tabs [data-tab="shop"]').click();await page.waitForSelector('[data-bundle-preview] .mb-premium-figure',{timeout:90000});
   const bundle={...defaults,coat:'drache',aura:'flamme',eyefx:'glut',pose_profile:'ansage'};
   const bundleChecks=await parity(page,[{selector:'[data-bundle-preview="drachen_bundle"] .mb-premium-figure',look:bundle,pose:'ansage',transparent:false}]);assert.equal(bundleChecks[0].max,0);all.push({engine,bundleChecks});
   await page.locator('[data-try-bundle="drachen_bundle"]').click();await page.waitForSelector('.mb-preview [data-artpack-pose="ansage"]',{timeout:90000});
   assert.match(await page.locator('.mb-stage-bar').innerText(),/Profil-Pose/,'bundle switches preview to its profile pose');
   await page.locator('.mb-tabs [data-tab="posen"]').click();assert.equal(await page.locator('[data-set="pose_card"][aria-pressed="true"]').getAttribute('data-val'),'jab','bundle leaves card pose intact');
   await page.waitForFunction(()=>document.querySelectorAll('[data-pose-preview] .mb-premium-figure').length===12,null,{timeout:90000});
   await page.locator('.mb-tabs [data-tab="shop"]').click();await page.waitForSelector('[data-bundle-preview] .mb-premium-figure',{timeout:90000});await page.screenshot({path:path.join(output,engine+'-editor-premium-bundle.png'),fullPage:true});
   assert.equal(await page.evaluate(()=>window.__calls.some(c=>c[0]==='save_my_holo'||c[0].startsWith('buy_'))),false,'previews and try-on never write account data');
   // Isolated adapter instance, so pending UI jobs cannot contaminate the cache/request measurement.
   const cachePage=await ctx.newPage();await cachePage.goto(base+'mein-boxer.html?art=svg');await cachePage.waitForSelector('.mb-preview svg.tlh');
   const cache=await cachePage.evaluate(async defaults=>{
    const api=await(await import('./takeover-premium-character.js')).init();
    const draw=c=>new Promise((resolve,reject)=>{const timer=setTimeout(()=>reject(Error('Preview did not settle')),15000);const ready=()=>{const html=api.preview(c,'guard',ready,{scene:'none'});if(html){clearTimeout(timer);resolve(html)}};ready()});
    const first=await draw(defaults),before=api.stats().images.requests;
    for(let tone=0;tone<8;tone++)for(const hc of ['schwarz','braun','blond','rot'])await draw({...defaults,tone,hc});
    const image=new Image();image.src=/src="([^"]+)"/.exec(first)[1];await image.decode();const stats=api.stats();return {previews:stats.previews,cached:stats.cached,pending:stats.pending,extraImageRequests:stats.images.requests-before,width:image.width,height:image.height};
   },defaults);
   assert.equal(cache.previews,24);assert.ok(cache.cached<=128);assert.equal(cache.pending,0);assert.equal(cache.extraImageRequests,0,'material thumbnails reuse loaded source assets');assert.equal(cache.height,240);all.push({engine,cache});await cachePage.close();
   assert.deepEqual(errors,[]);await ctx.close();
   // Missing graphic assets must never advertise Anime in selectable pose or bundle cards.
   const broken=await context();await broken.route('**/assets/premium-character/**/*.png',r=>r.fulfill({status:404,body:'missing'}));const bp=await broken.newPage();await bp.goto(base+'mein-boxer.html?tab=posen');await bp.waitForSelector('.mb-pose-fig svg.tlh');await bp.waitForFunction(()=>window.TLPremiumProduction?.loader.stats().failures>0);assert.equal(await bp.locator('[data-pose-preview] .mb-item-status[data-renderer="svg"]').count(),12);assert.equal(await bp.locator('.mb-premium-figure').count(),0);await bp.locator('.mb-tabs [data-tab="shop"]').click();await bp.waitForSelector('[data-bundle-preview] .mb-item-status[data-renderer="svg"]');assert.equal(await bp.locator('[data-bundle-preview] .mb-premium-figure').count(),0);await broken.close();
   // A failed core module gives a bounded recoverable message, and a real retry reloads the editor.
   const retry=await context();await retry.route('**/takeover-holo.js',r=>r.abort());const rp=await retry.newPage();await rp.goto(base+'mein-boxer.html');await rp.locator('#editorRetry').waitFor({timeout:15000});assert.match(await rp.locator('#status').innerText(),/nicht vollständig geladen/);await retry.unroute('**/takeover-holo.js');await rp.locator('#editorRetry').click();await rp.locator('.mb-preview').waitFor({timeout:30000});await retry.close();
   console.log('PASS '+engine+': 12 exact pose previews + FUT, bundle pixel parity, independent poses, rapid edits/focus, responsive layout, no writes, truthful SVG fallback and retry');
  }finally{await browser.close()}
 }}finally{await new Promise(r=>server.close(r));fs.rmSync(dir,{recursive:true,force:true})}
 fs.writeFileSync(path.join(output,'editor-preview-parity.json'),JSON.stringify(all,null,2)+'\n');
})().catch(e=>{console.error(e);process.exitCode=1});
