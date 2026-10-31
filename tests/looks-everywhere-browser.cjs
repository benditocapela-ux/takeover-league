'use strict';
// Chromium test with mocked Supabase (no real account, no server writes) for Etappe 11:
// Rahmen und Titel um jedes Profilbild (Rangliste, Podium, Level-Liste, Profil, Studio) auch für Gäste,
// FUT-Karten der Top 3 auf dem Podium (angemeldet), Boxerprofil übersichtlich ohne Leistungsprofil-Diagramm,
// Vergleichen-Knöpfe (fremdes Profil, eigenes Profil, eigene Karte in der Bewertung).
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
 const rating=o=>({categories:{OFF:o,DEF:o,BEI:o,KON:o,TAK:o,MEN:o},overall:o,scale:20,top:[{k:'jab',v:16}],low:[{k:'slip',v:8}],rated_at:'2026-10-20T10:00:00Z',delta:2});
 const rated={Anna:72,Ben:65,Cara:58};
 const rpc=async(name,args)=>{
  calls.push([name,args]);
  if(name==='get_public_boxer_looks')return {data:looks,error:null};
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
  maybeSingle:async()=>({data:{id:'p-me',role:cfg.studioRole||'boxer',is_active:true,display_name:me,avatar_key:'avatar-03'},error:null}),single:async()=>({data:null,error:null}),then:(r)=>Promise.resolve({data:[],error:null}).then(r)};
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

 // A: Liga-Seite als Gast – Rahmen und Titel auf Podium und Rangliste, keine FUT-Karten
 let {p,errors}=await page({signedIn:false},'index.html');
 await p.waitForSelector('.tl-podium [data-tl-boxer="Anna"].tl-framed');
 const anna=p.locator('.tl-podium [data-tl-boxer="Anna"]');
 assert.match(await anna.getAttribute('class'),/kg-fr-rank/);assert.equal(await anna.locator('.kg-rkbadge').textContent(),'D');
 assert.match(await p.locator('.tl-podium [data-tl-boxer="Ben"]').getAttribute('class'),/kg-fr-glut/);
 assert.doesNotMatch(await p.locator('.tl-podium [data-tl-boxer="Cara"]').getAttribute('class'),/tl-framed/,'no frame without frame');
 assert.equal(await p.locator('.tl-podium .tl-look-title .kg-title.r-rare').first().textContent(),'Contender');
 assert.equal(await p.locator('.tl-podium .tl-look-title .kg-title.r-leg').first().textContent(),'<b>Der Unermüdliche</b>','title escaped');
 assert.equal(await p.locator('.tl-podium .tl-look-title b').count(),0);
 assert.equal(await p.locator('.tlp-podium-cards').count(),0,'guests see no FUT cards');
 await shot(p,'11-index-gast');await noOverflow(p);
 // Rangliste und Level-Liste
 await p.evaluate(()=>{const b=[...document.querySelectorAll('button,a')].find(x=>/^(Rangliste|Ranking)$/i.test(x.textContent.trim())&&x.closest('nav,.tabs,.bottom,header,main'));if(b)b.click()});
 await p.waitForFunction(()=>document.querySelectorAll('.rank-row [data-tl-boxer].tl-framed').length>=2,{timeout:8000}).catch(()=>{});
 const rowsFramed=await p.evaluate(()=>[...document.querySelectorAll('.rank-row [data-tl-boxer]')].map(x=>[x.dataset.tlBoxer,x.classList.contains('tl-framed'),!!x.parentElement.querySelector('.tl-look-title')]));
 const annaRows=rowsFramed.filter(r=>r[0]==='Anna'),caraRows=rowsFramed.filter(r=>r[0]==='Cara');
 assert.ok(annaRows.length>=2&&annaRows.every(r=>r[1]&&r[2]),'ranking and level rows: Anna framed with title '+JSON.stringify(rowsFramed));
 assert.ok(caraRows.length>=2&&caraRows.every(r=>!r[1]&&!r[2]),'Cara without frame and title');
 assert.ok((await p.evaluate(()=>window.__calls)).filter(c=>c[0]==='get_public_boxer_looks').length===1,'looks loaded once');
 assert.deepEqual(errors,[]);

 // B: angemeldet – FUT-Karten der Top 3 auf dem Podium, verlinkt aufs Profil
 ({p,errors}=await page({signedIn:true},'index.html#podium'));
 await p.waitForSelector('.tlp-podium-cards .tlp-podium-card .tlp-card');
 assert.equal(await p.locator('.tlp-podium-card').count(),3);
 assert.deepEqual(await p.$$eval('.tlp-podium-card',a=>a.map(x=>[x.className,x.getAttribute('href')])),
  [['tlp-podium-card p1','./boxer-profile.html?name=Anna'],['tlp-podium-card p2','./boxer-profile.html?name=Ben'],['tlp-podium-card p3','./boxer-profile.html?name=Cara']]);
 assert.match(await p.textContent('.tlp-podium-card.p1'),/Platz 1[\s\S]*72/);
 await p.locator('.tlp-podium-cards').scrollIntoViewIfNeeded();await shot(p,'11-podium-karten');await noOverflow(p);
 assert.deepEqual(errors,[]);

 // C: fremdes Profil – Rahmen und Titel oben, Spielerkarte mit Figur, Vergleichen auf mich ausgerichtet, kein Diagramm
 ({p,errors}=await page({signedIn:true,me:'Ben'},'boxer-profile.html?name=Anna'));
 await p.waitForSelector('.tlp-player .tlp-card');
 assert.ok(await p.locator('#sportProfile').isHidden(),'Leistungsprofil-Diagramm ausgeblendet');
 await p.waitForSelector('#profilePhoto.tl-framed.kg-fr-rank');
 assert.equal(await p.locator('#profilePhoto .kg-rkbadge').textContent(),'D');
 assert.equal(await p.locator('#profileName + .tl-look-title .kg-title').textContent(),'Contender');
 assert.equal(await p.locator('.tlp-player .tlp-figure .kg-ava').count(),1,'Kampfgeist figure next to the card');
 const player=await p.textContent('.tlp-player');
 assert.match(player,/Spielerkarte[\s\S]*Gesamt[\s\S]*72[\s\S]*Stärken[\s\S]*Jab[\s\S]*Daran arbeiten[\s\S]*Ausweichen/);
 assert.match(await p.textContent('.tlp-style-det summary'),/Boxstil/);
 assert.equal(await p.locator('.tlp-style-det[open]').count(),0,'Boxstil starts closed');
 assert.equal(await p.getAttribute('.tlp-compare-btn','href'),'./boxer-compare.html?left=Ben&right=Anna');
 assert.equal(await p.textContent('.tlp-compare-btn'),'Karten & Boxstil vergleichen');
 assert.equal(await p.getAttribute('#compareAction','href'),'./boxer-compare.html?left=Ben&right=Anna');
 assert.ok(await p.locator('#compareAction').isHidden(),'kleiner Vergleichen-Knopf weicht dem grossen');assert.ok(await p.locator('#duelAction').isVisible());
 // Reihenfolge: Kopf, Spielerkarte, Aktionen, dann Rekorde/Auszeichnungen
 const order=await p.evaluate(()=>['.hero','.tlp-profile','.actions','#publicRecords','#publicBadges'].map(s=>Number(getComputedStyle(document.querySelector('#profileCard>'+s)).order)));
 assert.deepEqual(order,[2,6,7,8,9]);
 await p.waitForSelector('.badge-more');
 assert.equal(await p.locator('#publicBadgeGrid .badge-tile:visible').count(),6);
 await p.click('.badge-more');assert.equal(await p.locator('#publicBadgeGrid .badge-tile:visible').count(),8);
 await shot(p,'11-profil-anna');await noOverflow(p);
 assert.deepEqual(errors,[]);

 // D: eigenes Profil – «Meine Karte & Boxstil vergleichen»
 ({p,errors}=await page({signedIn:true,me:'Ben'},'boxer-profile.html?name=Ben'));
 await p.waitForSelector('.tlp-compare-btn');
 assert.equal(await p.getAttribute('.tlp-compare-btn','href'),'./boxer-compare.html?left=Ben');
 assert.equal(await p.textContent('.tlp-compare-btn'),'Meine Karte & Boxstil vergleichen');
 await p.waitForSelector('#profilePhoto.tl-framed.kg-fr-glut');
 assert.deepEqual(errors,[]);

 // E: Gast im Profil – Rahmen ja, Spielerkarte nein
 ({p,errors}=await page({signedIn:false},'boxer-profile.html?name=Anna'));
 await p.waitForSelector('#profilePhoto.tl-framed.kg-fr-rank');
 await p.waitForTimeout(300);
 assert.equal(await p.locator('.tlp-profile').count(),0);
 assert.deepEqual(errors,[]);

 // F: eigene Karte in der Bewertung – Vergleichen
 ({p,errors}=await page({signedIn:true,me:'Ben'},'bewertung.html'));
 await p.waitForSelector('.tlp-compare-btn');
 assert.equal(await p.getAttribute('.tlp-compare-btn','href'),'./boxer-compare.html?left=Ben');
 assert.deepEqual(errors,[]);

 // G: Mein Studio – eigenes Profilbild mit Rahmen, Titel beim Namen
 ({p,errors}=await page({signedIn:true,me:'Ben',studioRole:'coach'},'boxer.html')); // Takeover 3.0: boxer.html bleibt die Trainingsseite für Trainer; Boxer nutzen Mein Takeover
 await p.waitForSelector('#avatarPreview.tl-framed.kg-fr-glut',{state:'attached',timeout:15000});
 assert.equal(await p.locator('#profileName + .tl-look-title .kg-title').textContent(),'<b>Der Unermüdliche</b>');

 for(const c of ctxs)await c.close();
 await browser.close();server.close();
 console.log('PASS: Etappe 11 im Browser – Rahmen und Titel auf Podium, Rangliste, Profil und Studio (auch Gäste, escaped), FUT-Karten der Top 3 auf dem Podium, Profil geordnet ohne Leistungsprofil-Diagramm, Vergleichen im fremden und eigenen Profil und in der Bewertung');
})().catch(e=>{console.error(e);process.exit(1)});
