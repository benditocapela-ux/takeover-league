'use strict';
// Pinned before/after comparison of actual published artwork in the same browser engine.
// No account APIs. PNG evidence stays in output/, never in the committed baseline.
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),http=require('node:http'),crypto=require('node:crypto'),cp=require('node:child_process'),assert=require('node:assert/strict'),pw=require('playwright');
const root=path.resolve(__dirname,'..'),out=path.resolve(process.env.SHIRT_QA_OUTPUT||path.join(root,'output/shirt-qa'));
const BASE='6aad6108dbf59e3f800cf42b4cdea8dec7e26b26',NEW_SOURCE='completion/assets/shirt-registered.png';
const flexOnly=process.argv.includes('--flex-only'),poses=flexOnly?['flex']:['jab','sieg','flex','ansage'],colors=['schwarz','rot','weiss'],coats=['none','samurai','basic'];
const changedPoses=new Set(['flex']); // Accepted artwork scope; the three other retarget poses stay unchanged.
const cases=(flexOnly?poses:['cool','guard',...poses]).flatMap(pose=>colors.flatMap(topc=>coats.map(coat=>({pose,topc,coat,key:[pose,topc,coat].join('-')}))));
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const fixtureText=fs.readFileSync(path.join(root,'tests/boxer-holo-browser.cjs'),'utf8').replace(/\r\n/g,'\n');
const accountFixture=fixtureText.slice(fixtureText.indexOf('function injected(cfg){'),fixtureText.indexOf('\n(async()=>'));
const holoSQL=fs.readFileSync(path.join(root,'supabase/migrations/20261029140000_boxer_holo.sql'),'utf8'),catalogueSQL=holoSQL.slice(holoSQL.indexOf('INSERT INTO public.holo_items'),holoSQL.indexOf('ON CONFLICT (key) DO NOTHING;'));
const catalogue=[...catalogueSQL.matchAll(/\('([a-z_]+)','([a-z]+)','((?:[^']|'')*)','([a-z]+)','([a-z]+)',(NULL|\d+),(NULL|'(\{[^']*\})'),(\d+)\)/g)].map(m=>({key:m[1],slot:m[2],value:m[1].slice(m[2].length+1),name:m[3],rarity:m[4],unlock:m[5],price:m[6]==='NULL'?null:+m[6]}));
fs.mkdirSync(out,{recursive:true});
function inventory(dir){const files=[];function walk(at){for(const e of fs.readdirSync(at,{withFileTypes:true})){const file=path.join(at,e.name);if(e.isDirectory())walk(file);else if(e.isFile()){const bytes=fs.readFileSync(file);files.push({path:path.relative(dir,file).split(path.sep).join('/'),bytes:bytes.length,sha256:sha(bytes)})}}}walk(dir);return files}
function baseline(){
 const dir=path.join(out,'baseline-site'),manifestPath=path.join(out,'baseline-manifest.json');
 if(!fs.existsSync(manifestPath)){
  try{cp.execFileSync('git',['cat-file','-e',BASE+'^{commit}'],{cwd:root,stdio:'pipe'})}catch{throw Error('Required baseline commit '+BASE+' is missing. Fetch repository history; this regression must not be skipped.')}
  const source=fs.mkdtempSync(path.join(os.tmpdir(),'shirt-baseline-source-')),archive=path.join(source,'baseline.tar');
  cp.execFileSync('git',['archive','--format=tar','-o',archive,BASE],{cwd:root});cp.execFileSync('tar',['-xf',archive,'-C',source]);
  const build=require(path.join(source,'tools/assemble-pages-site.cjs')).assemble(source,dir);
  fs.writeFileSync(manifestPath,JSON.stringify({head:BASE,capturedAt:new Date().toISOString(),build,files:inventory(dir)},null,2)+'\n');
  // Only the freshly generated directory under the platform temp root may be removed.
  assert.ok(fs.realpathSync(source).startsWith(fs.realpathSync(os.tmpdir())+path.sep));assert.ok(path.basename(source).startsWith('shirt-baseline-source-'));fs.rmSync(source,{recursive:true,force:true});
 }
 const manifest=JSON.parse(fs.readFileSync(manifestPath,'utf8'));assert.equal(manifest.head,BASE);
 for(const file of manifest.files){const target=path.resolve(dir,file.path);assert.ok(target.startsWith(dir+path.sep));assert.equal(sha(fs.readFileSync(target)),file.sha256,'immutable baseline '+file.path)}
 return {dir,manifest};
}
const before=baseline(),captureOnly=process.argv.includes('--baseline-only'),sites={baseline:before.dir};
let candidate=null,candidateInfo=null;if(!captureOnly){candidate=fs.mkdtempSync(path.join(out,'candidate-site-'));const build=require('../tools/assemble-pages-site.cjs').assemble(root,candidate);sites.candidate=candidate;candidateInfo={head:cp.execFileSync('git',['rev-parse','HEAD'],{cwd:root,encoding:'utf8'}).trim(),capturedAt:new Date().toISOString(),build,files:inventory(candidate)};fs.writeFileSync(path.join(out,'candidate-manifest.json'),JSON.stringify(candidateInfo,null,2)+'\n')}
const mime={'.html':'text/html','.js':'text/javascript','.json':'application/json','.png':'image/png','.css':'text/css','.svg':'image/svg+xml','.woff':'font/woff'};
const server=http.createServer((req,res)=>{
 const [name,...rest]=new URL(req.url,'http://local').pathname.slice(1).split('/'),site=sites[name];if(!site){res.writeHead(404);return res.end()}
 const local=rest.join('/');
 if(local==='shirt-fixture.html'){const meta=fs.readFileSync(path.join(site,'mein-boxer.html'),'utf8').match(/<meta name="tl-premium-character"[^>]*>/)[0];res.setHeader('Content-Type','text/html');return res.end('<!doctype html><html><head>'+meta+'<script src="./takeover-holo.js"></script></head><body><script type="module">window.shirtAdapter=await(await import("./takeover-premium-character.js")).init();document.body.dataset.ready="true"</script></body></html>')}
 const file=path.resolve(site,decodeURIComponent(local));if(!file.startsWith(site+path.sep)){res.writeHead(403);return res.end()}fs.readFile(file,(error,bytes)=>{if(error){res.writeHead(404);return res.end()}res.setHeader('Content-Type',mime[path.extname(file)]||'application/octet-stream');res.end(bytes)});
});
async function draw(page,row){return page.evaluate(async row=>{
 const P=TLPremiumCompletion,c=TLHolo.normalize({...P.defaults,pose_profile:row.pose,pose_card:'guard',top:'shirt',topc:row.topc,coat:row.coat,hair:'afro',head:'none',hood:false,bottom:'boxer',bottomc:'schwarz',hands:'gloves',glove:'schwarzgold',scene:'holo',aura:'none',eyefx:'none'});
 const r=await P.prepare(c);if(r.renderer!=='anime-draft')throw Error('Missing rendered shirt '+row.key+': '+r.reason);
 const cv=document.createElement('canvas');cv.width=768;cv.height=1216;const g=cv.getContext('2d',{willReadFrequently:true});
 const digest=async()=>[...new Uint8Array(await crypto.subtle.digest('SHA-256',g.getImageData(0,0,768,1216).data))].map(v=>v.toString(16).padStart(2,'0')).join('');
 P.draw(g,r.selection,r.images);const full=await digest(),png=cv.toDataURL();
 const shoulder=document.createElement('canvas');shoulder.width=560;shoulder.height=320;shoulder.getContext('2d').drawImage(cv,105,145,560,320,0,0,560,320);const shoulder1=shoulder.toDataURL();
 const zoom=document.createElement('canvas');zoom.width=1120;zoom.height=640;zoom.getContext('2d').imageSmoothingEnabled=false;zoom.getContext('2d').drawImage(shoulder,0,0,1120,640);const shoulder2=zoom.toDataURL();
 const layers={};for(const slot of ['hands','bottom']){P.draw(g,r.selection,r.images,slot);layers[slot]=await digest()}
 const bare=await P.prepare({...c,coat:'none'});if(bare.renderer!=='anime-draft')throw Error('No isolated shirt');P.draw(g,bare.selection,bare.images,'top');const top=await digest();
 const onlyTop={...bare.selection,pieces:bare.selection.pieces.filter(p=>p.slot==='top')};P.draw(g,onlyTop,bare.images,'top');if(await digest()!==top)throw Error('Body or coat contaminated item source');
 const topSources=[...new Set(onlyTop.pieces.map(p=>p.src))];const heroTopSources=[...new Set(r.selection.pieces.filter(p=>p.slot==='top').map(p=>p.src))];if(heroTopSources.some(src=>!topSources.includes(src)))throw Error('Hero shirt source differs from item shirt');
 const frame=P.itemFrame(bare.selection,'top'),target=document.createElement('canvas'),scale=Math.min(1,180/Math.max(frame[2],frame[3]));target.width=Math.max(1,Math.round(frame[2]*scale));target.height=Math.max(1,Math.round(frame[3]*scale));target.getContext('2d').drawImage(cv,...frame,0,0,target.width,target.height);const expected=target.toDataURL();
 const item=await new Promise((resolve,reject)=>{const t=setTimeout(()=>reject(Error('Item preview did not settle')),15000);const ready=()=>{const html=shirtAdapter.item(c,c.pose_profile,'top',ready);if(html){clearTimeout(t);resolve(html)}};ready()});const itemSrc=/src="([^"]+)"/.exec(item)[1];
 // Compare decoded RGBA through the same PNG round-trip on both sides.
 const images=await Promise.all([expected,itemSrc].map(src=>new Promise((resolve,reject)=>{const im=new Image();im.onload=()=>resolve(im);im.onerror=reject;im.src=src})));const pixels=[];for(const im of images){target.width=im.width;target.height=im.height;target.getContext('2d').drawImage(im,0,0);pixels.push(target.getContext('2d').getImageData(0,0,target.width,target.height).data)}
 if(pixels[0].length!==pixels[1].length||pixels[0].some((n,i)=>n!==pixels[1][i]))throw Error('Item adapter pixels differ from isolated real shirt '+row.key);
 return {key:row.key,config:c,full,layers,top,topSources,heroTopSources,frame,png,item:itemSrc,shoulder1,shoulder2};
},row)}
function savePNG(file,url){fs.writeFileSync(file,Buffer.from(url.split(',')[1],'base64'))}
async function contact(page,rows,file){const png=await page.evaluate(async rows=>{const cv=document.createElement('canvas');cv.width=1680;cv.height=1080;const g=cv.getContext('2d');g.fillStyle='#101a2b';g.fillRect(0,0,cv.width,cv.height);g.font='16px sans-serif';for(let i=0;i<rows.length;i++){const x=i%3*560,y=Math.floor(i/3)*360;g.fillStyle='#f5d788';g.fillText(rows[i].key+' · before / after',x+8,y+23);for(let j=0;j<2;j++){const im=new Image();im.src=rows[i][j?'after':'before'];await im.decode();g.drawImage(im,x+j*280,y+32,280,160)}const full=new Image();full.src=rows[i].full;await full.decode();g.drawImage(full,240,80,320,500,x+208,y+198,144,150)}return cv.toDataURL()},rows);savePNG(file,png)}
async function editor(browser,base,result){
 const initial=result.candidate.find(r=>r.key==='flex-schwarz-none').config;
 async function context(failed){const ctx=await browser.newContext({viewport:{width:390,height:844},reducedMotion:'reduce'});await ctx.addInitScript({content:'('+accountFixture+')('+JSON.stringify({visualDemo:true,items:catalogue,saved:initial})+')'});await ctx.route('**/*',route=>{const url=route.request().url();if(url.startsWith(base)){if(failed&&new URL(url).pathname.endsWith(NEW_SOURCE))return route.fulfill({status:404,body:'synthetic missing new shirt'});return route.continue()}if(url.includes('@supabase/supabase-js'))return route.fulfill({contentType:'text/javascript',body:'export const createClient=()=>window.__takeoverMockClient;'});if(/^(data:|blob:)/.test(url))return route.continue();return route.fulfill({contentType:'application/json',body:'[]'})});return ctx}
 const ctx=await context(false),page=await ctx.newPage(),errors=[];page.on('pageerror',e=>errors.push(e.message));await page.goto(base+'/candidate/mein-boxer.html?tab=kleidung');
 for(const pose of ['flex','jab','sieg','ansage'].filter(p=>poses.includes(p))){
  if(pose!=='flex'){await page.locator('.mb-tabs [data-tab="posen"]').click();await page.locator('[data-set="pose_profile"][data-val="'+pose+'"]').focus();await page.keyboard.press('Enter');await page.locator('.mb-tabs [data-tab="kleidung"]').click()}
  const expected=result.candidate.find(r=>r.key===pose+'-schwarz-none');
  await page.waitForFunction(({pose,hero,item})=>document.querySelector('.mb-preview [data-premium-character][data-artpack-pose="'+pose+'"] img')?.src===hero&&document.querySelector('[data-set="top"][data-val="shirt"] .mb-premium-item')?.src===item,{pose,hero:expected.png,item:expected.item},{timeout:60000});
  assert.equal(await page.locator('[data-set="top"][data-val="shirt"] .mb-item-status').getAttribute('data-renderer'),'anime');
  assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1));await page.screenshot({path:path.join(out,result.engine+'-editor-'+pose+'.png')});
 }
 assert.equal(await page.evaluate(()=>__calls.some(c=>c[0]==='save_my_holo'||c[0].startsWith('buy_'))),false);assert.deepEqual(errors,[]);await ctx.close();
 const broken=await context(true),bp=await broken.newPage(),brokenErrors=[];bp.on('pageerror',e=>brokenErrors.push(e.message));await bp.goto(base+'/candidate/mein-boxer.html?tab=kleidung');await bp.waitForFunction(()=>window.TLPremiumProduction?.loader.stats().failures>0);await bp.waitForSelector('.mb-preview svg.tlh');
 await bp.waitForFunction(()=>document.querySelector('[data-set="top"][data-val="shirt"] .mb-item-status')?.dataset.renderer==='svg');
 assert.equal(await bp.locator('.mb-preview [data-premium-character],.mb-preview .mb-artpack-img,[data-set="top"][data-val="shirt"] .mb-premium-item').count(),0,'new shirt PNG failure must yield a complete SVG hero and truthful item fallback');
 await bp.screenshot({path:path.join(out,result.engine+'-editor-new-shirt-404-svg.png')});
 await bp.locator('.mb-tabs [data-tab="posen"]').click();await bp.locator('[data-set="pose_profile"][data-val="jab"]').focus();await bp.keyboard.press('Enter');await bp.waitForSelector('.mb-preview [data-premium-character][data-artpack-pose="jab"]',{timeout:60000});
 assert.equal(await bp.locator('.mb-preview svg.tlh').count(),0,'missing Flex shirt must not downgrade unaffected Jab');
 assert.equal(await bp.evaluate(()=>__calls.some(c=>c[0]==='save_my_holo'||c[0].startsWith('buy_'))),false);assert.deepEqual(brokenErrors,[]);await broken.close();
 result.editor={poses:poses.length,heroAndItemExact:true,newPNG404FullSVGFallback:true,unaffectedJabStillAnime:true,noAccountWrites:true};
}
async function unchangedPoseRequests(browser,base,result){
 result.unchangedPoseNewSourceRequests={};
 for(const pose of ['jab','sieg','ansage']){
  const ctx=await browser.newContext(),requests=[],page=await ctx.newPage();await ctx.route('**/*',r=>r.request().url().startsWith(base)?r.continue():r.abort());page.on('request',r=>{if(new URL(r.url()).pathname.endsWith(NEW_SOURCE))requests.push(r.url())});
  await page.goto(base+'/candidate/shirt-fixture.html');await page.waitForFunction(()=>document.body.dataset.ready==='true');
  await page.evaluate(async configs=>{for(const c of configs){const r=await TLPremiumCompletion.prepare(c);if(r.renderer!=='anime-draft')throw Error('Unchanged pose no longer supports Anime')}},result.candidate.filter(r=>r.config.pose_profile===pose).map(r=>r.config));
  assert.equal(requests.length,0,pose+' in fresh context must not request Flex shirt source');result.unchangedPoseNewSourceRequests[pose]=0;await ctx.close();
 }
}
(async()=>{await new Promise(r=>server.listen(0,'127.0.0.1',r));const base='http://127.0.0.1:'+server.address().port,report={baseline:BASE,baselineVersion:before.manifest.build.premium.version,candidateVersion:candidateInfo?.build.premium.version,newSourceSHA:candidateInfo?.files.find(f=>f.path.endsWith(NEW_SOURCE))?.sha256,captureOnly,scope:flexOnly?'flex-smoke-only':'flex-updated-five-poses-unchanged',acceptedChangedPoses:[...changedPoses],canvas:[768,1216],shoulderCrop:[105,145,560,320],shoulderZoom:{native:1,nearestNeighbor:2},engines:[]};try{
 for(const engine of (process.env.BROWSER||'chromium,webkit').split(',')){
  const browser=await pw[engine].launch();try{
   const context=await browser.newContext({viewport:{width:1280,height:900},reducedMotion:'reduce'}),errors=[],external=[];await context.route('**/*',route=>{const u=route.request().url();if(u.startsWith(base)||/^(data:|blob:)/.test(u))return route.continue();external.push(u);return route.abort()});
   const result={engine,baseline:[],candidate:[],fullOutfitsUnchanged:0,coolGuardUnchanged:0,handsBottomUnchanged:0,itemParity:0};
   for(const phase of captureOnly?['baseline']:['baseline','candidate']){
    const dir=path.join(out,phase,engine);fs.mkdirSync(dir,{recursive:true});const page=await context.newPage(),newShirtRequests=[];page.on('pageerror',e=>errors.push(e.message));page.on('request',request=>{if(new URL(request.url()).pathname.endsWith(NEW_SOURCE))newShirtRequests.push(request.url())});await page.goto(base+'/'+phase+'/shirt-fixture.html');await page.waitForFunction(()=>document.body.dataset.ready==='true');
    for(const row of cases){const rendered=await draw(page,row);if(phase==='candidate'&&row.key==='guard-weiss-basic'){assert.equal(newShirtRequests.length,0,'Cool/Guard must not request the new pose-specific shirt PNG');result.newShirtRequestsBeforeRetarget=0}if(poses.includes(row.pose)){for(const [suffix,key]of [['full','png'],['item','item'],['shoulder-100','shoulder1'],['shoulder-200','shoulder2']])savePNG(path.join(dir,row.key+'-'+suffix+'.png'),rendered[key]);}result[phase].push(rendered);}
    await page.close();
   }
   if(!captureOnly){
    for(const row of cases){const a=result.baseline.find(x=>x.key===row.key),b=result.candidate.find(x=>x.key===row.key);if(!changedPoses.has(row.pose)){assert.equal(b.full,a.full,'Unchanged pose must stay pixel-identical: '+row.key);assert.ok(!b.topSources.some(src=>src.endsWith(NEW_SOURCE)),'unaccepted pose must retain its own shirt source');result.fullOutfitsUnchanged++;if(['cool','guard'].includes(row.pose))result.coolGuardUnchanged++}else assert.ok(b.topSources.some(src=>src.endsWith(NEW_SOURCE)),'registered shirt source used: '+row.key);if(poses.includes(row.pose)){for(const slot of ['hands','bottom'])assert.equal(b.layers[slot],a.layers[slot],slot+' unchanged: '+row.key);result.handsBottomUnchanged++}result.itemParity++}
    const page=await context.newPage();await page.goto(base+'/candidate/shirt-fixture.html');await page.waitForFunction(()=>document.body.dataset.ready==='true');for(const pose of poses){const rows=cases.filter(r=>r.pose===pose).map(r=>({key:r.key,before:result.baseline.find(x=>x.key===r.key).shoulder1,after:result.candidate.find(x=>x.key===r.key).shoulder1,full:result.candidate.find(x=>x.key===r.key).png}));await contact(page,rows,path.join(out,engine+'-'+pose+'-before-after-contact.png'))}await page.close();
   }
   if(!captureOnly){await editor(browser,base,result);if(!flexOnly)await unchangedPoseRequests(browser,base,result)}
   assert.deepEqual(errors,[]);assert.deepEqual(external,[]);for(const phase of ['baseline','candidate'])result[phase]=result[phase].map(({png,item,shoulder1,shoulder2,...r})=>r);report.engines.push(result);await context.close();
   console.log('PASS '+engine+': '+(captureOnly?cases.length+' pinned baseline outfits and isolated-item parity':result.fullOutfitsUnchanged+' unchanged full outfits ('+result.coolGuardUnchanged+' Cool/Guard); '+result.handsBottomUnchanged+' unchanged hands/bottom pairs; '+result.itemParity+' exact item previews; published editor/404 and no extra source requests'));
  }finally{await browser.close()}
 }
 fs.writeFileSync(path.join(out,captureOnly?'baseline-render.json':flexOnly?'shirt-flex-smoke-report.json':'shirt-registration-report.json'),JSON.stringify(report,null,2)+'\n');
}finally{await new Promise(r=>server.close(r))}})().catch(error=>{console.error(error);process.exitCode=1});
