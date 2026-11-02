'use strict';
// Real page integrations, synthetic Supabase only; never reaches production.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),pw=require('playwright'),H=require('./takeover3-harness.cjs');
const output=path.join(H.root,'output/continuation/inbox');
const config=role=>`({traceQueries:true,users:[{id:'inbox-a',email:'a@test.invalid'},{id:'inbox-b',email:'b@test.invalid'}],tables:{
 profiles:[{id:'profile-a',auth_user_id:'inbox-a',display_name:'Inbox A',role:'${role}',is_active:true},{id:'profile-b',auth_user_id:'inbox-b',display_name:'Inbox B',role:'boxer',is_active:true}],
 training_types:[{id:2,name:'Joggen',points:20,is_active:true,category:'Ausdauer'}],training_submissions:[],training_drafts_v2:[],
 league_feature_flags:[{feature_key:'notifications',is_enabled:true}],
 boxer_notifications:[...Array.from({length:45},(_,i)=>({id:'n-'+String(i).padStart(2,'0'),recipient_id:'profile-a',title:'Mitteilung '+i,message:'Testnachricht '+i,target_path:i===0?'/league-history.html?month=2026-10':i===1?'/league-history.html?month=2026-09':'/duels.html',created_at:new Date(Date.UTC(2026,9,31)-i*60000).toISOString(),read_at:i>=35?'2026-11-01T12:00:00Z':null})),{id:'private-b',recipient_id:'profile-b',title:'Privat B',message:'Nicht für A',created_at:'2026-11-01T12:00:00Z',read_at:null}]},
 rpc:{get_training_v2_config:{enabled:false},get_public_leaderboard:[],get_my_feedback:{enabled:false},league_training_audit_recent:[],mark_my_notification_read:({p_notification_id})=>{
  if(window.__failMark)return {data:null,error:{message:'synthetic failed write'}};
  const d=JSON.parse(localStorage.getItem('__tl_mock_db')||'{}');d.boxer_notifications=(d.boxer_notifications||window.__tlMockConfig.tables.boxer_notifications).map(n=>n.id===p_notification_id?{...n,read_at:new Date().toISOString()}:n);localStorage.setItem('__tl_mock_db',JSON.stringify(d));return {data:true,error:null}
 }}})`;
async function run(browser,base,engine,legacy){
 const role=legacy?'coach':'boxer',ctx=await H.context(browser,{config:config(role)});
 await ctx.addInitScript(({key,role})=>{if(localStorage.getItem('__seeded_inbox'))return;localStorage.setItem('__seeded_inbox','1');const user={id:'inbox-a',email:'a@test.invalid'},session={access_token:'test',refresh_token:'valid-a',expires_at:Math.floor(Date.now()/1000)+3600,user};localStorage.setItem(key,JSON.stringify(session));localStorage.setItem('__tl_mock_server',JSON.stringify({valid:{'valid-a':'inbox-a'}}));localStorage.setItem('takeover_accounts_v2',JSON.stringify([{id:user.id,email:user.email,name:'Inbox A',role,session:JSON.stringify(session)}]))},{key:H.KEY,role});
 const page=await ctx.newPage(),errors=[];page.on('pageerror',e=>errors.push(e.message));
 const host=legacy?'boxerNotificationList':'ex-notifications',status=legacy?'boxerNotificationStatus':'ex-notifications-status',refresh=legacy?'refreshBoxerNotifications':'ex-notifications-refresh';
 await page.goto(base+(legacy?'/boxer.html#boxerNotificationSection':'/boxer-experience.html#heute/mitteilungen'));
 await page.waitForFunction(id=>document.getElementById(id)?.textContent.includes('35 ungelesen von 45'),status);
 assert.equal(await page.locator('#'+host+' article').count(),20);assert.equal(await page.locator('#'+host+' [data-notification-id="private-b"]').count(),0);
 const links=await page.locator('#'+host+' a').evaluateAll(nodes=>nodes.map(n=>n.href));assert.ok(links.some(x=>x.endsWith('?month=2026-10')));assert.ok(links.some(x=>x.endsWith('?month=2026-09')));
 if(!legacy)assert.equal(await page.locator('#ex-notify-badge').innerText(),'35');
 const seen=new Set(await page.locator('#'+host+' article').evaluateAll(nodes=>nodes.map(n=>n.dataset.notificationId)));
 for(const expected of [20,5]){await page.click('#'+host+'-next');await page.waitForFunction(({id,n})=>document.getElementById(id)?.querySelectorAll('article').length===n&&!document.getElementById(id+'-prev').disabled,{id:host,n:expected});for(const id of await page.locator('#'+host+' article').evaluateAll(nodes=>nodes.map(n=>n.dataset.notificationId))){assert.equal(seen.has(id),false,'no duplicate across pages');seen.add(id)}}
 assert.equal(seen.size,45);assert.equal(await page.locator('#'+host+'-next').isHidden(),true);assert.match(await page.locator('#'+status).innerText(),/35 ungelesen von 45/);
 await page.locator('#'+host+'-pager').scrollIntoViewIfNeeded();assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth-document.documentElement.clientWidth)<=1,'no mobile horizontal overflow');fs.mkdirSync(output,{recursive:true});await page.screenshot({path:path.join(output,engine+'-'+(legacy?'legacy':'studio')+'-last-page.png')});
 await page.click('#'+host+'-prev');await page.waitForFunction(id=>document.getElementById(id+'-page')?.textContent.includes('21–40'),host);
 await page.click('#'+host+'-prev');await page.waitForFunction(id=>document.getElementById(id+'-page')?.textContent.includes('1–20'),host);
 await page.evaluate(()=>window.__failMark=true);await page.locator('#'+host+' article button').first().click();await page.waitForFunction(id=>document.getElementById(id)?.textContent.includes('nicht gespeichert'),status);assert.equal(await page.locator('#'+host+' article button').count(),20);
 await page.evaluate(()=>window.__failMark=false);await page.locator('#'+host+' article button').first().click();await page.waitForFunction(id=>document.getElementById(id)?.textContent.includes('34 ungelesen von 45'),status);assert.equal(await page.locator('#'+host+' article button').count(),19);
 await page.evaluate(()=>{window.__tlMockConfig.fail={'boxer_notifications:select':{message:'synthetic unavailable'}}});await page.click('#'+refresh);await page.waitForFunction(id=>document.getElementById(id)?.textContent.includes('nicht vollständig'),status);assert.equal(await page.locator('#'+host+' article').count(),0);if(!legacy)assert.equal(await page.locator('#ex-notify-badge').innerText(),'–');
 await page.evaluate(()=>delete window.__tlMockConfig.fail);await page.click('#'+refresh);await page.waitForFunction(id=>document.getElementById(id)?.textContent.includes('34 ungelesen von 45'),status);
 await page.locator('#'+status).scrollIntoViewIfNeeded();fs.mkdirSync(output,{recursive:true});await page.screenshot({path:path.join(output,engine+'-'+(legacy?'legacy':'studio')+'.png')});
 const queries=await page.evaluate(()=>JSON.parse(localStorage.getItem('__tl_mock_log')).filter(([k])=>k==='query:boxer_notifications').map(([,s])=>s));assert.ok(queries.some(q=>q.offset===40&&q.limit===20));assert.ok(queries.some(q=>q.selectOpts?.head&&q.selectOpts.count==='exact'));assert.ok(queries.every(q=>q.filters.some(f=>f[0]==='eq'&&f[1]==='recipient_id'&&f[2]==='profile-a')));
 // A real Supabase auth event clears old notifications before any later response can repopulate them.
 await page.evaluate(async()=>{const {createClient}=await import('./takeover-client.js');const db=createClient('https://iqarjivcrddcixrvqbfb.supabase.co','test');await db.auth.signInWithPassword({email:'b@test.invalid',password:'pw'})});
 await page.waitForFunction(id=>!document.getElementById(id)||document.getElementById(id).querySelectorAll('article').length===0,host);
 assert.deepEqual(errors,[]);await ctx.close();console.log('PASS '+engine+' '+(legacy?'legacy coach':'studio boxer')+' exact count, 45 rows, links, failed mark, account clear');
}
(async()=>{const {server,base}=await H.serve();try{for(const engine of ['chromium','webkit']){const browser=await pw[engine].launch();try{for(const legacy of [false,true])await run(browser,base,engine,legacy)}finally{await browser.close()}}}finally{server.close()}})().catch(e=>{console.error(e);process.exitCode=1});
