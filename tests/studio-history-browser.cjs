'use strict';
// Published page assembly, synthetic own-profile RPCs; no external requests.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),pw=require('playwright'),H=require('./takeover3-harness.cjs');
const config=`({traceQueries:true,users:[{id:'history-a',email:'a@test.invalid'},{id:'history-b',email:'b@test.invalid'}],tables:{
 profiles:[{id:'profile-a',auth_user_id:'history-a',display_name:'History A',role:'boxer',is_active:true},{id:'profile-b',auth_user_id:'history-b',display_name:'History B',role:'boxer',is_active:true}],
 training_types:[{id:6,name:'Joggen',points:20,is_active:true}],training_submissions:[],training_drafts_v2:[],
 league_feature_flags:[{feature_key:'achievements',is_enabled:true}],achievement_definitions:[{id:'ach1',code:'training_100',title:'100 Trainings',description:'Count',is_active:true}],boxer_achievements:[]},
 rpc:{get_training_v2_config:{enabled:false},get_public_leaderboard:[],get_my_feedback:{enabled:false},league_training_audit_recent:[],
 get_my_studio_training_summary:async()=>{if(window.__summaryFail)return {data:null,error:{message:'offline'}};
  return {data:{profile_id:'profile-a',today:'2026-11-02',totals:{total:1205,approved:1200,pending:4,rejected:1},
   stats:{km:60.3,sprints:200,technique:6000},types:[{id:6,name:'Joggen',count:200,km:60.3,minutes:0}],
   progress:{training:1200,consistent:80,road:60.3,flash:200,technician:6000,fighter:200,engine:200,complete:200},
   weekly:{done:3,pending:1,boxing_done:2,boxing_pending:0,engine_done:1,engine_pending:1,streak:12},
   day_streak:80,last7:105,last30:450,days:[{date:'2026-11-02',count:15}]},error:null}},
 get_my_studio_training_history:async a=>{window.__historyCalls=(window.__historyCalls||0)+1;const delay=window.__delayHistory||0;
  if(delay)await new Promise(r=>setTimeout(r,delay));if(window.__historyFail)return {data:null,error:{message:'offline'}};
  const offset=a.p_before_id?Number(a.p_before_id.split('-').at(-1))+1:0;
  const total=a.p_status==='all'?1205:a.p_status==='pending'?4:a.p_status==='rejected'?1:1200;
  const items=Array.from({length:Math.max(0,Math.min(20,total-offset))},(_,i)=>({id:'row-'+(offset+i),training_type_id:6,training_type_name:'Joggen',training_date:'2026-11-02',created_at:'2026-11-02T10:00:00Z',status:a.p_status==='all'?'approved':a.p_status,notes:a.p_status+' note '+(offset+i),jogging_km:.3}));
  return {data:{profile_id:'profile-a',status:a.p_status,items,next_cursor:offset+items.length<total?{before:'2026-11-02T10:00:00Z',before_id:items.at(-1).id}:null},error:null}}
 }})`;
async function run(browser,base,engine){
 const ctx=await H.context(browser,{config});await ctx.addInitScript(({key})=>{if(localStorage.getItem('__seeded_history'))return;localStorage.setItem('__seeded_history','1');const user={id:'history-a',email:'a@test.invalid'},session={access_token:'test',refresh_token:'valid-a',expires_at:Math.floor(Date.now()/1000)+3600,user};localStorage.setItem(key,JSON.stringify(session));localStorage.setItem('__tl_mock_server',JSON.stringify({valid:{'valid-a':'history-a'}}));localStorage.setItem('takeover_accounts_v2',JSON.stringify([{id:user.id,email:user.email,name:'History A',role:'boxer',session:JSON.stringify(session)}]))},{key:H.KEY});
 const page=await ctx.newPage(),errors=[];page.on('pageerror',e=>errors.push(e.message));await page.goto(base+'/boxer-experience.html#training/historie');
 await page.waitForFunction(()=>document.querySelectorAll('#ex-history .ex-history-line').length===20&&document.getElementById('weeklyQuestsSection')?.textContent.includes('12 Wochen'));
 const stats=await page.locator('#ex-type-breakdown').innerText();assert.match(await page.locator('#ex-history-status').innerText(),/1205 Trainings/);assert.equal(await page.locator('#ex-streak').innerText(),'80');
 const achievements=await page.locator('#achievementGrid').innerText();assert.match(achievements,/100 \/ 100 Trainings/);
 await page.evaluate(()=>window.__delayHistory=100);const calls=await page.evaluate(()=>window.__historyCalls);
 await page.locator('#ex-history-more').evaluate(b=>{b.click();b.click()});await page.waitForFunction(()=>document.querySelectorAll('#ex-history .ex-history-line').length===40);
 assert.equal(await page.evaluate(()=>window.__historyCalls),calls+1);assert.equal(await page.locator('#ex-type-breakdown').innerText(),stats);assert.equal(await page.locator('#achievementGrid').innerText(),achievements);
 await page.selectOption('#ex-history-filter','approved');await page.evaluate(()=>window.__delayHistory=0);await page.selectOption('#ex-history-filter','rejected');
 await page.waitForFunction(()=>document.querySelectorAll('#ex-history .ex-history-line').length===1);await page.waitForTimeout(160);
 assert.match(await page.locator('#ex-history').innerText(),/rejected note 0/);assert.equal(await page.locator('#ex-history-more').isHidden(),true);assert.equal(await page.locator('#ex-streak').innerText(),'80');
 await page.selectOption('#ex-history-filter','pending');await page.waitForFunction(()=>document.querySelectorAll('#ex-history .ex-history-line').length===4);
 await page.evaluate(()=>{window.__historyFail=true;window.__summaryFail=true});await page.click('#ex-history-refresh');await page.waitForFunction(()=>document.getElementById('ex-history-status').textContent.includes('nicht geladen'));
 assert.equal(await page.locator('#ex-history .ex-history-line').count(),0);assert.equal(await page.locator('#ex-streak').innerText(),'–');assert.match(await page.locator('#weeklyQuestsSection').innerText(),/derzeit nicht verfügbar/);
 await page.evaluate(()=>{window.__historyFail=false;window.__summaryFail=false});await page.click('#ex-history-refresh');await page.waitForFunction(()=>document.querySelectorAll('#ex-history .ex-history-line').length===4&&document.getElementById('ex-streak').textContent==='80');
 const out=path.join(H.root,'output/continuation/studio-history');fs.mkdirSync(out,{recursive:true});for(const width of [320,360,390,430]){await page.setViewportSize({width,height:844});assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth-document.documentElement.clientWidth)<=1);await page.locator('#ex-history-card').scrollIntoViewIfNeeded();await page.screenshot({path:path.join(out,engine+'-'+width+'.png')})}
 // Supabase may emit SIGNED_IN again for the same account (e.g. tab focus); do not erase its current results.
 await page.evaluate(async()=>{const {createClient}=await import('./takeover-client.js');await createClient('https://iqarjivcrddcixrvqbfb.supabase.co','test').auth.signInWithPassword({email:'a@test.invalid',password:'pw'})});
 assert.equal(await page.locator('#ex-history .ex-history-line').count(),4);assert.equal(await page.locator('#ex-streak').innerText(),'80');
 // An old response after account transition cannot repopulate another account's history/statistics.
 await page.evaluate(()=>window.__delayHistory=200);await page.selectOption('#ex-history-filter','all');
 await page.evaluate(async()=>{const {createClient}=await import('./takeover-client.js');await createClient('https://iqarjivcrddcixrvqbfb.supabase.co','test').auth.signInWithPassword({email:'b@test.invalid',password:'pw'})});
 await page.waitForTimeout(300);assert.equal(await page.locator('#ex-history .ex-history-line').count(),0);assert.equal(await page.locator('#ex-streak').innerText(),'–');
 const q=await page.evaluate(()=>JSON.parse(localStorage.getItem('__tl_mock_log')||'[]').filter(([k])=>k==='query:training_submissions').map(([,x])=>x));assert.ok(q.every(x=>x.limit!==1000&&x.limit!==500),'No full-history/statistics raw-row load');
 assert.deepEqual(errors,[]);await ctx.close();console.log('PASS '+engine+' Studio server paging, aggregates, filter/load/session races, failure recovery and 320/360/390/430 layouts');
}
(async()=>{const {server,base}=await H.serve();try{for(const engine of ['chromium','webkit']){const b=await pw[engine].launch();try{await run(b,base,engine)}finally{await b.close()}}}finally{server.close()}})().catch(e=>{console.error(e);process.exitCode=1});
