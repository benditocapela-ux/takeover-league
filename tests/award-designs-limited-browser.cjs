'use strict';
// Chromium test with mocked Supabase (no real account, no server writes) for Etappe 13:
// Auszeichnungs-Designs zeigen «gilt bis», abgelaufene sind gesperrt (Symbole bleiben), Auszeichnungen und Vergeben nennen das Enddatum.
const assert=require('node:assert/strict'),fs=require('node:fs'),http=require('node:http'),path=require('node:path');
const {chromium}=require('playwright');
const root=process.cwd();
const server=http.createServer((req,res)=>{
 const u=new URL(req.url,'http://127.0.0.1');
 const file=path.resolve(root,decodeURIComponent(u.pathname.slice(1))||'index.html');
 if(!file.startsWith(root+path.sep)){res.writeHead(403);res.end();return}
 fs.readFile(file,(err,data)=>{if(err){res.writeHead(404);res.end();return}
  const ext=path.extname(file);res.setHeader('Content-Type',ext==='.js'?'text/javascript':ext==='.html'?'text/html':ext==='.css'?'text/css':ext==='.svg'?'image/svg+xml':'application/octet-stream');res.end(data)});
});
function injected(cfg){
 const calls=[];window.__calls=calls;
 const D=(key,name,unlock,extra,design)=>({key,name,description:name+' Design',unlock,min_rank:null,price:null,award_kind:null,design,valid_until:null,won:null,...extra});
 const designs=[D('classic','Klassisch','start',{available:true},{tier:true}),
  D('cotw','Card of the Week','award',{award_kind:'cotw',available:true,valid_until:'2026-11-01',won:1},{a:'#7be3a0',b:'#0f3b2a',ink:'#f2fff7',edge:'#f2c14e',pattern:'rays',badge:'COTW'}),
  D('cotm','Card of the Month','award',{award_kind:'cotm',available:false,won:1},{a:'#ff9f5a',b:'#3d1206',ink:'#fff3e8',edge:'#f2c14e',pattern:'rays',badge:'COTM',glow:true}),
  D('poty','Player of the Year','award',{award_kind:'poty',available:false,won:0},{a:'#fff0bf',b:'#0a0a0a',ink:'#f2c14e',edge:'#ffffff',pattern:'diamond',badge:'POTY',glow:true})];
 const awards=[{kind:'cotw',period_start:'2026-10-19'},{kind:'cotm',period_start:'2026-08-01'}];
 const lookOf=k=>(d=>({key:d.key,name:d.name,design:d.design,awards}))(designs.find(x=>x.key===k));
 const award={id:7,kind:'cotw',period_start:'2026-10-19',period_end:'2026-10-25',design_from:'2026-10-26',design_until:'2026-11-01',display_name:'Ben',exp:120,note:null,awarded_by:'Marco',revoked:false};
 const rpc=async(name,args)=>{
  calls.push([name,args]);
  if(name==='get_my_card_designs')return {data:{enabled:true,preview:false,display_name:'Ben',rank:'E',shop:true,coins:0,look:lookOf('cotw'),designs},error:null};
  if(name==='get_my_personal_design')return {data:{granted:false},error:null};
  if(name==='get_card_awards')return {data:{enabled:true,latest:{cotw:{...award,look:lookOf('cotw')},cotm:null,poty:null},history:[award]},error:null};
  if(name==='get_my_performance')return {data:{profile:{id:'p-me',display_name:'Ben',role:cfg.role},ratings_enabled:true,style_enabled:true,rating:null,style:{current:null}},error:null};
  if(name==='staff_card_award_overview')return {data:{today:'2026-10-29',boxers:[{id:'p-anna',display_name:'Anna'}],kinds:['cotw','cotm','poty'].map(k=>({kind:k,periods:[
   {start:k==='cotw'?'2026-10-19':k==='cotm'?'2026-09-01':'2025-01-01',end:k==='cotw'?'2026-10-25':k==='cotm'?'2026-09-30':'2025-12-31',completed:true,award:null,
    candidates:[{profile_id:'p-anna',display_name:'Anna',exp:120,trainings:2}]},
   {start:k==='cotw'?'2026-10-26':k==='cotm'?'2026-10-01':'2026-01-01',end:k==='cotw'?'2026-11-01':k==='cotm'?'2026-10-31':'2026-12-31',completed:false,award:null,candidates:[]}]}))},error:null};
  if(name==='equip_card_design')return {data:lookOf(args.p_key),error:null};
  if(/looks|get_public_boxer_looks/.test(name))return {data:name==='get_public_boxer_looks'?[]:{},error:null};
  return {data:null,error:{message:'unexpected rpc '+name}};
 };
 const q={select(){return q},eq(){return q},order(){return q},limit(){return q},maybeSingle:async()=>({data:{role:cfg.role,is_active:true},error:null}),then:(r)=>Promise.resolve({data:[],error:null}).then(r)};
 window.__takeoverMockClient={auth:{getSession:async()=>({data:{session:{access_token:'x'}}}),getUser:async()=>({data:{user:{id:'u1'}},error:null}),onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}})},from:()=>q,rpc};
}
(async()=>{
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const base='http://127.0.0.1:'+server.address().port+'/';
 const browser=await chromium.launch();
 const shot=async(p,n)=>{if(process.env.SHOTS)await p.screenshot({path:process.env.SHOTS+'/'+n+'.png',fullPage:true})};
 const ctxs=[];
 async function page(cfg,file){
  const context=await browser.newContext({viewport:{width:390,height:844}});ctxs.push(context);
  await context.addInitScript({content:'('+injected.toString()+')('+JSON.stringify(cfg)+')'});
  const p=await context.newPage();const errors=[];p.on('pageerror',e=>errors.push(e.message));p.on('dialog',d=>{errors.push('dialog');d.dismiss()});
  await p.route('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm',r=>r.fulfill({status:200,contentType:'text/javascript',body:'export const createClient=()=>window.__takeoverMockClient;'}));
  await p.route('https://iqarjivcrddcixrvqbfb.supabase.co/**',r=>r.fulfill({status:200,contentType:'application/json',body:'[]'}));
  await p.goto(base+file);return {p,errors};
 }
 const noOverflow=async p=>assert.ok(await p.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth),'no horizontal scroll');

 // A: Boxer – aktuelles Auszeichnungs-Design mit «gilt bis», abgelaufenes gesperrt, Symbole bleiben auf der Karte
 let {p,errors}=await page({role:'boxer'},'karten.html');
 await p.waitForSelector('.kd-grid');
 assert.match(await p.textContent('.tlp-panel.tlp-row'),/Card of the Week[\s\S]*gilt bis 01\.11\.2026/);
 assert.match(await p.textContent('.kd-item:has-text("Card of the Week")'),/gilt bis 01\.11\.2026[\s\S]*ausgewählt/);
 const cotm=await p.textContent('.kd-item:has-text("Card of the Month")');
 assert.match(cotm,/abgelaufen – gilt wieder nach der nächsten Card of the Month/);assert.doesNotMatch(cotm,/gilt bis/);
 assert.match(await p.textContent('.kd-item:has-text("Player of the Year")'),/nur als Player of the Year/);
 assert.equal(await p.locator('.kd-item:has-text("Card of the Month") [data-equip]').count(),0,'expired not selectable');
 {const st=await p.textContent('.tlp-panel.tlp-row .tlp-stars');assert.ok(st.includes('⭐')&&st.includes('🏆'),'symbols stay')}
 await shot(p,'13-designs');await noOverflow(p);
 await p.click('[data-view="awards"]');
 assert.match(await p.textContent('.kd-award'),/Ben[\s\S]*Spezial-Design bis 01\.11\.2026/);
 const note=await p.textContent('#app');
 assert.match(note,/nach der Card of the Week die ganze nächste Woche/);assert.doesNotMatch(note,/für immer\.<\/p>|bleibt dir für immer/);
 await shot(p,'13-awards');assert.deepEqual(errors,[]);

 // B: Trainer – beim Vergeben steht, bis wann das Design gilt
 ({p,errors}=await page({role:'coach'},'karten.html?view=staff'));
 await p.waitForSelector('.kd-confirm');
 const forms=await p.locator('.kd-confirm').allTextContents();
 assert.equal(forms.length,3);
 assert.match(forms[0],/Spezial-Design für den Gewinner bis 01\.11\.2026/);
 assert.match(forms[1],/bis 31\.10\.2026/);assert.match(forms[2],/bis 31\.12\.2026/);
 await shot(p,'13-staff');await noOverflow(p);assert.deepEqual(errors,[]);

 for(const c of ctxs)await c.close();
 await browser.close();server.close();
 console.log('PASS: Etappe 13 im Browser – Auszeichnungs-Design mit «gilt bis», abgelaufenes gesperrt mit Hinweis, Symbole bleiben, Auszeichnungen nennen das Enddatum, Trainer sieht beim Vergeben das Enddatum');
})().catch(e=>{console.error(e);process.exit(1)});
