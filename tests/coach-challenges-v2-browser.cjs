// Browser-like smoke tests. All Supabase calls are mocked; no live data is accessed.
const fs=require('node:fs');
const vm=require('node:vm');
const assert=require('node:assert/strict');
const {JSDOM}=require('jsdom');
const html=fs.readFileSync('challenges-v2-preview.html','utf8');
const source=html.match(/<script type="module">([\s\S]*?)<\/script>/)[1].replace(/^import .*;\s*$/gm,'');
const tick=()=>new Promise(resolve=>setTimeout(resolve,0));
async function mount({user=null,profile=null,challenges=[],rpcError=null,candidates=[]}={}){
 const dom=new JSDOM(html,{url:'https://example.test/challenges-v2-preview.html',runScripts:'outside-only'});
 const calls=[];
 const db={
  auth:{getUser:async()=>({data:{user},error:null}),signInWithPassword:async()=>({error:null}),signOut:async()=>({error:null})},
  from:(name)=>{assert.equal(name,'profiles');return {select:()=>({eq:()=>({maybeSingle:async()=>({data:profile,error:null})})})}},
  rpc:async(name,args)=>{calls.push({name,args});return rpcError?{data:null,error:{message:rpcError}}:{data:name==='coach_challenge_v2_list'?challenges:name==='coach_challenge_v2_review_candidates'?candidates:[],error:null}}
 };
 dom.window.createClient=()=>db;
 dom.window.confirm=()=>true;
 dom.window.eval(source.replace('init();','window.__ready=init();'));
 await dom.window.__ready;
 return {dom,document:dom.window.document,calls,db};
}
(async()=>{
 const guest=await mount();
 assert.equal(guest.document.querySelector('#login').hidden,false);
 assert.equal(guest.document.querySelector('#coach').hidden,true);
 assert.equal(guest.document.querySelector('#list').children.length,0);
 guest.dom.window.close();
 const coach=await mount({user:{id:'coach-id'},profile:{role:'coach',is_active:true},challenges:[]});
 assert.equal(coach.document.querySelector('#coach').hidden,false);
 assert.match(coach.document.querySelector('#list').textContent,/Noch keine Challenges/);
 coach.document.querySelector('#create [name=title]').value='Neuer Test';
 coach.document.querySelector('#create').dispatchEvent(new coach.dom.window.Event('submit',{bubbles:true,cancelable:true}));
 await tick();await tick();
 assert.equal(coach.calls.some(c=>c.name==='coach_challenge_v2_create_draft'&&c.args.p_title==='Neuer Test'),true);
 coach.document.querySelector('#logout').click();await tick();await tick();
 assert.equal(coach.document.querySelector('#coach').hidden,true);
 assert.equal(coach.document.querySelector('#login').hidden,false);
 coach.dom.window.close();
 const boxer=await mount({user:{id:'boxer-id'},profile:{role:'boxer',is_active:true},challenges:[{id:'challenge-id',title:'Box-Test',description:'Training',status:'open',joined_count:0,duration_days:7,my_enrollment_status:null,is_creator:false}]});
 assert.equal(boxer.document.querySelector('#coach').hidden,true);
 assert.match(boxer.document.querySelector('#list').textContent,/Box-Test/);
 assert.equal([...boxer.document.querySelectorAll('#list button')].some(b=>b.textContent==='Teilnehmen'),true);
 boxer.document.querySelector('#list button').click();await tick();await tick();
 assert.equal(boxer.calls.some(c=>c.name==='coach_challenge_v2_join'&&c.args.p_challenge_id==='challenge-id'),true);
 boxer.dom.window.close();
 const reviewCoach=await mount({user:{id:'coach-id'},profile:{role:'coach',is_active:true},challenges:[{id:'review-id',title:'Review',description:'Test',status:'awaiting_reviews',joined_count:1,duration_days:7,is_creator:true}]});
 const settle=Array.from(reviewCoach.document.querySelectorAll('#list button')).find(b=>b.textContent==='EXP abschliessen');
 assert.equal(settle.disabled,true,'EXP cannot settle before review candidate check');
 const reviewButton=Array.from(reviewCoach.document.querySelectorAll('#list button')).find(b=>b.textContent==='Offene Bewertungen laden');
 reviewButton.click();await tick();await tick();
 assert.equal(settle.disabled,false,'EXP can settle after zero open candidates');
 settle.click();await tick();await tick();
 assert.equal(reviewCoach.calls.some(c=>c.name==='coach_challenge_v2_settle_manual'),true);
 reviewCoach.dom.window.close();
 const pending=await mount({user:{id:'coach-id'},profile:{role:'coach',is_active:true},challenges:[{id:'pending-id',title:'Pending',description:'Test',status:'awaiting_reviews',joined_count:1,duration_days:7,is_creator:true}],candidates:[{boxer_id:'boxer-id',display_name:'Test Boxer'}]});
 const pendingReview=[...pending.document.querySelectorAll('#list button')].find(b=>b.textContent==='Offene Bewertungen laden');
 pendingReview.click();await tick();await tick();
 assert.equal([...pending.document.querySelectorAll('#list button')].find(b=>b.textContent==='EXP abschliessen').disabled,true,'pending reviews must block settlement');
 const reason=pending.document.querySelector('#list input');reason.value='Saubere Technik und drei Einheiten';
 [...pending.document.querySelectorAll('#list button')].find(b=>b.textContent==='Bestanden').click();await tick();await tick();
 assert.equal(pending.calls.some(c=>c.name==='coach_challenge_v2_review_manual'&&c.args.p_boxer_id==='boxer-id'&&c.args.p_approved===true),true);
 pending.dom.window.close();
 const malicious=await mount({user:{id:'boxer-id'},profile:{role:'boxer',is_active:true},challenges:[{id:'unsafe',title:'<img src=x onerror=alert(1)>',description:'<script>alert(1)</script>',status:'open',joined_count:0,duration_days:7,my_enrollment_status:null,is_creator:false}]});
 assert.equal(malicious.document.querySelector('#list img'),null,'untrusted title must not render HTML');
 assert.equal(malicious.document.querySelector('#list script'),null,'untrusted description must not render scripts');
 assert.match(malicious.document.querySelector('#list').textContent,/<img src=x/);
 malicious.dom.window.close();
 const inactive=await mount({user:{id:'inactive'},profile:{role:'coach',is_active:false}});
 assert.equal(inactive.document.querySelector('#coach').hidden,true);
 assert.equal(inactive.document.querySelector('#list').children.length,0);
 assert.equal(inactive.document.querySelector('#logout').hidden,false,'invalid signed-in account must be able to sign out');
 inactive.dom.window.close();
 const invalid=await mount({user:{id:'invalid'},profile:{role:'superuser',is_active:true}});
 assert.equal(invalid.document.querySelector('#coach').hidden,true);
 assert.match(invalid.document.querySelector('#status').textContent,/Unbekannte/);
 assert.equal(invalid.document.querySelector('#logout').hidden,false);
 invalid.dom.window.close();
 const denied=await mount({user:{id:'coach-id'},profile:{role:'coach',is_active:true},rpcError:'permission denied'});
 assert.match(denied.document.querySelector('#status').textContent,/permission denied/);
 assert.equal(denied.document.querySelector('#list').children.length,0);
 denied.dom.window.close();
 console.log('Mocked browser smoke tests passed: guest, coach draft and logout, boxer join, inactive and invalid roles');
})().catch(e=>{console.error(e);process.exitCode=1});
