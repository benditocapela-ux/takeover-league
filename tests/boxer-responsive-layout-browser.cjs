'use strict';
/* Studio layout regression. Local static server only; no authenticated calls. */
const assert=require('node:assert/strict');
const {chromium}=require('playwright');
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
 const browser=await chromium.launch({headless:true,args:['--no-sandbox']});
 try{
  for(const width of [360,390,700,850,900,1240,1600]){
   const context=await browser.newContext({viewport:{width,height:800},deviceScaleFactor:1});
   try{
    const page=await context.newPage();
    const errors=[];page.on('pageerror',error=>errors.push(error.message));
    await page.goto(origin+'/boxer.html',{waitUntil:'load'});
    await page.evaluate(()=>document.getElementById('content').classList.remove('hidden'));
    const choiceState=await page.evaluate(async()=>{
     const select=document.querySelector('#kind');
     const rail=select?.closest('label')?.nextElementSibling?.querySelector('.tl-choice-track');
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
 }finally{await browser.close();server.close()}
}
run().catch(error=>{console.error(error);server.close();process.exitCode=1});
