'use strict';
/* Studio layout regression. Local static server only; no authenticated calls. */
const assert=require('node:assert/strict');
const {chromium,webkit}=require('playwright');
const fs=require('node:fs'),path=require('node:path'),http=require('node:http');
const root=process.cwd();
const mime={'.html':'text/html; charset=utf-8','.css':'text/css','.js':'text/javascript','.svg':'image/svg+xml'};
const server=http.createServer((request,response)=>{
 const pathname=new URL(request.url,'http://localhost').pathname;
 const rel=pathname==='/'?'boxer.html':decodeURIComponent(pathname.slice(1));
 const file=path.resolve(root,rel);
 if(!file.startsWith(root+path.sep)){response.writeHead(403);response.end();return}
 fs.readFile(file,(error,data)=>{
  if(error){response.writeHead(404);response.end();return}
  response.setHeader('Content-Type',mime[path.extname(file)]||'application/octet-stream');
  if(rel==='boxer.html')response.end(data.toString().replace(/<script type="module">[\s\S]*?<\/script>/,''));
  else response.end(data);
 });
});
async function run(){
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 const origin='http://127.0.0.1:'+server.address().port;
 const engine=process.env.BROWSER==='webkit'?webkit:chromium;
 const browser=await engine.launch({headless:true,...(process.env.BROWSER_CHANNEL?{channel:process.env.BROWSER_CHANNEL}:{})});
 try{
  for(const width of process.env.EDITOR_ONLY?[]:[360,390,700,850,900,1240,1600]){
   const context=await browser.newContext({viewport:{width,height:800},deviceScaleFactor:1});
   try{
    const page=await context.newPage();
    const errors=[];page.on('pageerror',error=>errors.push(error.message));
    await page.goto(origin+'/boxer.html',{waitUntil:'load'});
    await page.evaluate(()=>document.getElementById('content').classList.remove('hidden'));
    const choiceState=await page.evaluate(async()=>{
     const select=document.querySelector('#kind');
     const rail=select?.nextElementSibling?.querySelector('.tl-choice-track');
     if(!select||!rail)throw new Error('Training choice track missing');
     const option=document.createElement('option');option.value='browser-fixture';option.textContent='Sparring';
     select.append(option);
     await new Promise(resolve=>setTimeout(resolve,0)); // let the native-select MutationObserver render its card
     const card=rail.querySelector('button[data-value="browser-fixture"]');
     if(card)card.click();
     return {cards:rail.querySelectorAll('.tl-choice-card').length,value:select.value,overflow:getComputedStyle(rail).overflowX};
    });
    assert.ok(choiceState.cards>=1,'Training choice card should render in Chromium');
    assert.equal(choiceState.value,'browser-fixture','Training card click should update the original select');
    assert.equal(choiceState.overflow,'auto','Training cards should use horizontal scrolling');
    const pairs=[
     ['studioTabOverview','studioPanelOverview'],
     ['studioTabHistory','studioPanelHistory'],
     ['studioTabDetails','studioPanelDetails']
    ];
    for(const [tabId,panelId] of pairs){
     await page.locator('#'+tabId).click();
     const stats=await page.evaluate(({tabId,panelId})=>{
      const container=document.getElementById('content');
      const tab=document.getElementById(tabId),panel=document.getElementById(panelId);
      const bounds=container.getBoundingClientRect();
      const cards=Array.from(panel.querySelectorAll(':scope > section.card')).map(el=>{
       const r=el.getBoundingClientRect();
       return {id:el.id,left:r.left,right:r.right,width:r.width,overflow:el.scrollWidth-el.clientWidth};
      });
      return {selected:tab.getAttribute('aria-selected'),hidden:panel.hidden,
       count:cards.length,overflow:document.documentElement.scrollWidth-window.innerWidth,
       left:bounds.left,right:bounds.right,width:bounds.width,cards,
       otherVisible:Array.from(document.querySelectorAll('.studio-pane')).filter(p=>p!==panel&&!p.hidden).length};
     },{tabId,panelId});
     assert.equal(stats.selected,'true','Selected tab missing at '+width);
     assert.equal(stats.hidden,false);
     assert.equal(stats.otherVisible,0,'Multiple panes exposed at '+width);
     assert.ok(stats.count>=2,'Studio panel has no cards');
     assert.ok(stats.overflow<=4,'Horizontal document overflow at '+width+': '+stats.overflow);
     for(const c of stats.cards){
      assert.ok(c.left>=stats.left-2&&c.right<=stats.right+2,'Card escapes '+c.id+' at '+width);
      assert.ok(c.width>=stats.width*(width<=760?.93:.37),'Card too narrow '+c.id+' at '+width);
      assert.ok(c.overflow<=5,'Card internal overflow '+c.id+' at '+width+': '+c.overflow);
     }
    }
    await page.locator('#studioTabOverview').focus();
    await page.keyboard.press('ArrowRight');
    assert.equal(await page.locator('#studioTabHistory').getAttribute('aria-selected'),'true','Keyboard tabs at '+width);
    await page.keyboard.press('End');
    assert.equal(await page.locator('#studioTabDetails').getAttribute('aria-selected'),'true','End navigation at '+width);
    assert.deepEqual(errors,[],'JavaScript errors in Studio at '+width);
    console.log('PASS Studio tabs / keyboard / responsive',width+'px');
   }finally{await context.close()}
  }
  await checkEditor(browser,origin);
 }finally{await browser.close();server.close()}
}

// Keep layout fixtures read-only and route every non-local request: no live data.
async function checkEditor(browser,origin){
 const sql=fs.readFileSync(path.join(root,'supabase/migrations/20261029140000_boxer_holo.sql'),'utf8');
 const catalog=sql.slice(sql.indexOf('INSERT INTO public.holo_items'),sql.indexOf('ON CONFLICT (key) DO NOTHING;'));
 const items=[...catalog.matchAll(/\('([a-z_]+)','([a-z]+)','((?:[^']|'')*)','([a-z]+)','([a-z]+)',(NULL|\d+),(NULL|'(\{[^']*\})'),(\d+)\)/g)].map(m=>({
  key:m[1],slot:m[2],value:m[1].slice(m[2].length+1),name:m[3].replace(/''/g,"'"),rarity:m[4],unlock:m[5],price:m[6]==='NULL'?null:+m[6],owned:true
 }));
 const context=await browser.newContext({reducedMotion:'reduce'});
 try{
  await context.route('**/*',route=>{
   const url=route.request().url();
   if(url.startsWith(origin+'/')||url.startsWith('blob:'+origin+'/'))return route.continue();
   if(url==='https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm')return route.fulfill({contentType:'text/javascript',body:'export const createClient=()=>window.__layoutClient;'});
   return route.abort();
  });
  await context.addInitScript(items=>{
   const q={select(){return q},eq(){return q},maybeSingle:async()=>({data:{role:'boxer',is_active:true,display_name:'Layout'},error:null})};
   window.__layoutClient={auth:{getSession:async()=>({data:{session:{access_token:'fixture'}}}),getUser:async()=>({data:{user:{id:'layout'}}}),onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}})},from:()=>q,
    rpc:async name=>name==='get_my_holo'?{data:{enabled:true,shop:true,coins:5000,saved:true,config:{tone:6,hair:'afro',coat:'samurai',pose_profile:'cool'},items,bundles:[]},error:null}:{data:null,error:null}};
  },items);
  const page=await context.newPage(),errors=[];
  page.on('pageerror',error=>errors.push(error.message));
  // Reuse the same page through resize, including desktop/mobile breakpoint changes.
  for(const [width,height] of [[375,812],[390,844],[430,932],[768,1024],[1440,900],[390,844]]){
   await page.setViewportSize({width,height});
   if(!page.url().startsWith(origin)){
    await page.goto(origin+'/mein-boxer.html');
    await page.waitForSelector('.mb-preview svg.tlh');
   }
   await page.evaluate(()=>scrollTo(0,0));
   for(const tab of ['koerper','kleidung','extras','posen','shop']){
    await page.locator('[data-tab="'+tab+'"]').click();
    assert.equal(await page.locator('[data-tab="'+tab+'"]').getAttribute('aria-selected'),'true');
    assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),'editor horizontal overflow '+width+' '+tab);
   }
   await page.locator('[data-tab="kleidung"]').click();
   const heading=await page.evaluate(()=>{
    const title=document.querySelector('.mb-stage-title strong').getBoundingClientRect(),state=document.querySelector('.mb-save-state').getBoundingClientRect();
    return {title:title.toJSON(),state:state.toJSON()};
   });
   assert.ok(heading.title.right<=heading.state.left+1||heading.title.bottom<=heading.state.top+1,'heading/save status overlap '+width);
   const initial=await page.locator('.mb-stage').boundingBox();
   if(width<820){
    const geometry=await page.evaluate(()=>{
     const stage=document.querySelector('.mb-stage').getBoundingClientRect(),panel=document.querySelector('.mb-panel').getBoundingClientRect(),body=document.querySelector('.mb-tabbody'),preview=document.querySelector('.mb-preview').getBoundingClientRect();
     body.scrollTop=200;
     return {stageBottom:stage.bottom,panelTop:panel.top,height:body.clientHeight,scroll:body.scrollTop,previewHeight:preview.height};
    });
    assert.ok(geometry.stageBottom<=geometry.panelTop+1,'stage overlaps tabs '+width);
    assert.ok(geometry.height>=100&&geometry.scroll>0,'usable independent gear scroll '+width);
    assert.ok(geometry.previewHeight>=100,'visible complete figure '+width);
    assert.ok(Math.abs((await page.locator('.mb-stage').boundingBox()).y-initial.y)<1,'stationary mobile stage '+width);
   }else{
    await page.evaluate(()=>scrollTo(0,600));
    await page.waitForFunction(()=>scrollY>500);
    const scrolled=await page.locator('.mb-stage').boundingBox();
    assert.ok(scrolled.y>=0&&scrolled.y<40,'desktop boxer stays visible while equipment scrolls: '+JSON.stringify(scrolled));
   }
   await page.locator('[data-tab="kleidung"]').focus();
   await page.keyboard.press('Home');
   assert.equal(await page.evaluate(()=>document.activeElement?.dataset.tab),'koerper','keyboard tab focus '+width);
   await page.keyboard.press('End');
   assert.equal(await page.evaluate(()=>document.activeElement?.dataset.tab),'shop','keyboard End focus '+width);
   await page.locator('[data-tab="kleidung"]').click();
   if(process.env.SHOTS){fs.mkdirSync(process.env.SHOTS,{recursive:true});await page.screenshot({path:path.join(process.env.SHOTS,'editor-'+(process.env.BROWSER||'chromium')+'-'+width+'x'+height+'.png')});}
   console.log('PASS Mein Boxer viewport / scroll / keyboard / resize',width+'x'+height);
  }
  for(const [width,height] of [[390,844],[1440,900]]){
   await page.setViewportSize({width,height});
   await page.goto(origin+'/mein-boxer.html?art=layers');
   await page.waitForSelector('.mb-draft-tools');
   await page.locator('.mb-draft-tools summary').click();
   await page.locator('[data-draft-repo]').click();
   await page.waitForFunction(()=>document.querySelector('[data-draft-sample]')||document.getElementById('status').classList.contains('error'));
   assert.equal(await page.locator('#status').evaluate(el=>el.classList.contains('error')),false,await page.locator('#status').textContent());
   if(await page.locator('[data-draft-sample]').getAttribute('aria-pressed')!=='true'){
    if(!await page.locator('.mb-draft-tools').evaluate(el=>el.open))await page.locator('.mb-draft-tools summary').click();
    await page.locator('[data-draft-sample]').click();
   }
   if(await page.locator('.mb-draft-tools').evaluate(el=>el.open))await page.locator('.mb-draft-tools summary').click();
   await page.waitForSelector('.mb-draft-artpack',{state:'attached'});
   const art=await page.locator('.mb-draft-artpack').boundingBox();
   assert.ok(art&&art.height>=100,'original PNG canvas remains visible at '+width+': '+JSON.stringify(art));
   assert.equal(await page.locator('.mb-draft-artpack img').count(),8,'eight real repository layers');
   assert.ok(await page.locator('.mb-draft-artpack img').evaluateAll(images=>images.every(img=>img.complete&&img.naturalWidth===768&&img.naturalHeight===1216)),'originals decoded');
   if(process.env.SHOTS)await page.screenshot({path:path.join(process.env.SHOTS,'editor-original-'+(process.env.BROWSER||'chromium')+'-'+width+'x'+height+'.png')});
   console.log('PASS original PNG canvas',width+'x'+height);
  }
  assert.deepEqual(errors,[],'editor page errors');
 }finally{await context.close()}
}
run().catch(error=>{console.error(error);server.close();process.exitCode=1});
