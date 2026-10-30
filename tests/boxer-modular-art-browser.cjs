'use strict';
// Browser integration of the twelve repository PNGs. Successful rendering proves
// technical assembly only; it does not approve illustration quality or anatomy.
const assert=require('node:assert/strict'),fs=require('node:fs'),http=require('node:http'),path=require('node:path');
const playwright=require('playwright');
const root=process.cwd(),artRoot='assets/boxer-artpacks/v1/modular-cool/';
const filenames=['body','bottom-black','bottom-red','coatback','coatfront','eyes','feet','hair-afro','hair-short','hands-blackgold','hands-white','top-tank'];
for(const name of filenames)assert.ok(fs.existsSync(artRoot+name+'.png'),'required real repository artwork: '+name);
const initial={tone:6,hair:'afro',hc:'schwarz',eye:'braun',eyefx:'none',head:'none',headc:'schwarz',top:'none',hood:false,topc:'schwarz',bottom:'boxer',bottomc:'schwarz',hands:'gloves',glove:'schwarzgold',feet:'boots',feetc:'schwarz',coat:'none',aura:'none',scene:'holo',pose_profile:'cool',pose_card:'cool'};
function mock(config){
 const items=[['hair','afro'],['hair','kurz_glatt'],['coat','samurai'],['glove','schwarzgold'],['glove','weiss'],['pose','cool']].map(([slot,value])=>({key:slot+'_'+value,slot,value,name:value,owned:true,unlock:'start',rarity:'common'}));
 window.__calls=[];
 const rpc=async(name,args)=>{
  window.__calls.push([name,args]);
  if(name==='get_my_holo')return {data:{enabled:true,shop:true,display_name:'Modular-Test',coins:0,config,items,bundles:[]},error:null};
  if(name==='get_my_performance')return {data:null,error:null};
  if(name==='save_my_holo')return {data:args.p_config,error:null};
  return {data:null,error:null};
 };
 const q={select(){return q},eq(){return q},order(){return q},limit(){return q},in(){return q},gte(){return q},lte(){return q},maybeSingle:async()=>({data:{role:'boxer',is_active:true,display_name:'Modular-Test'},error:null}),then:r=>Promise.resolve({data:[],error:null}).then(r)};
 window.__takeoverMockClient={auth:{getSession:async()=>({data:{session:{access_token:'test'}}}),getUser:async()=>({data:{user:{id:'test'}},error:null}),onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}})},from:()=>q,rpc};
}
const requested=(process.env.BROWSER||'chromium,webkit').split(',');
for(const engine of requested)assert.ok(['chromium','webkit'].includes(engine),'supported engine');
if(process.env.SHOTS)fs.mkdirSync(process.env.SHOTS,{recursive:true});
const server=http.createServer((req,res)=>{
 const file=path.resolve(root,decodeURIComponent(new URL(req.url,'http://localhost').pathname.slice(1)));
 if(!file.startsWith(root+path.sep)){res.writeHead(403);res.end();return}
 fs.readFile(file,(error,bytes)=>{if(error){res.writeHead(404);res.end();return}
  res.setHeader('Content-Type',({'.js':'text/javascript','.html':'text/html','.css':'text/css','.json':'application/json','.png':'image/png'})[path.extname(file)]||'application/octet-stream');res.end(bytes)});
});
(async()=>{
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const base='http://127.0.0.1:'+server.address().port;
 try{for(const engine of requested){
  const browser=await playwright[engine].launch();
  try{
   async function page(){
    const context=await browser.newContext({viewport:{width:390,height:844},reducedMotion:'reduce'});
    await context.addInitScript(mock,initial);
    await context.route('**/*',route=>{
     const url=route.request().url();
     if(url.startsWith(base))return route.continue();
     if(url==='https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm')return route.fulfill({contentType:'text/javascript',body:'export const createClient=()=>window.__takeoverMockClient;'});
     return route.fulfill({contentType:'application/json',body:'[]'});
    });
    const p=await context.newPage(),errors=[],images=[];
    p.on('pageerror',e=>errors.push(e.message));
    p.on('request',r=>{if(r.url().includes('/modular-cool/'))images.push(r.url())});
    return {p,context,errors,images};
   }
   const ready=async p=>{
    await p.waitForFunction(()=>document.querySelector('.mb-art-debug')?.dataset.artState==='ready');
    await p.waitForFunction(()=>Array.from(document.querySelectorAll('.mb-preview .mb-artpack-img')).every(i=>i.complete&&i.naturalWidth===768&&i.naturalHeight===1216));
   };
   const shot=async(p,name)=>{if(process.env.SHOTS)await p.screenshot({path:path.join(process.env.SHOTS,engine+'-'+name+'.png')})};
   const badgeClearOfHead=async p=>{
    const collision=await p.evaluate(()=>{
     // Use actual opaque hair/eye bounds from the registered repository layers,
     // rather than treating the transparent full canvas as the character's head.
     let left=Infinity,top=Infinity,right=-Infinity,bottom=-Infinity;
     for(const image of document.querySelectorAll('.mb-preview img[data-art-slot="hair"],.mb-preview img[data-art-slot="eyes"]')){
      const canvas=document.createElement('canvas');canvas.width=image.naturalWidth;canvas.height=image.naturalHeight;
      const ctx=canvas.getContext('2d',{willReadFrequently:true});ctx.drawImage(image,0,0);
      const pixels=ctx.getImageData(0,0,canvas.width,canvas.height).data,b=image.getBoundingClientRect();
      let x0=canvas.width,y0=canvas.height,x1=-1,y1=-1;
      for(let y=0;y<canvas.height;y++)for(let x=0;x<canvas.width;x++)if(pixels[(y*canvas.width+x)*4+3]>16){
       x0=Math.min(x0,x);x1=Math.max(x1,x);y0=Math.min(y0,y);y1=Math.max(y1,y);
      }
      if(x1<0)continue;
      const scale=Math.min(b.width/canvas.width,b.height/canvas.height);
      const drawLeft=b.left+(b.width-canvas.width*scale)/2,drawTop=b.top+(b.height-canvas.height*scale)/2;
      left=Math.min(left,drawLeft+x0*scale);right=Math.max(right,drawLeft+(x1+1)*scale);
      top=Math.min(top,drawTop+y0*scale);bottom=Math.max(bottom,drawTop+(y1+1)*scale);
     }
     const badge=document.querySelector('.mb-art-debug').getBoundingClientRect();
     return {overlap:badge.left<right&&badge.right>left&&badge.top<bottom&&badge.bottom>top,
      head:{left,right,top,bottom},badge:{left:badge.left,right:badge.right,top:badge.top,bottom:badge.bottom}};
    });
    assert.ok(Number.isFinite(collision.head.left),'real raster head region is present');
    assert.equal(collision.overlap,false,'draft badge does not obscure registered hair/eyes: '+JSON.stringify(collision));
   };
   const noWrites=async p=>assert.deepEqual(await p.evaluate(()=>window.__calls.filter(([name])=>/^(save_|buy_)/.test(name))),[],'preview does not save or buy');
   let x=await page();
   await x.p.goto(base+'/mein-boxer.html');await x.p.waitForSelector('.mb-preview svg.tlh');
   assert.equal(x.images.length,0,'normal URL does not request modular art');
   assert.equal(await x.p.locator('[data-artpack-draft],.mb-art-debug').count(),0,'normal editor has no experimental image or badge');
   assert.equal(await x.p.locator('#saveBtn').isDisabled(),true,'saved outfit unchanged on normal URL');
   await noWrites(x.p);await x.context.close();

   x=await page();await x.p.goto(base+'/mein-boxer.html?art=modular');await ready(x.p);
   const glovePixels=await require('./boxer-glove-pixels.cjs')(x.p,base);
   for(const report of glovePixels.reports){
    assert.ok(report.wrists.every(p=>p.min>220),'both cuffs cover body-derived wrist anchors');
    assert.ok(report.hands.every(p=>p.min>220),'gloves cover original bare fingertips/hand centres');
    assert.ok(report.forearm.every(p=>p.max<16),'foreground forearm stays uncovered by the glove sprites');
    const [rear,front]=report.boxes;
    assert.ok(rear.left>=235&&rear.right<=360&&rear.top>=305&&rear.bottom<=390&&rear.area>3500&&rear.area<6000,'rear glove fits the outer hand and stops at the foreground arm');
    assert.ok(front.left>=390&&front.right<=535&&front.top>=305&&front.bottom<=420&&front.area>6000&&front.area<9000,'front glove fits opposite wrist without covering the lower arm');
   }
   assert.ok(glovePixels.iou>.96,'colour variants share at least 96% alpha silhouette overlap');
   for(let i=0;i<2;i++){
    const a=glovePixels.reports[0].boxes[i],b=glovePixels.reports[1].boxes[i];
    assert.ok(Math.hypot(a.cx-b.cx,a.cy-b.cy)<1.5,'variant swap does not move either glove');
    for(const key of ['left','top','right','bottom'])assert.ok(Math.abs(a[key]-b[key])<=2,'variant contour bounds remain registered');
   }
   if(process.env.SHOTS)fs.writeFileSync(path.join(process.env.SHOTS,engine+'-glove-pixels.json'),JSON.stringify(glovePixels,null,2));
   assert.equal(await x.p.locator('#saveBtn').isDisabled(),true,'draft URL does not change saved outfit');
   const stable=await x.p.locator('.mb-preview').boundingBox();
   let combinations=0;const contact=[],geometryErrors=[];
   for(const coat of [false,true])for(const top of ['none','tank'])for(const bottom of ['schwarz','rot'])for(const hair of ['afro','kurz_glatt'])for(const glove of ['schwarzgold','weiss']){
    // Real delegated button events exercise the existing editor and renderer.
    await x.p.evaluate(({coat,top,bottom,hair,glove})=>{
     const click=selector=>{const el=document.querySelector(selector);if(!el)throw Error('Missing editor control '+selector);el.click()};
     click('.mb-tabs [data-tab="koerper"]');click('[data-set="hair"][data-val="'+hair+'"]');
     click('.mb-tabs [data-tab="kleidung"]');click('[data-set="top"][data-val="'+top+'"]');
     click('[data-set="bottomc"][data-val="'+bottom+'"]');click('[data-set="glove"][data-val="'+glove+'"]');
     if(coat)click('[data-set="coatPick"][data-val="samurai"]');
     else if(document.querySelector('[data-toggle="coat"]').getAttribute('aria-pressed')==='true')click('[data-toggle="coat"]');
    },{coat,top,bottom,hair,glove});
    await ready(x.p);
    const expected=['body.png','eyes.png','feet.png',bottom==='rot'?'bottom-red.png':'bottom-black.png',hair==='afro'?'hair-afro.png':'hair-short.png',glove==='weiss'?'hands-white.png':'hands-blackgold.png',...(top==='tank'?['top-tank.png']:[]),...(coat?['coatback.png','coatfront.png']:[])].sort();
    const sources=await x.p.locator('.mb-preview .mb-artpack-img').evaluateAll(imgs=>imgs.map(i=>i.getAttribute('src').split('/').pop()).sort());
    assert.deepEqual(sources,expected,'exact selected layers '+JSON.stringify({coat,top,bottom,hair,glove}));
    assert.match(await x.p.locator('.mb-art-debug').innerText(),/Entwurf – nicht freigegeben/);
    await badgeClearOfHead(x.p);
    assert.equal(await x.p.locator('.mb-preview svg.tlh').count(),0,'complete outfit replaces SVG atomically');
    const boxes=await x.p.locator('.mb-preview .mb-artpack-img').evaluateAll(imgs=>imgs.map(i=>{const b=i.getBoundingClientRect();return [b.x,b.y,b.width,b.height]}));
    assert.ok(boxes.every(b=>b[2]>100&&b[3]>100),'raster layers have visible dimensions');
    for(const b of boxes)for(let i=0;i<4;i++)assert.ok(Math.abs(b[i]-boxes[0][i])<0.1,'all raster layers share canvas registration');
    const current=await x.p.locator('.mb-preview').boundingBox();
    if(Math.abs(current.y-stable.y)>=1||Math.abs(current.height-stable.height)>=1)
     geometryErrors.push({stable,current,coat,top,bottom,hair,glove});
    assert.ok(await x.p.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),'mobile has no horizontal page overflow');
    await shot(x.p,'modular-'+String(++combinations).padStart(2,'0'));
    if(process.env.SHOTS)contact.push({label:`${combinations}: Mantel ${coat?'an':'aus'} · ${top} · ${bottom} · ${hair} · ${glove}`,
     image:(await x.p.locator('.mb-stage').screenshot()).toString('base64')});
   }
   assert.equal(combinations,32);await noWrites(x.p);
   assert.deepEqual(x.errors,[]);await x.context.close();
   if(contact.length){
    const sheet=await browser.newPage({viewport:{width:1000,height:900},deviceScaleFactor:1});
    await sheet.setContent('<!doctype html><html lang="de"><meta charset="utf-8"><style>body{margin:20px;background:#10141e;color:#f5dda1;font:14px system-ui}h1{font-size:23px}main{display:grid;grid-template-columns:repeat(4,1fr);gap:10px}figure{margin:0;padding:6px;background:#1d2533}img{display:block;width:100%;height:230px;object-fit:contain}figcaption{min-height:40px;font-size:11px}</style><h1>Modularer Boxer · '+engine+' · 32 Kombinationen</h1><p>Entwurf – nicht freigegeben. Technische Browserdarstellung, keine künstlerische Abnahme.</p><main>'+contact.map(c=>'<figure><img src="data:image/png;base64,'+c.image+'"><figcaption>'+c.label+'</figcaption></figure>').join('')+'</main></html>');
    await sheet.waitForFunction(()=>Array.from(document.images).every(i=>i.complete));
    await sheet.screenshot({path:path.join(process.env.SHOTS,engine+'-modular-contact-32.png'),fullPage:true});
    await sheet.close();
   }

   x=await page();await x.p.setViewportSize({width:1440,height:900});
   await x.p.goto(base+'/mein-boxer.html?art=modular');await ready(x.p);await badgeClearOfHead(x.p);
   const desktop=await x.p.evaluate(()=>{
    const p=document.querySelector('.mb-preview').getBoundingClientRect();
    const images=Array.from(document.querySelectorAll('.mb-preview .mb-artpack-img'));
    return {width:p.width,height:p.height,noOverflow:document.documentElement.scrollWidth<=innerWidth+1,
     sizes:images.map(i=>{const b=i.getBoundingClientRect();return [b.width,b.height]}),
     contained:images.every(i=>{const b=i.getBoundingClientRect();return b.width>100&&b.height>100&&b.left>=p.left-1&&b.right<=p.right+1&&b.top>=p.top-1&&b.bottom<=p.bottom+1})};
   });
   assert.ok(desktop.width>100&&desktop.height>100&&desktop.contained&&desktop.noOverflow,'desktop stage contains full canvas: '+JSON.stringify(desktop));
   await shot(x.p,'modular-desktop-1440x900');await noWrites(x.p);assert.deepEqual(x.errors,[]);await x.context.close();

   // Focused visual matrix: both gloves × coat × tank × mobile/desktop.
   // Compare the assembled central forearm against the original body pixels;
   // a displaced glove or incorrectly opaque tank/coat must not repaint it.
   for(const viewport of [{width:390,height:844},{width:1440,height:900}]){
    x=await page();await x.p.setViewportSize(viewport);await x.p.goto(base+'/mein-boxer.html?art=modular');await ready(x.p);
    for(const coat of [false,true])for(const top of ['none','tank'])for(const glove of ['schwarzgold','weiss']){
     await x.p.evaluate(({coat,top,glove})=>{
      document.querySelector('.mb-tabs [data-tab="kleidung"]').click();
      document.querySelector('[data-set="top"][data-val="'+top+'"]').click();
      document.querySelector('[data-set="glove"][data-val="'+glove+'"]').click();
      if(coat)document.querySelector('[data-set="coatPick"][data-val="samurai"]').click();
      else if(document.querySelector('[data-toggle="coat"]').getAttribute('aria-pressed')==='true')document.querySelector('[data-toggle="coat"]').click();
     },{coat,top,glove});await ready(x.p);
     const arm=await x.p.evaluate(()=>{
      const imgs=[...document.querySelectorAll('.mb-preview .mb-artpack-img')];
      const c=document.createElement('canvas');c.width=768;c.height=1216;const g=c.getContext('2d');
      g.drawImage(imgs.find(i=>i.dataset.artSlot==='body'),0,0);const body=g.getImageData(0,0,768,1216).data;
      g.clearRect(0,0,768,1216);for(const i of imgs)g.drawImage(i,0,0);const all=g.getImageData(0,0,768,1216).data;
      let delta=0;for(const [x,y] of [[360,407],[382,402],[366,399],[375,395]])for(let dy=-1;dy<=1;dy++)for(let dx=-1;dx<=1;dx++)for(let k=0;k<4;k++){const idx=((y+dy)*768+x+dx)*4+k;delta=Math.max(delta,Math.abs(all[idx]-body[idx]))}
      const crop=document.createElement('canvas');crop.width=1140;crop.height=705;crop.getContext('2d').drawImage(c,190,245,380,235,0,0,1140,705);
      const box=imgs[0].getBoundingClientRect();return {delta,crop:crop.toDataURL().split(',')[1],width:box.width,height:box.height};
     });
     assert.ok(arm.width>100&&arm.height>100,'focused outfit has visible dimensions');
     assert.equal(arm.delta,0,'coat/tank/gloves preserve foreground forearm at marked skin probes');
     const name=`gloves-${viewport.width}-${coat?'coat':'bare'}-${top}-${glove}`;
     await shot(x.p,name);
     if(process.env.SHOTS)fs.writeFileSync(path.join(process.env.SHOTS,engine+'-'+name+'-arms.png'),Buffer.from(arm.crop,'base64'));
    }
    await noWrites(x.p);assert.deepEqual(x.errors,[]);await x.context.close();
   }

   // Delay one real PNG request while choosing its variant. Keep complete SVG
   // until that request finishes, even though the other files are already cached.
   x=await page();let release,seen;
   const gate=new Promise(r=>release=r),requestedImage=new Promise(r=>seen=r);
   await x.context.route('**/modular-cool/bottom-red.png',async route=>{seen();await gate;await route.continue()});
   await x.p.goto(base+'/mein-boxer.html?art=modular');await ready(x.p);
   await x.p.locator('.mb-tabs [data-tab="kleidung"]').click();
   await x.p.locator('[data-set="bottomc"][data-val="rot"]').click();await requestedImage;
   assert.equal(await x.p.locator('.mb-preview .mb-artpack-img').count(),0,'pending outfit never shows partial raster');
   assert.equal(await x.p.locator('.mb-preview svg.tlh').count(),1,'pending outfit uses complete SVG');
   release();await ready(x.p);await shot(x.p,'modular-atomic-ready');
   assert.deepEqual(x.errors,[]);await x.context.close();

   x=await page();await x.context.route('**/modular-cool/feet.png',r=>r.fulfill({status:404,body:''}));
   await x.p.goto(base+'/mein-boxer.html?art=modular');
   await x.p.waitForFunction(()=>document.querySelector('.mb-art-debug')?.dataset.artState==='load-failed');
   assert.equal(await x.p.locator('.mb-preview .mb-artpack-img').count(),0,'missing image invalidates entire outfit');
   assert.equal(await x.p.locator('.mb-preview svg.tlh').count(),1,'missing image restores complete SVG');
   assert.match(await x.p.locator('.mb-art-debug').innerText(),/Entwurf – nicht freigegeben/);
   await shot(x.p,'modular-missing-fallback');await noWrites(x.p);assert.deepEqual(x.errors,[]);await x.context.close();
   assert.deepEqual(geometryErrors,[],'outfit changes keep stage stable');
   console.log('PASS '+engine+': 32 outfits + 16 focused glove views; wrist/hand coverage, clear forearm pixels, variant alpha alignment, mobile/desktop, atomic load and SVG fallback');
  }finally{await browser.close()}
 }}finally{await new Promise(r=>server.close(r))}
})().catch(e=>{console.error(e);process.exitCode=1});
