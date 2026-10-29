'use strict';
// Chromium test with mocked Supabase SDK (no real account, no server writes) for Etappe 15 (öffentliche Kartenwerte, beste = 92):
// Boxer sieht auf der Bewertungsseite echte Werte, öffentliche in Klammern, mit Erklärung; Trainer-Liste und Vorschau im Formular
// zeigen nur den öffentlichen Wert (Etappe 17b; beste Karte ohne den Boxer oder seine neue Wertung, falls besser).
const assert=require('node:assert/strict'),fs=require('node:fs'),http=require('node:http'),path=require('node:path');
const {chromium}=require('playwright');
const root=process.cwd();
const server=http.createServer((req,res)=>{
 const u=new URL(req.url,'http://127.0.0.1'),file=path.resolve(root,(u.pathname==='/'?'index.html':decodeURIComponent(u.pathname.slice(1))));
 if(!file.startsWith(root+path.sep)){res.writeHead(403);res.end();return}
 fs.readFile(file,(err,data)=>{if(err){res.writeHead(404);res.end();return}
  const ext=path.extname(file);res.setHeader('Content-Type',ext==='.js'?'text/javascript':ext==='.html'?'text/html':ext==='.css'?'text/css':ext==='.svg'?'image/svg+xml':'application/octet-stream');res.end(data)});
});
function injected(cfg){
 const keys=['jab','cross','hook','upper','body','combo','guard','block','slip','roll','parry','counter','stance','steps','angles','ring','endur','pace','recov','timing','dist','plan','focus','heart','coach'];
 const all=v=>Object.fromEntries(keys.map(k=>[k,v]));
 const calls=[];window.__calls=calls;
 const profile={id:cfg.role==='boxer'?'p-ben':'p-coach',display_name:cfg.role==='boxer'?'Ben':'Marco',role:cfg.role};
 const sum=(o,c,pub)=>({scale:20,overall:o,categories:c,top:[{k:'jab',v:14}],low:[{k:'endur',v:11}],public:pub});
 const rating={current:{scores:all(13),scale:20,created_at:'2026-10-20T10:00:00Z',note:null,rated_by:'Marco',
   summary:sum(65,{OFF:65,DEF:63,BEI:71,KON:57,TAK:65,MEN:62},{target:92,best:65,overall:92,categories:{OFF:92,DEF:89,BEI:99,KON:81,TAK:92,MEN:88}})},
  previous:{scores:all(12),scale:20,created_at:'2026-09-20T10:00:00Z',summary:sum(60,{OFF:60,DEF:60,BEI:60,KON:60,TAK:60,MEN:60},{target:92,best:65,overall:85,categories:{OFF:85,DEF:85,BEI:85,KON:85,TAK:85,MEN:85}})}};
 const rpc=async(name,args)=>{
  calls.push([name,args]);
  if(name==='get_my_performance')return {data:{profile,ratings_enabled:true,style_enabled:true,rating:cfg.role==='boxer'?rating:null,style:{current:null,previous:null,state:{}}},error:null};
  if(name==='get_my_self_rating')return {data:{enabled:false},error:null};
  if(name==='get_rating_card_scale')return {data:{target:92,best:65,best_others:60},error:null};
  if(name==='staff_list_performance')return {data:[{id:'p-ben',display_name:'Ben',role:'boxer',overall:65,public_overall:92,rated_at:'2026-10-20T10:00:00Z',style:{},style_scores:null,is_self:false},
   {id:'p-sasha',display_name:'Sasha',role:'boxer',overall:null,public_overall:null,rated_at:null,style:{},style_scores:null,is_self:false}],error:null};
  if(name==='staff_list_self_ratings')return {data:[],error:null};
  if(name==='staff_get_rating')return {data:null,error:null};
  if(/looks|awards|kampfgeist|kg_/.test(name))return {data:{},error:null};
  return {data:null,error:{message:'unexpected rpc '+name}};
 };
 const q={select(){return q},eq(){return q},order(){return q},limit(){return q},maybeSingle:async()=>({data:{role:profile.role,is_active:true,display_name:profile.display_name},error:null}),then:(r)=>Promise.resolve({data:[],error:null}).then(r)};
 window.__takeoverMockClient={
  auth:{getSession:async()=>({data:{session:{access_token:'x'}}}),getUser:async()=>({data:{user:{id:'u1'}},error:null}),onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}})},
  from:()=>q,rpc};
}
(async()=>{
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const url='http://127.0.0.1:'+server.address().port+'/';
 const browser=await chromium.launch();
 const ctxs=[];
 async function open(cfg,file){
  const context=await browser.newContext({viewport:{width:390,height:844}});ctxs.push(context);
  await context.addInitScript({content:'('+injected.toString()+')('+JSON.stringify(cfg)+')'});
  const p=await context.newPage();const errors=[];p.on('pageerror',e=>errors.push(e.message));
  p.on('dialog',d=>{errors.push('dialog '+d.message());d.dismiss()});
  await p.route('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm',r=>r.fulfill({status:200,contentType:'text/javascript',body:'export const createClient=()=>window.__takeoverMockClient;'}));
  await p.route('https://iqarjivcrddcixrvqbfb.supabase.co/**',r=>r.fulfill({status:200,contentType:'application/json',body:'[]'}));
  await p.goto(url+file);return {p,errors};
 }
 const shot=async(p,n)=>{if(process.env.SHOTS)await p.screenshot({path:process.env.SHOTS+'/'+n+'.png',fullPage:true})};
 const noOverflow=async p=>assert.ok(await p.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth),'no horizontal scroll');

 // A: Boxer – echte Karte, öffentliche Werte in Klammern, Erklärung
 let {p,errors}=await open({role:'boxer'},'bewertung.html');
 await p.waitForSelector('.tlp-card');
 assert.equal((await p.textContent('.tlp-card .tlp-ov')).trim(),'65','own card shows the real value');
 const big=await p.locator('.tlp-panel.tlp-row .tlp-big').first().textContent();
 assert.match(big,/65\s*\(92\)/);
 assert.match(await p.textContent('.tlp-scale-note'),/beste Karte der Liga hat 92[\s\S]*in Klammern den öffentlichen Wert/);
 const cats=await p.locator('.tlp-cat .tlp-catval').allTextContents();
 assert.match(cats.join('|'),/65\(92\)/);assert.match(cats.join('|'),/71\(99\)/);
 await shot(p,'15-bewertung');await noOverflow(p);assert.deepEqual(errors,[]);

 // B: Trainer – Liste mit echtem und öffentlichem Wert; Vorschau rechnet öffentlich
 ({p,errors}=await open({role:'coach'},'bewertung.html'));
 await p.waitForSelector('[data-open="p-ben"]');
 // Etappe 17b: Trainer sehen nur den öffentlichen Wert
 assert.equal((await p.textContent('[data-open="p-ben"] .tlp-chip')).trim(),'92');assert.doesNotMatch(await p.textContent('[data-open="p-ben"]'),/65|\(/);
 assert.doesNotMatch(await p.textContent('[data-open="p-sasha"]'),/\(/);
 await p.click('[data-open="p-sasha"]');
 await p.waitForSelector('.tlp-preview');
 assert.deepEqual((await p.evaluate(()=>window.__calls)).find(c=>c[0]==='get_rating_card_scale')[1],{p_boxer_id:'p-sasha'});
 // Alle Noten 10 → echt 50; beste ohne Sasha 60 → öffentlich 50×92/60 = 77 (Trainer sehen nur den öffentlichen Wert)
 assert.match(await p.textContent('.tlp-preview .tlp-big'),/^\s*77\s*$/);assert.equal((await p.textContent('.tlp-preview .tlp-ov')).trim(),'77');
 assert.match(await p.textContent('[data-cat="OFF"]'),/^77$/);
 // Sasha wird besser als die beste Karte → öffentlich 92
 await p.evaluate(()=>{for(const r of document.querySelectorAll('[data-range]')){r.value='20';r.dispatchEvent(new Event('input',{bubbles:true}))}});
 assert.match(await p.textContent('.tlp-preview .tlp-big'),/^\s*92\s*$/);
 await shot(p,'15-vorschau');await noOverflow(p);assert.deepEqual(errors,[]);

 for(const c of ctxs)await c.close();
 await browser.close();server.close();
 console.log('PASS: Etappe 15 im Browser – eigene Karte echt, öffentliche Werte in Klammern mit Erklärung, Trainer-Liste mit öffentlichem Wert, Vorschau rechnet öffentlich (auch wenn der Boxer die neue beste Karte wird)');
})().catch(e=>{console.error(e);process.exit(1)});
