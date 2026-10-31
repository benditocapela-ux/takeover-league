'use strict';
// Chromium test with mocked Supabase SDK (no real account, no server writes) for Etappe 10 (Selbsteinschätzung):
// Boxer ohne Karte schätzt sich ein und wartet dann auf den Trainer; Wartezeit und Ablehnung mit Kommentar (escaped);
// Trainer öffnet die Selbsteinschätzung aus der Mitteilung, gibt so frei, passt an oder lehnt mit zweitem Klick ab;
// Coach-Dashboard zeigt den Hinweis mit Link.
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
 const profile={id:cfg.role==='boxer'?'p-anna':'p-coach',display_name:cfg.role==='boxer'?'Anna':'Marco',role:cfg.role};
 let self=cfg.self;
 const review={id:7,boxer_id:'p-anna',display_name:'Anna',created_at:'2026-10-27T09:00:00Z',scores:{...all(14),jab:16},scale:20,note:'Mein <i>Jab</i> ist schneller',overall:71,is_self:false,
  current:{scores:all(6),scale:10,created_at:'2026-09-01T10:00:00Z',overall:60}};
 let reviews=cfg.reviews?[review]:[];
 const rpc=async(name,args)=>{
  calls.push([name,args]);
  if(name==='get_my_performance')return {data:{profile,ratings_enabled:true,style_enabled:true,rating:null,style:{current:null,previous:null,state:{}}},error:null};
  if(name==='get_my_self_rating')return {data:self,error:null};
  if(name==='submit_self_rating'){self={enabled:true,interval_days:14,can_submit:false,next_allowed_on:'2026-11-11',pending:{id:9,created_at:new Date().toISOString(),scores:args.p_scores,scale:20,overall:64},last:null};
   return {data:{id:9,overall:64,notified:2,next_allowed_on:'2026-11-11'},error:null}}
  if(name==='staff_list_performance')return {data:[{id:'p-anna',display_name:'Anna',role:'boxer',overall:60,rated_at:'2026-09-01T10:00:00Z',style:{},style_scores:null,is_self:false}],error:null};
  if(name==='staff_list_self_ratings')return {data:reviews.map(r=>({...r})),error:null};
  if(name==='staff_decide_self_rating'){reviews=[];
   return {data:{id:args.p_id,boxer:'Anna',status:args.p_decision==='decline'?'declined':args.p_decision==='adjust'?'adjusted':'approved',previous_overall:60,overall:args.p_decision==='decline'?null:69},error:null}}
  if(/looks|awards|kampfgeist|kg_/.test(name))return {data:{},error:null};
  return {data:null,error:{message:'unexpected rpc '+name}};
 };
 const q={select(){return q},eq(){return q},order(){return q},limit(){return q},maybeSingle:async()=>({data:{role:profile.role,is_active:true,display_name:profile.display_name},error:null}),then:(r)=>Promise.resolve({data:[],error:null}).then(r)};
 window.__takeoverMockClient={
  auth:{getSession:async()=>({data:{session:{access_token:'x'}}}),getUser:async()=>({data:{user:{id:'u1'}},error:null}),onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}})},
  from:()=>q,rpc};
}
// Coach-Dashboard: bewährter Basis-Mock wie in coach-feedback-browser.cjs plus die neue RPC
const base=fs.readFileSync(path.join(__dirname,'release-auth-ui-mocked.cjs'),'utf8');
const start=base.indexOf('function injected(role){');let coachMock=base.slice(start,base.indexOf('\n}\n',start)+2);
assert.ok(start>0,'base mock found');
coachMock=coachMock.replace('rpc:async(name,args)=>{','rpc:async(name,args)=>{const __x=window.__extraRpc&&window.__extraRpc(name,args);if(__x)return __x;');
assert.ok(coachMock.includes('window.__extraRpc'),'rpc hook');
function coachExtra(n){
 window.__extraRpc=(name)=>{
  if(name!=='staff_list_self_ratings')return null;
  const rows=[{id:7,display_name:'Anna',is_self:false},{id:8,display_name:'Ben',is_self:false},{id:9,display_name:'Ich',is_self:true}].slice(0,n);
  return Promise.resolve({data:rows,error:null});
 };
}
(async()=>{
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const url='http://127.0.0.1:'+server.address().port+'/';
 const browser=await chromium.launch();
 const ctxs=[];
 async function open(cfg,file){
  const context=await browser.newContext({viewport:{width:390,height:844}});ctxs.push(context);
  await context.addInitScript({content:cfg.coachDash?'('+coachExtra.toString()+')('+cfg.n+');('+coachMock+')("admin")':'('+injected.toString()+')('+JSON.stringify(cfg)+')'});
  const p=await context.newPage();const errors=[];p.on('pageerror',e=>errors.push(e.message));
  p.on('dialog',d=>{errors.push('dialog '+d.message());d.dismiss()});
  await p.route('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm',r=>r.fulfill({status:200,contentType:'text/javascript',body:'export const createClient=()=>window.__takeoverMockClient;'}));
  await p.route('https://iqarjivcrddcixrvqbfb.supabase.co/**',r=>r.fulfill({status:200,contentType:'application/json',body:'[]'}));
  await p.goto(url+file);return {p,errors};
 }
 const shot=async(p,n)=>{if(process.env.SHOTS)await p.screenshot({path:process.env.SHOTS+'/'+n+'.png',fullPage:true})};
 const noOverflow=async p=>assert.ok(await p.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth),'no horizontal scroll');

 // A: Boxer ohne Karte startet mit der Selbsteinschätzung
 let {p,errors}=await open({role:'boxer',self:{enabled:true,interval_days:14,can_submit:true,next_allowed_on:null,pending:null,last:null}},'bewertung.html');
 await p.waitForSelector('[data-act="self-open"]');
 assert.match(await p.textContent('#app'),/Starte mit deiner Selbsteinschätzung[\s\S]*Schätze dich selbst ein/);
 await shot(p,'10-boxer-start');
 await p.click('[data-act="self-open"]');await p.waitForSelector('[data-range="jab"]');
 assert.equal(await p.locator('[data-range]').count(),25);
 assert.equal(await p.inputValue('[data-range="jab"]'),'10','start at 10 without a card');
 assert.match(await p.textContent('#app'),/Wie stark bist du gerade\?[\s\S]*Deine Einschätzung/);
 await p.fill('[data-range="jab"]','16');await p.fill('[data-range="guard"]','13');
 await p.fill('#rateNote','Mein Jab ist schneller');
 await shot(p,'10-boxer-editor');
 await p.click('[data-act="self-save"]');
 await p.waitForFunction(()=>window.__calls.some(c=>c[0]==='submit_self_rating'));
 const sub=(await p.evaluate(()=>window.__calls)).find(c=>c[0]==='submit_self_rating')[1];
 assert.equal(Object.keys(sub.p_scores).length,25);assert.equal(sub.p_scores.jab,16);assert.equal(sub.p_scores.guard,13);assert.equal(sub.p_scores.cross,10);
 assert.equal(sub.p_note,'Mein Jab ist schneller');
 await p.waitForSelector('[data-self="pending"]');
 assert.match(await p.textContent('#status'),/Abgeschickt: deine Einschätzung 64\. Dein Trainer ist informiert\./);
 assert.match(await p.textContent('[data-self="pending"]'),/Wartet auf deinen Trainer[\s\S]*Gesamtwertung 64/);
 assert.equal(await p.locator('[data-act="self-open"]').count(),0,'no second submission while pending');
 await shot(p,'10-boxer-pending');
 await noOverflow(p);assert.deepEqual(errors,[]);

 // B: Wartezeit nach Ablehnung, Kommentar escaped
 ({p,errors}=await open({role:'boxer',self:{enabled:true,interval_days:14,can_submit:false,next_allowed_on:'2026-11-11',pending:null,
  last:{id:3,status:'declined',created_at:'2026-10-28T08:00:00Z',decided_at:'2026-10-28T09:00:00Z',decided_by:'Marco',coach_note:'<b>Erst sparren</b>',overall:90}}},'bewertung.html'));
 await p.waitForSelector('[data-self="wait"]');
 const wait=await p.textContent('[data-self="wait"]');
 assert.match(wait,/Nächste Selbsteinschätzung ab 11\.11\.2026/);assert.match(wait,/nicht übernommen von Marco · «<b>Erst sparren<\/b>»/);
 assert.equal(await p.locator('[data-self="wait"] b b').count(),0,'coach note escaped');
 assert.deepEqual(errors,[]);

 // C: Flag aus → keine Selbsteinschätzung sichtbar
 ({p,errors}=await open({role:'boxer',self:{enabled:false,reason:'flag'}},'bewertung.html'));
 await p.waitForSelector('#app .tlp-panel');
 assert.equal(await p.locator('.tlp-self').count(),0);assert.match(await p.textContent('#app'),/Dein Coach bewertet bald/);
 assert.deepEqual(errors,[]);

 // D: Trainer öffnet die Selbsteinschätzung aus der Mitteilung, passt an und gibt frei
 ({p,errors}=await open({role:'coach',reviews:true,self:{enabled:true,interval_days:14,can_submit:false,next_allowed_on:'2026-11-11',pending:null,last:null}},'bewertung.html?selbst=7'));
 await p.waitForSelector('[data-act="decide"]');
 const ed=await p.textContent('#app');
 assert.match(ed,/Selbsteinschätzung vom 27\.10\.2026[\s\S]*Anna[\s\S]*Anna schreibt[\s\S]*Mein <i>Jab<\/i> ist schneller/,'boxer note shown as text');
 assert.equal(await p.inputValue('[data-range="jab"]'),'16','starts with the boxer values');
 assert.equal(await p.textContent('[data-act="decide"]'),'So freigeben');
 await shot(p,'10-coach-review');
 await p.fill('[data-range="jab"]','13');
 assert.equal(await p.textContent('[data-act="decide"]'),'Angepasst freigeben');
 assert.match(await p.textContent('[data-row="jab"]'),/Boxer 16/);
 await p.fill('#rateNote','Jab gut, aber noch nicht 16');
 await p.click('[data-act="decide"]');
 await p.waitForFunction(()=>window.__calls.some(c=>c[0]==='staff_decide_self_rating'));
 const dec=(await p.evaluate(()=>window.__calls)).find(c=>c[0]==='staff_decide_self_rating')[1];
 assert.equal(dec.p_id,7);assert.equal(dec.p_decision,'adjust');assert.equal(dec.p_scores.jab,13);assert.equal(dec.p_scores.cross,14);assert.equal(dec.p_note,'Jab gut, aber noch nicht 16');
 await p.waitForFunction(()=>/Gespeichert: Anna 60 → 69 \(angepasst\)/.test(document.getElementById('status').textContent));
 assert.equal(await p.locator('[data-review]').count(),0,'list empty after decision');
 await noOverflow(p);assert.deepEqual(errors,[]);

 // E: Trainer: Liste, unverändert freigeben; Ablehnen braucht zwei Klicks
 ({p,errors}=await open({role:'admin',reviews:true},'bewertung.html'));
 await p.waitForSelector('[data-review="7"]');
 assert.match(await p.textContent('[data-review="7"]'),/71[\s\S]*Anna[\s\S]*aktuelle Karte 60/);
 await shot(p,'10-coach-list');
 await p.click('[data-review="7"]');await p.waitForSelector('[data-act="decline"]');
 await p.click('[data-act="decline"]');
 assert.equal(await p.textContent('[data-act="decline"]'),'Wirklich ablehnen?');
 assert.ok(!(await p.evaluate(()=>window.__calls)).some(c=>c[0]==='staff_decide_self_rating'),'first click does not decide');
 await p.click('[data-act="decline"]');
 await p.waitForFunction(()=>window.__calls.some(c=>c[0]==='staff_decide_self_rating'));
 const dl=(await p.evaluate(()=>window.__calls)).find(c=>c[0]==='staff_decide_self_rating')[1];
 assert.equal(dl.p_decision,'decline');assert.equal(dl.p_scores,null);
 await p.waitForFunction(()=>/abgelehnt, Karte bleibt/.test(document.getElementById('status').textContent));
 assert.deepEqual(errors,[]);
 ({p,errors}=await open({role:'admin',reviews:true},'bewertung.html?selbst=7'));
 await p.waitForSelector('[data-act="decide"]');await p.click('[data-act="decide"]');
 await p.waitForFunction(()=>window.__calls.some(c=>c[0]==='staff_decide_self_rating'));
 const ap=(await p.evaluate(()=>window.__calls)).find(c=>c[0]==='staff_decide_self_rating')[1];
 assert.equal(ap.p_decision,'approve');assert.equal(ap.p_scores,null);
 assert.deepEqual(errors,[]);

 // F: Coach-Dashboard zeigt den Hinweis (eigene Einschätzungen zählen nicht)
 ({p,errors}=await open({coachDash:true,n:3},'coach.html'));
 await p.waitForSelector('#selfRatingNotice:not([hidden])');
 assert.equal(await p.textContent('#selfRatingNotice'),'🃏 2 Selbsteinschätzungen warten auf dich: Anna, Ben – anpassen oder freigeben →');
 assert.match(await p.getAttribute('#selfRatingNotice','href'),/^\.\/bewertung\.html$/);
 // Trainer-Dashboard 2.0: Hinweis steht ganz oben auf der Startseite, der Server-Hinweis bleibt am Ende der Startseite
 assert.deepEqual(await p.evaluate(()=>{const h=document.getElementById('viewHome');const k=[...h.children];return [k.indexOf(document.getElementById('selfRatingNotice')),k.indexOf(h.querySelector('.notice'))===k.length-1]}),[0,true]);
 await shot(p,'10-coach-dashboard');
 assert.deepEqual(errors,[]);
 ({p,errors}=await open({coachDash:true,n:1},'coach.html'));
 await p.waitForSelector('#selfRatingNotice:not([hidden])');
 assert.equal(await p.getAttribute('#selfRatingNotice','href'),'./bewertung.html?selbst=7');
 assert.match(await p.textContent('#selfRatingNotice'),/1 Selbsteinschätzung wartet auf dich: Anna/);
 ({p,errors}=await open({coachDash:true,n:0},'coach.html'));
 await p.waitForFunction(()=>!document.querySelector('#content').classList.contains('hidden'));
 await p.waitForTimeout(300);
 assert.ok(await p.isHidden('#selfRatingNotice'),'no notice without open reviews');
 assert.deepEqual(errors,[]);

 for(const c of ctxs)await c.close();
 await browser.close();server.close();
 console.log('PASS: Selbsteinschätzung im Browser – Boxer schätzt sich ein und wartet, Wartezeit/Ablehnung mit escaptem Kommentar, Flag aus unsichtbar, Trainer passt an/gibt frei/lehnt mit zweitem Klick ab, Coach-Dashboard-Hinweis');
})().catch(e=>{console.error(e);process.exit(1)});
