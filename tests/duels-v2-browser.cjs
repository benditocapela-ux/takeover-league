const fs=require('node:fs');
const vm=require('node:vm');
const assert=require('node:assert/strict');
const {JSDOM}=require('jsdom');
const preview=fs.readFileSync('duels-v2-preview.html','utf8');
const production=fs.readFileSync('duels.html','utf8');
const source=preview.match(/<script type="module">([\s\S]*?)<\/script>/)?.[1]?.replace(/^import .*;\s*$/gm,'');
const prodSource=production.match(/<script type="module">([\s\S]*?)<\/script>/)?.[1]?.replace(/^import .*;\s*$/gm,'');
assert.ok(source&&prodSource,'both duel scripts required');
new vm.Script('(async()=>{'+source+'})()');
new vm.Script('(async()=>{'+prodSource+'})()');
assert.match(production,/TAKEOVER_DUELS_V2_ENABLED=true/,'released duel UI must be enabled');
assert.match(preview,/cfgdvcccsqwfjajuizsr\.supabase\.co/);
assert.doesNotMatch(preview,/iqarjivcrddcixrvqbfb/);
assert.match(production,/iqarjivcrddcixrvqbfb\.supabase\.co/);
assert.doesNotMatch(production,/cfgdvcccsqwfjajuizsr/);
assert.doesNotMatch(source,/innerHTML|document\.write|eval\(/);
const eligible=[
 {id:'boxer-1',display_name:'Boxer Eins'},
 {id:'boxer-2',display_name:'Boxer Zwei'},
 {id:'boxer-3',display_name:'Boxer Drei'}
];
const tick=()=>new Promise(resolve=>setTimeout(resolve,0));
async function mount({user={id:'user'},profile={id:'boxer-1',role:'boxer',is_active:true},boxers=eligible,duels=[],rpcError=null}={}){
 const dom=new JSDOM(preview,{url:'https://example.test/duels-v2-preview.html',runScripts:'outside-only'});
 const calls=[];let onAuthEvent=null;
 const db={
  auth:{
   getUser:async()=>({data:{user},error:null}),
   signInWithPassword:async()=>({error:null}),
   signOut:async()=>({error:null}),
   onAuthStateChange:cb=>{onAuthEvent=cb;return {data:{subscription:{unsubscribe(){}}}}}
  },
  from:name=>{assert.equal(name,'profiles');return{
   select:()=>({eq:()=>({maybeSingle:async()=>({data:profile,error:null})})})
  }},
  rpc:async(name,args)=>{calls.push({name,args});
   if(rpcError)return {data:null,error:{message:rpcError}};
   return {data:name==='duel_v2_list_mine'?duels:name==='duel_v2_eligible_boxers'?boxers:'ok',error:null};
  }
 };
 dom.window.createClient=()=>db;dom.window.confirm=()=>true;
 dom.window.eval('window.TAKEOVER_DUELS_V2_ENABLED=true;');
 dom.window.eval(source.replace('init();','window.__ready=init();'));
 await dom.window.__ready;
 return {dom,document:dom.window.document,calls,db,emitAuth:event=>onAuthEvent?.(event,null)};
}
(async()=>{
 const prod=new JSDOM(production,{url:'https://example.test/duels.html',runScripts:'outside-only'});
 let clientCalls=0;
 prod.window.createClient=()=>{clientCalls++;throw Error('Disabled production should not create Supabase client')};
 prod.window.eval('window.TAKEOVER_DUELS_V2_ENABLED=false;');
 prod.window.eval(prodSource.replace('init();','window.__ready=init();'));
 await prod.window.__ready;
 assert.equal(clientCalls,0);
 assert.equal(prod.window.document.querySelector('#app').hidden,true);
 assert.equal(prod.window.document.querySelector('#auth').hidden,true);
 assert.match(prod.window.document.querySelector('#status').textContent,/vorbereitet/);
 prod.window.close();

 const guest=await mount({user:null});
 assert.equal(guest.document.querySelector('#auth').hidden,false);
 assert.equal(guest.document.querySelector('#app').hidden,true);
 assert.equal(guest.calls.length,0,'guest cannot access duel RPCs');
 guest.dom.window.close();

 const boxer=await mount();
 const boxerForm=boxer.document.querySelector('#invite');
 assert.equal(boxer.document.querySelector('#auth').hidden,true);
 assert.equal(boxerForm.elements.challenger.disabled,true);
 assert.equal(boxerForm.elements.challenger.value,'boxer-1');
 assert.equal(boxerForm.elements.opponent.value,'boxer-2');
 boxerForm.dispatchEvent(new boxer.dom.window.Event('submit',{bubbles:true,cancelable:true}));
 await tick();await tick();
 assert.ok(boxer.calls.some(x=>x.name==='duel_v2_invite'&&x.args.p_challenger==='boxer-1'&&x.args.p_opponent==='boxer-2'&&x.args.p_duration_days===7));
 boxer.document.querySelector('#logout').click();await tick();await tick();
 assert.equal(boxer.document.querySelector('#app').hidden,true);
 assert.equal(boxer.document.querySelector('#auth').hidden,false);
 boxer.dom.window.close();

 const raced=await mount();
 let resolveLateList;
 const originalRpc=raced.db.rpc;
 raced.db.rpc=(name,args)=>name==='duel_v2_list_mine'
   ?new Promise(resolve=>{resolveLateList=resolve})
   :originalRpc(name,args);
 raced.document.querySelector('#refresh').click();await tick();
 assert.equal(typeof resolveLateList,'function');
 raced.document.querySelector('#logout').click();await tick();
 resolveLateList({data:[{
  id:'secret',challenger_id:'boxer-1',challenger_name:'Privater Teilnehmer',
  opponent_id:'boxer-2',opponent_name:'Nur für Mitglieder',status:'pending',duration_days:7
 }],error:null});
 await tick();await tick();
 assert.equal(raced.document.querySelector('#app').hidden,true,'logout hides duel application');
 assert.equal(raced.document.querySelector('#duelList').children.length,0,'late requests must not restore private duels');
 assert.doesNotMatch(raced.document.body.textContent,/Nur für Mitglieder/);
 raced.dom.window.close();
 const otherTab=await mount({duels:[{
 id:'private-duel',challenger_id:'boxer-1',challenger_name:'Boxer Eins',
 opponent_id:'boxer-2',opponent_name:'Boxer Zwei',
 status:'pending',duration_days:7
 }]});
 assert.match(otherTab.document.querySelector('#duelList').textContent,/Boxer Eins/);
 otherTab.emitAuth('SIGNED_OUT');
 assert.equal(otherTab.document.querySelector('#app').hidden,true);
 assert.equal(otherTab.document.querySelector('#duelList').children.length,0,'cross-tab signout must wipe duels');
 assert.equal(otherTab.document.querySelector('#auth').hidden,false);
 otherTab.dom.window.close();
 const coach=await mount({profile:{id:'coach-1',role:'coach',is_active:true}});
 const form=coach.document.querySelector('#invite');
 assert.equal(form.elements.challenger.disabled,false);
 form.elements.challenger.value='boxer-2';
 form.elements.challenger.dispatchEvent(new coach.dom.window.Event('change',{bubbles:true}));
 assert.equal(form.elements.challenger.value,'boxer-2','coach challenger must survive rerender');
 assert.equal([...form.elements.opponent.options].some(x=>x.value==='boxer-2'),false,'no self duel');
 form.elements.duration.value='14';
 form.dispatchEvent(new coach.dom.window.Event('submit',{bubbles:true,cancelable:true}));
 await tick();await tick();
 assert.ok(coach.calls.some(x=>x.name==='duel_v2_invite'&&x.args.p_challenger==='boxer-2'&&x.args.p_duration_days===14));
 coach.dom.window.close();

 const incoming={
  id:'duel-1',challenger_id:'boxer-1',challenger_name:'Boxer Eins',
  opponent_id:'boxer-2',opponent_name:'Boxer Zwei',
  status:'pending',duration_days:7,invited_at:'2026-10-18T12:00:00Z',
  expires_at:'2100-10-20T12:00:00Z'
 };
 const invited=await mount({profile:{id:'boxer-2',role:'boxer',is_active:true},duels:[incoming]});
 const accept=[...invited.document.querySelectorAll('#duelList button')].find(x=>x.textContent==='Annehmen');
 const decline=[...invited.document.querySelectorAll('#duelList button')].find(x=>x.textContent==='Ablehnen');
 assert.ok(accept&&decline,'only the invited boxer can answer');
 accept.click();await tick();await tick();
 assert.ok(invited.calls.some(x=>x.name==='duel_v2_respond'&&x.args.p_duel_id==='duel-1'&&x.args.p_accept===true));
 invited.dom.window.close();
 const declining=await mount({profile:{id:'boxer-2',role:'boxer',is_active:true},duels:[incoming]});
 const reject=[...declining.document.querySelectorAll('#duelList button')].find(x=>x.textContent==='Ablehnen');
 reject.click();await tick();await tick();
 assert.ok(declining.calls.some(x=>x.name==='duel_v2_respond'&&x.args.p_duel_id==='duel-1'&&x.args.p_accept===false));
 declining.dom.window.close();


 const nonRecipient=await mount({profile:{id:'boxer-1',role:'boxer',is_active:true},duels:[incoming]});
 assert.equal(nonRecipient.document.querySelectorAll('#duelList button').length,0,'inviting boxer cannot accept own invitation');
 nonRecipient.dom.window.close();

 const expired=await mount({profile:{id:'boxer-2',role:'boxer',is_active:true},duels:[{...incoming,expires_at:'2020-01-01T00:00:00Z'}]});
 assert.equal(expired.document.querySelectorAll('#duelList button').length,0,'expired invitation no actions');
 assert.match(expired.document.querySelector('#duelList').textContent,/Einladung abgelaufen/);
 expired.dom.window.close();

 const withdrawing=await mount({profile:{id:'boxer-1',role:'boxer',is_active:true},duels:[incoming]});
 const withdrawButton=[...withdrawing.document.querySelectorAll('#duelList button')].find(x=>x.textContent==='Einladung zurückziehen');
 assert.ok(withdrawButton,'inviting boxer can withdraw a pending invitation');
 withdrawButton.click();await tick();await tick();
 assert.ok(withdrawing.calls.some(x=>x.name==='duel_v2_withdraw_invite'&&x.args.p_duel_id==='duel-1'));
 withdrawing.dom.window.close();

 const coachWithdraw=await mount({profile:{id:'coach-1',role:'coach',is_active:true},duels:[incoming]});
 const coachWithdrawButton=[...coachWithdraw.document.querySelectorAll('#duelList button')].find(x=>x.textContent==='Einladung zurückziehen');
 assert.ok(coachWithdrawButton,'coach can withdraw a pending duel invitation');
 coachWithdrawButton.click();await tick();await tick();
 assert.ok(coachWithdraw.calls.some(x=>x.name==='duel_v2_withdraw_invite'&&x.args.p_duel_id==='duel-1'));
 coachWithdraw.dom.window.close();

 const finished={
  ...incoming,status:'active',ends_at:'2020-10-20T12:00:00Z',
  challenger_score:70,opponent_score:40
 };
 const coachReview=await mount({profile:{id:'coach-1',role:'coach',is_active:true},duels:[finished]});
 const reconcileButton=[...coachReview.document.querySelectorAll('#duelList button')].find(x=>x.textContent==='Ergebnis prüfen');
 assert.ok(reconcileButton,'coach can reconcile ended duels');
 assert.match(coachReview.document.querySelector('#duelList').textContent,/Die Trainingspunkte werden nach Ablauf/,'active duel should not present stale scores');
 assert.doesNotMatch(coachReview.document.querySelector('#duelList').textContent,/Trainingspunkte: 70 : 40/,'active score must not appear finalized');
 reconcileButton.click();await tick();await tick();
 assert.ok(coachReview.calls.some(x=>x.name==='duel_v2_reconcile'&&x.args.p_duel_id==='duel-1'));
 coachReview.dom.window.close();
 const boxerReview=await mount({profile:{id:'boxer-1',role:'boxer',is_active:true},duels:[finished]});
 assert.equal([...boxerReview.document.querySelectorAll('#duelList button')].some(x=>x.textContent==='Ergebnis prüfen'),false,'boxer cannot manually reconcile a duel');
 boxerReview.dom.window.close();
 const completed=await mount({duels:[{
  ...incoming,status:'settled',challenger_score:120,opponent_score:95,winner_id:'boxer-1',
  ends_at:'2026-10-25T12:00:00Z'
 }]});
 assert.match(completed.document.querySelector('#duelList').textContent,/120 : 95/);
 assert.match(completed.document.querySelector('#duelList').textContent,/Endstand \(Trainingspunkte\)/,'settled score must be labeled final');
 assert.match(completed.document.querySelector('#duelList').textContent,/Gewinner: Boxer Eins/);
 completed.dom.window.close();

 const malicious=await mount({duels:[{...incoming,challenger_name:'<img src=x onerror=alert(1)>',status:'settled'}]});
 assert.equal(malicious.document.querySelector('#duelList img'),null,'backend-controlled display name must be escaped');
 malicious.dom.window.close();

 const inactive=await mount({profile:{id:'boxer-1',role:'boxer',is_active:false}});
 assert.equal(inactive.document.querySelector('#app').hidden,true);
 assert.equal(inactive.calls.length,0);
 inactive.dom.window.close();

 const denied=await mount({rpcError:'permission denied'});
 assert.match(denied.document.querySelector('#status').textContent,/permission denied/);
 denied.dom.window.close();
 console.log('Duels V2: production guard, invitation, acceptance, expiry, coach selection, scoring and XSS tests passed');
})().catch(err=>{console.error(err);process.exitCode=1});
