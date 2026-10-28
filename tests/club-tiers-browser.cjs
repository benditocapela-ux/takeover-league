'use strict';
// Chromium test with mocked Supabase SDK (no real account, no server writes) for Etappe 6a:
// Einheit aus dem Stundenplan starten, Stufe anzeigen, bestätigte Einheit umstellen, Wochenplan aus dem Stundenplan,
// Stundenplan-Tab (Admin pflegt Einheiten), Pflichtquote in der Präsenz.
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
 const today=new Intl.DateTimeFormat('en-CA',{timeZone:'Europe/Zurich'}).format(new Date());
 const add=(s,n)=>{const d=new Date(s+'T12:00:00Z');d.setUTCDate(d.getUTCDate()+n);return d.toISOString().slice(0,10)};
 const dow0=(new Date(today+'T12:00:00Z').getUTCDay()+6)%7,monday=add(today,-dow0),todayDow=dow0+1;
 const profile={id:cfg.role==='boxer'?'p-anna':cfg.role==='admin'?'p-owner':'p-coach',display_name:cfg.role==='boxer'?'Anna':cfg.role==='admin'?'Bendo':'Marco',role:cfg.role};
 const types=[{id:1,name:'Reguläres Boxtraining',points:30,is_active:true,club_only:true},{id:2,name:'Techniktraining',points:30,is_active:true,club_only:true},{id:3,name:'Joggen',points:20,is_active:true},
  {id:4,name:'Pratzentraining',points:30,is_active:true,club_only:true},{id:8,name:'Krafttraining',points:30,is_active:true},{id:9,name:'Technisches Sparring',points:30,is_active:true,club_only:true},
  {id:10,name:'Sandsack / Rundenarbeit',points:30,is_active:true,club_only:true}];
 const groups=[{key:'newcomer',name:'Newcomer',weekly_target:2,members:3},{key:'fortgeschritten',name:'Fortgeschrittene',weekly_target:3,members:4},{key:'wettkampf',name:'Wettkämpfer',weekly_target:5,members:2}];
 const tiers=[{tier:'pflicht',label:'Pflichttraining',exp:60,coins:15,pass_points:15,required_groups:['wettkampf']},{tier:'ergaenzung',label:'Ergänzungstraining',exp:40,coins:12,pass_points:12,required_groups:[]}];
 const TL={pflicht:'Pflichttraining',ergaenzung:'Ergänzungstraining'};
 let slots=[[1,9,'pflicht','Technisches Sparring'],[2,10,'ergaenzung','Sandsack'],[3,2,'pflicht','Technik / Pratzen'],[4,8,'ergaenzung','Athletik / Kraft'],[6,9,'pflicht','Technisches Sparring']]
  .map(([dow,t,tier,label],i)=>({id:i+1,dow,day:dow-1,day_name:['Montag','Dienstag','Mittwoch','Donnerstag','Freitag','Samstag','Sonntag'][dow-1],training_type_id:t,training_type:types.find(x=>x.id===t).name,tier,tier_label:TL[tier],label,duration_minutes:90,is_active:true,today_session:null}));
 // Für den Test hat heute immer eine Einheit: den heutigen Tag als Pflicht-Einheit ergänzen, falls keiner existiert.
 if(!slots.some(x=>x.dow===todayDow))slots.push({id:9,dow:todayDow,day:todayDow-1,day_name:'Heute',training_type_id:2,training_type:'Techniktraining',tier:'pflicht',tier_label:'Pflichttraining',label:'Technik / Pratzen',duration_minutes:90,is_active:true,today_session:null});
 let session=null;
 const people=()=>[{id:'p-anna',display_name:'Anna',group:'wettkampf',present:true,source:'self',confirmed:false,points:null},{id:'p-ben',display_name:'Ben',group:'newcomer',present:true,source:'coach',confirmed:false,points:null}];
 const sched=()=>({enabled:true,preview:false,today,today_dow:todayDow,can_edit:profile.role==='admin',tiers,home:{coins:10,pass_points:10},
   slots:slots.map(x=>({...x,today_session:x.dow===todayDow&&session?{id:session.id,status:session.status}:null})),club_types:['Technisches Sparring','Reguläres Boxtraining','Techniktraining','Pratzentraining','Sandsack / Rundenarbeit']});
 const sessJson=()=>({id:session.id,session_date:today,status:session.status,duration_minutes:90,note:session.note,training_type:types.find(t=>t.id===session.type).name,training_type_id:session.type,
   club_tier:session.tier,tier_label:TL[session.tier]||null,slot_id:session.slot,editable:true,group:null,people:session.people});
 const rpc=async(name,args)=>{
  calls.push([name,args]);
  switch(name){
   case 'get_my_performance':return {data:{profile},error:null};
   case 'list_training_groups':return {data:groups,error:null};
   case 'get_club_schedule':return {data:sched(),error:null};
   case 'staff_list_gym_sessions':return {data:session?[{id:session.id,session_date:today,status:session.status,training_type:types.find(t=>t.id===session.type).name,club_tier:session.tier,tier_label:TL[session.tier]||null,present:2,confirmed:session.status==='confirmed'?2:0,opened_by:'Marco'}]:[],error:null};
   case 'staff_open_club_session':{const sl=slots.find(x=>x.id===args.p_slot_id);session={id:21,status:'open',type:sl.training_type_id,tier:sl.tier,slot:sl.id,note:sl.label,people:people()};return {data:{id:21,session_date:today,existing:false,club_tier:sl.tier,tier_label:TL[sl.tier]},error:null}}
   case 'staff_get_gym_session':return {data:sessJson(),error:null};
   case 'staff_set_gym_attendance':{const p=session.people.find(x=>x.id===args.p_profile_id);p.present=args.p_present;return {data:{present:args.p_present},error:null}}
   case 'staff_confirm_gym_session':session.status='confirmed';session.people.forEach(p=>{if(p.present){p.confirmed=true;p.points=60}});return {data:{confirmed:2,points_awarded:120,skipped:[],club_tier:session.tier},error:null};
   case 'staff_update_gym_session':{const before=session.people.reduce((t,p)=>t+(p.points||0),0);session.type=args.p_training_type_id;session.tier=args.p_tier==='none'?null:args.p_tier;
     const v=session.tier==='pflicht'?60:session.tier==='ergaenzung'?40:30;session.people.forEach(p=>{if(p.confirmed)p.points=v});
     return {data:{id:session.id,status:session.status,club_tier:session.tier,updated_trainings:session.status==='confirmed'?2:0,points_before:before,points_after:session.people.reduce((t,p)=>t+(p.points||0),0)},error:null}}
   case 'my_gym_sessions_today':return {data:[{id:21,training_type:'Technisches Sparring',duration_minutes:90,note:'Technisches Sparring',group:null,club_tier:'pflicht',tier_label:'Pflichttraining',checked_in:false}],error:null};
   case 'get_my_presence':return {data:{enabled:true,today,group:{key:'wettkampf',name:'Wettkämpfer',weekly_target:5},
     days:Array.from({length:28},(_,i)=>({date:add(monday,i-21),trainings:i%3===0&&add(monday,i-21)<=today?1:0,tier:i%3===0?'pflicht':null,pending:0,gym:i%6===0})),
     weeks:[0,1,2,3].map(i=>({week_start:add(monday,-7*i),trainings:[2,5,5,3][i],target:5,met:[false,true,true,false][i],current:i===0})),streak_weeks:2,
     pflicht:{required:true,target:3,week:2,weeks:[],pct_4w:75}},error:null};
   case 'staff_presence_overview':return {data:[{id:'p-anna',display_name:'Anna',group:{key:'wettkampf',name:'Wettkämpfer',weekly_target:5},weeks:[{trainings:5,target:5,met:true,current:true},{met:true},{met:false},{met:true}],streak_weeks:3,last_training:today,pflicht:{required:true,target:3,week:1,pct_4w:83}},
     {id:'p-ben',display_name:'Ben',group:{key:'newcomer',name:'Newcomer',weekly_target:2},weeks:[{trainings:0,target:2,met:false,current:true},{met:false},{met:false},{met:false}],streak_weeks:0,last_training:null,pflicht:{required:false,target:3,week:0}}],error:null};
   case 'get_my_week_plan':return {data:{enabled:true,today,week_start:monday,group:{key:'wettkampf',name:'Wettkämpfer',weekly_target:5},trainings:2,pflicht:{required:true,target:3,week:1,pct_4w:50},
     plan:{auto:true,focus:null,need:5,items:slots.map(x=>({day:x.day,type_id:x.training_type_id,minutes:90,tier:x.tier,label:x.label,training_type:x.training_type,tier_label:x.tier_label,status:x.day<dow0?'done':x.day===dow0?'today':'open'}))}},error:null};
   case 'staff_get_training_plan':return {data:{group:{key:args.p_group_key},week_start:args.p_week_start,plan:null,auto_items:slots.map(x=>({day:x.day,type_id:x.training_type_id,minutes:90,tier:x.tier,label:x.label,slot_id:x.id}))},error:null};
   case 'staff_save_training_plan':return {data:{published:args.p_publish},error:null};
   case 'admin_save_club_slot':{const x=slots.find(s=>s.id===args.p_slot_id);Object.assign(x,{dow:args.p_dow,label:args.p_label,tier:args.p_tier,tier_label:TL[args.p_tier]||null,duration_minutes:args.p_duration_minutes,is_active:args.p_active});return {data:{...x,day_name:'Montag'},error:null}}
   case 'staff_list_group_members':return {data:[],error:null};
  }
  return {data:null,error:{message:'unexpected rpc '+name}};
 };
 const from=table=>{const q={select(){return q},eq(){return q},order(){return q},limit(){return q},
  maybeSingle:async()=>({data:{role:profile.role,is_active:true,display_name:profile.display_name},error:null}),
  then:(r)=>Promise.resolve({data:table==='training_types'?types:[],error:null}).then(r)};return q};
 window.__takeoverMockClient={auth:{getSession:async()=>({data:{session:{access_token:'x'}}}),getUser:async()=>({data:{user:{id:'u1'}},error:null}),onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}})},from,rpc};
}
(async()=>{
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const base='http://127.0.0.1:'+server.address().port+'/';
 const browser=await chromium.launch();
 async function open(role,file){
  const context=await browser.newContext({viewport:{width:390,height:844}});
  await context.addInitScript({content:'('+injected.toString()+')('+JSON.stringify({role})+')'});
  const p=await context.newPage();const errors=[];p.on('pageerror',e=>errors.push(e.message));
  await p.route('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm',r=>r.fulfill({status:200,contentType:'text/javascript',body:'export const createClient=()=>window.__takeoverMockClient;'}));
  await p.goto(base+file);
  return {p,errors,context};
 }
 const calls=p=>p.evaluate(()=>window.__calls);
 const shot=async(p,n)=>{if(process.env.SHOTS)await p.screenshot({path:process.env.SHOTS+'/'+n+'.png',fullPage:true})};
 const done=async({p,errors,context})=>{assert.ok(await p.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth),'no horizontal scroll');assert.deepEqual(errors,[]);await context.close()};

 // Coach: heutige Einheit aus dem Stundenplan mit einem Tippen starten, bestätigen, danach umstellen
 let x=await open('coach','checkin.html');
 await x.p.waitForSelector('[data-slot]');
 assert.match(await x.p.textContent('#app'),/Heute laut Stundenplan/);
 assert.match(await x.p.textContent('#app'),/Andere Einheit starten/);
 await shot(x.p,'6a-checkin-start');
 await x.p.click('[data-slot]');
 await x.p.waitForSelector('[data-act="confirm"]');
 const openCall=(await calls(x.p)).find(c=>c[0]==='staff_open_club_session');assert.ok(openCall&&Number.isInteger(openCall[1].p_slot_id),'open club session');
 assert.ok(!(await calls(x.p)).some(c=>c[0]==='staff_open_gym_session'),'no manual form needed');
 assert.match(await x.p.textContent('#app'),/Pflichttraining/);
 await x.p.click('[data-act="confirm"]');
 await x.p.waitForFunction(()=>/bestätigt/.test(document.getElementById('status').textContent));
 assert.match(await x.p.textContent('#status'),/2 Trainings bestätigt als Pflichttraining · 120 Punkte/);
 assert.match(await x.p.textContent('#app'),/bestätigt · 60 EXP/);
 // Einheit ändern: Pratzen statt Sparring, Ergänzung → Punkte werden nachgeführt
 await x.p.click('details.tlp-form summary');
 assert.match(await x.p.textContent('details.tlp-form'),/Punkte, EXP, Coins und Kampfpfad aller Anwesenden/);
 assert.ok(!(await x.p.$$eval('#edType option',o=>o.map(e=>e.textContent))).includes('Joggen'),'no jogging');
 await x.p.selectOption('#edType','4');await x.p.selectOption('#edTier','ergaenzung');
 await x.p.click('[data-act="edit"]');
 await x.p.waitForFunction(()=>/nachgeführt/.test(document.getElementById('status').textContent));
 const upd=(await calls(x.p)).find(c=>c[0]==='staff_update_gym_session')[1];
 assert.deepEqual(upd,{p_session_id:21,p_training_type_id:4,p_tier:'ergaenzung'});
 assert.match(await x.p.textContent('#status'),/2 Trainings nachgeführt · Punkte 120 → 80/);
 assert.match(await x.p.textContent('#app'),/Ergänzungstraining/);
 await x.p.click('details.tlp-form summary');await shot(x.p,'6a-checkin-edit');await x.p.click('details.tlp-form summary');
 await x.p.click('details.tlp-form summary');await x.p.selectOption('#edTier','none');await x.p.click('[data-act="edit"]');
 await x.p.waitForFunction(()=>/120 → 80|80 → 60/.test(document.getElementById('status').textContent)&&/80 → 60/.test(document.getElementById('status').textContent));
 await done(x);

 // Boxer: Check-in zeigt die Stufe; Wochenplan aus dem Stundenplan; Pflichtquote
 x=await open('boxer','checkin.html');
 await x.p.waitForSelector('[data-checkin]');
 assert.match(await x.p.textContent('#app'),/Technisches Sparring\s*Pflichttraining/);
 await done(x);
 x=await open('boxer','wochenplan.html');
 await x.p.waitForSelector('.tlp-dayrow');
 const wp=await x.p.textContent('#app');
 assert.match(wp,/Stundenplan des Vereins/);assert.match(wp,/Ziel deiner Gruppe: 5 von \d Einheiten/);
 assert.match(wp,/Pflichttrainings\s*1 \/ 3/);assert.match(wp,/letzte 4 Wochen 50 %/);
 await shot(x.p,'6a-wochenplan-boxer');
 assert.match(wp,/Technik \/ Pratzen\s*Pflichttraining/);assert.match(wp,/Sandsack\s*Ergänzungstraining/);
 await done(x);
 x=await open('boxer','praesenz.html');
 await x.p.waitForSelector('.tlp-heat');
 assert.match(await x.p.textContent('#app'),/Pflichttrainings\s*2 \/ 3/);
 assert.ok(await x.p.$('.tlp-heat .hc.on.pfl'),'Pflicht days marked');
 await done(x);

 // Coach: Präsenz mit Pflichtquote nur bei Wettkämpfern; Wochenplan-Vorschlag; Stundenplan lesen (nicht ändern)
 x=await open('coach','praesenz.html');
 await x.p.waitForSelector('.tlp-li');
 const pr=await x.p.textContent('#app');
 assert.match(pr,/Anna[\s\S]*Pflicht 1\/3 \(4 Wo\. 83 %\)/);assert.doesNotMatch(pr,/Ben[^·]*· diese Woche 0\/2 · Pflicht/);
 await done(x);
 x=await open('coach','wochenplan.html');
 await x.p.waitForSelector('[data-tab="schedule"]');
 assert.match(await x.p.textContent('#app'),/Vorschlag aus dem Stundenplan/);
 assert.ok((await x.p.$$('.tlp-unit')).length>=5,'auto items prefilled');
 await x.p.click('[data-tab="schedule"]');
 await x.p.waitForFunction(()=>/Wertung pro Training/.test(document.getElementById('app').textContent));
 const sv=await x.p.textContent('#app');
 assert.match(sv,/60 EXP · 15 Coins · 15 Kampfpfad-Punkte · Pflicht für Wettkämpfer/);assert.match(sv,/40 EXP · 12 Coins · 12 Kampfpfad-Punkte/);
 assert.match(sv,/10 Coins · 10 Kampfpfad-Punkte/);assert.match(sv,/Nur der Admin ändert den Stundenplan/);
 assert.equal((await x.p.$$('[data-editslot]')).length,0,'coach cannot edit');
 await shot(x.p,'6a-stundenplan-coach');
 await done(x);

 // Admin: Einheit im Stundenplan ändern
 x=await open('admin','wochenplan.html');
 await x.p.waitForSelector('[data-tab="schedule"]');
 await x.p.click('[data-tab="schedule"]');
 await x.p.waitForSelector('[data-editslot="1"]');
 await x.p.click('[data-editslot="1"]');
 await shot(x.p,'6a-stundenplan-admin-edit');
 await x.p.fill('#slLabel','Sparring & Technik');await x.p.fill('#slMin','100');
 await x.p.click('[data-act="slotsave"]');
 await x.p.waitForFunction(()=>/Stundenplan gespeichert/.test(document.getElementById('status').textContent));
 const sv2=(await calls(x.p)).find(c=>c[0]==='admin_save_club_slot')[1];
 assert.deepEqual(sv2,{p_slot_id:1,p_dow:1,p_training_type_id:9,p_tier:'pflicht',p_label:'Sparring & Technik',p_duration_minutes:100,p_active:true});
 assert.match(await x.p.textContent('#app'),/Sparring & Technik/);
 await done(x);

 await browser.close();server.close();
 console.log('PASS: Etappe 6a im Browser – Einheit aus dem Stundenplan starten, Stufe beim Bestätigen, bestätigte Einheit umstellen (Punkte nachgeführt), Boxer sieht Stufe, Wochenplan aus dem Stundenplan, Pflichtquote (Boxer/Coach), Stundenplan-Wertung, Admin pflegt Einheiten');
})().catch(e=>{console.error(e);process.exit(1)});
