'use strict';
// Chromium test with mocked Supabase SDK (no real account, no server writes) for
// Gym-Check-in, Präsenz and Wochenplan – boxer and coach views.
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
 const dow=(new Date(today+'T12:00:00Z').getUTCDay()+6)%7,monday=add(today,-dow);
 const profile={id:cfg.role==='boxer'?'p-anna':'p-coach',display_name:cfg.role==='boxer'?'Anna':'Marco',role:cfg.role};
 const types=[{id:1,name:'Reguläres Boxtraining',points:50,is_active:true},{id:2,name:'Techniktraining',points:40,is_active:true},{id:3,name:'Joggen',points:20,is_active:true},
  {id:4,name:'Pratzentraining',points:35,is_active:true},{id:5,name:'Sprint-Intervalle',points:40,is_active:true},{id:6,name:'Wettkampfsparring',points:70,is_active:true},
  {id:7,name:'Mobilität / Regeneration',points:15,is_active:true},{id:8,name:'Krafttraining',points:30,is_active:true}];
 const groups=[{key:'newcomer',name:'Newcomer',weekly_target:2,members:3,description:'Einstieg'},{key:'fortgeschritten',name:'Fortgeschrittene',weekly_target:3,members:4,description:'Festigen'},{key:'wettkampf',name:'Wettkämpfer',weekly_target:5,members:2,description:'Wettkampf'}];
 let session=null,checked=false;
 const people=()=>[{id:'p-anna',display_name:'Anna',group:'wettkampf',present:true,source:'self',confirmed:false},{id:'p-ben',display_name:'Ben',group:null,present:false,source:null,confirmed:false},{id:'p-coach',display_name:'Marco',group:null,present:false,is_self:true,confirmed:false}];
 const rpc=async(name,args)=>{
  calls.push([name,args]);
  switch(name){
   case 'get_my_performance':return {data:{profile,ratings_enabled:false,style_enabled:false},error:null};
   case 'list_training_groups':return {data:groups,error:null};
   case 'staff_list_gym_sessions':return {data:session?[{id:7,session_date:today,status:session.status,training_type:'Reguläres Boxtraining',present:1,confirmed:0,opened_by:'Marco'}]:[],error:null};
   case 'staff_open_gym_session':session={id:7,status:'open',people:people()};return {data:{id:7,session_date:today},error:null};
   case 'staff_get_gym_session':return {data:{id:7,session_date:today,status:session.status,duration_minutes:90,note:'Konter',training_type:'Reguläres Boxtraining',group:null,people:session.people},error:null};
   case 'staff_set_gym_attendance':{const p=session.people.find(x=>x.id===args.p_profile_id);p.present=args.p_present;return {data:{present:args.p_present},error:null}}
   case 'staff_confirm_gym_session':session.status='confirmed';session.people.forEach(p=>{if(p.present)p.confirmed=true});return {data:{confirmed:2,points_awarded:100,skipped:[]},error:null};
   case 'my_gym_sessions_today':return {data:[{id:7,training_type:'Reguläres Boxtraining',duration_minutes:90,note:'Konter',group:null,checked_in:checked}],error:null};
   case 'gym_check_in':checked=true;return {data:{checked_in:true},error:null};
   case 'get_my_presence':return {data:{enabled:true,today,group:{key:'wettkampf',name:'Wettkämpfer',weekly_target:5},
     days:Array.from({length:28},(_,i)=>({date:add(monday,i-21),trainings:i%3===0&&add(monday,i-21)<=today?1:0,pending:0,gym:i%6===0})),
     weeks:[0,1,2,3].map(i=>({week_start:add(monday,-7*i),trainings:[2,5,5,3][i],target:5,met:[false,true,true,false][i],current:i===0})),streak_weeks:2},error:null};
   case 'staff_presence_overview':return {data:[{id:'p-anna',display_name:'Anna',group:{key:'wettkampf',name:'Wettkämpfer',weekly_target:5},weeks:[{trainings:5,target:5,met:true,current:true},{met:true},{met:false},{met:true}],streak_weeks:3,last_training:today},
     {id:'p-ben',display_name:'Ben',group:null,weeks:[{trainings:0,target:2,met:false,current:true},{met:false},{met:false},{met:false}],streak_weeks:0,last_training:null}],error:null};
   case 'get_my_week_plan':return {data:{enabled:true,today,week_start:monday,group:{key:'wettkampf',name:'Wettkämpfer',weekly_target:5},trainings:2,
     plan:{focus:'Konter nach dem Jab',updated_by:'Marco',items:[{day:0,type_id:1,minutes:90,training_type:'Reguläres Boxtraining',status:'done'},{day:dow,type_id:4,minutes:60,training_type:'Pratzentraining',status:'today'}]}},error:null};
   case 'staff_get_training_plan':return {data:{group:{key:args.p_group_key},week_start:args.p_week_start,plan:null},error:null};
   case 'staff_save_training_plan':return {data:{published:args.p_publish},error:null};
   case 'staff_list_group_members':return {data:[{id:'p-anna',display_name:'Anna',role:'boxer',group:'wettkampf'},{id:'p-ben',display_name:'Ben',role:'boxer',group:null}],error:null};
   case 'staff_set_training_group':return {data:{profile:'Ben',group:args.p_group_key},error:null};
   case 'admin_set_group_target':return {data:{name:'Newcomer',weekly_target:args.p_weekly_target},error:null};
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
 const done=async({p,errors,context})=>{assert.ok(await p.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth),'no horizontal scroll');assert.deepEqual(errors,[]);await context.close()};

 // Coach: Einheit starten, Anwesenheit, alle bestätigen
 let x=await open('coach','checkin.html');
 await x.p.waitForSelector('[data-act="open"]');
 assert.ok(!(await x.p.$$eval('#ciType option',o=>o.map(e=>e.textContent))).includes('Joggen'),'Joggen not offered');
 await x.p.click('[data-act="open"]');assert.match(await x.p.textContent('#status'),/Bemerkung/);
 await x.p.fill('#ciNote','Konter nach Jab, 4 Runden');await x.p.click('[data-act="open"]');
 await x.p.waitForSelector('[data-person="p-ben"]');
 const openArgs=(await calls(x.p)).find(c=>c[0]==='staff_open_gym_session')[1];
 assert.equal(openArgs.p_training_type_id,1);assert.equal(openArgs.p_note,'Konter nach Jab, 4 Runden');
 await x.p.click('[data-person="p-ben"]');
 await x.p.waitForFunction(()=>window.__calls.some(c=>c[0]==='staff_set_gym_attendance'&&c[1].p_profile_id==='p-ben'&&c[1].p_present===true));
 assert.match(await x.p.textContent('[data-act="confirm"]'),/Alle 2 Anwesenden bestätigen/);
 await x.p.click('[data-act="confirm"]');
 await x.p.waitForFunction(()=>/2 Trainings bestätigt/.test(document.getElementById('status').textContent));
 await done(x);

 // Boxer: einchecken
 x=await open('boxer','checkin.html');
 await x.p.waitForSelector('[data-checkin="7"]');await x.p.click('[data-checkin="7"]');
 await x.p.waitForFunction(()=>/Eingecheckt/.test(document.getElementById('app').textContent));
 assert.ok((await calls(x.p)).some(c=>c[0]==='gym_check_in'&&c[1].p_session_id===7));
 await done(x);

 // Boxer: Präsenz
 x=await open('boxer','praesenz.html');
 await x.p.waitForSelector('.tlp-heat .hc');
 assert.equal(await x.p.locator('.tlp-heat .hc').count(),28);
 const pres=await x.p.textContent('#app');assert.match(pres,/Wettkämpfer/);assert.match(pres,/2 von 5/);assert.match(pres,/Wochen in Folge/);
 await done(x);

 // Coach: Präsenz-Übersicht (unter Ziel zuerst)
 x=await open('coach','praesenz.html');
 await x.p.waitForSelector('.tlp-dots');
 const first=await x.p.locator('.tlp-li b').first().textContent();assert.equal(first,'Ben','below target first');
 await done(x);

 // Boxer: Wochenplan
 x=await open('boxer','wochenplan.html');
 await x.p.waitForSelector('.tlp-dayrow');
 const wp=await x.p.textContent('#app');assert.match(wp,/Konter nach dem Jab/);assert.match(wp,/Erledigt/);assert.match(wp,/2 \/ 5/);
 await done(x);

 // Coach: Vorlage laden und veröffentlichen, Gruppe zuteilen
 x=await open('coach','wochenplan.html');
 await x.p.waitForSelector('[data-act="tpl"]');
 await x.p.selectOption('#plTpl','Wettkampf-Woche');await x.p.click('[data-act="tpl"]');
 assert.ok(await x.p.locator('.tlp-unit').count()>=6,'template units shown');
 await x.p.fill('#plFocus','Konter nach dem Jab');await x.p.click('[data-act="publish"]');
 await x.p.waitForFunction(()=>window.__calls.some(c=>c[0]==='staff_save_training_plan'));
 const saveArgs=(await calls(x.p)).find(c=>c[0]==='staff_save_training_plan')[1];
 assert.equal(saveArgs.p_publish,true);assert.equal(saveArgs.p_group_key,'wettkampf');assert.equal(saveArgs.p_focus,'Konter nach dem Jab');
 assert.ok(saveArgs.p_items.length>=6&&saveArgs.p_items.every(i=>Number.isInteger(i.day)&&Number.isInteger(i.type_id)&&i.minutes>=5));
 await x.p.click('[data-tab="groups"]');await x.p.waitForSelector('[data-member="p-ben"]');
 assert.equal(await x.p.locator('[data-target]').count(),0,'coach cannot edit weekly targets');
 await x.p.selectOption('[data-member="p-ben"]','newcomer');
 await x.p.waitForFunction(()=>window.__calls.some(c=>c[0]==='staff_set_training_group'&&c[1].p_group_key==='newcomer'));
 await done(x);

 // Admin sieht Wochenziele
 x=await open('admin','wochenplan.html');
 await x.p.waitForSelector('[data-tab="groups"]');await x.p.click('[data-tab="groups"]');await x.p.waitForSelector('[data-target="newcomer"]');
 await x.p.fill('[data-target="newcomer"]','3');await x.p.dispatchEvent('[data-target="newcomer"]','change');
 await x.p.waitForFunction(()=>window.__calls.some(c=>c[0]==='admin_set_group_target'&&c[1].p_weekly_target===3));
 await done(x);

 await browser.close();server.close();
 console.log('PASS: Gym-Check-in (Coach/Boxer), Präsenz (Boxer/Coach) und Wochenplan (Boxer/Coach/Admin) im Browser geprüft');
})().catch(e=>{console.error(e);process.exit(1)});
