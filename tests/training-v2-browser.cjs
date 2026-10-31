'use strict';
// Training 2.0 + Trainer-Dashboard 2.0 im echten Browser (Chromium, WebKit falls installiert) mit gemocktem Supabase-SDK.
// Kein echtes Konto, keine Serveränderungen. Prüft die Abläufe aus dem Owner-Auftrag und erzeugt Screenshots (SHOTS=Ordner).
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
 const calls=[];window.__calls=calls;
 const today=new Intl.DateTimeFormat('en-CA',{timeZone:'Europe/Zurich'}).format(new Date());
 const add=(s,n)=>{const d=new Date(s+'T12:00:00Z');d.setUTCDate(d.getUTCDate()+n);return d.toISOString().slice(0,10)};
 const dow=s=>((new Date(s+'T12:00:00Z').getUTCDay()+6)%7)+1;
 const lastDow=d=>{let x=today;for(let i=0;i<7;i++){if(dow(x)===d)return x;x=add(x,-1)}return x};
 const mon=lastDow(1),wed=lastDow(3),sat=lastDow(6),tue=lastDow(2);
 const role=cfg.role;
 const me=role==='boxer'?{id:'p-anna',auth_user_id:'u-anna',display_name:'Anna',role:'boxer',is_active:true,avatar_key:'avatar-01',avatar_url:null}
  :{id:'p-coach',auth_user_id:'u-coach',display_name:'Marco',role:role,is_active:true};
 const types=[{id:1,name:'Reguläres Boxtraining',points:30,is_active:true,category:'Boxen',club_only:true,sort_order:110},{id:3,name:'Techniktraining',points:30,is_active:true,category:'Boxen',club_only:true,sort_order:120},
  {id:10,name:'Sandsack / Rundenarbeit',points:30,is_active:true,category:'Boxen',club_only:true,sort_order:140},{id:4,name:'Krafttraining',points:30,is_active:true,category:'Athletik',club_only:false,sort_order:220},
  {id:6,name:'Joggen',points:20,is_active:true,category:'Ausdauer',club_only:false,sort_order:310},{id:11,name:'Schattenboxen / Heimtraining',points:20,is_active:true,category:'Boxen',club_only:false,sort_order:150}];
 const tiers={pflicht:{tier:'pflicht',label:'Pflichttraining',exp:60,coins:15,pass_points:15},ergaenzung:{tier:'ergaenzung',label:'Ergänzungstraining',exp:40,coins:12,pass_points:12}};
 const reward=(typeId,tier)=>{const t=types.find(x=>x.id===Number(typeId));const ct=tier&&tiers[tier];const p=Math.max(ct?ct.exp:0,t?t.points:0);return {tier:tier||null,tier_label:ct?ct.label:null,points:p,exp:p,coins:Math.max(ct?ct.coins:0,10),pass_points:ct?ct.pass_points:10}};
 const slots=[[1,1,'Montag'],[2,3,'Mittwoch'],[3,6,'Samstag']].map(([id,d,n])=>({slot_id:id,dow:d,day_name:n,label:'Reguläres Boxtraining',training_type_id:1,training_type:'Reguläres Boxtraining',duration_minutes:90,reward:reward(1,'pflicht')}));
 const extras=[['sandsack','Sandsacktraining im Verein',10],['athletik','Athletiktraining im Verein',4],['technik','Techniktraining im Verein',3]].map(([key,label,t])=>({key,label,training_type_id:t,training_type:types.find(x=>x.id===t).name,reward:reward(t,'ergaenzung')}));
 const v2config={enabled:cfg.v2!==false,preview:cfg.v2===false,today,tiers:Object.values(tiers),pflicht:slots,extras,types:types.map(t=>({id:t.id,name:t.name,category:t.category,club_only:t.club_only,reward:reward(t.id,null)}))};
 const names=['Anna','Ben','Bob','Cleo','Dario','Elif','Fynn','Gina','Hugo','Ida','Jon','Kaya'];
 const people=names.map((n,i)=>({id:'p-'+n.toLowerCase(),display_name:n,role:'boxer',is_active:true})).concat([{id:'p-coach',display_name:'Marco',role:'coach',is_active:true}]);
 const label=s=>s.requested_slot_id?slots.find(x=>x.slot_id===s.requested_slot_id).day_name+' – Reguläres Boxtraining':s.requested_extra_key?extras.find(x=>x.key===s.requested_extra_key).label:s.training_location==='individual'?'Individuelles Training':null;
 const sugg=s=>s.requested_slot_id&&dow(s.training_date)===slots.find(x=>x.slot_id===s.requested_slot_id).dow?'pflicht':s.requested_extra_key?'ergaenzung':null;
 let subs=[];let n=0;
 const mk=(boxer,date,o)=>({id:'s'+String(++n).padStart(3,'0'),boxer_id:'p-'+boxer.toLowerCase(),training_date:date,duration_minutes:90,notes:'',status:'pending',created_at:new Date(Date.now()-n*60000).toISOString(),training_type_id:1,club_tier:null,training_location:'club',requested_tier:null,requested_slot_id:null,requested_extra_key:null,...o});
 subs.push(mk('Anna',mon,{requested_slot_id:1,requested_tier:'pflicht',notes:'Kombinationen, Runden'}),mk('Ben',wed,{requested_slot_id:2,requested_tier:'pflicht'}),
  mk('Bob',sat,{requested_slot_id:3,requested_tier:'pflicht'}),mk('Cleo',tue,{requested_extra_key:'sandsack',requested_tier:'ergaenzung',training_type_id:10,duration_minutes:60}),
  mk('Dario',mon,{training_location:'individual',training_type_id:6,duration_minutes:45,jogging_km:7.5,notes:'Lockerer Lauf'}),mk('Elif',mon,{training_location:'individual',training_type_id:1,notes:'War eigentlich im Vereinstraining'}),
  mk('Fynn',sat,{requested_slot_id:3,requested_tier:'pflicht',gymConflict:true}),mk('Gina',tue,{requested_extra_key:'athletik',requested_tier:'ergaenzung',training_type_id:4}),
  mk('Hugo',wed,{requested_slot_id:2,requested_tier:'pflicht'}),mk('Ida',tue,{requested_extra_key:'technik',requested_tier:'ergaenzung',training_type_id:3}),
  mk('Jon',mon,{training_location:'individual',training_type_id:4,duration_minutes:60}),mk('Kaya',sat,{requested_slot_id:3,requested_tier:'pflicht'}));
 for(let i=0;i<8;i++)subs.push(mk(names[i],add(mon,-7-i),{status:'approved',club_tier:i%3===0?'pflicht':i%3===1?'ergaenzung':null,reviewed_at:new Date(Date.now()-i*3600e3).toISOString(),points:i%3===0?60:i%3===1?40:30,training_type_id:i%3===2?4:1}));
 const tx=new Map(subs.filter(s=>s.status==='approved').map(s=>[s.id,s.points]));
 const card=s=>{const sug=sugg(s),eff=s.status==='approved'?s.club_tier:sug;return {...s,boxer_name:people.find(p=>p.id===s.boxer_id)?.display_name,training_type_name:types.find(t=>t.id===s.training_type_id)?.name,
  requested_label:label(s),suggested_tier:sug,category:eff||'individual',reward:reward(s.training_type_id,eff),points:tx.get(s.id)??null,exp:tx.get(s.id)??null,
  conflicts:s.status==='pending'&&s.gymConflict?['gym_same_day']:[],corrected:!!s.tier_note,editable:true,own:false}};
 const stats={reviews:[],corrections:[],inserted:[],failNext:0};window.__stats=stats;
 const err=(message,code)=>({data:null,error:{message,code:code||'P0001'}});
 const rpc=async(name,args)=>{
  calls.push([name,args]);
  await new Promise(r=>setTimeout(r,40));
  switch(name){
   case 'coach_list_boxers':return {data:people,error:null};
   case 'get_training_v2_config':return {data:v2config,error:null};
   case 'staff_training_summary':return {data:{today,enabled:true,pending:subs.filter(s=>s.status==='pending').length,pending_conflicts:subs.filter(s=>s.status==='pending'&&s.gymConflict).length,
     today_trainings:4,confirmed_today:subs.filter(s=>s.status==='approved'&&s.reviewed_at&&s.reviewed_at.slice(0,10)===today).length,active_boxers:12,open_gym_sessions:1,
     recent_confirmed:subs.filter(s=>s.status==='approved').sort((a,b)=>String(b.reviewed_at).localeCompare(String(a.reviewed_at))).slice(0,5).map(card)},error:null};
   case 'staff_list_trainings':{
    const q=String(args.p_search||'').toLowerCase();
    let rows=subs.filter(s=>(!args.p_status||s.status===args.p_status)&&(!args.p_boxer_id||s.boxer_id===args.p_boxer_id)&&(!args.p_training_type_id||s.training_type_id===args.p_training_type_id)).map(card)
     .filter(c=>(!args.p_category||c.category===args.p_category)&&(!q||[c.boxer_name,c.training_type_name,c.notes,c.training_date].join(' ').toLowerCase().includes(q)));
    rows.sort((a,b)=>String(b.training_date).localeCompare(String(a.training_date))||String(b.created_at).localeCompare(String(a.created_at)));
    const off=Number(args.p_offset||0),lim=Math.min(50,Number(args.p_limit||10));
    return {data:{items:rows.slice(off,off+lim),total_count:rows.length,limit:lim,offset:off},error:null};
   }
   case 'training_reward_preview':return {data:reward(args.p_training_type_id,args.p_tier),error:null};
   case 'staff_review_training':{
    stats.reviews.push(args);
    if(stats.failNext>0){stats.failNext--;return err('Netzwerkfehler: Verbindung unterbrochen','08006')}
    const s=subs.find(x=>x.id===args.p_submission_id);if(!s)return err('Training nicht gefunden');
    if(s.status!=='pending'){if(s.status===args.p_decision)return {data:{...card(s),already:true},error:null};return err('Dieses Training wurde bereits bearbeitet','55000')}
    if(args.p_decision==='rejected'){s.status='rejected';s.tier_note=args.p_reason||null;return {data:{...card(s),already:false},error:null}}
    if(args.p_training_type_id)s.training_type_id=args.p_training_type_id;if(args.p_training_date)s.training_date=args.p_training_date;if(args.p_duration_minutes)s.duration_minutes=args.p_duration_minutes;
    const sug=sugg(s);const want=!args.p_tier||args.p_tier==='auto'?sug:args.p_tier==='none'?null:args.p_tier;
    if(want!==sug&&!args.p_reason)return err('Die Kategorie weicht vom Antrag ab: bitte kurz begründen','22023');
    if(s.gymConflict&&!args.p_allow_duplicate)return err('Mögliches Duplikat','23505');
    s.status='approved';s.club_tier=want;s.tier_note=args.p_reason||null;s.reviewed_at=new Date().toISOString();tx.set(s.id,reward(s.training_type_id,want).points);
    return {data:{...card(s),already:false},error:null};
   }
   case 'staff_correct_training':{stats.corrections.push(args);const s=subs.find(x=>x.id===args.p_submission_id);if(!args.p_reason)return err('Bitte die Korrektur begründen (3 bis 500 Zeichen)','22023');
    s.club_tier=args.p_tier==='none'?null:args.p_tier;if(args.p_training_type_id)s.training_type_id=args.p_training_type_id;s.tier_note=args.p_reason;const before=tx.get(s.id);tx.set(s.id,reward(s.training_type_id,s.club_tier).points);return {data:{...card(s),points_before:before},error:null}}
   case 'coach_list_training_history':{let rows=subs.filter(s=>(!args.p_boxer_id||s.boxer_id===args.p_boxer_id)&&(!args.p_status||s.status===args.p_status)).map(card);return {data:{items:rows.slice(0,args.p_limit||10),total_count:rows.length},error:null}}
   case 'coach_training_audit_recent':return {data:[{boxer_name:'Elif',happened_at:new Date().toISOString(),old_status:'pending',new_status:'approved',old_points:null,new_points:60,changed_by_name:'Marco'}],error:null};
   case 'get_club_schedule':return {data:{enabled:true,preview:false,today,today_dow:dow(today),slots:[{id:1,dow:dow(today),label:'Reguläres Boxtraining',tier_label:'Pflichttraining',duration_minutes:90,is_active:true,today_session:{id:5,status:'open'}}],tiers:Object.values(tiers)},error:null};
   case 'staff_list_self_ratings':return {data:[],error:null};
   case 'staff_list_feedback':return {data:[],error:null};
   case 'admin_training_tier_review':return {data:{dry_run:true,total_count:1,total_delta:30,items:[{id:'s013',boxer_name:'Ben',training_date:add(mon,-14),training_type:'Reguläres Boxtraining',current_points:30,proposed_tier:'pflicht',proposed_points:60,delta:30,basis:'Vereinsart am Pflichttag (bitte mit Trainer prüfen)'}]},error:null};
   case 'get_my_performance':return {data:{profile:me},error:null};
   default:return {data:[],error:null};
  }
 };
 function query(table){
  const f=[],o={};const self={select:(x,opt)=>{o.opt=opt;return self},eq:(k,v)=>{f.push([k,v]);return self},in:(k,v)=>{f.push([k,v,'in']);return self},order:()=>self,limit:()=>self,range:()=>self,gte:()=>self,lte:()=>self,
   maybeSingle:async()=>({data:compute().data[0]||null,error:null}),single:async()=>({data:compute().data[0]||null,error:null}),
   insert:async payload=>{await new Promise(r=>setTimeout(r,60));stats.inserted.push(payload);return {data:payload,error:null}},
   upsert:async()=>({data:null,error:null}),delete:()=>({eq:async()=>({data:null,error:null})}),then:(a,b)=>Promise.resolve(compute()).then(a,b)};
  function compute(){
   let rows=table==='profiles'?[me]:table==='training_types'?types:table==='training_submissions'?(role==='boxer'?[]:subs):table==='league_feature_flags'?[{feature_key:'coach_feedback',is_enabled:false}]:[];
   rows=rows.filter(r=>f.every(([k,v,op])=>op==='in'?v.includes(r[k]):k==='auth_user_id'||r[k]===v));
   if(o.opt?.head)return {data:null,count:rows.length,error:null};return {data:rows,error:null};
  }
  return self;
 }
 window.__takeoverMockClient={auth:{getUser:async()=>({data:{user:{id:me.auth_user_id}},error:null}),signOut:async()=>({error:null}),onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}}),getSession:async()=>({data:{session:null},error:null})},
  from:table=>query(table),rpc,storage:{from:()=>({getPublicUrl:()=>({data:{publicUrl:''}}),upload:async()=>({error:null})})}};
}
const shotsDir=process.env.SHOTS||'';
async function shot(page,name){if(shotsDir){fs.mkdirSync(shotsDir,{recursive:true});await page.screenshot({path:path.join(shotsDir,name+'.png'),fullPage:false})}}
async function open(browser,cfg,file,viewport){
 const context=await browser.newContext({viewport:viewport||{width:390,height:844},deviceScaleFactor:2,isMobile:!viewport,hasTouch:!viewport,locale:'de-CH',timezoneId:'Europe/Zurich'});
 await context.addInitScript({content:'('+injected.toString()+')('+JSON.stringify(cfg)+')'});
 const page=await context.newPage();page.setDefaultTimeout(12000);const errors=[];
 page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error'&&!/Failed to load resource/.test(m.text()))errors.push(m.text()+' @'+(m.location()?.url||'')+':'+(m.location()?.lineNumber||''))});
 page.on('dialog',d=>d.accept());
 await page.route(/^https:\/\/(?!127\.0\.0\.1)/,r=>r.abort()); // zuerst: später registrierte Routen haben Vorrang
 await page.route('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm',r=>r.fulfill({status:200,contentType:'text/javascript',body:'export const createClient=()=>window.__takeoverMockClient;'}));
 await page.goto(url+'/'+file);
 return {page,context,errors};
}
const overflow=page=>page.evaluate(()=>document.documentElement.scrollWidth-window.innerWidth);
let url;
async function coachFlow(browser,engine){
 let {page,context,errors}=await open(browser,{role:'admin'},'coach.html');
 await page.waitForFunction(()=>!document.querySelector('#content').classList.contains('hidden'));
 // 1. Startseite: offene Bestätigungen sofort sichtbar
 assert.equal(await page.textContent('#pendingCount'),'12');
 assert.ok(await page.isVisible('#viewHome'));assert.ok(await page.isHidden('#viewReview'));
 assert.match(await page.textContent('#cv2Tasks'),/12 Trainings warten auf deine Bestätigung/);
 assert.match(await page.textContent('#cv2Tasks'),/1 Meldung mit Hinweis/);
 assert.equal(await page.textContent('#cv2Tabs [data-view="review"] .badge'),'12');
 assert.equal(await page.getAttribute('#cv2Tabs [data-view="home"]','aria-current'),'page');
 assert.ok(await overflow(page)<=2,'no horizontal overflow (home)');
 if(engine==='chromium')await shot(page,'01-trainer-dashboard-start-mobil');
 // 2. Offene Trainingskarten (max. 10, dann «Mehr anzeigen»)
 await page.click('.cv2-kpi.hero');
 await page.waitForSelector('#entries .cv2-card');
 assert.equal(new URL(page.url()).hash,'#bestaetigen');
 assert.equal(await page.locator('#entries .cv2-card').count(),10);
 assert.ok(await page.isVisible('#cv2PendingMore'));
 const first=page.locator('#entries .cv2-card').first();
 assert.match(await first.textContent(),/Dauer: 90 Min\./);
 for(const box of await page.locator('#entries .cv2-actions button').all()){const b=await box.boundingBox();assert.ok(b.height>=44&&b.width>=44,'touch target ≥44px')}
 if(engine==='chromium')await shot(page,'02-offene-trainingskarten');
 await page.click('#cv2PendingMore');await page.waitForFunction(()=>document.querySelectorAll('#entries .cv2-card').length===12);
 // 3. Pflichttraining schnell bestätigen (zweimal tippen = bewusst; Server bucht 60)
 const anna=page.locator('#entries .cv2-card',{hasText:'Anna ›'});
 assert.match(await anna.textContent(),/Montag – Reguläres Boxtraining/);assert.match(await anna.textContent(),/60 Punkte · 60 EXP · 15 Coins/);
 await anna.locator('button.cv2-btn-ok').click();
 assert.match(await anna.locator('button.cv2-btn-ok').textContent(),/Jetzt bestätigen · 60 P/);
 if(engine==='chromium')await shot(page,'03-pflichttraining-bestaetigen');
 await anna.locator('button.cv2-btn-ok').dblclick();
 await anna.locator('.cv2-result').filter({hasText:'Bestätigt'}).waitFor();
 assert.match(await anna.locator('.cv2-result').textContent(),/Bestätigt als Pflichttraining: \+60 Punkte/);
 let reviews=await page.evaluate(()=>window.__stats.reviews);
 assert.equal(reviews.filter(r=>r.p_submission_id==='s001').length,1,'double tap books once');assert.equal(reviews[0].p_tier,'auto');
 assert.equal(await anna.locator('button').count()>=1,true);assert.equal(await anna.locator('.cv2-actions button').count(),0,'no further action after confirm');
 assert.equal(await page.textContent('#pendingCount'),'11');
 // 4. Bearbeiten im Bottom Sheet: individuell → Pflicht, Vorher/Nachher, Begründung Pflicht, Daten bleiben bei Fehler
 const elif=page.locator('#entries .cv2-card',{hasText:'Elif ›'});
 await elif.getByRole('button',{name:'Bearbeiten'}).click();
 await page.waitForSelector('#cv2Sheet[open]');
 await page.click('#cv2Sheet .cv2-seg button[data-tier="pflicht"]');
 await page.waitForFunction(()=>/Nachher: Pflichttraining · 60 EXP/.test(document.querySelector('#cv2Sheet .cv2-delta').textContent));
 assert.match(await page.textContent('#cv2Sheet .cv2-delta'),/Vorher: Individuell · 30 EXP/);assert.match(await page.textContent('#cv2Sheet .cv2-delta'),/\+30 Punkte\/EXP/);
 if(engine==='chromium')await shot(page,'04-bearbeiten-bottom-sheet');
 await page.click('#cv2Sheet .cv2-sheet-foot .cv2-btn-ok');
 await page.waitForFunction(()=>/Nicht gespeichert – deine Angaben bleiben erhalten/.test(document.querySelector('#cv2Sheet .cv2-sheet-msg').textContent));
 assert.equal(await page.getAttribute('#cv2Sheet .cv2-seg button[data-tier="pflicht"]','aria-checked'),'true','input kept after error');
 await page.fill('#cv2Sheet textarea','War im Vereinstraining am Montag');
 await page.click('#cv2Sheet .cv2-sheet-foot .cv2-btn-ok');
 await page.waitForFunction(()=>/Bestätigt als Pflichttraining: 60/.test(document.querySelector('#cv2Sheet .cv2-sheet-msg').textContent));
 await page.waitForFunction(()=>!document.querySelector('#cv2Sheet').open);
 reviews=await page.evaluate(()=>window.__stats.reviews);const er=reviews.filter(r=>r.p_submission_id==='s006').at(-1);
 assert.equal(er.p_tier,'pflicht');assert.equal(er.p_reason,'War im Vereinstraining am Montag');
 // 5. Netzwerkfehler: Status «Buchung fehlgeschlagen», erneut versuchen möglich, keine Erfolgsmeldung vorher
 await page.evaluate(()=>{window.__stats.failNext=1});
 const ben=page.locator('#entries .cv2-card',{hasText:'Ben ›'});
 await ben.locator('button.cv2-btn-ok').click();await ben.locator('button.cv2-btn-ok').click();
 await ben.locator('.cv2-pill',{hasText:'Buchung fehlgeschlagen'}).waitFor();
 assert.match(await ben.locator('.cv2-result').textContent(),/Nicht gespeichert: Netzwerkfehler/);
 assert.equal(await ben.locator('button.cv2-btn-ok').isEnabled(),true);
 // 6. Sammelbestätigung: Werte pro Training, Hinweis wird übersprungen
 for(const who of ['Cleo','Fynn','Hugo'])await page.locator('#entries .cv2-card',{hasText:who+' ›'}).locator('input.pending-checkbox').check();
 assert.ok(await page.isVisible('#cv2BulkBar'));assert.equal(await page.textContent('#cv2BulkCount'),'3 ausgewählt');
 await page.click('#bulkApprove');await page.waitForSelector('#cv2Sheet[open]');
 const summary=await page.textContent('#cv2Sheet .cv2-sheet-body');
 assert.match(summary,/2 von 3 Trainings werden bestätigt · zusammen voraussichtlich 100 Punkte/);
 assert.match(summary,/Wird übersprungen: Am selben Tag schon per Gym-Check-in erfasst/);
 assert.match(summary,/\+40 P[\s\S]*\+60 P|\+60 P[\s\S]*\+40 P/);
 if(engine==='chromium')await shot(page,'05-sammelbestaetigung');
 await page.click('#cv2Sheet .cv2-sheet-foot .cv2-btn-ok');
 await page.waitForFunction(()=>/2 von 2 verarbeitet/.test(document.querySelector('#cv2Sheet .cv2-sheet-msg').textContent));
 reviews=await page.evaluate(()=>window.__stats.reviews);
 assert.ok(!reviews.some(r=>r.p_submission_id==='s007'),'conflict not bulk confirmed');
 await page.click('#cv2Sheet .cv2-sheet-foot .cv2-btn-sec');
 // Filter (Kategorie) bleibt beim Wechsel zwischen Bereichen erhalten
 await page.click('#cv2PendingChips [data-cat="pflicht"]');
 await page.waitForFunction(()=>[...document.querySelectorAll('#entries .cv2-card')].every(c=>c.dataset.cat==='pflicht'));
 // 7. Boxer suchen und letzte fünf bestätigte Einträge
 await page.click('#cv2Tabs [data-view="boxers"]');
 await page.fill('#cv2BoxerSearch','Gin');
 assert.equal(await page.locator('#cv2People li').count(),1);
 await page.click('#cv2People li button');
 await page.waitForFunction(()=>document.querySelector('#coachBoxerQuick').open&&/Die letzten fünf bestätigten Trainings/.test(document.querySelector('#coachBoxerQuickBody').textContent));
 await page.click('#closeCoachQuick');
 // 8. Gym und zurück: Filter bleibt
 await page.click('#cv2Tabs [data-view="gym"]');assert.match(await page.textContent('.gym-today'),/Reguläres Boxtraining · Pflichttraining · 90 Min\.\s*läuft/);
 assert.ok(await page.isVisible('.staff-entry'));
 await page.goBack();await page.goBack();
 await page.waitForFunction(()=>!document.querySelector('#viewReview').hidden);
 assert.equal(await page.getAttribute('#cv2PendingChips [data-cat="pflicht"]','aria-pressed'),'true','filter kept');
 // 9. Historie mit Status, Kategorie, Korrektur
 await page.click('#cv2Tabs [data-view="history"]');
 await page.waitForSelector('#allEntries .entry');
 assert.ok((await page.locator('#allEntries .entry').count())<=10);
 assert.match(await page.textContent('#allEntries'),/Bestätigt|Korrigiert/);
 if(engine==='chromium')await shot(page,'06-trainingshistorie');
 const approved=page.locator('#allEntries .entry[data-status="approved"]').first();
 await approved.getByRole('button',{name:'Korrigieren'}).click();await page.waitForSelector('#cv2Sheet[open]');
 await page.click('#cv2Sheet .cv2-seg button[data-tier="ergaenzung"]');await page.fill('#cv2Sheet textarea','Nur Ergänzungsteil absolviert');
 await page.click('#cv2Sheet .cv2-sheet-foot .cv2-btn-ok');
 await page.waitForFunction(()=>window.__stats.corrections.length===1);
 assert.equal((await page.evaluate(()=>window.__stats.corrections[0])).p_tier,'ergaenzung');
 await page.waitForFunction(()=>!document.querySelector('#cv2Sheet').open);
 // Admin-Prüfbericht (Dry-Run)
 await page.click('#cv2ReportLoad');await page.waitForFunction(()=>/1 mögliche Fehlbewertungen/.test(document.querySelector('#cv2ReportBody').textContent));
 // Tastatur: Bereichsnavigation per Tab/Enter
 await page.focus('#cv2Tabs [data-view="more"]');await page.keyboard.press('Enter');
 assert.ok(await page.isVisible('#viewMore'));
 assert.ok(await overflow(page)<=2,'no horizontal overflow (mobile)');
 assert.deepEqual(errors,[],'no page errors: '+JSON.stringify(errors));
 await context.close();
 // 320 px, Desktop
 ({page,context,errors}=await open(browser,{role:'coach'},'coach.html#bestaetigen',{width:320,height:640}));
 await page.waitForSelector('#entries .cv2-card');
 assert.ok(await overflow(page)<=2,'no horizontal overflow at 320px');
 await context.close();
 ({page,context,errors}=await open(browser,{role:'admin'},'coach.html',{width:1366,height:900}));
 await page.waitForFunction(()=>!document.querySelector('#content').classList.contains('hidden'));
 if(engine==='chromium')await shot(page,'08-trainer-dashboard-desktop');
 await page.click('#cv2Tabs [data-view="review"]');await page.waitForSelector('#entries .cv2-card');
 if(engine==='chromium')await shot(page,'09-offene-trainings-desktop');
 assert.deepEqual(errors,[]);await context.close();
 // Schalter aus: Kategorien gesperrt, Bestätigung wie bisher
 ({page,context,errors}=await open(browser,{role:'coach',v2:false},'coach.html#bestaetigen'));
 await page.waitForSelector('#entries .cv2-card');
 await page.locator('#entries .cv2-card').first().getByRole('button',{name:'Bearbeiten'}).click();
 assert.equal(await page.isDisabled('#cv2Sheet .cv2-seg button[data-tier="pflicht"]'),true);
 await context.close();
 console.log('PASS '+engine+': Trainer-Dashboard – Startseite, Karten, Schnellbestätigung (doppelt = 1 Buchung), Bottom Sheet mit Vorher/Nachher, Netzwerkfehler, Sammelbestätigung pro Training, Boxer-Suche/letzte 5, Filter bleiben, Historie/Korrektur, Prüfbericht, Tastatur, 320–1366 px ohne Querscrollen');
}
async function boxerFlow(browser,engine){
 const {page,context,errors}=await open(browser,{role:'boxer'},'boxer.html');
 await page.waitForSelector('#trainingV2 .tl-v2-card');
 await page.locator('#trainingFormCard').scrollIntoViewIfNeeded();
 await page.getByRole('radio',{name:/Im Verein \/ Gym/}).click();
 await page.waitForSelector('text=PFLICHTTRAINING');await page.waitForSelector('text=ERGÄNZUNGSTRAINING');
 assert.equal(await page.isVisible('#kind'),false,'type picker hidden for club units');
 await page.getByRole('radio',{name:/Pflichttraining Montag – Reguläres Boxtraining/}).click();
 const date=await page.inputValue('#date');assert.equal(new Date(date+'T12:00:00Z').getUTCDay(),1,'date moved to a Monday');
 assert.match(await page.textContent('#trainingV2Reward'),/Pflichttraining\s*60 Punkte · 60 EXP · 15 Coins/);
 assert.match(await page.textContent('#trainingV2Reward'),/Die endgültige Gutschrift erfolgt nach Bestätigung durch deinen Trainer/);
 await page.fill('#techniqueMinutes','90');await page.fill('#notes','Kombinationen und Runden');
 await page.locator('[data-step="2"]').scrollIntoViewIfNeeded();
 if(engine==='chromium')await shot(page,'07-boxer-trainingsauswahl');
 // falscher Wochentag → kein Einreichen
 const tue=await page.evaluate(()=>{const t=new Intl.DateTimeFormat('en-CA',{timeZone:'Europe/Zurich'}).format(new Date());let d=new Date(t+'T12:00:00Z');while(d.getUTCDay()!==2)d.setUTCDate(d.getUTCDate()-1);return d.toISOString().slice(0,10)});
 await page.fill('#date',tue);
 await page.waitForFunction(()=>/ist am Montag/.test(document.querySelector('.tl-v2-msg.bad')?.textContent||''));
 await page.evaluate(()=>document.querySelector('#form').requestSubmit());
 await page.waitForTimeout(200);assert.equal((await page.evaluate(()=>window.__stats.inserted)).length,0);
 await page.fill('#date',date);
 await page.evaluate(()=>{const f=document.querySelector('#form');f.requestSubmit();f.requestSubmit()});
 await page.waitForFunction(()=>window.__stats.inserted.length>=1);await page.waitForTimeout(150);
 const ins=await page.evaluate(()=>window.__stats.inserted);
 assert.equal(ins.length,1,'double submit = one row');
 assert.equal(ins[0].training_location,'club');assert.equal(ins[0].requested_slot_id,1);assert.equal(ins[0].requested_extra_key,null);
 assert.equal(ins[0].training_type_id,1);assert.equal(ins[0].status,'pending');assert.ok(!('club_tier' in ins[0]),'no tier from client');
 // Ergänzung und individuell
 await page.getByRole('radio',{name:/Ergänzungstraining Sandsacktraining im Verein/}).click();
 assert.match(await page.textContent('#trainingV2Reward'),/Ergänzungstraining\s*40 Punkte · 40 EXP · 12 Coins/);
 await page.getByRole('radio',{name:/Individuell \/ ausserhalb/}).click();
 assert.equal(await page.isVisible('#kind')||await page.locator('.tl-choice-field').first().isVisible(),true,'type picker visible for individual');
 const disabled=await page.evaluate(()=>[...document.querySelectorAll('#kind option')].filter(o=>o.disabled).map(o=>o.textContent));
 assert.ok(disabled.includes('Reguläres Boxtraining')&&!disabled.includes('Joggen'),'club types hidden for individual');
 await page.selectOption('#kind','6');
 assert.match(await page.textContent('#trainingV2Reward'),/Individuelles Training · Joggen\s*20 Punkte · 20 EXP · 10 Coins/);
 assert.ok(await overflow(page)<=2,'boxer form no horizontal overflow');
 assert.deepEqual(errors.filter(e=>!/Gamification|takeover-gamification/.test(e)),[]);
 await context.close();
 console.log('PASS '+engine+': Boxer-Formular – Ort → Einheit → Details → Belohnungsvorschau, Datum gegen Pflichttag geprüft, Antrag ohne Stufe, doppelt = eine Meldung, individuelle Arten ohne Vereinsarten');
}
(async()=>{
 await new Promise(r=>server.listen(0,'127.0.0.1',r));url='http://127.0.0.1:'+server.address().port;
 const engines=[['chromium',playwright.chromium],['webkit',playwright.webkit]];
 let ran=0;
 for(const [name,type] of engines){
  let browser;try{browser=await type.launch({headless:true})}catch(e){if(name==='chromium')throw e;console.log('SKIP '+name+': nicht installiert ('+e.message.split('\n')[0]+')');continue}
  try{await coachFlow(browser,name);await boxerFlow(browser,name);ran++}finally{await browser.close()}
 }
 server.close();
 if(process.env.REQUIRE_WEBKIT&&ran<2)throw new Error('WebKit required');
})().catch(e=>{console.error('BROWSER TEST FAILED',e);server.close();process.exit(1)});
