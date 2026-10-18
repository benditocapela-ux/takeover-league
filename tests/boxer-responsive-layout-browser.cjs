'use strict';
/* Real Chromium regression for the authenticated dashboard's CSS layout.
 * Supabase scripts are omitted on the local test-server response because
 * layout must be robust independent of data fetch/auth timing.
 * No account, production request or database mutation is used. */
const assert=require('node:assert/strict');
const {chromium}=require('playwright');
const fs=require('node:fs'),path=require('node:path'),http=require('node:http');
const root=process.cwd(),types={'.html':'text/html; charset=utf-8','.css':'text/css','.js':'application/javascript'};
const server=http.createServer((request,response)=>{
 const url=new URL(request.url,'http://localhost');
 const rel=url.pathname==='/'?'boxer.html':decodeURIComponent(url.pathname.slice(1));
 const file=path.resolve(root,rel);
 if(!file.startsWith(root+path.sep)){response.writeHead(403);response.end();return}
 fs.readFile(file,(err,data)=>{
  if(err){response.writeHead(404);response.end();return}
  response.setHeader('Content-Type',types[path.extname(file)]||'application/octet-stream');
  if(rel==='boxer.html'){
   const html=data.toString().replace(/<script type="module">[\s\S]*?<\/script>/,'');
   response.end(html);
  }else response.end(data);
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
    const page=await context.newPage();page.setDefaultTimeout(10000);
    await page.goto(origin+'/boxer.html',{waitUntil:'load'});
    const bounds=await page.evaluate(()=>{
     const main=document.getElementById('content');
     main.classList.remove('hidden');
     const anchor=document.getElementById('expRankSection');
     const a=document.createElement('section');a.className='card';a.id='achievementsV2';
     a.innerHTML='<h2>Achievements</h2><p>Testbereich für Auszeichnungen</p>';
     anchor.insertAdjacentElement('afterend',a);
     const ids=['profileCard','trainingFormCard','trainingStats','entriesCard',
      'boxerAuditSection','boxerTaskCenter','boxerNotificationSection',
      'trainingInsights','expRankSection','performance30Section','boxerFeedbackSection','achievementsV2'];
     const box=main.getBoundingClientRect();
     const cards=Object.fromEntries(ids.map(id=>{
      const el=document.getElementById(id);
      if(!el)throw Error('Missing dashboard card: '+id);
      const r=el.getBoundingClientRect();
      return [id,{left:r.left,right:r.right,top:r.top,bottom:r.bottom,width:r.width,overflow:el.scrollWidth-el.clientWidth}];
     }));
     return {box:{left:box.left,right:box.right,width:box.width},
      documentOverflow:document.documentElement.scrollWidth-window.innerWidth,
      cards};
    });
    assert.ok(bounds.box.width>100,'Dashboard container missing at '+width);
    assert.ok(bounds.documentOverflow<=4,'Page horizontal overflow at '+width+': '+bounds.documentOverflow);
    for(const [id,c] of Object.entries(bounds.cards)){
     assert.ok(c.left>=bounds.box.left-2&&c.right<=bounds.box.right+2,
      'Card escapes dashboard container: '+id+' at '+width);
     assert.ok(c.width>=bounds.box.width*(width<=850?.95:.35),
      'Unreasonably narrow dashboard card: '+id+' at '+width+' ('+Math.round(c.width)+'px)');
     assert.ok(c.overflow<=5,'Card internal overflow: '+id+' at '+width+' ('+c.overflow+'px)');
    }
    const {cards}=bounds;
    const pairs=[['trainingFormCard','trainingStats'],['boxerAuditSection','boxerTaskCenter'],
     ['boxerNotificationSection','trainingInsights'],['expRankSection','performance30Section']];
    for(const [left,right] of pairs){
     const a=cards[left],b=cards[right];
     if(width>850){
      assert.ok(Math.abs(a.top-b.top)<=2,'Paired cards should share a row: '+left+'/'+right+' at '+width);
      assert.ok(a.right+6<=b.left,'Overlapping card columns: '+left+'/'+right+' at '+width);
     }else assert.ok(b.top>=a.bottom-1,'Cards not vertically stacked: '+left+'/'+right+' at '+width);
    }
    console.log('PASS boxer responsive cards',width+'px','no horizontal clipping or overlap');
   }finally{await context.close()}
  }
 }finally{await browser.close();server.close()}
}
run().catch(e=>{console.error(e);server.close();process.exit(1)});
