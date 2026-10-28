'use strict';
// Real Chromium test with mocked Supabase SDK (no real account, no server writes):
// boxer sees own rating, coach rates via 1–20 sliders (Etappe 7a), compare page shows cards and style overlay, boxer takes the style test once,
// coach unlocks, public profile shows the card only for signed-in viewers.
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
 const keys=['jab','cross','hook','upper','body','combo','guard','block','slip','roll','parry','counter','stance','steps','angles','ring','endur','pace','recov','timing','dist','plan','focus','heart','coach'];
 const all=v=>Object.fromEntries(keys.map(k=>[k,v]));
 const cur={...all(7),jab:10,slip:3},prev=all(7);
 const sum=s=>({categories:{OFF:75,DEF:63,BEI:70,KON:70,TAK:70,MEN:70},overall:70,top:[{k:'jab',v:10},{k:'cross',v:7},{k:'hook',v:7}],low:[{k:'slip',v:3},{k:'cross',v:7},{k:'hook',v:7}]});
 const calls=[];window.__calls=calls;
 const profile={id:cfg.role==='boxer'?'p-anna':'p-coach',display_name:cfg.role==='boxer'?'Anna':'Marco',role:cfg.role};
 let styleState={can_take:true,locked:false,unlocked:false,next_allowed_on:'2026-11-01'},styleCur=null;
 const rpc=async(name,args)=>{
  calls.push([name,args]);
  if(name==='get_my_performance')return {data:{profile,ratings_enabled:true,style_enabled:true,
   rating:cfg.role==='boxer'?{current:{scores:cur,summary:sum(cur),created_at:'2026-10-20T10:00:00Z',note:'Jab top, Slip üben',rated_by:'Marco'},previous:{scores:prev,summary:{categories:{OFF:70,DEF:70,BEI:70,KON:70,TAK:70,MEN:70},overall:70},created_at:'2026-09-29T10:00:00Z'}}:null,
   style:{current:styleCur,previous:null,state:styleState}},error:null};
  if(name==='staff_list_performance')return {data:[
   {id:'p-anna',display_name:'Anna',role:'boxer',overall:70,rated_at:'2026-10-20T10:00:00Z',style:{locked:true,unlocked:false,last_at:'2026-10-03T10:00:00Z'},style_scores:{o:20,v:45,c:18,p:80,s:20,a:75},is_self:false},
   {id:'p-coach',display_name:'Marco',role:'coach',overall:null,rated_at:null,style:{locked:false,unlocked:false,last_at:null},style_scores:null,is_self:true}],error:null};
  if(name==='staff_get_rating')return {data:{current:{scores:cur,scale:10,created_at:'2026-10-20T10:00:00Z'},previous:null},error:null};
  if(name==='staff_rate_boxer')return {data:{id:9,previous_overall:70,overall:71},error:null};
  if(name==='submit_style_test'){styleState={can_take:false,locked:true,unlocked:false,next_allowed_on:'2026-11-01'};styleCur={scores:{o:20,v:45,c:18,p:80,s:20,a:63},created_at:new Date().toISOString()};
   return {data:{id:1,scores:styleCur.scores,next_allowed_on:'2026-11-01'},error:null}}
  if(name==='staff_unlock_style_test')return {data:{status:'unlocked',boxer:'Anna'},error:null};
  if(name==='get_performance_card'){
   if(args.p_display_name==='Ben')return {data:{display_name:'Ben',is_me:cfg.role==='boxer'&&cfg.me==='Ben',rating:{categories:{OFF:60,DEF:80,BEI:65,KON:70,TAK:72,MEN:75},overall:70,scale:20,top:[],low:[],rated_at:'2026-10-21T10:00:00Z',delta:2},style:{scores:{o:85,v:30,c:70,p:15,s:60,a:25},created_at:'2026-10-04T10:00:00Z'}},error:null};
   return {data:{display_name:'Anna',is_me:false,rating:{...sum(cur),scale:10,rated_at:'2026-10-20T10:00:00Z',delta:0},style:{scores:{o:20,v:45,c:18,p:80,s:20,a:63},created_at:'2026-10-03T10:00:00Z'}},error:null};
  }
  return {data:null,error:{message:'unexpected rpc '+name}};
 };
 const q={select(){return q},eq(){return q},order(){return q},limit(){return q},maybeSingle:async()=>({data:{role:profile.role,is_active:true,display_name:profile.display_name},error:null}),then:(r)=>Promise.resolve({data:[],error:null}).then(r)};
 window.__takeoverMockClient={
  auth:{getSession:async()=>({data:{session:cfg.signedIn?{access_token:'x'}:null}}),getUser:async()=>({data:{user:cfg.signedIn?{id:'u1'}:null},error:null}),onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}})},
  from:()=>q,rpc};
}
(async()=>{
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const base='http://127.0.0.1:'+server.address().port+'/';
 const browser=await chromium.launch();
 async function page(cfg){
  const context=await browser.newContext({viewport:{width:390,height:844}});
  await context.addInitScript({content:'('+injected.toString()+')('+JSON.stringify(cfg)+')'});
  const p=await context.newPage();const errors=[];p.on('pageerror',e=>errors.push(e.message));
  await p.route('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm',r=>r.fulfill({status:200,contentType:'text/javascript',body:'export const createClient=()=>window.__takeoverMockClient;'}));
  await p.route('https://iqarjivcrddcixrvqbfb.supabase.co/**',r=>{const u=r.request().url();
   const body=u.includes('get_public_levels')?[{boxer_name:'Anna',lifetime_exp:500},{boxer_name:'Ben',lifetime_exp:300}]:u.includes('get_public_leaderboard')?[{boxer_name:'Anna',rank_position:1,monthly_points:100,approved_sessions:4,points_training:100,points_bonus:0},{boxer_name:'Ben',rank_position:2,monthly_points:80,approved_sessions:3,points_training:80,points_bonus:0}]:[];
   r.fulfill({status:200,contentType:'application/json',body:JSON.stringify(body)})});
  return {p,errors,context};
 }
 const shot=async(p,n)=>{if(process.env.SHOTS)await p.screenshot({path:process.env.SHOTS+'/'+n+'.png',fullPage:true})};
 const noOverflow=async p=>assert.ok(await p.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth),'no horizontal scroll');

 // A: Boxer sieht eigene Bewertung
 let {p,errors,context}=await page({role:'boxer',signedIn:true});
 await p.goto(base+'bewertung.html');await p.waitForSelector('.tlp-card');
 const txt=await p.textContent('#app');
 assert.match(txt,/Jab top, Slip üben/);assert.match(txt,/Deine Stärken/);assert.match(txt,/Daran arbeiten/);
 assert.equal(await p.textContent('#pageTitle'),'Meine Bewertung');
 assert.equal(await p.locator('[data-range]').count(),0,'boxer has no editor');
 assert.match(txt,/\/20/,'own rating shown on the 20 scale');assert.match(txt,/Stärken[\s\S]*Jab 20/,'old 10-scale value doubled');
 await noOverflow(p);assert.deepEqual(errors,[]);await context.close();

 // B: Coach bewertet mit Reglern 1–20 (bisherige 10er-Noten werden verdoppelt angezeigt)
 ({p,errors,context}=await page({role:'coach',signedIn:true}));
 await p.goto(base+'bewertung.html');await p.waitForSelector('[data-open="p-anna"]');
 assert.match(await p.textContent('#app'),/1 bis 20/);
 assert.ok(await p.locator('[data-open="p-coach"]').isDisabled(),'coach cannot rate himself');
 await p.click('[data-open="p-anna"]');await p.waitForSelector('[data-range="angles"]');
 assert.equal(await p.inputValue('[data-range="jab"]'),'20','old 10 → 20');assert.equal(await p.inputValue('[data-range="angles"]'),'14','old 7 → 14');
 const bandBefore=await p.textContent('[data-row="angles"] .tlp-band');assert.match(bandBefore,/^Stark · /);
 await p.fill('[data-range="angles"]','18');await p.fill('[data-range="slip"]','9');
 assert.match(await p.textContent('[data-row="angles"] .tlp-band'),/^Elite · Drehungen und Winkel/,'text follows the slider');
 assert.match(await p.textContent('[data-row="slip"] .tlp-band'),/^Solide · Knappes Ausweichen/);
 assert.match(await p.textContent('[data-row="angles"]'),/war 14/);
 assert.equal(await p.getAttribute('[data-range="angles"]','aria-valuetext'),'18 von 20 · Elite');
 // Vorschau rechnet live: BEI (14*3+18)/4=15 → 75; DEF (14*4+6+9... ) sichtbar auf der Karte
 assert.match(await p.textContent('.tlp-preview'),/Neue Gesamtwertung/);
 assert.match(await p.textContent('[data-cat="BEI"]'),/^75/);
 await shot(p,'7a-bewertung');
 await p.fill('#rateNote','Winkel schon besser');await p.click('[data-act="save"]');
 await p.waitForFunction(()=>window.__calls.some(c=>c[0]==='staff_rate_boxer'));
 const save=(await p.evaluate(()=>window.__calls)).find(c=>c[0]==='staff_rate_boxer')[1];
 assert.equal(save.p_boxer_id,'p-anna');assert.equal(Object.keys(save.p_scores).length,25);assert.equal(save.p_scale,20);
 assert.equal(save.p_scores.angles,18);assert.equal(save.p_scores.slip,9);assert.equal(save.p_scores.jab,20);assert.equal(save.p_scores.cross,14);assert.equal(save.p_note,'Winkel schon besser');
 await p.waitForFunction(()=>/Gespeichert: Anna 70 → 71/.test(document.getElementById('status').textContent));
 await noOverflow(p);assert.deepEqual(errors,[]);await context.close();

 // C: Boxer macht den Boxstil-Test
 ({p,errors,context}=await page({role:'boxer',signedIn:true}));
 await p.goto(base+'stil-test.html');await p.waitForSelector('[data-act="start"]');
 await p.click('[data-act="start"]');
 for(let i=0;i<8;i++){await p.click('[data-pick="'+(i%3)+'"]');await p.click('[data-act="next"]');}
 await p.waitForSelector('.tlp-radar .tlp-shape');
 const sub=(await p.evaluate(()=>window.__calls)).find(c=>c[0]==='submit_style_test')[1];
 assert.deepEqual(sub.p_answers,[0,1,2,0,1,2,0,1]);
 assert.match(await p.textContent('#app'),/Druck-Boxer/);assert.match(await p.textContent('#app'),/Nächster Test ab/);
 await noOverflow(p);assert.deepEqual(errors,[]);await context.close();

 // D: Coach gibt frei
 ({p,errors,context}=await page({role:'coach',signedIn:true}));
 await p.goto(base+'stil-test.html');await p.waitForSelector('[data-unlock="p-anna"]');
 await p.click('[data-unlock="p-anna"]');
 await p.waitForFunction(()=>window.__calls.some(c=>c[0]==='staff_unlock_style_test'&&c[1].p_boxer_id==='p-anna'));
 assert.deepEqual(errors,[]);await context.close();

 // E: Profil – angemeldet mit Karte, Gast ohne
 ({p,errors,context}=await page({role:'boxer',signedIn:true}));
 await p.goto(base+'boxer-profile.html?name=Anna');await p.waitForSelector('.tlp-profile .tlp-card');
 const prof=await p.textContent('.tlp-profile');assert.match(prof,/Coach-Bewertung/);assert.match(prof,/Boxstil/);assert.doesNotMatch(prof,/Slip üben/);
 await noOverflow(p);await context.close();
 ({p,errors,context}=await page({role:'boxer',signedIn:false}));
 await p.goto(base+'boxer-profile.html?name=Anna');await p.waitForSelector('#profileCard:not([hidden])');await p.waitForTimeout(400);
 assert.equal(await p.locator('.tlp-profile').count(),0,'guest sees no rating');
 assert.ok(!(await p.evaluate(()=>window.__calls)).some(c=>c[0]==='get_performance_card'),'guest triggers no card request');
 await context.close();

 // F: Boxervergleich – Karten nebeneinander, Bereiche, Stil-Overlay (eigener Stil gold)
 ({p,errors,context}=await page({role:'boxer',signedIn:true,me:'Ben'}));
 await p.goto(base+'boxer-compare.html?left=Anna&right=Ben');await p.waitForSelector('.tlp-compare:not([hidden]) .tlp-radar-cmp');
 const cmp=await p.textContent('.tlp-compare');
 assert.match(cmp,/Ben \(du\)/);assert.equal(await p.locator('.tlp-compare .tlp-card').count(),2);
 assert.equal((await p.textContent('.tlp-legend span:first-child')).trim(),'Anna','order follows the selection');
 assert.equal(await p.locator('.tlp-legend span:last-child .sw.g').count(),1,'own boxer (right) is gold');
 assert.equal(await p.locator('.tlp-vs-side.b .tlp-name').textContent(),'ANNA');
 assert.match(cmp,/% gleicher Stil/);assert.equal(await p.locator('.tlp-radar-cmp .tlp-overlap').count(),1);
 assert.match(await p.textContent('.tlp-cmprow.total'),/70[\s\S]*70/);
 const sim=await p.evaluate(()=>window.TLPerf.similarity({o:85,v:30,c:70,p:15,s:60,a:25},{o:20,v:45,c:18,p:80,s:20,a:63}));
 assert.ok(sim>0&&sim<100);assert.match(cmp,new RegExp(sim+'% gleicher Stil'));
 await shot(p,'7a-vergleich');await noOverflow(p);assert.deepEqual(errors,[]);await context.close();
 ({p,errors,context}=await page({role:'boxer',signedIn:false}));
 await p.goto(base+'boxer-compare.html?left=Anna&right=Ben');await p.waitForSelector('.tlp-compare:not([hidden])');
 assert.match(await p.textContent('.tlp-compare'),/angemeldet/);
 assert.ok(!(await p.evaluate(()=>window.__calls)).some(c=>c[0]==='get_performance_card'),'guest: no card request');
 await context.close();

 await browser.close();server.close();
 console.log('PASS: Bewertung (Boxer, Coach mit Reglern 1–20 und Stufentexten), Boxervergleich mit Karten und Stil-Overlay, Boxstil-Test mit Monatssperre-Anzeige, Freigabe und Profilkarte nur für Angemeldete im Browser geprüft');
})().catch(e=>{console.error(e);process.exit(1)});
