'use strict';
// Chromium test with mocked Supabase SDK (no real account, no server writes) for Etappe 5:
// Kampfpfad page, emotes + Einlauf on the duel page, Podium-Emote on index.html (Etappe 8), emote/Einlauf items in the shop.
const assert=require('node:assert/strict'),fs=require('node:fs'),http=require('node:http'),path=require('node:path');
const {chromium}=require('playwright');
const root=process.cwd();
const unq=s=>s==='NULL'?null:s.slice(1,-1).replace(/''/g,"'");
const parse=sql=>[...sql.matchAll(/\('([a-z0-9_]+)','(avatar|aura|banner|rahmen|titel|handschuhe|emote|einlauf)','((?:[^']|'')*)',(NULL|'(?:[^']|'')*'),'(\w+)','([FEDCBAS])','(start|rank|shop|pass)',(NULL|\d+),'(\{[^']*\})',(\d+)\)/g)]
 .map(m=>({key:m[1],category:m[2],name:m[3].replace(/''/g,"'"),description:unq(m[4]),rarity:m[5],min_rank:m[6],unlock:m[7],price:m[8]==='NULL'?null:+m[8],design:JSON.parse(m[9])}));
const ITEMS=[...parse(fs.readFileSync('supabase/migrations/20261028210000_kampfgeist_shop.sql','utf8')),...parse(fs.readFileSync('supabase/migrations/20261028220000_kampfgeist_etappe5.sql','utf8'))];
assert.equal(ITEMS.length,145,'parsed catalogue');
const server=http.createServer((req,res)=>{
 const u=new URL(req.url,'http://127.0.0.1'),file=path.resolve(root,decodeURIComponent(u.pathname.slice(1))||'index.html');
 if(!file.startsWith(root+path.sep)){res.writeHead(403);res.end();return}
 fs.readFile(file,(err,data)=>{if(err){res.writeHead(404);res.end();return}
  const ext=path.extname(file);res.setHeader('Content-Type',ext==='.js'?'text/javascript':ext==='.html'?'text/html':ext==='.css'?'text/css':ext==='.svg'?'image/svg+xml':ext==='.webp'?'image/webp':'application/octet-stream');res.end(data)});
});
function injected(cfg){
 const calls=[];window.__calls=calls;
 const names={boxer:'Anna',coach:'Marco',admin:'Owner'},profile={id:'p-'+cfg.role,display_name:names[cfg.role],role:cfg.role,is_active:true};
 const find=k=>cfg.items.find(i=>i.key===k);
 const look=(av,em,ein,ti)=>({level:7,rank:'F',avatar:find(av),aura:find('u_glut'),banner:find('b_dojo'),rahmen:find('f_glut'),titel:find(ti||'t_rookie'),handschuhe:find('g_rot'),emote:find(em),einlauf:find(ein)});
 const today=new Intl.DateTimeFormat('en-CA',{timeZone:'Europe/Zurich'}).format(new Date()),month=today.slice(0,8)+'01';
 let claimed=new Set(),events=[{id:1,sender_id:'p-ben',sender:'Ben',emote:find('m_gg'),created_at:new Date().toISOString(),hidden:false}];
 const tiers=()=>Array.from({length:30},(_,i)=>{const t=i+1,item={10:'m_pass_feuer',15:'b_pass',20:'e_pass_sturm',25:'f_pass',30:'t_pass'}[t];
  return {tier:t,need:t*20,reached:t<=7,claimed:claimed.has(t),reward:{coins:item?0:t===5?100:15,item:item?find(item):null,substitute:false}}});
 const duel={id:'d-1',challenger_id:'p-boxer',challenger_name:'Anna',opponent_id:'p-ben',opponent_name:'Ben',status:'active',duration_days:7,invited_at:new Date().toISOString(),expires_at:new Date(Date.now()+864e5).toISOString(),accepted_at:new Date().toISOString(),ends_at:new Date(Date.now()+6*864e5).toISOString(),challenger_score:0,opponent_score:0,winner_id:null};
 const myEmotes=['m_respekt','m_gg','m_deckung','m_runde','m_stark'].map(find);
 const rpc=async(name,args)=>{
  calls.push([name,args]);
  switch(name){
   case 'get_my_performance':return {data:{profile,ratings_enabled:false,style_enabled:false},error:null};
   case 'get_my_kampfpfad':return {data:cfg.off?{enabled:false}:{enabled:true,preview:false,can_claim:true,today,month,current_month:month,days_left:4,previous_open:0,
     points:{month,trainings:8,quests_weekly:3,quests_daily:4,quests_chest:0,duels_played:1,duels_won:1,points_trainings:80,points_quests:50,points_duels:25,total:155,per_tier:20,tier:7},tiers:tiers()},error:null};
   case 'claim_kampfpfad':{const open=tiers().filter(t=>t.reached&&!t.claimed&&(args.p_tier==null||t.tier===args.p_tier));open.forEach(t=>claimed.add(t.tier));
     return {data:{month,claimed:open.length,coins:open.reduce((s,t)=>s+t.reward.coins,0),items:[],balance:500},error:null}}
   case 'duel_v2_list_mine':return {data:[duel],error:null};
   case 'duel_v2_eligible_boxers':return {data:[],error:null};
   case 'duel_v2_live_scores':return {data:{duel_id:'d-1',status:'active',challenger_score:120,opponent_score:90,pending:0},error:null};
   case 'get_duel_kampfgeist':return {data:{enabled:true,preview:false,can_moderate:cfg.role!=='boxer',muted:false,my_emotes:myEmotes,
     duels:[{id:'d-1',status:'active',challenger:Object.assign(look('a_nia','m_stark','e_glut','t_unerm'),{id:'p-boxer',name:'Anna'}),opponent:Object.assign(look('a_malik','m_gg','e_donner'),{id:'p-ben',name:'Ben'}),
      can_send:cfg.role==='boxer',events:events.slice()}]},error:null};
   case 'send_duel_emote':{const e={id:events.length+1,sender_id:profile.id,sender:profile.display_name,emote:find(args.p_emote_key),created_at:new Date().toISOString(),hidden:false};events.push(e);return {data:e,error:null}}
   case 'hide_kg_emote':events.forEach(e=>{if(e.id===args.p_event_id)e.hidden=true});return {data:{id:args.p_event_id,hidden:true},error:null};
   case 'get_podium_kampfgeist':{const mine=cfg.podium||{show:false,key:'m_respekt'};
     return {data:{enabled:true,preview:false,my_show:mine.show,my_emote:find(mine.key),my_emotes:myEmotes,places:[
     {rank:1,name:'Ben',is_me:false,show_emote:true,emote:find('m_kg')},
     {rank:2,name:'Anna',is_me:cfg.role==='boxer',show_emote:mine.show,emote:mine.show?find(mine.key):null},
     {rank:3,name:'Bob',is_me:false,show_emote:false,emote:null}]},error:null}}
   case 'set_podium_emote':cfg.podium={show:args.p_show,key:args.p_emote_key||(cfg.podium&&cfg.podium.key)||'m_respekt'};return {data:{show:args.p_show,emote:find(cfg.podium.key)},error:null};
   case 'get_my_kampfgeist':return {data:{enabled:true,preview:false,can_buy:true,settings:{start_coins:100,coins_per_training:10},wallet:{balance:600,earned:700,spent:100,quest_pending:0},
     level:{exp:1010,level:7,rank:'F',rank_idx:0},look:look('a_kenji','m_respekt','e_slam'),
     items:cfg.items.map(i=>Object.assign({},i,{owned:i.unlock==='start',rank_ok:i.min_rank==='F',is_active:true})),history:[]},error:null};
  }
  return {data:null,error:{message:'unexpected rpc '+name}};
 };
 const from=()=>{const q={select(){return q},eq(){return q},order(){return q},limit(){return q},
  maybeSingle:async()=>({data:{id:profile.id,role:profile.role,is_active:true,display_name:profile.display_name},error:null}),
  then:(r)=>Promise.resolve({data:[],error:null}).then(r)};return q};
 window.__takeoverMockClient={auth:{getSession:async()=>({data:{session:{access_token:'x'}}}),getUser:async()=>({data:{user:{id:'u1'}},error:null}),onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}}),signOut:async()=>({error:null})},from,rpc};
}
(async()=>{
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const base='http://127.0.0.1:'+server.address().port+'/';
 const browser=await chromium.launch();
 const shots=process.env.KG_SHOTS||'';
 async function open(cfg,file,motion){
  const context=await browser.newContext({viewport:{width:390,height:844},reducedMotion:motion||'reduce'});
  await context.addInitScript({content:'('+injected.toString()+')('+JSON.stringify(Object.assign({items:ITEMS},cfg))+')'});
  const p=await context.newPage();const errors=[];p.on('pageerror',e=>errors.push(e.message));
  await p.route('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm',r=>r.fulfill({status:200,contentType:'text/javascript',body:'export const createClient=()=>window.__takeoverMockClient;'}));
  await p.route('https://iqarjivcrddcixrvqbfb.supabase.co/**',r=>{const u=r.request().url();
   const body=u.includes('get_public_leaderboard')?[{rank_position:1,boxer_name:'Ben',monthly_points:300,lifetime_exp:900,approved_sessions:6,points_training:300,points_bonus:0},{rank_position:2,boxer_name:'Anna',monthly_points:200,lifetime_exp:800,approved_sessions:4,points_training:200,points_bonus:0},{rank_position:3,boxer_name:'Bob',monthly_points:100,lifetime_exp:500,approved_sessions:2,points_training:100,points_bonus:0}]
    :u.includes('get_public_levels')?[{boxer_name:'Ben',lifetime_exp:900}]:[];
   r.fulfill({status:200,contentType:'application/json',body:JSON.stringify(body)})});
  await p.route('https://docs.google.com/**',r=>r.abort());
  await p.goto(base+file);
  return {p,errors,context};
 }
 const calls=p=>p.evaluate(()=>window.__calls);
 const shot=async(p,n,full)=>{if(shots)await p.screenshot({path:path.join(shots,n+'.png'),fullPage:!!full})};
 const noScroll=async p=>assert.ok(await p.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth),'no horizontal scroll');
 const done=async({p,errors,context})=>{await noScroll(p);assert.deepEqual(errors,[]);await context.close()};

 // Kampfpfad: Stufe 7, 30 Stufen, alle abholen
 let x=await open({role:'boxer'},'kampfpfad.html');
 await x.p.waitForSelector('.kg-tier');
 assert.equal(await x.p.locator('.kg-tier').count(),30);
 let t=await x.p.textContent('#app');
 assert.match(t,/Stufe 7/);assert.match(t,/155 Punkte/);assert.match(t,/8 Trainings/);assert.match(t,/1 Duelle, 1 gewonnen/);assert.match(t,/Monatsfeuer!/);
 assert.equal(await x.p.locator('[data-tier]').count(),7);
 await shot(x.p,'kg5-kampfpfad',true);
 await x.p.click('[data-all="1"]');
 await x.p.waitForFunction(()=>/7 Stufen abgeholt/.test(document.getElementById('app').textContent));
 assert.deepEqual((await calls(x.p)).find(c=>c[0]==='claim_kampfpfad')[1].p_tier,null);
 assert.equal(await x.p.locator('[data-tier]').count(),0);
 await done(x);
 x=await open({role:'boxer',off:true},'kampfpfad.html');
 await x.p.waitForFunction(()=>/Geduld/.test(document.getElementById('app').textContent));
 await done(x);

 // Duell: Kämpfer mit Avatar/Titel, Emote-Feed, Emote senden, Einlauf
 x=await open({role:'boxer'},'duels.html','no-preference');
 await x.p.waitForSelector('.tl-duel-card .kg-social');
 t=await x.p.textContent('.tl-duel-card .kg-social');
 assert.match(t,/Anna/);assert.match(t,/Ben/);assert.match(t,/Der Unermüdliche/);assert.match(t,/GG!/);
 assert.equal(await x.p.locator('[data-kg-send]').count(),5,'own emotes offered');
 await x.p.click('[data-kg-send][data-kg-emote="m_stark"]');
 await x.p.waitForFunction(()=>window.__calls.some(c=>c[0]==='send_duel_emote'&&c[1].p_duel_id==='d-1'&&c[1].p_emote_key==='m_stark'));
 await x.p.waitForFunction(()=>document.querySelectorAll('.kg-feed .kg-ev').length===2);
 assert.equal(await x.p.locator('[data-kg-hide]').count(),0,'boxer cannot hide');
 await shot(x.p,'kg5-duel');
 await x.p.click('[data-kg-intro="d-1"]');
 await x.p.waitForSelector('.kg-intro.vs');
 t=await x.p.textContent('.kg-intro');assert.match(t,/GLUT!/);assert.match(t,/DONNER!/);assert.match(t,/VS/);
 await x.p.waitForTimeout(1200);await shot(x.p,'kg5-einlauf');
 await x.p.keyboard.press('Escape');assert.equal(await x.p.locator('.kg-intro').count(),0);
 await done(x);
 // Coach: kann ausblenden, nicht senden
 x=await open({role:'coach'},'duels.html');
 await x.p.waitForSelector('[data-kg-hide]');
 assert.equal(await x.p.locator('[data-kg-send]').count(),0);
 await x.p.click('[data-kg-hide="1"]');
 await x.p.waitForFunction(()=>window.__calls.some(c=>c[0]==='hide_kg_emote'&&c[1].p_event_id===1));
 await done(x);

 // Podium (Etappe 8): kein eigenes Kampfgeist-Podium; Emote nur bei Boxern, die es eingeschaltet haben; eigene Auswahl unter dem Podium
 x=await open({role:'boxer'},'index.html');
 await x.p.waitForSelector('.tl-podium-emote-pick');
 assert.equal(await x.p.locator('.kg-podium,.kg-podium-place,[data-kg-react]').count(),0,'no separate Kampfgeist podium');
 assert.equal(await x.p.locator('.tl-podium .tl-podium-emote').count(),1,'only Ben shows an emote');
 assert.match(await x.p.textContent('.tl-podium-1'),/KAMPF-GEIST!!/);
 assert.equal(await x.p.locator('.tl-podium-2 .tl-podium-emote').count(),0,'Anna off by default');
 assert.equal(await x.p.evaluate(()=>document.querySelector('.tl-podium-emote-pick').open),false,'picker collapsed by default');
 assert.equal(await x.p.isVisible('[data-podium-emote=""]'),false,'options hidden while collapsed');
 assert.match(await x.p.textContent('.tl-podium-emote-pick summary'),/Dein Emote im Podium\s*Aus/);
 await x.p.evaluate(()=>document.querySelector('.tl-podium-emote-pick').scrollIntoView({block:'center'}));await shot(x.p,'kg8-podium-zu');
 await x.p.click('.tl-podium-emote-pick summary');
 assert.equal(await x.p.getAttribute('[data-podium-emote=""]','aria-pressed'),'true','Kein Emote selected');
 assert.equal(await x.p.locator('[data-podium-emote]').count(),6,'Kein Emote + 5 own emotes');
 await x.p.click('[data-podium-emote="m_stark"]');
 await x.p.waitForFunction(()=>window.__calls.some(c=>c[0]==='set_podium_emote'&&c[1].p_show===true&&c[1].p_emote_key==='m_stark'));
 await x.p.waitForSelector('.tl-podium-2 .tl-podium-emote');
 assert.equal(await x.p.getAttribute('[data-podium-emote="m_stark"]','aria-pressed'),'true');
 assert.equal(await x.p.evaluate(()=>document.querySelector('.tl-podium-emote-pick').open),true,'stays open after choosing');
 assert.match(await x.p.innerHTML('.tl-podium-emote-pick summary'),/STARK/);
 await x.p.locator('.tl-podium').scrollIntoViewIfNeeded();await shot(x.p,'kg8-podium');
 // Neu laden der Rangliste (Tab-Wechsel) behält die Emotes
 await x.p.evaluate(()=>load());
 await x.p.waitForFunction(()=>document.querySelector('.tl-podium-emote-pick')&&document.querySelector('.tl-podium-emote-pick').open);
 await x.p.waitForFunction(()=>document.querySelectorAll('.tl-podium .tl-podium-emote').length===2&&document.querySelectorAll('.tl-podium-emote-pick').length===1);
 await x.p.click('[data-podium-emote=""]');
 await x.p.waitForFunction(()=>window.__calls.some(c=>c[0]==='set_podium_emote'&&c[1].p_show===false));
 await x.p.waitForFunction(()=>!document.querySelector('.tl-podium-2 .tl-podium-emote'));
 await done(x);
 // Wer nicht auf dem Podium steht, bekommt keine Auswahl
 x=await open({role:'coach'},'index.html');
 await x.p.waitForSelector('.tl-podium .tl-podium-emote');
 assert.equal(await x.p.locator('.tl-podium-emote-pick').count(),0,'no picker when not on podium');
 await done(x);

 // Shop: Emotes und Einläufe, Kampfpfad-Items nicht käuflich, Einlauf-Vorschau
 x=await open({role:'boxer'},'shop.html','no-preference');
 await x.p.waitForSelector('.kg-item');
 await x.p.click('[data-cat="emote"]');assert.equal(await x.p.locator('.kg-item').count(),13,'13 emotes in shop');
 await x.p.click('[data-cat="einlauf"]');assert.equal(await x.p.locator('.kg-item').count(),8,'8 Einläufe in shop');
 await x.p.click('[data-item="e_ring"]');await x.p.click('[data-play="e_ring"]');
 await x.p.waitForSelector('.kg-intro');assert.match(await x.p.textContent('.kg-intro'),/DING DING!/);
 await x.p.click('.kg-intro-close');
 await x.p.click('#layer button[data-close]');
 await x.p.click('[data-tab="inv"]');
 assert.equal(await x.p.locator('.kg-slot').count(),8,'8 slots');
 await x.p.click('[data-item="t_pass"]');assert.match(await x.p.textContent('#layer'),/nur im Kampfpfad/);assert.equal(await x.p.locator('[data-buy]').count(),0);
 await done(x);

 await browser.close();server.close();
 console.log('PASS: Etappe 5 im Browser – Kampfpfad (30 Stufen, abholen, Flag aus), Duell (Kämpfer, Emote-Feed, senden, Einlauf VS, Coach blendet aus), Podium (Emote nur wer es einschaltet, eigene Auswahl, kein separates Podium), Shop (13 Emotes, 8 Einläufe, Vorschau, Kampfpfad-Items)');
})().catch(e=>{console.error(e);process.exit(1)});
