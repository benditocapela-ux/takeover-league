'use strict';
// Real Chromium test with mocked Supabase SDK for Etappe 7c: tour on next login (once), «?» opens the matching
// help register, search across registers and FAQ, flag-gated registers, admin edits FAQ, guest reads FAQ.
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
 let seen=Number(sessionStorage.getItem('seen')||cfg.seen||0);
 let faq=[{id:1,category:'training',question:'Wie trage ich ein Training ein?',answer:'In Mein Studio auf «Training einreichen».',sort_order:20,is_published:true},
  {id:2,category:'kampfgeist',question:'Was sind Coins?',answer:'Coins gibt es für bestätigte Trainings.',sort_order:100,is_published:true}];
 const rpc=async(name,args)=>{
  calls.push([name,args]);
  if(name==='get_my_onboarding')return {data:cfg.signedIn?{enabled:true,role:cfg.role,tour_version:seen}:{enabled:false},error:null};
  if(name==='mark_tour_seen'){seen=args.p_version;sessionStorage.setItem('seen',String(seen));return {data:{tour_version:seen},error:null}}
  if(name==='get_faq')return {data:{can_edit:cfg.role==='admin'&&cfg.signedIn,items:faq},error:null};
  if(name==='admin_save_faq'){const x={id:args.p_id||3,category:args.p_category,question:args.p_question,answer:args.p_answer,sort_order:args.p_sort_order,is_published:args.p_published};faq=faq.filter(f=>f.id!==x.id).concat(x);return {data:x,error:null}}
  return {data:null,error:{message:'unexpected rpc '+name}};
 };
 const q={select(){return q},eq(){return q},order(){return q},limit(){return q},maybeSingle:async()=>({data:{role:cfg.role,is_active:true,display_name:'Anna'},error:null}),then:(r)=>Promise.resolve({data:[],error:null}).then(r)};
 window.__takeoverMockClient={auth:{getSession:async()=>({data:{session:cfg.signedIn?{access_token:'x'}:null}}),getUser:async()=>({data:{user:cfg.signedIn?{id:'u1'}:null},error:null}),onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}})},from:()=>q,rpc};
}
(async()=>{
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const base='http://127.0.0.1:'+server.address().port+'/';
 const browser=await chromium.launch();
 const shot=async(p,n)=>{if(process.env.SHOTS)await p.screenshot({path:process.env.SHOTS+'/'+n+'.png',fullPage:n.endsWith('full')})};
 async function page(cfg,flags){
  const context=await browser.newContext({viewport:{width:390,height:844}});
  await context.addInitScript({content:'('+injected.toString()+')('+JSON.stringify(cfg)+')'});
  const p=await context.newPage();const errors=[];p.on('pageerror',e=>errors.push(e.message));
  await p.route('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm',r=>r.fulfill({status:200,contentType:'text/javascript',body:'export const createClient=()=>window.__takeoverMockClient;'}));
  await p.route('https://iqarjivcrddcixrvqbfb.supabase.co/**',r=>{const u=r.request().url();
   r.fulfill({status:200,contentType:'application/json',body:JSON.stringify(u.includes('league_feature_flags')?(flags||[]).map(k=>({feature_key:k,is_enabled:true})):[])})});
  return {p,errors,context};
 }
 const noOverflow=async p=>assert.ok(await p.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth),'no horizontal scroll');

 // A: Tour beim nächsten Login (Boxer: ohne Trainer-Schritt), einmal pro Version
 let {p,errors,context}=await page({role:'boxer',signedIn:true});
 await p.goto(base+'boxer.html');await p.waitForSelector('.tl-tour',{timeout:8000});
 assert.match(await p.textContent('.tl-tour'),/Willkommen in der Takeover League/);assert.match(await p.textContent('.tl-tour-count'),/1 \/ 5/);
 await p.click('[data-tour="next"]');assert.match(await p.textContent('.tl-tour'),/Training eintragen/);
 await p.click('[data-tour="back"]');assert.match(await p.textContent('.tl-tour'),/Willkommen/);
 for(let i=0;i<3;i++)await p.click('[data-tour="next"]');
 assert.match(await p.textContent('.tl-tour'),/Alle Bereiche im Menü/);assert.equal(await p.locator('#takeover-menu-open.tl-tour-focus').count(),1,'menu highlighted');
 await shot(p,'7c-tour');
 await p.click('[data-tour="next"]');assert.match(await p.textContent('.tl-tour'),/Hilfe auf jeder Seite/);
 assert.doesNotMatch(await p.textContent('.tl-tour'),/Für Trainer/);
 await p.click('[data-tour="next"]');await p.waitForSelector('.tl-tour',{state:'detached'});
 await p.waitForFunction(()=>window.__calls.some(c=>c[0]==='mark_tour_seen'&&c[1].p_version===1));
 assert.equal(await p.locator('.tl-help-link').getAttribute('href'),'./hilfe.html#studio');
 await p.reload();await p.waitForTimeout(1500);assert.equal(await p.locator('.tl-tour').count(),0,'tour only once');
 await noOverflow(p);assert.deepEqual(errors,[]);await context.close();

 // B: Trainer: Escape schliesst, Trainer-Schritt vorhanden
 ({p,errors,context}=await page({role:'coach',signedIn:true}));
 await p.goto(base+'boxer.html');await p.waitForSelector('.tl-tour');assert.match(await p.textContent('.tl-tour-count'),/1 \/ 6/);
 await p.keyboard.press('Escape');await p.waitForSelector('.tl-tour',{state:'detached'});
 await p.waitForFunction(()=>window.__calls.some(c=>c[0]==='mark_tour_seen'));
 assert.deepEqual(errors,[]);await context.close();

 // C: «?» auf einer Seite → passendes Register offen; Flag-Register ausgeblendet; Suche über Register und FAQ
 ({p,errors,context}=await page({role:'boxer',signedIn:true,seen:1},['coach_ratings']));
 await p.goto(base+'boxer-compare.html');await p.waitForSelector('.tl-help-link');
 await p.click('.tl-help-link');await p.waitForURL(/hilfe\.html#vergleich$/);await p.waitForSelector('[data-key="vergleich"][open]');
 const help=await p.textContent('#app');
 assert.match(help,/Mein Studio/);assert.match(help,/Bewertung & Spielerkarte/,'flag on → shown');
 assert.doesNotMatch(help,/Kampfgeist-Shop|Wochen-Quests/,'flag off → hidden');assert.doesNotMatch(help,/Trainer-Dashboard/,'staff only');
 await p.fill('#helpSearch','coins');
 assert.equal(await p.locator('.help-qa:not([hidden])').count(),1);assert.ok(await p.locator('.help-qa:not([hidden])').evaluate(e=>e.open));
 await p.fill('#helpSearch','duell einladung');assert.equal(await p.locator('[data-key="duelle"]:not([hidden])').count(),1);
 await p.fill('#helpSearch','xyzzy');assert.ok(await p.locator('.help-none').isVisible());
 await p.fill('#helpSearch','');assert.ok(await p.locator('[data-act="tour"]').isVisible(),'tour can be repeated');
 await shot(p,'7c-hilfe');await noOverflow(p);assert.deepEqual(errors,[]);await context.close();

 // D: Admin pflegt die FAQ
 ({p,errors,context}=await page({role:'admin',signedIn:true,seen:1}));
 await p.goto(base+'hilfe.html');await p.waitForSelector('[data-act="new"]');
 assert.match(await p.textContent('#app'),/Trainer-Dashboard/,'admin sees staff registers');
 await p.click('[data-act="new"]');await p.selectOption('[data-edit="new"] select[name="cat"]','konto');
 await p.fill('[data-edit="new"] input[name="q"]','Gibt es eine App?');await p.fill('[data-edit="new"] textarea[name="a"]','Website zum Startbildschirm hinzufügen.');
 await p.click('[data-edit="new"] button[type="submit"]');
 await p.waitForFunction(()=>/Gespeichert/.test(document.getElementById('status').textContent));
 const save=(await p.evaluate(()=>window.__calls)).find(c=>c[0]==='admin_save_faq')[1];
 assert.deepEqual(save,{p_id:null,p_category:'konto',p_question:'Gibt es eine App?',p_answer:'Website zum Startbildschirm hinzufügen.',p_sort_order:100,p_published:true});
 assert.match(await p.textContent('.help-faq'),/Konto & Hilfe[\s\S]*Gibt es eine App\?/);
 assert.deepEqual(errors,[]);await context.close();

 // E: Gast: FAQ lesbar, keine Tour, kein Bearbeiten
 ({p,errors,context}=await page({role:'boxer',signedIn:false}));
 await p.goto(base+'hilfe.html');await p.waitForSelector('.help-qa');
 assert.ok(await p.locator('[data-act="tour"]').isHidden());assert.equal(await p.locator('[data-act="new"]').count(),0);
 assert.deepEqual(errors,[]);await context.close();

 await browser.close();server.close();
 console.log('PASS: Tour beim nächsten Login (einmal, Staff-Schritt, Escape), «?» öffnet das passende Register, Flags/Staff gefiltert, Suche über Register und FAQ, Admin pflegt FAQ, Gast liest – im Browser geprüft');
})().catch(e=>{console.error(e);process.exit(1)});
