'use strict';
// Chromium test with mocked Supabase (no real account, no server writes) for Etappe 19:
// Kampfgeist-Anzeige (Banner, Avatar mit Aura/Rahmen, Rang, Level) im Ranking, auf dem Podium, im Boxerprofil und im Studio.
// Eigener Avatar ersetzt das Profilbild; ohne eigene Wahl bleibt das Profilbild (mit Aura/Rahmen). Harness: looks-everywhere-browser.cjs.
const assert=require('node:assert/strict'),fs=require('node:fs'),http=require('node:http'),path=require('node:path');
const {chromium}=require('playwright');
const root=process.cwd();
const server=http.createServer((req,res)=>{
 const u=new URL(req.url,'http://127.0.0.1');
 if(u.pathname==='/news.json'){res.setHeader('Content-Type','application/json');res.end('{"entries":[]}');return}
 const file=path.resolve(root,decodeURIComponent(u.pathname.slice(1))||'index.html');
 if(!file.startsWith(root+path.sep)){res.writeHead(403);res.end();return}
 fs.readFile(file,(err,data)=>{if(err){res.writeHead(404);res.end();return}
  const ext=path.extname(file);res.setHeader('Content-Type',ext==='.js'?'text/javascript':ext==='.html'?'text/html':ext==='.css'?'text/css':ext==='.svg'?'image/svg+xml':ext==='.webp'?'image/webp':'application/octet-stream');res.end(data)});
});
function injected(cfg){
 const calls=[];window.__calls=calls;
 const me=cfg.me||'Ben';
 const looks=[
  {name:'Anna',rank:'D',rahmen:{key:'f_rang_d',name:'Emblem Rang D',design:{fr:'rank',rk:'D'}},titel:{key:'t_contender',name:'Contender',rarity:'rare'}},
  {name:'Ben',rank:'E',rahmen:{key:'f_glut',name:'Glutrand',design:{fr:'glut'}},titel:{key:'t_x',name:'<b>Der Unermüdliche</b>',rarity:'leg'}},
  {name:'Cara',rank:'F',rahmen:null,titel:null}];

 const it=(key,design,extra)=>Object.assign({key,name:key,rarity:'common',design},extra||{});
 const cards=[
  {name:'Anna',level:25,rank:'D',own_avatar:false,avatar:it('a_kenji',{hair:'spiky',skin:'#e8b48a'}),aura:it('u_glut',{g:'#ff5a1f,#ffb347,#ff5a1f',p:'#ffb347'}),
   banner:it('b_ember',{bn:'ember'}),rahmen:it('f_rang_d',{fr:'rank',rk:'D'}),titel:it('t_contender',null,{name:'Contender',rarity:'rare'}),handschuhe:it('g_rot',{c:'#d8282f'})},
  {name:'Ben',level:12,rank:'E',own_avatar:true,avatar:it('a_zara',{hair:'buns',hc:'#1a100c',skin:'#6b4027',eye:'#ffb020'}),aura:it('u_none',{}),
   banner:it('b_moon',{bn:'moon'}),rahmen:it('f_glut',{fr:'glut'}),titel:it('t_x',null,{name:'<b>Der Unermüdliche</b>',rarity:'leg'}),handschuhe:it('g_rot',{c:'#d8282f'})},
  {name:'Cara',level:3,rank:'F',own_avatar:false,avatar:it('a_kenji',{hair:'spiky',skin:'#e8b48a'}),aura:it('u_none',{}),
   banner:it('b_dojo',{bn:'dojo'}),rahmen:it('f_none',{fr:'none'}),titel:it('t_rookie',null,{name:'Rookie',rarity:'common'}),handschuhe:it('g_rot',{c:'#d8282f'})}];
 const rating=o=>({categories:{OFF:o,DEF:o,BEI:o,KON:o,TAK:o,MEN:o},overall:o,scale:20,top:[{k:'jab',v:16}],low:[{k:'slip',v:8}],rated_at:'2026-10-20T10:00:00Z',delta:2});
 const rated={Anna:72,Ben:65,Cara:58};
 const rpc=async(name,args)=>{
  calls.push([name,args]);
  if(name==='get_public_boxer_looks')return {data:looks,error:null};
  if(name==='get_public_boxer_cards'){if(cfg.noCards)return {data:null,error:{message:'missing'}};return {data:cards,error:null}}
  if(name==='get_performance_card'){const n=args.p_display_name;return {data:{display_name:n,is_me:n===me,rating:rated[n]?rating(rated[n]):null,style:{scores:{o:30,v:60,c:40,p:80,s:30,a:70},created_at:'2026-10-03T10:00:00Z'}},error:null}}
  if(name==='get_my_performance')return {data:{profile:{id:'p-me',display_name:me,role:'boxer'},ratings_enabled:true,style_enabled:true,
   rating:{current:{scores:Object.fromEntries(['jab','cross','hook','upper','body','combo','guard','block','slip','roll','parry','counter','stance','steps','angles','ring','endur','pace','recov','timing','dist','plan','focus','heart','coach'].map(k=>[k,13])),scale:20,
    summary:{categories:{OFF:65,DEF:65,BEI:65,KON:65,TAK:65,MEN:65},overall:65,top:[{k:'jab',v:13}],low:[{k:'slip',v:13}]},created_at:'2026-10-20T10:00:00Z',note:null,rated_by:'Marco'},previous:null},
   style:{current:null,previous:null,state:{}}},error:null};
  if(name==='get_kg_look')return {data:{name:args.p_display_name,avatar:{key:'a_kenji',design:{hair:'spiky',skin:'#e8b48a'}},rahmen:{key:'f_rang_d',design:{fr:'rank',rk:'D'}},titel:{name:'Contender',rarity:'rare'},rank:'D',level:25},error:null};
  if(name==='get_my_self_rating')return {data:{enabled:false,reason:'flag'},error:null};
  if(/^(get_card_looks|get_holo_looks)$/.test(name))return {data:{},error:null};
  if(/^(get_podium_kampfgeist|get_card_awards)$/.test(name))return {data:{enabled:false},error:null};
  return {data:null,error:{message:'unexpected rpc '+name}};
 };
 const q={select(){return q},eq(){return q},order(){return q},limit(){return q},in(){return q},gte(){return q},lte(){return q},range(){return q},
  maybeSingle:async()=>({data:{id:'p-me',role:'boxer',is_active:true,display_name:me,avatar_key:'avatar-03'},error:null}),single:async()=>({data:null,error:null}),then:(r)=>Promise.resolve({data:[],error:null}).then(r)};
 window.__takeoverMockClient={auth:{getSession:async()=>({data:{session:cfg.signedIn?{access_token:'x'}:null}}),getUser:async()=>({data:{user:cfg.signedIn?{id:'u1'}:null},error:null}),
  onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}})},from:()=>q,rpc,channel:()=>({on(){return this},subscribe(){return this}}),removeChannel(){}};
}
(async()=>{
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const base='http://127.0.0.1:'+server.address().port+'/';
 const browser=await chromium.launch();
 const shot=async(p,n)=>{if(process.env.SHOTS)await p.screenshot({path:process.env.SHOTS+'/'+n+'.png',fullPage:true})};
 const ctxs=[];
 async function page(cfg,file){
  const context=await browser.newContext({viewport:{width:390,height:844}});ctxs.push(context);
  await context.addInitScript({content:'('+injected.toString()+')('+JSON.stringify(cfg)+')'});
  const p=await context.newPage();const errors=[];p.on('pageerror',e=>errors.push(e.message));
  p.on('dialog',d=>{errors.push('dialog '+d.message());d.dismiss()});
  await p.route('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm',r=>r.fulfill({status:200,contentType:'text/javascript',body:'export const createClient=()=>window.__takeoverMockClient;'}));
  await p.route('https://docs.google.com/**',r=>r.fulfill({status:200,contentType:'text/javascript',body:''}));
  await p.route('https://iqarjivcrddcixrvqbfb.supabase.co/**',r=>{const u=r.request().url();
   const body=u.includes('get_public_levels')?[{boxer_name:'Anna',lifetime_exp:6000},{boxer_name:'Ben',lifetime_exp:2500},{boxer_name:'Cara',lifetime_exp:400}]
    :u.includes('get_public_leaderboard')?[{boxer_name:'Anna',rank_position:1,monthly_points:120,approved_sessions:6,points_training:100,points_bonus:20,lifetime_exp:6000},
      {boxer_name:'Ben',rank_position:2,monthly_points:90,approved_sessions:4,points_training:90,points_bonus:0,lifetime_exp:2500},{boxer_name:'Cara',rank_position:3,monthly_points:40,approved_sessions:2,points_training:40,points_bonus:0,lifetime_exp:400}]
    :u.includes('get_public_boxer_avatars')?[{boxer_name:'Anna',avatar_key:'avatar-02',avatar_url:null},{boxer_name:'Ben',avatar_key:'avatar-03',avatar_url:null}]
    :u.includes('league_public_badges_v21')?Array.from({length:8},(_,i)=>({title:'Abzeichen '+(i+1),icon_key:'x',earned_at:'2026-10-0'+(i+1)+'T10:00:00Z'}))
    :[];
   r.fulfill({status:200,contentType:'application/json',body:JSON.stringify(body)})});
  await p.goto(base+file);return {p,errors};
 }
 const noOverflow=async p=>assert.ok(await p.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth),'no horizontal scroll');

 const kgState=p=>p.evaluate(()=>({
  rows:[...document.querySelectorAll('#ranking-content .rank-row')].map(r=>{const n=r.querySelector('.rank-name');const f=r.querySelector('.tl-kg-face');
   return {name:n&&n.textContent.trim(),bn:(r.querySelector(':scope>.tl-kg-bg .kg-bn')||{}).className||'',photo:!!(f&&f.querySelector('.kg-photo img')),svg:!!(f&&f.querySelector('.kg-disc>svg')),
    src:!!r.querySelector('.tl-kg-src'),meta:(r.querySelector('.tl-kg-meta')||{}).textContent||''}})}));

 // A: Gast – Podium (Champion mit Banner und Avatar, Treppchen) und Ranking-Zeilen
 let {p,errors}=await page({signedIn:false},'index.html');
 await p.waitForSelector('#podium-content .tl-champion.tl-kg-banner .tl-kg-face .kg-ava');
 const champ=p.locator('#podium-content .tl-champion');
 assert.match(await champ.locator(':scope>.tl-kg-bg .kg-bn').getAttribute('class'),/kg-bn-ember/,'champion banner = Anna ember');
 assert.equal(await champ.locator('.tl-kg-face .kg-photo img').count(),1,'Anna has no own avatar → profile photo inside the frame');
 assert.equal(await champ.locator('.tl-kg-face .kg-aura').count()>0,true,'aura around champion');
 assert.equal(await champ.locator('.tl-kg-face .kg-rkbadge').textContent(),'D');
 assert.match(await champ.locator('.tl-kg-meta').textContent(),/Rang D · .* · Level 25/);
 assert.ok(await champ.locator('.league-champion .tl-kg-src').count()===1&&await champ.locator('.league-champion .tl-kg-src').isHidden(),'old photo hidden');
 // Treppchen: Ben mit eigenem Avatar (Figur), Banner im Sockel
 const ben=p.locator('#podium-content .tl-podium-step',{hasText:'Ben'});
 await ben.locator('.tl-kg-face .kg-disc>svg').waitFor();
 assert.equal(await ben.locator('.tl-kg-face .kg-photo').count(),0,'own avatar replaces photo');
 assert.match(await ben.locator('.tl-podium-block>.tl-kg-bg .kg-bn').getAttribute('class'),/kg-bn-moon/);
 assert.match(await ben.locator('.tl-kg-face .kg-ava').getAttribute('class'),/kg-fr-glut/);
 // Cara: kein Profilbild → Kampfgeist-Standardfigur
 const cara=p.locator('#podium-content .tl-podium-step',{hasText:'Cara'});
 assert.equal(await cara.locator('.tl-kg-face .kg-disc>svg').count(),1);
 // Titel (Etappe 11) bleibt erhalten und escaped
 assert.equal(await p.locator('.tl-podium .tl-look-title .kg-title.r-leg').first().textContent(),'<b>Der Unermüdliche</b>');
 if(process.env.SHOTS){await p.locator('.tl-podium').scrollIntoViewIfNeeded();await p.evaluate(()=>scrollBy(0,120));await p.screenshot({path:process.env.SHOTS+'/19-podium-steps.png'})}
 await shot(p,'19-podium');await noOverflow(p);
 // Ranking
 await p.click('[data-tab="ranking"]');
 await p.waitForFunction(()=>document.querySelectorAll('#ranking-content .rank-row .tl-kg-face').length>=3,{timeout:8000});
 let st=await kgState(p);
 const row=n=>st.rows.find(r=>r.name===n);
 assert.ok(/kg-bn-ember/.test(row('Anna').bn)&&row('Anna').photo&&row('Anna').src&&/^D ?Rang D · Level 25$/.test(row('Anna').meta.trim()),'Anna row '+JSON.stringify(row('Anna')));
 assert.ok(/kg-bn-moon/.test(row('Ben').bn)&&row('Ben').svg&&!row('Ben').photo&&/^E ?Rang E · Level 12$/.test(row('Ben').meta.trim()),'Ben row '+JSON.stringify(row('Ben')));
 assert.ok(/kg-bn-dojo/.test(row('Cara').bn)&&row('Cara').svg&&/^F ?Rang F · Level 3$/.test(row('Cara').meta.trim()),'Cara row');
 assert.equal((await p.evaluate(()=>window.__calls)).filter(c=>c[0]==='get_public_boxer_cards').length,1,'cards loaded once');
 // Kein doppeltes Anwenden bei erneutem Rendern
 await p.waitForTimeout(300);
 assert.equal(await p.locator('#ranking-content .rank-row .tl-kg-meta').count(),st.rows.length);
 await shot(p,'19-ranking');await noOverflow(p);
 assert.deepEqual(errors,[]);

 // B: Ohne Kartenliste (Migration fehlt / Shop aus): alles wie bisher
 ({p,errors}=await page({signedIn:false,noCards:true},'index.html'));
 await p.waitForSelector('.tl-podium [data-tl-boxer="Anna"].tl-framed');await p.waitForTimeout(400);
 assert.equal(await p.locator('.tl-kg-face,.tl-kg-bg,.tl-kg-src').count(),0,'unchanged without data');
 assert.deepEqual(errors,[]);

 // C: Boxerprofil – Kopf mit Banner, Avatar, Rang/Level; Figur neben der Spielerkarte entfällt
 ({p,errors}=await page({signedIn:true,me:'Anna'},'boxer-profile.html?name=Ben'));
 await p.waitForSelector('.hero.tl-kg-banner .tl-kg-face .kg-disc>svg');
 assert.match(await p.locator('.hero>.tl-kg-bg .kg-bn').getAttribute('class'),/kg-bn-moon/);
 assert.match(await p.textContent('.hero .tl-kg-meta'),/Rang E · .* · Level 12/);
 assert.ok(await p.locator('#profilePhoto').isHidden());
 await p.waitForSelector('.tlp-player .tlp-card');
 assert.equal(await p.locator('.tlp-player .tlp-figure').count(),0,'no duplicate figure');
 await shot(p,'19-profil-ben');await noOverflow(p);
 assert.deepEqual(errors,[]);

 // D: Mein Studio – die komplette Anzeige statt des grossen Namens
 ({p,errors}=await page({signedIn:true,me:'Ben'},'boxer.html'));
 await p.waitForSelector('.studio-identity .tl-kg-studio .kg-card',{timeout:15000});
 const card=p.locator('.tl-kg-studio .kg-card');
 assert.match(await card.textContent(),/Der Unermüdliche[\s\S]*Ben[\s\S]*Rang E · .* · Level 12/);
 assert.equal(await card.locator('.kg-bn-moon').count(),1);assert.equal(await card.locator('.kg-disc>svg').count(),1);
 assert.equal(await card.locator('b.kg-title b').count(),0,'title escaped');
 assert.ok(await p.locator('#studioBoxerName').isHidden());
 if(process.env.SHOTS)await p.locator('.studio-identity').screenshot({path:process.env.SHOTS+'/19-studio-card.png'});await shot(p,'19-studio');await noOverflow(p);
 assert.deepEqual(errors,[]);

 for(const c of ctxs)await c.close();
 await browser.close();server.close();
 console.log('PASS: Etappe 19 im Browser – Kampfgeist-Anzeige im Ranking (Banner, Avatar/Profilbild mit Aura und Rahmen, Rang und Level), auf dem Podium (Champion und Treppchen), im Boxerprofil und im Studio; eigener Avatar ersetzt das Profilbild, ohne Daten unverändert');
})().catch(e=>{console.error(e);process.exit(1)});
