'use strict';
// Real Chromium test with mocked Supabase SDK for Etappe 7d: choose/buy card designs, locked designs,
// awards overview, coach confirms suggestion and revokes with reason, podium spotlight, designs on compare cards.
const assert=require('node:assert/strict'),fs=require('node:fs'),http=require('node:http'),path=require('node:path');
const {chromium}=require('playwright');
const root=process.cwd();
const server=http.createServer((req,res)=>{
 const u=new URL(req.url,'http://127.0.0.1');
 if(u.pathname==='/news.json'){res.setHeader('Content-Type','application/json');res.end('{"entries":[]}');return}
 const file=path.resolve(root,decodeURIComponent(u.pathname.slice(1))||'index.html');
 if(!file.startsWith(root+path.sep)){res.writeHead(403);res.end();return}
 fs.readFile(file,(err,data)=>{if(err){res.writeHead(404);res.end();return}
  const ext=path.extname(file);res.setHeader('Content-Type',ext==='.js'?'text/javascript':ext==='.html'?'text/html':ext==='.css'?'text/css':ext==='.svg'?'image/svg+xml':'application/octet-stream');res.end(data)});
});
function injected(cfg){
 const calls=[];window.__calls=calls;
 const D=(key,name,unlock,extra,design)=>({key,name,description:name+' Design',unlock,min_rank:null,price:null,award_kind:null,design,...extra});
 const designs=[D('classic','Klassisch','start',{},{tier:true}),D('carbon','Carbon','rank',{min_rank:'E'},{a:'#3a3f4b',b:'#14171d',ink:'#e8ecf2',edge:'#9aa3b0',pattern:'carbon'}),
  D('ocean','Ozean','rank',{min_rank:'D'},{a:'#5fc3ff',b:'#0d3a6e',ink:'#f2f8ff',edge:'#bfe6ff',pattern:'waves'}),D('neon','Neon','shop',{price:400},{a:'#ff3ea5',b:'#1b0a3a',ink:'#ffffff',edge:'#3ef0ff',pattern:'grid'}),
  D('thunder','Donner','shop',{price:900},{a:'#7fa7ff',b:'#141a3d',ink:'#f5f8ff',edge:'#ffe066',pattern:'bolts'}),D('cotw','Card of the Week','award',{award_kind:'cotw'},{a:'#7be3a0',b:'#0f3b2a',ink:'#f2fff7',edge:'#f2c14e',pattern:'rays',badge:'COTW'})];
 let owned=new Set(['classic','carbon']),coins=450,equipped='classic';
 const lookOf=k=>{const d=designs.find(x=>x.key===k);return {key:d.key,name:d.name,design:d.design,awards:k==='cotw'?[{kind:'cotw',period_start:'2026-10-19'}]:[]}};
 const award={id:7,kind:'cotw',period_start:'2026-10-19',period_end:'2026-10-25',display_name:'Anna',exp:120,note:'Zwei starke Sparrings',awarded_by:'Marco',revoked:false,look:lookOf('cotw')};
 let given=cfg.role==='coach'?null:award;
 const rating={categories:{OFF:75,DEF:63,BEI:70,KON:70,TAK:70,MEN:70},overall:70,scale:20,top:[],low:[],rated_at:'2026-10-20T10:00:00Z',delta:0};
 const rpc=async(name,args)=>{
  calls.push([name,args]);
  if(name==='get_my_card_designs')return {data:{enabled:true,preview:false,display_name:cfg.me||'Ben',rank:'E',shop:true,coins,look:lookOf(equipped),
   designs:designs.map(d=>({...d,available:owned.has(d.key)}))},error:null};
  if(name==='equip_card_design'){if(!owned.has(args.p_key))return {data:null,error:{message:'Dieses Design ist für dich noch gesperrt'}};equipped=args.p_key;return {data:lookOf(equipped),error:null}}
  if(name==='buy_card_design'){const d=designs.find(x=>x.key===args.p_key);if(coins<d.price)return {data:null,error:{message:'Zu wenig Coins'}};coins-=d.price;owned.add(d.key);return {data:{key:d.key,price:d.price,balance:coins},error:null}}
  if(name==='get_card_awards')return {data:{enabled:true,preview:false,latest:{cotw:given,cotm:null,poty:null},history:given?[given]:[]},error:null};
  if(name==='get_my_performance')return {data:{profile:{id:'p-me',display_name:cfg.me||'Ben',role:cfg.role},ratings_enabled:true,style_enabled:true,rating:{current:{scores:{},scale:20,summary:rating,created_at:'2026-10-20T10:00:00Z'},previous:null},style:{current:null,state:{}}},error:null};
  if(name==='staff_card_award_overview')return {data:{today:'2026-10-28',boxers:[{id:'p-anna',display_name:'Anna'},{id:'p-ben',display_name:'Ben'}],kinds:['cotw','cotm','poty'].map(k=>({kind:k,periods:[
   {start:k==='cotw'?'2026-10-19':k==='cotm'?'2026-09-01':'2025-01-01',end:k==='cotw'?'2026-10-25':k==='cotm'?'2026-09-30':'2025-12-31',completed:true,award:k==='cotw'?given:null,
    candidates:[{profile_id:'p-anna',display_name:'Anna',exp:120,trainings:2},{profile_id:'p-ben',display_name:'Ben',exp:90,trainings:1}]},
   {start:'2026-10-26',end:'2026-11-01',completed:false,award:null,candidates:[]}]}))},error:null};
  if(name==='staff_confirm_card_award'){given={...award,display_name:args.p_profile_id==='p-anna'?'Anna':'Ben',note:args.p_note};return {data:given,error:null}}
  if(name==='staff_revoke_card_award'){given=null;return {data:{...award,revoked:true},error:null}}
  if(name==='get_card_looks'){const o={};for(const n of args.p_display_names)o[n]=n==='Anna'?lookOf('cotw'):lookOf(equipped);return {data:o,error:null}}
  if(name==='get_performance_card')return {data:{display_name:args.p_display_name,is_me:args.p_display_name===(cfg.me||'Ben'),rating,style:{scores:{o:50,v:50,c:50,p:50,s:50,a:50}}},error:null};
  return {data:null,error:{message:'unexpected rpc '+name}};
 };
 const q={select(){return q},eq(){return q},order(){return q},limit(){return q},in(){return q},gte(){return q},lte(){return q},maybeSingle:async()=>({data:{role:cfg.role,is_active:true,display_name:cfg.me||'Ben'},error:null}),then:(r)=>Promise.resolve({data:[],error:null}).then(r)};
 window.__takeoverMockClient={auth:{getSession:async()=>({data:{session:{access_token:'x'}}}),getUser:async()=>({data:{user:{id:'u1'}},error:null}),onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}})},from:()=>q,rpc,channel:()=>({on(){return this},subscribe(){return this}}),removeChannel(){}};
}
(async()=>{
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const base='http://127.0.0.1:'+server.address().port+'/';
 const browser=await chromium.launch();
 const shot=async(p,n)=>{if(process.env.SHOTS)await p.screenshot({path:process.env.SHOTS+'/'+n+'.png',fullPage:true})};
 async function page(cfg){
  const context=await browser.newContext({viewport:{width:390,height:844}});
  await context.addInitScript({content:'('+injected.toString()+')('+JSON.stringify(cfg)+')'});
  const p=await context.newPage();const errors=[];p.on('pageerror',e=>errors.push(e.message));
  await p.route('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm',r=>r.fulfill({status:200,contentType:'text/javascript',body:'export const createClient=()=>window.__takeoverMockClient;'}));
  await p.route('https://iqarjivcrddcixrvqbfb.supabase.co/**',r=>{const u=r.request().url();
   const body=u.includes('get_public_levels')?[{boxer_name:'Anna',lifetime_exp:500},{boxer_name:'Ben',lifetime_exp:3000}]:u.includes('get_public_leaderboard')?[{boxer_name:'Anna',rank_position:1,monthly_points:120},{boxer_name:'Ben',rank_position:2,monthly_points:90}]:[];
   r.fulfill({status:200,contentType:'application/json',body:JSON.stringify(body)})});
  return {p,errors,context};
 }
 const noOverflow=async p=>assert.ok(await p.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth),'no horizontal scroll');

 // A: Boxer wählt, kauft, sieht gesperrte Designs
 let {p,errors,context}=await page({role:'boxer',me:'Ben'});
 await p.goto(base+'karten.html');await p.waitForSelector('.kd-grid');
 assert.match(await p.textContent('#app'),/Rang E · 450 Coins/);
 assert.match(await p.textContent('.kd-item:has-text("Ozean")'),/ab Rang D \(du: E\)/);
 assert.match(await p.textContent('.kd-item:has-text("Card of the Week")'),/nur als Card of the Week/);
 assert.ok(await p.locator('[data-buy="thunder"]').isDisabled(),'not enough coins');
 await p.click('[data-equip="carbon"]');await p.waitForFunction(()=>/Design ausgewählt/.test(document.getElementById('status').textContent));
 assert.equal(await p.locator('.kd-item.on > b').textContent(),'Carbon');
 await p.click('[data-buy="neon"]');await p.waitForFunction(()=>/Gekauft und ausgewählt/.test(document.getElementById('status').textContent));
 assert.match(await p.textContent('#app'),/50 Coins/);assert.equal(await p.locator('.kd-item.on > b').textContent(),'Neon');
 assert.equal(await p.locator('.tlp-panel .tlp-card.d-design[data-pattern="grid"]').count(),1,'preview shows neon');
 await shot(p,'7d-designs');await noOverflow(p);
 await p.click('[data-view="awards"]');assert.match(await p.textContent('#app'),/Card of the Week[\s\S]*Anna[\s\S]*120 EXP[\s\S]*Zwei starke Sparrings/);
 assert.equal(await p.locator('[data-view="staff"]').count(),0,'boxer cannot award');
 assert.deepEqual(errors,[]);await context.close();

 // B: Coach bestätigt Vorschlag, nimmt mit Grund zurück
 ({p,errors,context}=await page({role:'coach',me:'Marco'}));
 await p.goto(base+'karten.html?view=staff');await p.waitForSelector('.kd-confirm');
 assert.match(await p.textContent('#app'),/Anna · 120 EXP · 2 Trainings Vorschlag/);
 assert.match(await p.textContent('#app'),/Vergeben kannst du nach Ende des Zeitraums/);
 const form=p.locator('.kd-confirm[data-kind="cotw"]');
 assert.equal(await form.locator('select').inputValue(),'p-anna','suggestion preselected');
 await form.locator('input[name="note"]').fill('Zwei starke Sparrings');await form.locator('button').click();
 await p.waitForFunction(()=>/Card of the Week: Anna ist ausgezeichnet/.test(document.getElementById('status').textContent));
 assert.deepEqual((await p.evaluate(()=>window.__calls)).find(c=>c[0]==='staff_confirm_card_award')[1],{p_kind:'cotw',p_period_start:'2026-10-19',p_profile_id:'p-anna',p_note:'Zwei starke Sparrings'});
 await shot(p,'7d-vergeben');
 await p.locator('.kd-more:has(.kd-revoke) > summary').click();
 const rv=p.locator('.kd-revoke');await rv.locator('button').click();
 await p.waitForTimeout(200);assert.ok(!(await p.evaluate(()=>window.__calls)).some(c=>c[0]==='staff_revoke_card_award'),'no revoke without reason');
 await rv.locator('input').fill('Falsche Woche');await rv.locator('button').click();
 await p.waitForFunction(()=>/zurückgezogen/.test(document.getElementById('status').textContent));
 assert.deepEqual((await p.evaluate(()=>window.__calls)).find(c=>c[0]==='staff_revoke_card_award')[1],{p_award_id:7,p_reason:'Falsche Woche'});
 await noOverflow(p);assert.deepEqual(errors,[]);await context.close();

 // C: Podium zeigt die Card of the Week im Spezial-Design; Vergleich zeigt Designs
 ({p,errors,context}=await page({role:'boxer',me:'Ben'}));
 await p.goto(base+'index.html#podium');await p.waitForSelector('.tlp-awards .tlp-card.d-design .tlp-badge',{timeout:10000});
 assert.match(await p.textContent('.tlp-awards'),/Card of the Week[\s\S]*ANNA/);
 await p.goto(base+'boxer-compare.html?left=Anna&right=Ben');await p.waitForSelector('.tlp-compare .tlp-card.d-design');
 assert.equal(await p.locator('.tlp-compare .tlp-badge').textContent(),'COTW');
 await shot(p,'7d-vergleich');assert.deepEqual(errors,[]);await context.close();

 await browser.close();server.close();
 console.log('PASS: Karten-Designs wählen/kaufen/gesperrt, Auszeichnungen ansehen, Coach bestätigt Vorschlag und nimmt mit Grund zurück, Podium und Vergleich zeigen die Designs – im Browser geprüft');
})().catch(e=>{console.error(e);process.exit(1)});
