'use strict';
// Chromium test with mocked Supabase SDK (no real account, no server writes) for the Wochen-Quests page:
// boxer claims quests and opens the chest, coach sees the overview, admin edits a quest; flag-off state.
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
 const names={boxer:'Anna',coach:'Marco',admin:'Owner'};
 const profile={id:'p-'+cfg.role,display_name:names[cfg.role],role:cfg.role};
 const claimed=new Set();
 const W=[['box_sessions','4 Boxeinheiten','box_sessions',4,4,20,60],['technique','120 Technik-Minuten','technique_minutes',120,75,20,50],
  ['plan','Wochenplan zu 80 % erfüllen','plan_pct',80,100,30,80],['recovery','1× Mobilität / Regeneration','recovery_sessions',1,0,10,30],['duel','1 Duell bestreiten','duels',1,1,20,40]];
 const quest=(k,t,m,tgt,prog,exp,coins,per,kind)=>({key:k,kind,metric:m,title:t,description:'Beschreibung '+k,target:tgt,progress:prog,exp,coins,available:true,
  done:claimed.has(k+per)||prog>=tgt,claimed:claimed.has(k+per),claimed_at:null,period_start:per});
 const state=()=>{
  const weekly=W.map(w=>quest(...w,monday,'weekly'));
  const av=weekly.length,cl=weekly.filter(q=>q.claimed).length;
  const daily=Array.from({length:dow+1},(_,i)=>quest('d_any','Heute trainieren','sessions',1,i===dow?1:0,5,25,add(monday,i),'daily'));
  const exp=[...weekly,...daily].filter(q=>q.claimed).reduce((t,q)=>t+q.exp,0)+(claimed.has('chest'+monday)?40:0);
  return {enabled:true,preview:cfg.role==='admin',can_claim:cfg.role!=='admin',today,week_start:monday,current_week:monday,claim_from:add(monday,-7),
   group:{key:'wettkampf',name:'Wettkämpfer',weekly_target:5},weekly,daily,
   chest:{key:'chest',kind:'chest',title:'Wochentruhe',description:'',target:av,progress:cl,exp:40,coins:200,available:true,done:cl>=av,claimed:claimed.has('chest'+monday),period_start:monday},
   exp_week:exp,coins_pending:exp*2};
 };
 const adminQuests=[{key:'box_sessions',kind:'weekly',title:'{n} Boxeinheiten',metric:'box_sessions',target:3,group_targets:{newcomer:2,fortgeschritten:3,wettkampf:4},exp:20,coins:60,is_active:true,claims:4},
  {key:'chest',kind:'chest',title:'Wochentruhe',metric:'weekly_all',target:1,group_targets:{},exp:40,coins:200,is_active:true,claims:1},
  {key:'d_any',kind:'daily',title:'Heute trainieren',metric:'sessions',target:1,group_targets:{},exp:5,coins:25,is_active:true,claims:9}];
 const rpc=async(name,args)=>{
  calls.push([name,args]);
  switch(name){
   case 'get_my_performance':return {data:{profile,ratings_enabled:false,style_enabled:false},error:null};
   case 'get_my_quests':return cfg.off?{data:{enabled:false},error:null}:{data:state(),error:null};
   case 'claim_quest':{
    const q=[...state().weekly,state().chest,...state().daily].find(x=>x.key===args.p_quest_key&&x.period_start===args.p_period);
    if(!q||!q.done||q.claimed)return {data:null,error:{message:'Diese Quest ist noch nicht erfüllt'}};
    claimed.add(q.key+q.period_start);return {data:{key:q.key,title:q.title,period_start:q.period_start,exp:q.exp,coins:q.coins},error:null}}
   case 'staff_quest_overview':return {data:[{id:'p-anna',display_name:'Anna',group:{key:'wettkampf',name:'Wettkämpfer'},available:5,done:4,claimed:2,chest:false,exp_week:45},
     {id:'p-ben',display_name:'Ben',group:null,available:4,done:4,claimed:4,chest:true,exp_week:115}],error:null};
   case 'admin_list_quests':return {data:{today_daily:'d_any',quests:adminQuests},error:null};
   case 'list_training_groups':return {data:[{key:'newcomer',name:'Newcomer',weekly_target:2},{key:'fortgeschritten',name:'Fortgeschrittene',weekly_target:3},{key:'wettkampf',name:'Wettkämpfer',weekly_target:5}],error:null};
   case 'admin_update_quest':return {data:{key:args.p_quest_key,target:args.p_target,exp:args.p_exp,coins:args.p_coins,is_active:args.p_is_active,group_targets:args.p_group_targets},error:null};
  }
  return {data:null,error:{message:'unexpected rpc '+name}};
 };
 const from=()=>{const q={select(){return q},eq(){return q},order(){return q},limit(){return q},
  maybeSingle:async()=>({data:{role:profile.role,is_active:true,display_name:profile.display_name},error:null}),
  then:(r)=>Promise.resolve({data:[],error:null}).then(r)};return q};
 window.__takeoverMockClient={auth:{getSession:async()=>({data:{session:{access_token:'x'}}}),getUser:async()=>({data:{user:{id:'u1'}},error:null}),onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}})},from,rpc};
}
(async()=>{
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const base='http://127.0.0.1:'+server.address().port+'/';
 const browser=await chromium.launch();
 async function open(cfg,file){
  const context=await browser.newContext({viewport:{width:390,height:844}});
  await context.addInitScript({content:'('+injected.toString()+')('+JSON.stringify(cfg)+')'});
  const p=await context.newPage();const errors=[];p.on('pageerror',e=>errors.push(e.message));
  await p.route('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm',r=>r.fulfill({status:200,contentType:'text/javascript',body:'export const createClient=()=>window.__takeoverMockClient;'}));
  await p.goto(base+file);
  return {p,errors,context};
 }
 const calls=p=>p.evaluate(()=>window.__calls);
 const done=async({p,errors,context})=>{assert.ok(await p.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth),'no horizontal scroll');assert.deepEqual(errors,[]);await context.close()};

 // Boxer: Quests abholen, Truhe öffnen
 let x=await open({role:'boxer'},'quests.html');
 await x.p.waitForSelector('.tlp-quest');
 let t=await x.p.textContent('#app');
 assert.match(t,/4 Boxeinheiten/);assert.match(t,/75 Min\./);assert.match(t,/Tagesquest · heute/);assert.match(t,/Wochentruhe/);
 assert.equal(await x.p.locator('[data-claim="recovery"]').count(),0,'unfinished quest has no claim button');
 assert.equal(await x.p.locator('[data-claim="chest"]').count(),0,'chest closed until all weekly quests claimed');
 await x.p.click('[data-claim="box_sessions"]');
 await x.p.waitForFunction(()=>/Quest abgeschlossen/.test(document.getElementById('app').textContent));
 assert.match(await x.p.textContent('#app'),/\+20/);
 const arg=(await calls(x.p)).find(c=>c[0]==='claim_quest')[1];
 assert.equal(arg.p_quest_key,'box_sessions');assert.match(arg.p_period,/^\d{4}-\d{2}-\d{2}$/);
 for(const k of ['plan','duel']){await x.p.click(`[data-claim="${k}"]`);await x.p.waitForFunction(k=>window.__calls.filter(c=>c[0]==='claim_quest'&&c[1].p_quest_key===k).length===1,k)}
 await x.p.waitForSelector('[data-claim="d_any"]');await x.p.click('[data-claim="d_any"]');
 await x.p.waitForFunction(()=>window.__calls.some(c=>c[0]==='claim_quest'&&c[1].p_quest_key==='d_any'));
 t=await x.p.textContent('#app');assert.match(t,/3 von 5 Wochenquests abgeholt/);assert.match(t,/Abgeholt/);
 await done(x);

 // Flag aus: Hinweis, keine Quests
 x=await open({role:'boxer',off:true},'quests.html');
 await x.p.waitForFunction(()=>/noch nicht freigeschaltet/.test(document.getElementById('app').textContent));
 assert.equal(await x.p.locator('.tlp-quest').count(),0);
 await done(x);

 // Coach: Übersicht
 x=await open({role:'coach'},'quests.html');
 await x.p.waitForSelector('[data-tab="overview"]');
 assert.equal(await x.p.locator('[data-tab="admin"]').count(),0,'coach has no settings tab');
 await x.p.click('[data-tab="overview"]');
 t=await x.p.textContent('#app');assert.match(t,/Anna/);assert.match(t,/erfüllt 4\/5/);assert.match(t,/Truhe/);
 await done(x);

 // Admin: Vorschau ohne Abholen, Quest bearbeiten
 x=await open({role:'admin'},'quests.html');
 await x.p.waitForSelector('[data-tab="admin"]');
 await x.p.click('[data-tab="quests"]');
 await x.p.waitForFunction(()=>/Vorschau/.test(document.getElementById('app').textContent));
 assert.equal(await x.p.locator('[data-claim]').count(),0,'admin cannot claim');
 await x.p.click('[data-tab="admin"]');
 await x.p.waitForSelector('form[data-key="box_sessions"]');
 assert.equal(await x.p.textContent('#maxExp'),'95');
 await x.p.fill('form[data-key="box_sessions"] [name="exp"]','25');
 await x.p.fill('form[data-key="box_sessions"] [name="g_newcomer"]','');
 await x.p.click('form[data-key="box_sessions"] button[type="submit"]');
 await x.p.waitForFunction(()=>window.__calls.some(c=>c[0]==='admin_update_quest'));
 const up=(await calls(x.p)).find(c=>c[0]==='admin_update_quest')[1];
 assert.equal(up.p_exp,25);assert.equal(up.p_target,3);assert.equal(up.p_is_active,true);
 assert.deepEqual(up.p_group_targets,{fortgeschritten:3,wettkampf:4},'empty group field = standard');
 await x.p.waitForFunction(()=>document.getElementById('maxExp').textContent==='100');
 await done(x);

 await browser.close();server.close();
 console.log('PASS: Wochen-Quests im Browser – Boxer holt ab (Truhe erst nach allen), Flag aus, Coach-Übersicht, Admin-Vorschau ohne Abholen und Quest-Einstellungen');
})().catch(e=>{console.error(e);process.exit(1)});
