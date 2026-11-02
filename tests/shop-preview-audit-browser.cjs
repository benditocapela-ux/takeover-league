'use strict';
// Real browser and existing item renderers; all accounts, receipts and purchases are synthetic.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),pw=require('playwright'),H=require('./takeover3-harness.cjs');
const source=fs.readFileSync('tests/kampfgeist-browser.cjs','utf8').replace(/\r\n/g,'\n');
const fixture=source.slice(source.indexOf('function injected(cfg){'),source.indexOf('\n(async()=>'));
const sql=fs.readFileSync('supabase/migrations/20261028210000_kampfgeist_shop.sql','utf8');
const items=[...sql.matchAll(/\('([a-z0-9_]+)','(avatar|aura|banner|rahmen|titel|handschuhe)','((?:[^']|'')*)',(NULL|'(?:[^']|'')*'),'(\w+)','([FEDCBAS])','(start|rank|shop)',(NULL|\d+),'(\{[^']*\})',(\d+)\)/g)].map(m=>({key:m[1],category:m[2],name:m[3].replace(/''/g,"'"),description:m[4]==='NULL'?null:m[4].slice(1,-1).replace(/''/g,"'"),rarity:m[5],min_rank:m[6],unlock:m[7],price:m[8]==='NULL'?null:+m[8],design:JSON.parse(m[9])}));
assert.equal(items.length,114);
function controls(){
 const old=__takeoverMockClient.rpc,state=window.__shopAudit={throwOnce:false,malformed:false,readFailure:false,hold:false,receipt:null,lastState:null};
 __takeoverMockClient.rpc=async(name,args)=>{
  if(['buy_kg_item','equip_kg_item'].includes(name)){
   if(state.throwOnce){state.throwOnce=false;throw Error('Synthetischer Verbindungsabbruch')}
   if(state.malformed){state.malformed=false;return {data:{key:'wrong-item',balance:1},error:null}}
   const result=await old(name,args);state.receipt=result;
   if(state.hold)return new Promise(resolve=>state.release=()=>{state.hold=false;resolve(result)});
   return result;
  }
  if(name==='get_my_kampfgeist'&&state.readFailure)return {data:null,error:{message:'Synthetische Nachlese offline'}};
  const result=await old(name,args);if(name==='get_my_kampfgeist')state.lastState=result.data;return result;
 };
}
(async()=>{const {server,base}=await H.serve(),out=path.resolve('output/continuation/shop-audit');fs.mkdirSync(out,{recursive:true});try{
 for(const engine of (process.env.BROWSER||'chromium,webkit').split(',')){
  const browser=await pw[engine].launch();
  try{
   async function open(config={}){
    const ctx=await browser.newContext({viewport:{width:360,height:740},reducedMotion:'reduce'});
    await ctx.addInitScript({content:'('+fixture+')('+JSON.stringify({role:'boxer',items,balance:50000,exp:500000,level:99,rankIdx:6,...config})+');('+controls.toString()+')()'});
    await ctx.route('**/*',route=>{const url=route.request().url();if(url.startsWith(base)||/^(data:|blob:)/.test(url))return route.continue();if(url.includes('@supabase/supabase-js'))return route.fulfill({contentType:'text/javascript',body:'export const createClient=()=>window.__takeoverMockClient;'});return route.fulfill({contentType:'application/json',body:'[]'})});
    const page=await ctx.newPage(),errors=[];page.on('pageerror',e=>errors.push(e.message));await page.goto(base+'/shop.html');await page.locator('.kg-item').first().waitFor();return {page,ctx,errors};
   }
   const close=async x=>{assert.deepEqual(x.errors,[]);await x.ctx.close()};
   // Failed transport must release the busy guard and allow a deliberate retry.
   let x=await open();await x.page.locator('[data-item="a_lina"]').click();await x.page.evaluate(()=>__shopAudit.throwOnce=true);await x.page.locator('[data-buy="a_lina"]').click();
   await x.page.waitForFunction(()=>document.getElementById('status').textContent.includes('Verbindungsabbruch'),null,{timeout:4000});
   assert.equal(await x.page.evaluate(()=>__shopAudit.lastState.items.find(i=>i.key==='a_lina').owned),false);
   if(!await x.page.locator('[data-buy="a_lina"]').isVisible())await x.page.locator('[data-item="a_lina"]').click();
   await x.page.locator('[data-buy="a_lina"]').click();await x.page.locator('[data-equip="a_lina"]').waitFor();
   const beforeEquip=await x.page.locator('#app .kg-card').innerHTML();await x.page.evaluate(()=>__shopAudit.throwOnce=true);await x.page.locator('[data-equip="a_lina"]').click();
   await x.page.waitForFunction(()=>document.getElementById('status').textContent.includes('Ausrüstung nicht bestätigt: Synthetischer Verbindungsabbruch'));
   assert.equal(await x.page.locator('#app .kg-card').innerHTML(),beforeEquip,'failed equip does not invent an applied look');
   await x.page.evaluate(()=>__shopAudit.readFailure=true);await x.page.locator('[data-equip="a_lina"]').click();
   await x.page.waitForFunction(()=>document.getElementById('status').textContent.includes('Ausrüstung bestätigt.'));
   assert.equal(await x.page.evaluate(()=>{const wrap=document.createElement('div');wrap.innerHTML=TLKG.card(__shopAudit.receipt.data.look,{name:'Anna',size:104});return document.querySelector('#app .kg-card').outerHTML===wrap.firstElementChild.outerHTML}),true,'equip receipt supplies actual look despite offline refresh');
   assert.equal(await x.page.locator('[data-equip="a_lina"]').count(),0,'confirmed equip is not offered again');await close(x);
   x=await open();const initialBalance=await x.page.locator('.kg-bal').innerText();await x.page.locator('[data-item="a_lina"]').click();await x.page.evaluate(()=>__shopAudit.malformed=true);await x.page.locator('[data-buy="a_lina"]').click();
   await x.page.waitForFunction(()=>document.getElementById('status').textContent.includes('Keine vollständige Bestätigung'));
   assert.equal(await x.page.locator('.kg-bal').innerText(),initialBalance,'unmatched receipt cannot overwrite wallet');assert.equal(await x.page.locator('[data-item="a_lina"]').evaluate(n=>n.classList.contains('owned')),false,'unmatched receipt cannot grant ownership');await close(x);
   // Catalogue identity, price and SVG designs are shared by tile, detail and applied look.
   x=await open();
   for(const category of ['avatar','aura','banner','rahmen','titel','handschuhe']){
    const item=items.find(i=>i.category===category&&i.unlock==='shop');
    await x.page.locator('[data-cat="'+category+'"]').click();
    const tile=x.page.locator('[data-item="'+item.key+'"]');
    const tileArt=await tile.locator('.kg-pv').innerHTML();assert.match(await tile.innerText(),new RegExp(String(item.price)));
    await tile.click();assert.equal(await x.page.locator('#layer .kg-pv').innerHTML(),tileArt,category+' detail uses exact tile source');
    assert.equal(await x.page.locator('#layer .mb-premium-figure,#layer .mb-premium-item').count(),0,'Kampfgeist remains its own SVG catalogue');
    assert.match(await x.page.locator('[data-buy]').innerText(),new RegExp(String(item.price)));
    await x.page.locator('[data-buy]').click();await x.page.locator('[data-equip]').waitFor();
    await x.page.locator('[data-equip]').click();await x.page.waitForFunction(key=>__shopAudit.lastState.look[__shopAudit.lastState.items.find(i=>i.key===key).category]?.key===key,item.key);
    const parity=await x.page.evaluate(()=>{const wrapper=document.createElement('div');wrapper.innerHTML=TLKG.card(__shopAudit.lastState.look,{name:'Anna',size:104});return document.querySelector('#app .kg-card').outerHTML===wrapper.firstElementChild.outerHTML});assert.equal(parity,true,category+' applied look matches receipt-backed renderer');
   }
   assert.equal(await x.page.evaluate(()=>__calls.filter(c=>c[0]==='buy_kg_item').length),6);
   await x.page.locator('[data-tab="coins"]').click();assert.match(await x.page.locator('#app').innerText(),/Startguthaben/);assert.match(await x.page.locator('#app').innerText(),/10/);
   await close(x);
   // A confirmed receipt survives a failed subsequent read; do not offer a second purchase.
   x=await open();await x.page.locator('[data-item="a_lina"]').click();await x.page.evaluate(()=>__shopAudit.readFailure=true);await x.page.locator('[data-buy="a_lina"]').click();
   await x.page.waitForFunction(()=>/Kauf bestätigt/.test(document.getElementById('status').textContent));
   assert.equal(await x.page.locator('[data-buy="a_lina"]').count(),0);assert.match(await x.page.locator('[data-item="a_lina"]').innerText(),/Gehört dir/);
   const balance=await x.page.evaluate(()=>__shopAudit.receipt.data.balance);assert.equal(Number((await x.page.locator('.kg-bal').innerText()).replace(/[^0-9]/g,'')),balance);
   await x.page.screenshot({path:path.join(out,engine+'-confirmed-offline.png')});await close(x);
   // Closing an in-flight detail and choosing another must not reopen the old selection.
   x=await open();await x.page.locator('[data-item="a_lina"]').click();await x.page.evaluate(()=>__shopAudit.hold=true);await x.page.locator('[data-buy="a_lina"]').click();await x.page.waitForFunction(()=>typeof __shopAudit.release==='function');
   await x.page.keyboard.press('Escape');await x.page.locator('[data-item="a_tomas"]').click();await x.page.evaluate(()=>__shopAudit.release());
   await x.page.waitForFunction(()=>document.getElementById('status').textContent.includes('Gekauft: Lina'));assert.equal(await x.page.locator('#layer [role=dialog]').getAttribute('aria-label'),items.find(i=>i.key==='a_tomas').name);
   assert.equal(await x.page.evaluate(()=>__calls.filter(c=>c[0]==='buy_kg_item').length),1);
   for(const width of [320,390,430]){await x.page.setViewportSize({width,height:640});assert.ok(await x.page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1));assert.ok(await x.page.locator('#layer [role=dialog]').evaluate(n=>n.scrollWidth<=n.clientWidth+1));}
   await x.page.evaluate(()=>document.documentElement.style.zoom='2');assert.ok(await x.page.locator('#layer [role=dialog]').evaluate(n=>n.scrollWidth<=n.clientWidth+1));await x.page.locator('#layer button[data-close]').click();assert.equal(await x.page.locator('#layer [role=dialog]').count(),0);await close(x);
   console.log('PASS '+engine+': shop source/price/applied-look parity, buy/equip transport recovery, both receipts + offline read, malformed receipt, rapid selection, mobile/200% detail');
  }finally{await browser.close()}
 }
}finally{server.close()}})().catch(error=>{console.error(error);process.exitCode=1});
