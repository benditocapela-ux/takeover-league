'use strict';
// Exercise real editor code with isolated RPC responses; never contact a live backend.
const assert=require('node:assert/strict'),fs=require('node:fs'),http=require('node:http'),path=require('node:path');
const playwright=require('playwright');
const engine=process.env.BROWSER||'chromium';
assert.ok(['chromium','webkit'].includes(engine),'supported transaction browser');
const root=process.cwd();
function mock(options){
 const items=[
  {key:'coat_drache',slot:'coat',value:'drache',name:'Drachen-Mantel',unlock:'shop',rarity:'epic',price:2000,owned:false},
  {key:'aura_flamme',slot:'aura',value:'flamme',name:'Flammen-Aura',unlock:'shop',rarity:'epic',price:1000,owned:false}
 ];
 const bundles=[{key:'test_bundle',name:'Test-Bundle',price:2500,value:3000,items:items.map(i=>i.key),owned_all:false}];
 window.__calls=[];let reads=0,coins=5000;
 const rpc=async(name,args)=>{
  window.__calls.push([name,args]);
  if(name==='get_my_performance')throw Error('Optional performance offline');
  if(name==='get_my_holo'){
   if(++reads>1){
    if(options.refresh==='null')return {data:null,error:null};
    if(options.refresh==='disabled')return {data:{enabled:false},error:null};
    throw Error('Inventory offline');
   }
   return {data:{enabled:true,shop:true,display_name:'Test',coins,config:{},items,bundles},error:null};
  }
  if(name==='buy_holo_item'||name==='buy_holo_bundle'){
   await new Promise(r=>setTimeout(r,150));
   coins-=name==='buy_holo_item'?2000:2500;
   return {data:{key:args.p_key,name:'Bestätigter Kauf',balance:coins},error:null};
  }
  if(name==='save_my_holo')return {data:args.p_config,error:null};
  return {data:null,error:null};
 };
 const q={select(){return q},eq(){return q},order(){return q},limit(){return q},in(){return q},gte(){return q},lte(){return q},maybeSingle:async()=>({data:{role:'boxer',is_active:true,display_name:'Test'},error:null}),then:r=>Promise.resolve({data:[],error:null}).then(r)};
 window.__takeoverMockClient={auth:{getSession:async()=>({data:{session:{access_token:'test'}}}),getUser:async()=>({data:{user:{id:'test'}},error:null}),onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}})},from:()=>q,rpc};
}
(async()=>{
 const server=http.createServer((req,res)=>{
  const file=path.resolve(root,decodeURIComponent(new URL(req.url,'http://localhost').pathname.slice(1)));
  if(!file.startsWith(root+path.sep)){res.writeHead(403);res.end();return}
  fs.readFile(file,(error,bytes)=>{if(error){res.writeHead(404);res.end();return}
   res.setHeader('Content-Type',({'.js':'text/javascript','.html':'text/html','.css':'text/css','.json':'application/json'})[path.extname(file)]||'application/octet-stream');res.end(bytes)});
 });
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const base='http://127.0.0.1:'+server.address().port;
 let browser;
 try{
  browser=await playwright[engine].launch();
  for(const kind of ['item','bundle'])for(const refresh of ['reject','null','disabled']){
   const context=await browser.newContext({viewport:{width:390,height:844}});
   await context.addInitScript(mock,{refresh});
   await context.route('**/*',route=>{
    const url=route.request().url();
    if(url.startsWith(base))return route.continue();
    if(url==='https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm')return route.fulfill({contentType:'text/javascript',body:'export const createClient=()=>window.__takeoverMockClient;'});
    return route.fulfill({contentType:'application/json',body:'[]'});
   });
   const page=await context.newPage(),errors=[];page.on('pageerror',e=>errors.push(e.message));
   await page.goto(base+'/mein-boxer.html?tab=shop');
   await page.waitForSelector('.mb-preview svg.tlh');
   assert.equal(await page.locator('.mb-wallet').count(),1,'optional performance rejection must not block editor');
   const key=kind==='item'?'coat_drache':'test_bundle',selector=`[data-buy-${kind}="${key}"]`;
   await page.locator(selector).click();
   await page.locator(selector+'[data-confirm]').focus();
   // Dispatch both before the delayed RPC settles: exactly one transaction is allowed.
   await page.locator(selector+'[data-confirm]').evaluate(btn=>{btn.click();btn.click()});
   await page.waitForFunction(()=>document.querySelector('#status').textContent.includes('Kauf bestätigt.'));
   assert.equal(await page.locator(selector).count(),0,'confirmed purchase cannot still offer purchase after failed refresh');
   assert.equal(await page.evaluate(()=>document.activeElement?.dataset.tab),'shop','removed purchase control returns keyboard focus to the active tab');
   assert.match(await page.locator('.mb-wallet').textContent(),kind==='item'?/3.?000/:/2.?500/,'receipt balance remains visible');
   assert.equal(await page.evaluate(k=>window.__calls.filter(c=>c[0]==='buy_holo_'+k).length,kind),1,'rapid double confirmation makes one RPC');
   await page.locator('[data-tab="kleidung"]').click();
   await page.locator('[data-set="coatPick"][data-val="drache"]').click();
   assert.equal(await page.locator('.mb-tryon').count(),0,'confirmed item is owned even while inventory refresh is offline');
   assert.equal(await page.locator('#saveBtn').isEnabled(),true,'purchased outfit can be saved');
   await page.locator('#saveBtn').click();
   await page.waitForFunction(()=>document.querySelector('.mb-save-state').dataset.saveStatus==='saved');
   if(kind==='bundle'){
    await page.locator('[data-tab="extras"]').click();
    await page.locator('[data-set="aura"][data-val="flamme"]').click();
    assert.equal(await page.locator('.mb-tryon').count(),0,'every purchased bundle item becomes owned');
   }
   assert.deepEqual(errors,[],'failed refresh must not destroy rendering');
   await context.close();
  }
  console.log('PASS: optional performance outage, item/bundle receipts, failed/null/disabled inventory refresh, double confirmation, purchased outfit saving');
 }finally{if(browser)await browser.close();await new Promise(r=>server.close(r))}
})().catch(e=>{console.error(e);process.exitCode=1});
