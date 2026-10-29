'use strict';
// Chromium test with mocked Supabase (no real account, no server writes) for Etappe 16 (Kartenarena im Boxervergleich):
// alle Karten von der besten zur schwächsten, sortierbar; zwei antippen → Kampfplakat, Punktzettel, Tale of the Tape, Kartenprofil,
// Boxstil, Liga-Bilanz und Duellbilanz; abwählen, ersetzen, Ecken tauschen, Links mit ?left=&right=.
const assert=require('node:assert/strict'),fs=require('node:fs'),http=require('node:http'),path=require('node:path');
const {chromium}=require('playwright');
const root=process.cwd();
const server=http.createServer((req,res)=>{
 const u=new URL(req.url,'http://127.0.0.1'),file=path.resolve(root,decodeURIComponent(u.pathname.slice(1))||'index.html');
 if(!file.startsWith(root+path.sep)){res.writeHead(403);res.end();return}
 fs.readFile(file,(err,data)=>{if(err){res.writeHead(404);res.end();return}
  const ext=path.extname(file);res.setHeader('Content-Type',ext==='.js'?'text/javascript':ext==='.html'?'text/html':ext==='.css'?'text/css':ext==='.svg'?'image/svg+xml':'application/octet-stream');res.end(data)});
});
function injected(cfg){
 const calls=[];window.__calls=calls;
 const R=(o,c,d)=>({overall:o,categories:c,scaled:true,target:92,rated_at:'2026-10-20T10:00:00Z',delta:d});
 const gallery=[
  {display_name:'Ben',is_me:true,rating:R(92,{OFF:92,DEF:89,BEI:99,KON:81,TAK:92,MEN:88},4),style:{scores:{o:70,v:40,c:60,p:30,s:55,a:45},created_at:'2026-10-01T10:00:00Z'}},
  {display_name:'Matteo',is_me:false,rating:R(64,{OFF:61,DEF:64,BEI:68,KON:61,TAK:61,MEN:90},null),style:{scores:{o:20,v:75,c:30,p:80,s:25,a:70},created_at:'2026-10-02T10:00:00Z'}},
  {display_name:'Natan',is_me:false,rating:R(54,{OFF:42,DEF:42,BEI:50,KON:64,TAK:61,MEN:99},-2),style:null},
  {display_name:'Sasha',is_me:false,rating:R(38,{OFF:37,DEF:40,BEI:33,KON:38,TAK:31,MEN:54},null),style:null},
  {display_name:'Lia',is_me:false,rating:null,style:null}];
 const rpc=async(name,args)=>{
  calls.push([name,args]);
  if(name==='get_card_gallery')return {data:gallery,error:null};
  if(/looks|get_public_boxer_looks/.test(name))return {data:name==='get_public_boxer_looks'?[]:{},error:null};
  return {data:null,error:{message:'unexpected rpc '+name}};
 };
 const q={select(){return q},eq(){return q},order(){return q},limit(){return q},maybeSingle:async()=>({data:{role:'boxer',is_active:true,display_name:'Ben'},error:null}),then:(r)=>Promise.resolve({data:[],error:null}).then(r)};
 window.__takeoverMockClient={auth:{getSession:async()=>({data:{session:{access_token:'x'}}}),getUser:async()=>({data:{user:{id:'u1'}},error:null}),onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}})},from:()=>q,rpc};
}
const LEVELS=[['Ben',2400],['Matteo',1500],['Natan',900],['Sasha',300],['Lia',100]].map(([boxer_name,lifetime_exp])=>({boxer_name,lifetime_exp}));
const BOARD=LEVELS.map((x,i)=>({boxer_name:x.boxer_name,rank_position:i+1,monthly_points:200-i*30,approved_sessions:8-i,points_training:180-i*30,points_bonus:20}));
const DUELS=[{challenger_id:'b',opponent_id:'m',challenger_name:'Ben',opponent_name:'Matteo',challenger_score:12,opponent_score:9,winner_id:'b',settled_at:'2026-10-10T10:00:00Z'}];
(async()=>{
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const base='http://127.0.0.1:'+server.address().port+'/';
 const browser=await chromium.launch();
 const shot=async(p,n)=>{if(process.env.SHOTS)await p.screenshot({path:process.env.SHOTS+'/'+n+'.png',fullPage:true})};
 const ctxs=[];
 async function page(file,opts){
  const context=await browser.newContext({viewport:{width:390,height:844},...(opts||{})});ctxs.push(context);
  await context.addInitScript({content:'('+injected.toString()+')({})'});
  const p=await context.newPage();const errors=[];p.on('pageerror',e=>errors.push(e.message));p.on('dialog',d=>{errors.push('dialog');d.dismiss()});
  await p.route('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm',r=>r.fulfill({status:200,contentType:'text/javascript',body:'export const createClient=()=>window.__takeoverMockClient;'}));
  await p.route('https://iqarjivcrddcixrvqbfb.supabase.co/**',r=>{const u=r.request().url();
   const body=u.includes('get_public_levels')?LEVELS:u.includes('get_public_leaderboard')?BOARD:u.includes('league_public_duel_history_v21')?DUELS:[];
   r.fulfill({status:200,contentType:'application/json',body:JSON.stringify(body)})});
  await p.goto(base+file);return {p,errors};
 }
 const noOverflow=async p=>assert.ok(await p.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth),'no horizontal scroll');
 const names=p=>p.locator('.tla-item').evaluateAll(es=>es.map(e=>e.dataset.pick));

 // A: Galerie von der besten zur schwächsten Karte, Platz-Nummern, eigene Karte markiert, Auswahl-Listen ausgeblendet
 let {p,errors}=await page('boxer-compare.html');
 await p.waitForSelector('.tla-item');
 assert.deepEqual(await names(p),['Ben','Matteo','Natan','Sasha','Lia']);
 assert.deepEqual(await p.locator('.tla-place').allTextContents(),['1','2','3','4','–']);
 assert.match(await p.getAttribute('.tla-item[data-pick="Ben"]','class'),/first/);assert.equal((await p.textContent('.tla-item[data-pick="Ben"] .tla-pick')).trim(),'Du');
 assert.equal(await p.locator('.tla-item[data-pick="Lia"] .tla-blank').count(),1);
 await p.waitForFunction(()=>document.getElementById('left').options.length>1);
 assert.equal(await p.locator('#chooser').isVisible(),false,'selects hidden in gallery mode');
 assert.equal(await p.locator('.tla-arena').isHidden(),true);
 await shot(p,'16-galerie');await noOverflow(p);
 // Sortieren nach Mentalität
 await p.click('[data-sort="MEN"]');
 assert.deepEqual(await names(p),['Natan','Matteo','Ben','Sasha','Lia']);
 assert.match(await p.textContent('.tla-item[data-pick="Natan"] .tla-sv'),/MEN 99/);
 await p.click('[data-sort="overall"]');
 // Zwei Karten antippen → Arena
 await p.click('.tla-item[data-pick="Ben"]');
 assert.equal(await p.getAttribute('.tla-item[data-pick="Ben"]','aria-pressed'),'true');
 await p.waitForSelector('.tla-bar:not([hidden])');assert.match(await p.textContent('.tla-bar'),/Ben[\s\S]*zweite Karte wählen/);
 await p.click('.tla-item[data-pick="Matteo"]');
 await p.waitForSelector('.tla-arena:not([hidden]) .tla-poster');
 assert.equal(await p.textContent('.tla-corner.a .tla-name'),'Ben (du)');assert.equal(await p.textContent('.tla-corner.b .tla-name'),'Matteo');
 assert.match(await p.textContent('.tla-corner.a .tla-rank'),/Platz 1 von 4/);assert.match(await p.textContent('.tla-corner.b .tla-rank'),/Platz 2 von 4/);
 const verdict=await p.textContent('.tla-verdict');
 assert.match(verdict,/Nach Karten gewinnt Ben 59:55 – 5 von 6 Runden\./);
 assert.deepEqual(await p.locator('.tla-score tfoot td').allTextContents(),['59','55']);
 assert.equal(await p.locator('.tla-score tbody tr').count(),6);
 assert.match(await p.textContent('.tla-score tbody tr:last-child'),/9[\s\S]*Mentalität[\s\S]*10/);
 assert.match(await p.textContent('.tlp-cmprow.total'),/92[\s\S]*64[\s\S]*\+28/);
 assert.equal(await p.locator('.tla-hex .tlp-shape').count(),1);
 assert.match(await p.textContent('.tla-edges'),/Ben hat den grössten Vorsprung in Offense \(\+31\)[\s\S]*Matteo hat den grössten Vorsprung in Mentalität \(\+2\)/);
 assert.match(await p.textContent('.tla-arena'),/% gleicher Stil/);
 // Seite: Auswahl-Listen, Link, Liga-Bilanz und Duellbilanz folgen der Auswahl
 assert.equal(await p.inputValue('#left'),'Ben');assert.equal(await p.inputValue('#right'),'Matteo');
 assert.match(p.url(),/left=Ben&right=Matteo/);
 await p.waitForSelector('#headToHead:not([hidden]) .tla-tape');
 await p.waitForFunction(()=>/Direkte Duelle: 1/.test(document.getElementById('directDuelsStatus').textContent));
 assert.deepEqual((await p.locator('.tla-board strong').allTextContents()),['1','0','0']);
 await shot(p,'16-arena');if(process.env.SHOTS)await p.locator('.tla-arena').screenshot({path:process.env.SHOTS+'/16-arena-detail.png'});await noOverflow(p);
 // Dritte Karte ersetzt die blaue Ecke; Ecken tauschen; abwählen
 await p.click('.tla-item[data-pick="Natan"]');
 await p.waitForFunction(()=>document.querySelector('.tla-corner.b .tla-name')?.textContent==='Natan');
 assert.match(await p.textContent('.tla-verdict'),/Nach Karten gewinnt Ben/);
 await p.click('[data-act="swap"]');
 await p.waitForFunction(()=>document.querySelector('.tla-corner.a .tla-name')?.textContent==='Natan');
 assert.match(p.url(),/left=Natan&right=Ben/);
 await p.click('.tla-item[data-pick="Ben"]');
 await p.waitForSelector('.tla-arena[hidden]',{state:'attached'});
 // Karte ohne Bewertung: Hinweis statt Punktzettel
 await p.click('.tla-item[data-pick="Lia"]');
 await p.waitForSelector('.tla-arena:not([hidden]) .tla-poster');
 assert.match(await p.textContent('.tla-arena'),/Lia hat noch keine Karte/);assert.equal(await p.locator('.tla-score').count(),0);
 assert.deepEqual(errors,[]);

 // B: Link aus dem Profil (?left=Matteo&right=Natan) öffnet direkt das Duell; ?left=Ben wartet auf die zweite Karte
 ({p,errors}=await page('boxer-compare.html?left=Matteo&right=Natan'));
 await p.waitForSelector('.tla-arena:not([hidden]) .tla-poster');
 assert.equal(await p.textContent('.tla-corner.a .tla-name'),'Matteo');assert.equal(await p.textContent('.tla-corner.b .tla-name'),'Natan');
 assert.match(await p.textContent('.tla-verdict'),/gewinnt Matteo/);
 assert.deepEqual(errors,[]);
 ({p,errors}=await page('boxer-compare.html?left=Ben'));
 await p.waitForSelector('.tla-item.sel.a');
 assert.equal(await p.getAttribute('.tla-item.sel.a','data-pick'),'Ben');
 await p.waitForSelector('.tla-bar:not([hidden])');assert.deepEqual(errors,[]);

 // C: Breiter Bildschirm und reduzierte Bewegung
 ({p,errors}=await page('boxer-compare.html?left=Ben&right=Matteo',{viewport:{width:1100,height:900},reducedMotion:'reduce'}));
 await p.waitForSelector('.tla-arena:not([hidden]) .tla-poster');
 assert.equal(await p.evaluate(()=>getComputedStyle(document.querySelector('.tla-vs')).animationName),'none');
 await shot(p,'16-arena-desktop');await noOverflow(p);assert.deepEqual(errors,[]);

 for(const c of ctxs)await c.close();
 await browser.close();server.close();
 console.log('PASS: Etappe 16 im Browser – Kartenrangliste (beste zuerst, Platz-Nummern, sortierbar), zwei Karten antippen öffnen die Arena (Plakat, Punktzettel, Tale of the Tape, Kartenprofil, Vorteile, Boxstil), Liga-Bilanz und Duellbilanz folgen der Auswahl, ersetzen, tauschen, abwählen, Links, reduzierte Bewegung');
})().catch(e=>{console.error(e);process.exit(1)});
