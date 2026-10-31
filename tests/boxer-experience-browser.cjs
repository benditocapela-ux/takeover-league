'use strict';
// Boxer Experience (Takeover 3.0: integriertes Trainingsformular statt iframe) im echten Browser mit gemocktem Supabase-SDK (keine echten Konten, keine Schreibzugriffe).
// Prüft: Anmeldung/Rollen, fünf Bereiche, Holo nur auf «Heute», Podium mit Top 3, feststehende FUT-Card + Boxstil-Diagramm,
// scrollbarer Inhalt, Training-Bereich mit dem Ein-Klick-RPC aus PR #84 (alle Status) und Rückfall ohne Training 2.0,
// Touch/Tastatur, 320/390/1366 px ohne Querscrollen. Chromium; WebKit, wenn installiert (CI). Screenshots mit SHOTS=Ordner.
const assert=require('node:assert/strict'),fs=require('node:fs'),http=require('node:http'),path=require('node:path');
const playwright=require('playwright');
const root=process.cwd();
const server=http.createServer((req,res)=>{
 const u=new URL(req.url,'http://127.0.0.1'),file=path.resolve(root,decodeURIComponent(u.pathname.slice(1))||'index.html');
 if(!file.startsWith(root+path.sep)){res.writeHead(403);res.end();return}
 fs.readFile(file,(err,data)=>{if(err){res.writeHead(404);res.end();return}
  const ext=path.extname(file);res.setHeader('Content-Type',{'.js':'text/javascript','.html':'text/html','.css':'text/css','.svg':'image/svg+xml','.woff':'font/woff','.png':'image/png'}[ext]||'application/octet-stream');res.end(data)});
});
function injected(cfg){
 const today=new Intl.DateTimeFormat('en-CA',{timeZone:'Europe/Zurich'}).format(new Date());
 const dow=((new Date(today+'T12:00:00Z').getUTCDay()+6)%7)+1;
 const calls=[];window.__calls=calls;
 const me=cfg.anon?null:{id:'p-anna',auth_user_id:'u-anna',display_name:'Anna',role:cfg.role||'boxer',is_active:true};
 const reward={points:60,exp:60,coins:15,pass_points:15};
 const v2={enabled:cfg.v2!==false,preview:false,today,pflicht:[{slot_id:7,dow,day_name:'Heute',label:'Reguläres Boxtraining',training_type_id:1,duration_minutes:90,reward}].concat(cfg.twoSlots?[{slot_id:8,dow,day_name:'Heute',label:'Abendtraining',training_type_id:1,duration_minutes:60,reward}]:[]),
  extras:[{key:'sandsack',label:'Sandsacktraining im Verein',training_type_id:10,reward:{points:40,exp:40,coins:12}}],types:[],tiers:[]};
 const statuses=(cfg.statuses||['submitted','already_pending']).slice();
 window.__quick=[];
 const rpc=async(name,args)=>{calls.push([name,args]);await new Promise(r=>setTimeout(r,30));
  switch(name){
   case 'get_my_performance':return {data:{profile:me,rating:{current:{summary:{overall:78,categories:{OFF:80,DEF:74,BEI:79,KON:76,TAK:77,MEN:81}}}},style:{current:{scores:{o:80,v:45,c:60,p:70,s:55,a:65}}}},error:null};
   case 'get_card_looks':return {data:{},error:null};
   case 'get_holo_looks':{const o={};for(const n of (args.p_display_names||[]))o[n]={skin:'#c68642',pose_profile:'guard'};return {data:o,error:null}}
   case 'get_public_leaderboard':return {data:[{rank_position:2,boxer_name:'Ben',monthly_points:900,lifetime_exp:900},{rank_position:1,boxer_name:'Anna',monthly_points:1200,lifetime_exp:1500},{rank_position:3,boxer_name:'Cleo',monthly_points:700,lifetime_exp:800},{rank_position:4,boxer_name:'Dario',monthly_points:500,lifetime_exp:600}],error:null};
   case 'get_boxer_exp_level_rank':return {data:[{lifetime_exp:1500}],error:null};
   case 'get_training_v2_config':return cfg.v2==='missing'?{data:null,error:{code:'PGRST202',message:'Could not find the function'}}:{data:cfg.v2===false?{enabled:false}:v2,error:null};
   case 'submit_scheduled_club_training_today':{window.__quick.push(args);const st=args.p_slot_id==null?statuses.shift()||'already_pending':'submitted';
     return {data:{status:st,label:'Reguläres Boxtraining',submission_id:'x1',training_date:today},error:null}}
   default:return {data:[],error:null};
  }};
 function query(table){const f=[],o={};const self={select:(x,opt)=>{o.opt=opt;return self},eq:(k,v)=>{f.push([k,v]);return self},in:(k,v)=>{f.push([k,v,'in']);return self},order:()=>self,limit:()=>self,range:()=>self,insert:p=>{(window.__inserts=window.__inserts||[]).push([table,p]);return self},upsert:()=>self,delete:()=>self,
   maybeSingle:()=>({then:(a,b)=>Promise.resolve({data:compute().data[0]||null,error:null}).then(a,b)}),then:(a,b)=>Promise.resolve(compute()).then(a,b)};
  // wie postgrest-js: nur «thenable», kein .catch
  function compute(){
   const flags=[{feature_key:'performance_dashboard',is_enabled:true},{feature_key:'gym_training',is_enabled:!!cfg.checkinOnly},{feature_key:'club_checkin_only',is_enabled:!!cfg.checkinOnly}];
   let rows=table==='profiles'?(me?[me]:[]):table==='training_types'?[{id:1,name:'Reguläres Boxtraining'},{id:6,name:'Joggen'}]:
    table==='training_submissions'?[{training_date:today,status:'pending',training_type_id:1,created_at:new Date().toISOString()},{training_date:today,status:'approved',training_type_id:6,created_at:new Date(Date.now()-864e5).toISOString()}]:
    table==='league_feature_flags'?flags:[];
   rows=rows.filter(r=>f.every(([k,v,op])=>op==='in'?v.includes(r[k]):k==='auth_user_id'||k==='boxer_id'||k==='is_active'||r[k]===v));
   return {data:rows,error:null};
  }
  return self;}
 window.__takeoverMockClient={auth:{getUser:async()=>me?{data:{user:{id:me.auth_user_id}},error:null}:{data:{user:null},error:null},getSession:async()=>({data:{session:null},error:null}),onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}})},
  from:t=>query(t),rpc};
}
const shotsDir=process.env.SHOTS||'';
let url;
async function open(browser,cfg,hash,viewport){
 const context=await browser.newContext({viewport:viewport||{width:390,height:844},deviceScaleFactor:2,isMobile:!viewport,hasTouch:!viewport,locale:'de-CH',timezoneId:'Europe/Zurich'});
 await context.addInitScript({content:'('+injected.toString()+')('+JSON.stringify(cfg)+')'});
 const page=await context.newPage();page.setDefaultTimeout(12000);const errors=[];
 page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error'&&!/Failed to load resource/.test(m.text()))errors.push(m.text())});
 await page.route(/^https:\/\/(?!127\.0\.0\.1)/,r=>r.abort());
 await page.route('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm',r=>r.fulfill({status:200,contentType:'text/javascript',body:'export const createClient=()=>window.__takeoverMockClient;'}));
 await page.goto(url+'/boxer-experience.html'+(hash||''));
 return {page,context,errors};
}
const overflow=p=>p.evaluate(()=>document.documentElement.scrollWidth-window.innerWidth);
async function shot(page,name){if(shotsDir){fs.mkdirSync(shotsDir,{recursive:true});await page.screenshot({path:path.join(shotsDir,name+'.png')})}}
async function run(browser,engine){
 // Gäste und Trainer sehen die Sperrseite, keine Boxer-Daten
 let {page,context,errors}=await open(browser,{anon:true});
 await page.waitForFunction(()=>/BITTE ANMELDEN/.test(document.getElementById('ex-gate-title').textContent));
 assert.equal(await page.isHidden('#ex-app'),true);await context.close();
 ({page,context}=await open(browser,{role:'coach'}));
 await page.waitForFunction(()=>/BOXER-BEREICH/.test(document.getElementById('ex-gate-title').textContent));
 assert.equal(await page.getAttribute('#ex-gate-link','href'),'./coach.html');await context.close();
 // Boxer
 ({page,context,errors}=await open(browser,{role:'boxer'}));
 await page.waitForSelector('#ex-app:not([hidden])');
 await page.waitForFunction(()=>document.querySelector('#ex-home-holo svg')&&document.querySelector('#ex-podium .ex-step.first svg'));
 assert.deepEqual(await page.evaluate(()=>[...document.querySelectorAll('.ex-menu [data-tab]')].map(b=>b.dataset.tab)),['heute','training','kaempfe','liga','boxer']);
 assert.ok(await page.isVisible('#ex-home-holo svg'),'own holo on Heute');
 assert.equal(await page.textContent('#ex-home-rank'),'#1');assert.equal(await page.textContent('#ex-pending'),'1');
 assert.ok(await overflow(page)<=2);
 if(engine==='chromium')await shot(page,'83-01-heute');
 for(const tab of ['training','kaempfe','liga']){await page.click(`.ex-menu [data-tab="${tab}"]`);
  assert.equal(await page.isHidden('#ex-home-stage'),true,'no personal holo on '+tab);assert.equal(await page.isHidden('#ex-card-stage'),true);
  assert.equal(await page.getAttribute(`.ex-menu [data-tab="${tab}"]`,'aria-current'),'page');}
 // Liga: Podium mit echten Top 3 in der richtigen Reihenfolge (2-1-3) und deren Holos
 assert.deepEqual(await page.evaluate(()=>[...document.querySelectorAll('#ex-podium .ex-step-name')].map(x=>x.textContent)),['Ben','Anna','Cleo']);
 assert.equal(await page.locator('#ex-podium .ex-step svg').count(),3);
 // Tausendertrennzeichen hängt von der ICU-Version des Browsers ab (' oder ’ oder schmales Leerzeichen)
 assert.match(await page.textContent('#ex-league-points'),/^1\D?200$/);
 if(engine==='chromium')await shot(page,'83-02-liga-podium');
 // Mein Boxer: feststehende FUT-Card, darunter Boxstil-Diagramm, Inhalt scrollt, Karte bleibt
 await page.click('.ex-menu [data-tab="boxer"]');
 await page.waitForSelector('#ex-fut-card .tlp-card');await page.waitForSelector('#ex-radar svg.tlp-radar');
 assert.equal(await page.textContent('#ex-overall'),'78');
 assert.doesNotMatch(await page.textContent('#ex-fut-card'),/undefined|NaN/,'card values complete');
 const cs=await page.locator('#ex-card-stage').boundingBox(),cc=await page.locator('#ex-fut-card .tlp-card').boundingBox();
 assert.ok(cc.y+cc.height<=cs.y+cs.height+1,'FUT-Card not cut off '+JSON.stringify([cs,cc]));
 const before=await page.locator('#ex-card-stage').boundingBox();
 const scrolled=await page.evaluate(()=>{const s=document.getElementById('ex-scroll');s.scrollTop=400;return s.scrollTop});
 assert.ok(scrolled>0,'content below the FUT-Card scrolls');
 const after=await page.locator('#ex-card-stage').boundingBox();
 assert.equal(Math.round(after.y),Math.round(before.y),'FUT-Card stays fixed while content scrolls');
 await page.evaluate(()=>{document.getElementById('ex-scroll').scrollTop=0});
 if(engine==='chromium')await shot(page,'83-03-mein-boxer');
 // Training: Ja/Nein, Ein-Klick-RPC aus PR #84, Doppelklick, Status, Ergänzung separat
 await page.click('.ex-menu [data-tab="training"]');
 await page.waitForSelector('text=Warst du heute im Vereinstraining?');
 const yes=page.getByRole('button',{name:/Ja, im Verein/i});
 await yes.dblclick();
 await page.waitForFunction(()=>/zur Trainerfreigabe eingereicht/.test(document.querySelector('#ex-training-options [role=status]').textContent));
 assert.equal(await page.evaluate(()=>window.__quick.length),1,'double click → one request (button disabled while saving)');
 await yes.click();
 await page.waitForFunction(()=>/bereits eingereicht/.test(document.querySelector('#ex-training-options [role=status]').textContent));
 if(engine==='chromium')await shot(page,'83-04-training-ein-klick');
 // Takeover 3.0: «Nein, eigenes Training» und Ergänzungstraining öffnen das integrierte Formular (kein iframe, keine alte Seite).
 assert.equal(await page.locator('iframe').count(),0,'no iframe in Boxer Experience');
 await page.getByRole('button',{name:/Nein, eigenes Training/i}).click();
 await page.locator('#ex-training-form:not([hidden]) .tf-form').waitFor();
 assert.match(page.url(),/boxer-experience\.html#training\/eigenes$/);
 assert.equal(await page.locator('.ex-menu [data-tab]').count(),5);
 await page.locator('.tf-close').click();
 assert.ok(await page.locator('#ex-training-form').isHidden(),'close restores the training tab');
 await page.getByRole('button',{name:/Ergänzungstraining im Verein/i}).click();
 await page.locator('.tf-card[aria-checked="true"]:has-text("Im Verein")').waitFor();
 assert.match(page.url(),/#training\/verein$/);
 await page.locator('.ex-menu [data-tab="kaempfe"]').click();
 assert.ok(await page.locator('[data-view="kaempfe"]').isVisible());
 // Weitere Bereiche sind normale Seiten in der gemeinsamen App-Shell (keine Einbettung).
 await page.locator('.ex-menu [data-tab="boxer"]').click();
 assert.equal(await page.getAttribute('.ex-view[data-view="boxer"] a[href="./shop.html"]','href'),'./shop.html');
 await page.locator('.ex-menu [data-tab="training"]').click();

 // Tastatur: Tabs per Enter
 await page.focus('.ex-menu [data-tab="heute"]');await page.keyboard.press('Enter');
 assert.ok(await page.isVisible('#ex-home-holo'));
 // Drawer: Escape schliesst und gibt den Fokus zurück
 await page.click('#ex-settings');assert.ok(await page.isVisible('#tla-drawer'));assert.match(await page.textContent('#tla-drawer'),/MEIN ACCOUNT/i);await page.keyboard.press('Escape');assert.ok(await page.isHidden('#tla-drawer'));
 // Simulate iPhone standalone status-bar inset even on desktop CI runners.
 // The top-right menu and drawer close must be below that reserved area.
 const simulatedInset=58;
 const safeStyle=await page.addStyleTag({content:':root{--ex-safe-top:'+simulatedInset+'px!important;--tla-safe-top:'+simulatedInset+'px!important}'});
 const headBounds=await page.locator('.ex-head').boundingBox();
 const menuBounds=await page.locator('#ex-settings').boundingBox();
 assert.ok(headBounds&&headBounds.height>=simulatedInset+62,'iPhone safe area must increase header height');
 assert.ok(menuBounds&&menuBounds.y>=simulatedInset,'menu button must sit below iPhone status bar');
 assert.ok(menuBounds.width>=44&&menuBounds.height>=44,'menu must have >=44px hit target');
 assert.ok(menuBounds.y+menuBounds.height<=headBounds.y+headBounds.height+1,'iPhone menu remains fully inside the header, not clipped or obscured');
 assert.equal(await page.evaluate(()=>{
   const button=document.getElementById('ex-settings'),r=button.getBoundingClientRect();
   return button.contains(document.elementFromPoint(r.left+r.width/2,r.top+r.height/2));
 }),true,'menu is topmost hit target, not covered by another element');
 await page.click('#ex-settings');
 const closeBounds=await page.locator('#tla-drawer-close').boundingBox();
 assert.ok(closeBounds&&closeBounds.y>=simulatedInset,'drawer close button must sit below iPhone status bar');
 await page.click('#tla-drawer-close');
 assert.ok(await page.isHidden('#tla-drawer'),'menu still closes under safe-area inset');
 await safeStyle.evaluate(node=>node.remove());
 assert.deepEqual(errors,[],'no page errors: '+JSON.stringify(errors));await context.close();
 // Weitere Status, Check-in-only, zwei Einheiten, Rückfall ohne Training 2.0 bzw. ohne Migration
 const statusCase=async(cfg,re,extra)=>{const o=await open(browser,cfg,'#training');await o.page.waitForSelector('text=Warst du heute im Vereinstraining?');
  await o.page.getByRole('button',{name:/Ja, im Verein/i}).click();
  await o.page.waitForFunction(r=>new RegExp(r).test(document.querySelector('#ex-training-options [role=status]').textContent),re.source);
  if(extra)await extra(o.page);assert.deepEqual(o.errors,[]);await o.context.close()};
 await statusCase({statuses:['checked_in']},/Erfolgreich eingecheckt/);
 await statusCase({statuses:['already_checked_in']},/bereits eingecheckt/);
 await statusCase({statuses:['already_approved']},/bereits bestätigt/);
 await statusCase({statuses:['no_slot']},/kein Pflichttraining hinterlegt/);
 await statusCase({statuses:['disabled']},/nicht aktiviert/);
 await statusCase({statuses:['choose_gym_session']},/Mehrere Gym-Einheiten/,async p=>assert.ok(await p.locator('#ex-training-options a[href="./checkin.html"]').count()>=1));
 await statusCase({checkinOnly:true,statuses:['gym_not_open']},/noch nicht zum Check-in geöffnet/,async p=>{
  assert.match(await p.textContent('#ex-training-options'),/betreuten Gym-Check-in/);
  assert.equal(await p.getAttribute('a.ex-link-card:has-text("ERGÄNZUNGSTRAINING IM VEREIN")','href'),'./checkin.html')});
 await statusCase({twoSlots:true,statuses:['choose_slot']},/Mehrere Vereinseinheiten/,async p=>{
  await p.getByRole('button',{name:'Abendtraining'}).click();
  await p.waitForFunction(()=>window.__quick.some(x=>x.p_slot_id===8));
  await p.waitForFunction(()=>/zur Trainerfreigabe eingereicht/.test(document.querySelector('#ex-training-options [role=status]').textContent))});
 for(const v of [false,'missing']){const o=await open(browser,{v2:v},'#training');
  await o.page.waitForFunction(()=>/Trage dein Training ein/.test(document.getElementById('ex-training-options').textContent));
  await o.page.getByRole('button',{name:/Training eintragen/i}).click();await o.page.locator('#ex-training-form:not([hidden]) .tf-form').waitFor();
  assert.equal(await o.page.locator('.tf-legend:has-text("Wo hast du")').count(),0,'without Training 2.0 no location/unit step');
  assert.equal(await o.page.evaluate(()=>window.__quick.length),0);await o.context.close()}
 // Grössen
 for(const vp of [{width:320,height:640},{width:1366,height:900}]){const o=await open(browser,{},'#boxer',vp);
  await o.page.waitForSelector('#ex-fut-card .tlp-card');
  assert.ok(await overflow(o.page)<=2,'no horizontal overflow at '+vp.width);
  {const cs=await o.page.locator('#ex-card-stage').boundingBox(),cc=await o.page.locator('#ex-fut-card .tlp-card').boundingBox();assert.ok(cc.y+cc.height<=cs.y+cs.height+1,'FUT-Card not cut off at '+vp.width)}
  const menu=await o.page.locator('.ex-menu').boundingBox();assert.ok(menu.y+menu.height<=vp.height+1,'menu visible at '+vp.width);
  for(const b of await o.page.locator('.ex-menu button').all()){const bb=await b.boundingBox();assert.ok(bb.height>=44&&bb.width>=44,'touch target')}
  if(engine==='chromium'&&vp.width===1366)await shot(o.page,'83-05-desktop');
  await o.context.close()}
 console.log('PASS '+engine+': Boxer Experience – Gast/Trainer gesperrt, 5 Bereiche, Holo nur auf Heute, Podium Top 3 mit Holos, feststehende FUT-Card + Boxstil, scrollbarer Inhalt, Ein-Klick-RPC (alle Status, Doppelklick, Check-in-only, Einheitenwahl), integriertes Formular ohne iframe, Rückfall ohne Training 2.0, Tastatur, 320/390/1366 px');
}
(async()=>{
 await new Promise(r=>server.listen(0,'127.0.0.1',r));url='http://127.0.0.1:'+server.address().port;
 let ran=0;
 for(const [name,type] of [['chromium',playwright.chromium],['webkit',playwright.webkit]]){
  let browser;try{browser=await type.launch({headless:true})}catch(e){if(name==='chromium')throw e;console.log('SKIP '+name+': nicht installiert');continue}
  try{await run(browser,name);ran++}finally{await browser.close()}
 }
 server.close();if(process.env.REQUIRE_WEBKIT&&ran<2)throw new Error('WebKit required');
})().catch(e=>{console.error('BROWSER TEST FAILED',e);
 // In GitHub Actions als Annotation ausgeben (lesbar über die Checks-API, auch ohne Log-Zugriff)
 if(process.env.GITHUB_ACTIONS)console.log('::error title=boxer-experience-browser::'+String(e&&e.stack||e).slice(0,1500).replace(/%/g,'%25').replace(/\r/g,'%0D').replace(/\n/g,'%0A'));
 server.close();process.exit(1)});
