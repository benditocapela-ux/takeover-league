'use strict';
// Real published static build; all account/RPC data is local test data.
const assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),http=require('node:http');
const pw=require('playwright'),H=require('./takeover3-harness.cjs');
const out=path.resolve(process.env.SHOTS||'../../outputs/seven-hour/graphics');
const rows=[{rank_position:1,boxer_name:'Anna',monthly_points:900},{rank_position:2,boxer_name:'Ben',monthly_points:700},{rank_position:3,boxer_name:'Cleo',monthly_points:500}];
const config=`{users:[{id:'u-ben',email:'ben@test.invalid'}],tables:{profiles:[{id:'p-ben',auth_user_id:'u-ben',display_name:'Ben',role:'boxer',is_active:true}],league_feature_flags:[],training_types:[]},rpc:{get_public_leaderboard:${JSON.stringify(rows)},get_holo_looks:a=>({data:Object.fromEntries((a.p_display_names||[]).map(n=>[n,{pose_profile:n==='Cleo'?'jab':'guard',scene:'arena'}])),error:null}),get_card_looks:{},get_my_feedback:{enabled:false},league_training_audit_recent:[],get_training_v2_config:{enabled:false}}}`;
const scenarios={
  tied:[{rank_position:1,boxer_name:'First tie',monthly_points:900},{rank_position:1,boxer_name:'Second tie',monthly_points:900},{rank_position:3,boxer_name:'Third',monthly_points:700}],
  zero:rows.map(r=>({...r,rank_position:1,monthly_points:0})),
  two:rows.slice(0,2),
  empty:[],
  long:[{rank_position:1,boxer_name:'Maximilian Alexander der lange Boxername',monthly_points:123456},{rank_position:2,boxer_name:'UnunterbrochenExtremLangerBoxernameMitVielenZeichen',monthly_points:12345},{rank_position:3,boxer_name:'<img src=x onerror=alert(1)>',monthly_points:1234}]
};
const mime={'.html':'text/html; charset=utf-8','.js':'text/javascript','.css':'text/css','.json':'application/json','.png':'image/png','.webp':'image/webp','.svg':'image/svg+xml','.woff':'font/woff'};
async function layout(page,selector){return page.locator(selector).evaluate(host=>{
  const r=host.getBoundingClientRect();
  const names=[...host.querySelectorAll('.tl-podium-person-name')].map(n=>({name:n.textContent,width:n.clientWidth,scroll:n.scrollWidth}));
  const figures=[...host.querySelectorAll('.tl-podium-figure')].map(n=>({height:n.getBoundingClientRect().height,svg:!!n.querySelector('svg')}));
  return {height:r.height,width:r.width,left:r.left,right:r.right,viewport:innerWidth,overflow:document.documentElement.scrollWidth>innerWidth+1,names,figures};
})}
async function checkLayout(page,selector,width,label){
  const l=await layout(page,selector);
  assert.ok(!l.overflow,label+': page overflow at '+width);
  assert.ok(l.left>=-1&&l.right<=l.viewport+1,label+': podium fits viewport');
  assert.ok(l.height>=420,label+': enlarged stage');
  assert.ok(l.names.every(n=>n.scroll<=n.width+1),label+': all names wrap');
  assert.ok(l.figures.every(n=>n.height>=210),label+': larger full-body figure space');
  return l;
}
async function characterBounds(page){return page.locator('#ex-podium svg.tlh-anime').evaluateAll(async nodes=>{
 const host=document.getElementById('ex-podium').getBoundingClientRect(),results=[];
 for(const node of nodes){const image=new Image();image.src=node.querySelector('image').getAttribute('href');await image.decode();const cv=document.createElement('canvas');cv.width=image.width;cv.height=image.height;const g=cv.getContext('2d');g.drawImage(image,0,0);const d=g.getImageData(0,0,cv.width,cv.height).data;let x0=cv.width,x1=0,y0=cv.height,y1=0;
  for(let y=0;y<cv.height;y++)for(let x=0;x<cv.width;x++)if(d[(y*cv.width+x)*4+3]>20){x0=Math.min(x0,x);x1=Math.max(x1,x);y0=Math.min(y0,y);y1=Math.max(y1,y)}
  const r=node.getBoundingClientRect(),scale=Math.min(r.width/240,r.height/380),canvasLeft=r.left+(r.width-240*scale)/2,canvasTop=r.bottom-380*scale,left=canvasLeft+x0/cv.width*240*scale,right=canvasLeft+(x1+1)/cv.width*240*scale;
  const captionOverlaps=[];
  for(const cap of document.querySelectorAll('#ex-podium .tl-podium-caption')){
   if(cap.closest('.tl-podium-person')===node.closest('.tl-podium-person'))continue;
   const box=cap.getBoundingClientRect(),cx0=Math.max(0,Math.floor((box.left-canvasLeft)/(240*scale)*cv.width)),cx1=Math.min(cv.width,Math.ceil((box.right-canvasLeft)/(240*scale)*cv.width)),cy0=Math.max(0,Math.floor((box.top-canvasTop)/(380*scale)*cv.height)),cy1=Math.min(cv.height,Math.ceil((box.bottom-canvasTop)/(380*scale)*cv.height));let pixels=0;
   for(let y=cy0;y<cy1;y++)for(let x=cx0;x<cx1;x++)if(d[(y*cv.width+x)*4+3]>20)pixels++;
   if(pixels)captionOverlaps.push({caption:cap.textContent,pixels});
  }
  results.push({pose:node.dataset.tlPose,inside:left>=host.left&&right<=host.right,bounds:[x0,y0,x1,y1],left,right,captionOverlaps});
 }return results;
})}
(async()=>{
 fs.mkdirSync(out,{recursive:true});
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'league-podium-'));
 require('../tools/assemble-pages-site.cjs').assemble(process.cwd(),dir);
 const server=http.createServer((req,res)=>{const file=path.resolve(dir,'.'+decodeURIComponent(new URL(req.url,'http://x').pathname));if(!file.startsWith(dir+path.sep)||!fs.existsSync(file)||fs.statSync(file).isDirectory()){res.writeHead(404);return res.end()}res.writeHead(200,{'content-type':mime[path.extname(file)]||'application/octet-stream'});fs.createReadStream(file).pipe(res)});
 await new Promise(r=>server.listen(0,'127.0.0.1',r));const base='http://127.0.0.1:'+server.address().port,report=[];
 try{for(const name of ['chromium','webkit']){
  const browser=await pw[name].launch();
  try{
   const ctx=await H.context(browser,{config}),page=await ctx.newPage(),errors=[];page.on('pageerror',e=>errors.push(e.message));
   await page.goto(base+'/login.html');await page.fill('#email','ben@test.invalid');await page.fill('#password','pw');await page.click('#loginBtn');await page.waitForURL(/boxer-experience\.html/);await page.locator('#ex-app:not([hidden])').waitFor();
   await page.click('.ex-menu [data-tab="liga"]');
   await page.waitForFunction(()=>document.querySelectorAll('#ex-podium svg.tlh-anime').length===3,null,{timeout:90000});
   assert.deepEqual(await page.locator('#ex-podium .tl-podium-plinth b').allTextContents(),['2','1','3']);
   // An explicitly transparent Holo must stay transparent after the asynchronous Anime upgrade.
   const alpha=await page.locator('#ex-podium svg.tlh-anime image').first().evaluate(async node=>{const img=new Image();img.src=node.getAttribute('href');await img.decode();const cv=document.createElement('canvas');cv.width=img.width;cv.height=img.height;const g=cv.getContext('2d');g.drawImage(img,0,0);return {corner:g.getImageData(0,0,1,1).data[3],pixels:[...g.getImageData(0,0,cv.width,cv.height).data].filter((_,i)=>i%4===3).filter(a=>a>0).length}});
   assert.equal(alpha.corner,0,'scene:none produces transparent Anime');assert.ok(alpha.pixels>1000,'transparent image still contains the character');
   for(const width of [320,360,390,430,1000]){
    await page.setViewportSize({width,height:950});report.push({engine:name,surface:'authenticated',viewportWidth:width,...await checkLayout(page,'#ex-podium',width,'actual page')});
    assert.ok((await characterBounds(page)).every(r=>r.inside),'actual rendered hands and feet stay inside the arena at '+width);
    await page.locator('#ex-podium').screenshot({path:path.join(out,name+'-podium-after-'+width+'.png')});
   }
   // A scene override must also remain distinct in the same renderer cache.
   await page.evaluate(()=>{const host=document.createElement('div');host.id='scene-contract';host.innerHTML=TLHolo.svg({scene:'arena'},{scene:'dojo',holo:false});document.body.append(host)});
   await page.locator('#scene-contract svg.tlh-anime image').waitFor({timeout:90000});
   assert.equal(await page.locator('#scene-contract svg').evaluate(n=>JSON.parse(decodeURIComponent(n.dataset.tlAnime)).scene),'dojo');
   await page.locator('#scene-contract').evaluate(n=>n.remove());
   // All six actual pose compositions, including the wide Flex silhouette, fit mobile arena bounds.
   for(const poses of [['cool','sieg','flex'],['guard','jab','ansage'],['flex','jab','sieg'],['ansage','cool','guard'],['sieg','guard','cool'],['jab','flex','ansage']]){
    await page.evaluate(poses=>TLLeaguePodium.render(document.getElementById('ex-podium'),poses.map((pose,i)=>({boxer_name:['flex','ansage'].includes(poses[0])?['Maximilian Alexander Spitzenreiter','Alexander Maximilian Zweitplatzierter','Christopher Maximilian Drittplatzierter'][i]:pose,rank_position:i+1,monthly_points:900-i*100,pose})),{figure:r=>TLHolo.svg({pose_profile:r.pose,coat:'samurai',hands:'gloves',glove:'schwarzgold',bottomc:'schwarz',feetc:'schwarz',hair:'afro',tone:6},{pose:r.pose,scene:'none',holo:false})}),poses);
    await page.waitForFunction(()=>document.querySelectorAll('#ex-podium svg.tlh-anime').length===3,null,{timeout:90000});
    for(const width of [320,360,390,430,1000]){await page.setViewportSize({width,height:950});const bounds=await characterBounds(page);assert.ok(bounds.every(r=>r.inside),'six-pose silhouette inside arena '+width+' '+JSON.stringify(bounds));assert.ok(bounds.every(r=>!r.captionOverlaps.length),'no hands underneath adjacent names '+width+' '+JSON.stringify(bounds));await checkLayout(page,'#ex-podium',width,'pose '+poses[0])}
    await page.setViewportSize({width:390,height:950});await page.locator('#ex-podium').screenshot({path:path.join(out,name+'-podium-poses-'+poses.join('-')+'.png')});
   }
   for(const [scenario,data]of Object.entries(scenarios)){
    await page.evaluate(data=>TLLeaguePodium.render(document.getElementById('ex-podium'),data),data);
    const ranks=await page.locator('#ex-podium .tl-podium-plinth b').allTextContents();
    if(scenario==='tied'){assert.deepEqual(ranks,['1','1','3']);const heights=await page.locator('#ex-podium [data-rank="1"] .tl-podium-plinth').evaluateAll(ns=>ns.map(n=>n.getBoundingClientRect().height));assert.equal(heights[0],heights[1]);assert.match(await page.locator('#ex-podium').innerText(),/Gleichstand/)}
    if(scenario==='zero'||scenario==='empty'){assert.deepEqual(ranks,['–','–','–']);assert.equal(await page.locator('#ex-podium .tl-podium-crown').count(),0)}
    if(scenario==='two')assert.equal(await page.locator('#ex-podium [data-empty="true"]').count(),1);
    assert.equal(await page.locator('#ex-podium img').count(),0,'names are text and missing looks have a safe placeholder');
    for(const width of [320,360,390,430,1000]){await page.setViewportSize({width,height:950});await checkLayout(page,'#ex-podium',width,scenario)}
    await page.setViewportSize({width:390,height:950});await page.locator('#ex-podium').screenshot({path:path.join(out,name+'-podium-'+scenario+'.png')});
   }
   assert.deepEqual(errors,[]);await ctx.close();
   // Public page uses only the public avatar contract; guarded Holo data is never requested.
   const pub=await H.context(browser),p=await pub.newPage(),rpc=[];const publicErrors=[];p.on('pageerror',e=>publicErrors.push(e.message));
   await pub.route('https://iqarjivcrddcixrvqbfb.supabase.co/rest/v1/rpc/**',async route=>{const method=new URL(route.request().url()).pathname.split('/').pop();rpc.push(method);const data=method==='get_public_leaderboard'?rows:method==='get_public_boxer_avatars'?[{boxer_name:'Anna',avatar_key:'avatar-01'}]:[];await route.fulfill({status:200,contentType:'application/json',headers:{'access-control-allow-origin':'*'},body:JSON.stringify(data)})});
   await p.goto(base+'/index.html');await p.locator('#league-shared-podium .tl-podium-person').first().waitFor({timeout:30000});
   assert.equal(await p.locator('#league-shared-podium .league-avatar').count(),3);assert.ok(!rpc.includes('get_holo_looks'));
   assert.ok(!(await p.evaluate(()=>JSON.parse(localStorage.getItem('__tl_mock_log')||'[]'))).some(([method])=>method==='rpc:get_holo_looks'),'anonymous client never requests private Holo data');
   assert.doesNotMatch(await p.locator('#podium-content').innerText(),/Champion des Monats/);
   for(const width of [320,360,390,430,1000]){await p.setViewportSize({width,height:950});report.push({engine:name,surface:'public',viewportWidth:width,...await checkLayout(p,'#league-shared-podium',width,'public page')});await p.locator('#league-shared-podium').screenshot({path:path.join(out,name+'-public-podium-after-'+width+'.png')})}
   assert.deepEqual(publicErrors,[]);await pub.close();
   console.log('PASS '+name+': shared responsive podium, true ranks, ties, zeros, fewer than three, empty, long names, missing looks, transparent Anime, public access boundary');
  }finally{await browser.close()}
 }}finally{await new Promise(r=>server.close(r));fs.rmSync(dir,{recursive:true,force:true})}
 fs.writeFileSync(path.join(out,'podium-layout-report.json'),JSON.stringify(report,null,2)+'\n');
})().catch(e=>{console.error(e);process.exitCode=1});
