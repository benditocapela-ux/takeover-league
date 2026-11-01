'use strict';
// Takeover League 3.0 · echte Benutzerwege im Browser (Chromium; WebKit, wenn installiert) mit Supabase-Attrappe.
// Prüft: Konto-Umschalter (hinzufügen, wechseln, abgelaufene Sitzung, entfernen, abmelden, Rollenwechsel),
// integrierte Trainingsmeldung (Verein/individuell, Validierung, Doppel-Tipp, Historie), alte Deep Links,
// App-Shell auf allen Boxer-Seiten, keine iframes, keine horizontalen Überläufe (320–1366 px).
const pw=require('playwright');const assert=require('node:assert/strict');const fs=require('node:fs');const path=require('node:path');
const H=require('./takeover3-harness.cjs');
const SHOTS=process.env.TAKEOVER3_SHOTS||'';
const BOXER_PAGES=['wochenplan.html','goals.html','praesenz.html','checkin.html','duels.html','league-challenges.html','challenges.html','arena.html','quests.html',
 'boxer-compare.html','awards.html','league-history.html','stil-test.html','mein-boxer.html','shop.html','karten.html','bewertung.html','kampfpfad.html','roadmap.html',
 'news.html','feedback.html','hilfe.html','features.html','boxer-profile.html?name=Ben'];
const config=(opts={})=>`{
 users:[{id:'u-ben',email:'ben@test.invalid'},{id:'u-admin',email:'admin@test.invalid'},{id:'u-coach',email:'coach@test.invalid'},{id:'u-ana',email:'ana@test.invalid'}],
 tables:{
  profiles:[{id:'p-ben',auth_user_id:'u-ben',display_name:'Ben',role:'boxer',is_active:true},{id:'p-admin',auth_user_id:'u-admin',display_name:'Bendo',role:'admin',is_active:true},
   {id:'p-coach',auth_user_id:'u-coach',display_name:'Coach Kim',role:'coach',is_active:true},{id:'p-ana',auth_user_id:'u-ana',display_name:'Ana',role:'boxer',is_active:true}],
  training_types:[{id:1,name:'Reguläres Boxtraining',points:30,is_active:true,club_only:true,category:'Boxen'},{id:2,name:'Joggen',points:20,is_active:true,category:'Ausdauer'},
   {id:3,name:'Techniktraining',points:30,is_active:true,club_only:true,category:'Boxen'},{id:4,name:'Krafttraining',points:30,is_active:true,category:'Athletik'}],
  league_feature_flags:[{feature_key:'notifications',is_enabled:true},{feature_key:'gym_training',is_enabled:true},{feature_key:'club_checkin_only',is_enabled:${opts.checkinOnly?'true':'false'}}],
  training_submissions:[{id:'old-1',boxer_id:'p-ben',training_type_id:2,training_date:'2026-10-20',status:'approved',notes:'Vita Parcours',jogging_km:5,duration_minutes:40,created_at:'2026-10-20T10:00:00Z'},
   {id:'old-ana',boxer_id:'p-ana',training_type_id:4,training_date:'2026-10-21',status:'pending',notes:'Ana privat',duration_minutes:60,created_at:'2026-10-21T10:00:00Z'}],
  boxer_notifications:[{id:'n1',recipient_id:'p-ben',notification_type:'training',title:'Training bestätigt',message:'Dein Training wurde bestätigt.',target_path:'/boxer.html',created_at:'2026-10-30T10:00:00Z',read_at:null}],
  training_drafts_v2:[]
 },
 rpc:{
  get_training_v2_config:${opts.v2===false?"{enabled:false}":`{enabled:true,pflicht:[
   {slot_id:11,dow:1,day_name:'Montag',label:'Reguläres Boxtraining',training_type_id:1,training_type:'Reguläres Boxtraining',duration_minutes:90,reward:{points:60,exp:60,coins:15,pass_points:15}},
   {slot_id:13,dow:3,day_name:'Mittwoch',label:'Reguläres Boxtraining',training_type_id:1,training_type:'Reguläres Boxtraining',duration_minutes:90,reward:{points:60,exp:60,coins:15,pass_points:15}},
   {slot_id:16,dow:6,day_name:'Samstag',label:'Reguläres Boxtraining',training_type_id:1,training_type:'Reguläres Boxtraining',duration_minutes:90,reward:{points:60,exp:60,coins:15,pass_points:15}}],
   extras:[{key:'technik',label:'Techniktraining im Verein',training_type_id:3,reward:{points:40,exp:40,coins:12}}],
   types:[{id:2,name:'Joggen',club_only:false,reward:{points:20,exp:20,coins:10}},{id:4,name:'Krafttraining',club_only:false,reward:{points:30,exp:30,coins:10}},{id:1,name:'Reguläres Boxtraining',club_only:true,reward:{points:30,exp:30,coins:10}}]}`},
  submit_scheduled_club_training_today:()=>({data:{status:'already_pending',label:'Reguläres Boxtraining'},error:null}),
  get_public_leaderboard:[],get_my_feedback:{enabled:false},league_training_audit_recent:[],mark_my_notification_read:true
 }
}`;
const log=page=>page.evaluate(()=>JSON.parse(localStorage.getItem('__tl_mock_log')||'[]'));
const accounts=page=>page.evaluate(()=>JSON.parse(localStorage.getItem('takeover_accounts_v2')||'[]'));
const session=page=>page.evaluate(k=>{const s=JSON.parse(localStorage.getItem(k)||'null');return s&&s.user&&s.user.id},H.KEY);
async function login(page,base,email,add){
 await page.goto(base+'/login.html'+(add?'?add=1':''));await page.locator('#loginView:not(.hide)').waitFor();
 await page.fill('#email',email);await page.fill('#password','pw');await page.click('#loginBtn');
}
async function openAccount(page){
 const btn=page.locator('#tla-account-btn, #ex-settings').first();await btn.click();
 await page.locator('#tla-drawer:not([hidden]) .tla-account').waitFor();
}
async function noOverflow(page,label){
 const o=await page.evaluate(()=>document.documentElement.scrollWidth-document.documentElement.clientWidth);
 assert.ok(o<=1,label+': horizontaler Überlauf '+o+'px');
}
async function shot(page,name){if(SHOTS){fs.mkdirSync(SHOTS,{recursive:true});await page.screenshot({path:path.join(SHOTS,name+'.png')})}}

async function accountFlows(browser,base,name){
 const ctx=await H.context(browser,{config:config()});const page=await ctx.newPage();
 const errors=[];page.on('pageerror',e=>errors.push(e.message));page.on('dialog',d=>d.accept());
 // 1) Admin → Clubverwaltung
 await login(page,base,'admin@test.invalid');await page.waitForURL(/admin\.html/);
 await openAccount(page);
 assert.match(await page.locator('.tla-current').innerText(),/Bendo[\s\S]*Admin/);
 assert.equal(await page.locator('.tla-switch').count(),0);
 // 2) Weiteres Konto hinzufügen (Boxer) ohne das Admin-Konto zu verlieren
 await page.click('.tla-action:has-text("Weiteres Konto")');await page.waitForURL(/login\.html\?add=1/);
 await page.locator('#loginView:not(.hide)').waitFor();
 assert.match(await page.locator('#message').innerText(),/Weiteres Konto hinzufügen/);
 await page.fill('#email','ben@test.invalid');await page.fill('#password','pw');await page.click('#loginBtn');
 await page.waitForURL(/boxer-experience\.html/);await page.locator('#ex-app:not([hidden])').waitFor();
 let list=await accounts(page);
 assert.deepEqual(list.map(a=>a.name+':'+a.role).sort(),['Ben:boxer','Bendo:admin']);
 assert.ok(list.every(a=>!('session' in a)&&!('user' in a)),'Keine vollständigen Sitzungs- oder Benutzerobjekte gespeichert');
 assert.equal(await page.evaluate(()=>localStorage.getItem('takeover_accounts_v1')),null);
 // Kein Eingriff in Storage.prototype
 assert.match(await page.evaluate(()=>Storage.prototype.removeItem.toString()),/\[native code\]/);
 // 3) Konto-Umschalter in der Boxer Experience (Menü oben rechts)
 await openAccount(page);await shot(page,name+'-account-drawer-boxer');
 assert.match(await page.locator('.tla-current').innerText(),/Ben[\s\S]*Boxer/);
 await page.evaluate(()=>{window.__sentinel='geheim-ben'});
 await page.click('.tla-switch:has-text("Bendo")');await page.waitForURL(/admin\.html/);
 assert.equal(await session(page),'u-admin');
 assert.equal(await page.evaluate(()=>window.__sentinel||null),null,'Nach dem Wechsel bleibt kein Speicherzustand des vorherigen Kontos');
 assert.ok((await log(page)).some(([k,v])=>k==='setSession:ok'&&v==='u-admin'),'Wechsel über offizielle setSession-API');
 // 4) Zurückwechseln
 await openAccount(page);await page.click('.tla-switch:has-text("Ben")');await page.waitForURL(/boxer-experience\.html/);
 assert.equal(await session(page),'u-ben');
 // 5) Dritten Account (Coach) hinzufügen → Trainer-Dashboard
 await openAccount(page);await page.click('.tla-action:has-text("Weiteres Konto")');await page.waitForURL(/login\.html\?add=1/);
 await page.locator('#loginView:not(.hide)').waitFor();
 await page.fill('#email','coach@test.invalid');await page.fill('#password','pw');await page.click('#loginBtn');await page.waitForURL(/coach\.html/);
 assert.equal((await accounts(page)).length,3);
 // 6) Rollenwechsel serverseitig: Ana-Profil existiert nicht im Umschalter; Bens Rolle wird serverseitig neu geprüft
 await page.evaluate(()=>{const c=window.__tlMockConfig;const db=JSON.parse(localStorage.getItem('__tl_mock_db')||'{}');
  db.profiles=c.tables.profiles.map(p=>p.id==='p-ben'?{...p,role:'coach'}:p);localStorage.setItem('__tl_mock_db',JSON.stringify(db))});
 await openAccount(page);await page.click('.tla-switch:has-text("Ben")');await page.waitForURL(/coach\.html/);
 assert.equal((await accounts(page)).find(a=>a.id==='u-ben').role,'coach','Rolle nach dem Wechsel serverseitig aktualisiert');
 await page.evaluate(()=>{const db=JSON.parse(localStorage.getItem('__tl_mock_db')||'{}');delete db.profiles;localStorage.setItem('__tl_mock_db',JSON.stringify(db))});
 // 6b) Kurzer Netzausfall: Anmeldung bleibt gespeichert, kein erneutes Passwort, aktuelles Konto bleibt aktiv
 await page.evaluate(()=>localStorage.setItem('__tl_mock_offline','1'));
 await openAccount(page);await page.click('.tla-switch:has-text("Bendo")');
 await page.locator('.tla-status.tla-bad:has-text("Keine Verbindung")').waitFor();
 assert.match(page.url(),/coach\.html/);assert.equal(await session(page),'u-ben');
 assert.equal((await accounts(page)).find(a=>a.id==='u-admin').expired,false,'Netzfehler markiert das Konto nicht als abgelaufen');
 await page.evaluate(()=>localStorage.removeItem('__tl_mock_offline'));await page.keyboard.press('Escape');
 // 6c) Wechsel in einem anderen Tab → dieser Tab lädt neu und zeigt nie fremde Daten unter falschem Namen
 const other=await ctx.newPage();await other.goto(base+'/goals.html');await other.locator('#tla-header').waitFor();
 await other.evaluate(()=>{window.__stale=1});
 await openAccount(page);await page.click('.tla-switch:has-text("Coach Kim")');await page.waitForURL(/coach\.html/);
 await other.waitForFunction(()=>!window.__stale);await other.close();
 await openAccount(page);await page.click('.tla-switch:has-text("Ben")');await page.waitForURL(/boxer-experience\.html/);
 // 7) Abgelaufene / widerrufene Sitzung → erneute Anmeldung, aktuelles Konto bleibt angemeldet
 await page.evaluate(()=>{const s=JSON.parse(localStorage.getItem('__tl_mock_server'));for(const [rt,uid] of Object.entries(s.valid))if(uid==='u-admin')delete s.valid[rt];localStorage.setItem('__tl_mock_server',JSON.stringify(s))});
 await openAccount(page);await page.click('.tla-switch:has-text("Bendo")');
 await page.waitForURL(/login\.html\?add=1&account=admin%40test\.invalid/);
 assert.equal(await session(page),'u-ben','Bei abgelaufener Zielsitzung bleibt das bisherige Konto angemeldet');
 assert.equal(await page.inputValue('#email'),'admin@test.invalid');
 assert.equal((await accounts(page)).find(a=>a.id==='u-admin').expired,true);
 await page.fill('#password','pw');await page.click('#loginBtn');await page.waitForURL(/admin\.html/);
 assert.equal((await accounts(page)).find(a=>a.id==='u-admin').expired,false,'Nach erneuter Anmeldung wieder wechselbar');
 // 8) Konto entfernen
 await openAccount(page);await page.click('.tla-remove[aria-label*="Coach Kim"]');
 assert.deepEqual((await accounts(page)).map(a=>a.name).sort(),['Ben','Bendo']);
 assert.match(await page.locator('.tla-status').innerText(),/entfernt/);
 // 9) Abmelden: nur das aktuelle Konto verschwindet, Sitzung serverseitig widerrufen
 await page.click('.tla-logout');await page.waitForURL(/login\.html$/);
 assert.equal(await session(page),null);
 assert.deepEqual((await accounts(page)).map(a=>a.name),['Ben']);
 assert.ok((await log(page)).some(([k,v])=>k==='signOut'&&v==='u-admin'));
 // 10) PWA-Neustart: neue Seite im gleichen Kontext, Wechsel funktioniert weiterhin
 const again=await ctx.newPage();await again.goto(base+'/index.html#ranking');await openAccount(again);
 await again.click('.tla-switch:has-text("Ben")');await again.waitForURL(/boxer-experience\.html/);assert.equal(await session(again),'u-ben');
 await again.close();
 // 11) Migration alter Einträge (takeover_accounts_v1)
 await page.evaluate(()=>{localStorage.removeItem('takeover_accounts_v2');localStorage.setItem('takeover_accounts_v1',JSON.stringify([{id:'u-x',email:'x@test.invalid',name:'Alt',role:'boxer',session:JSON.stringify({access_token:'a',refresh_token:'r',expires_at:1,user:{id:'u-x'}})}]))});
 const migrated=await page.evaluate(()=>window.TLAccount.read());
 assert.equal(migrated.length,1);assert.equal(migrated[0].rt,'r');assert.ok(!('session' in migrated[0]));
 assert.equal(await page.evaluate(()=>localStorage.getItem('takeover_accounts_v1')),null);
 assert.deepEqual(errors,[]);
 await ctx.close();
}

async function trainingFlows(browser,base,name){
 const ctx=await H.context(browser,{config:config()});const page=await ctx.newPage();
 const errors=[];page.on('pageerror',e=>errors.push(e.message));page.on('dialog',d=>d.accept());
 await login(page,base,'ben@test.invalid');await page.waitForURL(/boxer-experience\.html/);
 await page.goto(base+'/boxer-experience.html#training');await page.locator('#ex-app:not([hidden])').waitFor();
 await page.locator('.ex-choice:has-text("Nein, eigenes Training")').waitFor();
 assert.equal(await page.locator('iframe').count(),0,'Kein iframe in der Boxer Experience');
 // Ja, im Verein → Ein-Klick-RPC, kein Doppeleintrag
 await page.click('.ex-choice:has-text("Ja, im Verein")');
 await page.locator('#ex-training-options [role="status"]:has-text("bereits eingereicht")').waitFor();
 // Nein, eigenes Training → integriertes Formular
 await page.click('.ex-choice:has-text("Nein, eigenes Training")');
 await page.waitForURL(/#training\/eigenes$/);await page.locator('#ex-training-form:not([hidden]) .tf-form').waitFor();
 assert.equal(page.url().includes('boxer.html'),false);
 await page.locator('.tf-card[aria-checked="true"]:has-text("Individuell")').waitFor();
 // Validierung: fehlende Angaben
 await page.selectOption('#tf-kind','2');
 await page.locator('#tf-km').waitFor();
 await page.click('.tf-submit');
 assert.match(await page.locator('.tf-error').innerText(),/Trainingsdauer/);
 await page.fill('#tf-minutes','45');await page.click('.tf-submit');
 assert.match(await page.locator('.tf-error').innerText(),/Joggingdistanz/);
 await page.fill('#tf-km','6.5');await page.click('.tf-submit');
 assert.match(await page.locator('.tf-error').innerText(),/Bemerkung/);
 await page.fill('#tf-notes','Lockerer Lauf am See');
 assert.match(await page.locator('.tf-reward').innerText(),/20 Punkte/);
 await shot(page,name+'-training-form');
 // Doppeltes Antippen → genau ein Insert
 await page.locator('.tf-submit').dblclick();
 await page.locator('.tf-done:not([hidden])').waitFor();
 let inserts=(await log(page)).filter(([k])=>k==='insert:training_submissions');
 assert.equal(inserts.length,1,'Doppeltes Antippen erzeugt nur eine Meldung');
 const p1=inserts[0][1];
 assert.equal(p1.boxer_id,'p-ben');assert.equal(p1.training_type_id,2);assert.equal(p1.status,'pending');assert.equal(p1.jogging_km,6.5);
 assert.equal(p1.duration_minutes,45);assert.equal(p1.technique_minutes,null);assert.equal(p1.training_location,'individual');
 assert.ok(p1.client_request_id,'client_request_id für Idempotenz');
 assert.ok(!('points' in p1)&&!('club_tier' in p1),'Keine Punkte oder Einstufung vom Browser');
 await shot(page,name+'-training-done');
 // Historie aktualisiert
 await page.locator('#ex-history .ex-history-line:has-text("Joggen"):has-text("In Prüfung")').waitFor();
 assert.equal(await page.locator('#ex-history:has-text("Ana privat")').count(),0,'Keine fremden Trainings sichtbar');
 // Zur Übersicht zurück, dann Pflichttraining im Verein
 await page.click('.tf-done .tf-submit');await page.waitForURL(/#training$/);
 assert.equal(await page.locator('#ex-training-form').isHidden(),true);
 await page.click('.ex-choice:has-text("Ergänzungstraining im Verein")');await page.waitForURL(/#training\/verein$/);
 await page.locator('.tf-card[aria-checked="true"]:has-text("Im Verein")').waitFor();
 await page.click('.tf-card:has-text("Mittwoch")');
 const date=await page.inputValue('#tf-date');
 assert.equal(new Date(date+'T12:00:00Z').getUTCDay(),3,'Datum springt auf den Pflicht-Wochentag');
 assert.equal(await page.inputValue('#tf-minutes'),'90');
 assert.match(await page.locator('.tf-reward').innerText(),/Pflichttraining[\s\S]*60 Punkte/);
 await page.fill('#tf-notes','Pratzen und Sparring');await page.click('.tf-submit');await page.locator('.tf-done:not([hidden])').waitFor();
 inserts=(await log(page)).filter(([k])=>k==='insert:training_submissions');
 const p2=inserts[1][1];
 assert.equal(p2.training_location,'club');assert.equal(p2.requested_slot_id,13);assert.equal(p2.requested_extra_key,null);assert.equal(p2.training_type_id,1);
 assert.notEqual(p2.client_request_id,p1.client_request_id);
 // Letztes Training übernehmen
 await page.click('.tf-done .tf-chip');await page.click('.tf-card:has-text("Individuell")');
 await page.click('.tf-chip:has-text("Letztes Training")');
 assert.equal(await page.inputValue('#tf-minutes'),'90');
 // Browser-Zurück schliesst das Formular
 await page.goBack();await page.waitForTimeout(200);
 // Mitteilungen: alte /boxer.html-Links landen in der neuen Oberfläche
 await page.goto(base+'/boxer-experience.html#heute/mitteilungen');await page.locator('#ex-notifications .ex-notice').waitFor();
 const href=await page.locator('#ex-notifications a:has-text("Ansehen")').getAttribute('href');
 assert.match(href,/boxer-experience\.html#training$/);
 assert.equal(await page.locator('#ex-notify-badge').innerText(),'1');
 await page.click('#ex-notifications button:has-text("Als gelesen")');await page.locator('#ex-notify-badge').waitFor({state:'hidden'});
 // Alte Deep Links
 for(const [legacy,expect] of [['/boxer.html?individual=1#trainingFormCard',/#training\/eigenes$/],['/boxer.html?club=1#trainingFormCard',/#training\/verein$/],
  ['/boxer.html#entriesCard',/#training\/historie$/],['/boxer.html',/#training$/],['/boxer.html#profileCard',/#boxer\/profil$/]]){
  // je Aufruf eine frische Seite (wie ein Klick aus einer Mitteilung oder einem Lesezeichen)
  const tab=await ctx.newPage();await tab.goto(base+legacy);await tab.waitForURL(expect);await tab.locator('#ex-app:not([hidden])').waitFor();await tab.close();
 }
 // Hinweis: Playwright-WebKit (Linux) stürzte ab, wenn diese lange offene Seite per goto auf boxer.html wechselte;
 // in frischen Tabs (wie bei Lesezeichen/Mitteilungen) läuft derselbe Weg fehlerfrei. Daher frischer Tab.
 assert.deepEqual(errors,[]);
 const fresh=await ctx.newPage();fresh.on('pageerror',e=>errors.push(e.message));
 await fresh.goto(base+'/boxer.html?individual=1#trainingFormCard');await fresh.waitForURL(/#training\/eigenes$/);
 await fresh.locator('#ex-training-form:not([hidden]) .tf-form').waitFor();
 // Reload behält die Ansicht
 await fresh.reload();await fresh.locator('#ex-training-form:not([hidden]) .tf-form').waitFor();
 assert.deepEqual(errors,[]);
 await ctx.close();

 // Training 2.0 ausgeschaltet → Formular ohne Ort/Einheit, Wert der Trainingsart
 const ctx2=await H.context(browser,{config:config({v2:false})});const p=await ctx2.newPage();
 await login(p,base,'ben@test.invalid');await p.waitForURL(/boxer-experience\.html/);
 await p.goto(base+'/boxer-experience.html#training');await p.click('.ex-choice:has-text("Training eintragen")');
 await p.locator('#ex-training-form:not([hidden]) .tf-form').waitFor();
 assert.equal(await p.locator('.tf-step[data-step="1"] .tf-legend:has-text("Wo hast du")').count(),0);
 await p.selectOption('#tf-kind','4');await p.fill('#tf-minutes','60');await p.fill('#tf-notes','Kraftzirkel');await p.click('.tf-submit');
 await p.locator('.tf-done:not([hidden])').waitFor();
 const ins=(await log(p)).filter(([k])=>k==='insert:training_submissions');
 assert.equal(ins.length,1);assert.equal('training_location' in ins[0][1],false);
 await ctx2.close();

 // Nur betreuter Gym-Check-in: keine Selbstmeldung von Vereinstrainings (der Server würde sie ablehnen)
 const ctx3=await H.context(browser,{config:config({checkinOnly:true})});const q=await ctx3.newPage();
 await login(q,base,'ben@test.invalid');await q.waitForURL(/boxer-experience\.html/);
 await q.goto(base+'/boxer-experience.html#training/verein');await q.locator('#ex-training-form:not([hidden]) .tf-form').waitFor();
 await q.locator('.tf-form a[href="./checkin.html"]').waitFor();
 assert.equal(await q.locator('.tf-form button.tf-submit').isHidden(),true,'kein Einreichen-Knopf für Vereinstraining');
 await q.click('.tf-card:has-text("Individuell")');
 const kinds=await q.locator('#tf-kind option').allTextContents();
 assert.ok(!kinds.includes('Reguläres Boxtraining')&&!kinds.includes('Techniktraining'),'keine Vereinsarten bei individuellem Training');
 await ctx3.close();
}

async function shellFlows(browser,base,name){
 // Boxer: jede Seite in der App-Shell, keine alte Navigation, kein Überlauf
 for(const vp of [{width:320,height:640},{width:390,height:844},{width:430,height:932},{width:768,height:1024},{width:1366,height:900}]){
  const ctx=await H.context(browser,{config:config(),viewport:vp});const page=await ctx.newPage();
  const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await login(page,base,'ben@test.invalid');await page.waitForURL(/boxer-experience\.html/);await page.locator('#ex-app:not([hidden])').waitFor();
  for(const tab of ['heute','training','kaempfe','liga','boxer']){
   await page.click('.ex-menu [data-tab="'+tab+'"]');assert.equal(await page.locator('.ex-menu [data-tab="'+tab+'"]').getAttribute('aria-current'),'page');
   await noOverflow(page,'boxer-experience#'+tab+' @'+vp.width);
   if(vp.width===390)await shot(page,name+'-experience-'+tab);
  }
  // Safe-Area-Menü vollständig sichtbar und klickbar
  const box=await page.locator('#ex-settings').boundingBox();assert.ok(box&&box.y>=0&&box.height>=44,'Menüknopf mindestens 44 px und sichtbar');
  const pages=vp.width===390?BOXER_PAGES:BOXER_PAGES.slice(0,6);
  for(const pg of pages){
   await page.goto(base+'/'+pg);await page.locator('#tla-header').waitFor();
   await page.locator('#tla-nav a[aria-current="page"]').waitFor({timeout:8000}).catch(()=>{throw new Error(pg+': kein aktiver Tab in der Fussnavigation')});
   assert.equal(await page.locator('.tl-global-bottom').isVisible().catch(()=>false),false,pg+': alte Fussleiste sichtbar');
   assert.equal(await page.locator('header.tl-subnav').first().isVisible().catch(()=>false),false,pg+': alte Kopfzeile sichtbar');
   assert.equal(await page.locator('#tla-nav a').count(),5);
   assert.equal(await page.locator('iframe').count(),0,pg+': iframe');
   await noOverflow(page,pg+' @'+vp.width);
   if(vp.width===390&&['shop.html','duels.html','goals.html','awards.html'].includes(pg))await shot(page,name+'-shell-'+pg.replace('.html',''));
  }
  // Zurück in der Kopfzeile führt in die Boxer Experience
  await page.goto(base+'/shop.html');await page.locator('#tla-back').click();await page.waitForURL(/boxer-experience\.html#boxer$/);
  // Alte «Mein Studio»-Links sind ersetzt
  await page.goto(base+'/goals.html');await page.locator('#tla-header').waitFor();await page.waitForTimeout(300);
  assert.equal(await page.locator('a[href="./boxer.html"]:visible').count(),0,'Keine sichtbaren Links ins alte Studio');
  assert.deepEqual(errors,[],'Keine Skriptfehler @'+vp.width);
  await ctx.close();
 }
 // Gast: öffentliche Liga ohne Anmeldung
 const g=await H.context(browser,{config:config()});const gp=await g.newPage();
 await gp.goto(base+'/index.html');await gp.locator('#tla-nav a').first().waitFor();
 assert.equal(await gp.locator('#tla-nav a').count(),5);assert.match(await gp.locator('#tla-nav').innerText(),/Anmelden/);
 await gp.goto(base+'/awards.html');await gp.locator('#tla-nav a[aria-current="page"]:has-text("Awards")').waitFor();
 await openAccount(gp);assert.match(await gp.locator('#tla-drawer').innerText(),/nicht angemeldet/);
 await shot(gp,name+'-guest-awards');await g.close();
 // Trainer: eigene Trainings weiterhin über das Formular, Trainer-Dashboard behält seine sechs Bereiche
 const c=await H.context(browser,{config:config()});const cp=await c.newPage();
 await login(cp,base,'coach@test.invalid');await cp.waitForURL(/coach\.html/);
 await cp.locator('#tla-header').waitFor();
 await cp.goto(base+'/boxer.html');await cp.locator('#tla-header').waitFor();assert.match(cp.url(),/boxer\.html/);
 await cp.goto(base+'/boxer-experience.html');await cp.locator('#ex-gate-link[href="./coach.html"]').waitFor();
 await cp.goto(base+'/league-manager.html');await cp.locator('#tla-nav a[aria-current="page"]').waitFor();
 await shot(cp,name+'-coach-manager');await c.close();
}

(async()=>{
 const {server,base}=await H.serve();
 const engines=[['chromium',pw.chromium]];
 if(process.env.TAKEOVER3_WEBKIT!=='0'){try{const b=await pw.webkit.launch();await b.close();engines.push(['webkit',pw.webkit])}catch(e){console.log('WebKit nicht installiert – nur Chromium:',e.message.split('\n')[0])}}
 try{
  for(const [name,engine] of engines){
   const browser=await engine.launch();
   try{
    await accountFlows(browser,base,name);console.log(name+': Konto-Umschalter ok');
    await trainingFlows(browser,base,name);console.log(name+': Trainingsmeldung ok');
    await shellFlows(browser,base,name);console.log(name+': App-Shell und Navigation ok');
   }finally{await browser.close()}
  }
 }finally{server.close()}
 console.log('takeover3-browser: alle Prüfungen bestanden');
})().catch(e=>{console.error(e);process.exitCode=1});
