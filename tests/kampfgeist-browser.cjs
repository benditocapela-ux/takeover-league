'use strict';
// Chromium test with mocked Supabase SDK (no real account, no server writes) for Kampfgeist-Shop and Level-Roadmap.
// The mocked catalogue is parsed from the real migration seed, so every item design is rendered once.
const assert=require('node:assert/strict'),fs=require('node:fs'),http=require('node:http'),path=require('node:path');
const {chromium}=require('playwright');
const root=process.cwd();
const sql=fs.readFileSync('supabase/migrations/20261028210000_kampfgeist_shop.sql','utf8');
const unq=s=>s==='NULL'?null:s.slice(1,-1).replace(/''/g,"'");
const ITEMS=[...sql.matchAll(/\('([a-z0-9_]+)','(avatar|aura|banner|rahmen|titel|handschuhe)','((?:[^']|'')*)',(NULL|'(?:[^']|'')*'),'(\w+)','([FEDCBAS])','(start|rank|shop)',(NULL|\d+),'(\{[^']*\})',(\d+)\)/g)]
 .map(m=>({key:m[1],category:m[2],name:m[3].replace(/''/g,"'"),description:unq(m[4]),rarity:m[5],min_rank:m[6],unlock:m[7],price:m[8]==='NULL'?null:+m[8],design:JSON.parse(m[9]),sort:+m[10]}));
assert.equal(ITEMS.length,114,'parsed catalogue');
const server=http.createServer((req,res)=>{
 const u=new URL(req.url,'http://127.0.0.1'),file=path.resolve(root,decodeURIComponent(u.pathname.slice(1))||'index.html');
 if(!file.startsWith(root+path.sep)){res.writeHead(403);res.end();return}
 fs.readFile(file,(err,data)=>{if(err){res.writeHead(404);res.end();return}
  const ext=path.extname(file);res.setHeader('Content-Type',ext==='.js'?'text/javascript':ext==='.html'?'text/html':ext==='.css'?'text/css':ext==='.svg'?'image/svg+xml':'application/octet-stream');res.end(data)});
});
function injected(cfg){
 const calls=[];window.__calls=calls;
 const names={boxer:'Anna',coach:'Marco',admin:'Owner'},profile={id:'p-'+cfg.role,display_name:names[cfg.role],role:cfg.role};
 const R=['F','E','D','C','B','A','S'],ri=cfg.rankIdx||0;
 let balance=cfg.balance,owned=new Set(),eq={};
 const isOwned=it=>it.unlock==='start'||(it.unlock==='rank'&&ri>=R.indexOf(it.min_rank))||owned.has(it.key);
 const def={avatar:'a_kenji',aura:'u_none',banner:'b_dojo',rahmen:'f_none',titel:'t_rookie',handschuhe:'g_rot'};
 const find=k=>cfg.items.find(i=>i.key===k);
 const look=()=>{const o={level:cfg.level,rank:R[ri]};for(const s in def)o[s]=find(eq[s]||def[s]);return o};
 const history=[{amount:100,reason:'start',note:'Startguthaben',created_at:'2026-10-28T08:00:00Z'},{amount:10,reason:'training',note:'Bestätigtes Training vom 27.10.2026',created_at:'2026-10-28T08:00:00Z'}];
 const state=full=>{const o={enabled:!cfg.off,preview:!!cfg.preview,can_buy:!cfg.preview,settings:{start_coins:100,coins_per_training:10},
   wallet:{balance,earned:240,spent:240-balance,quest_pending:0},level:{exp:cfg.exp,level:cfg.level,rank:R[ri],rank_idx:ri},look:look()};
  if(cfg.off&&cfg.role!=='admin')return {enabled:false};
  if(full){o.items=cfg.items.map(i=>Object.assign({},i,{owned:isOwned(i),rank_ok:ri>=R.indexOf(i.min_rank),is_active:true}));o.history=history}
  return o};
 const rpc=async(name,args)=>{
  calls.push([name,args]);
  switch(name){
   case 'get_my_performance':return {data:{profile,ratings_enabled:false,style_enabled:false},error:null};
   case 'get_my_kampfgeist':return {data:state(args&&args.p_full!==false),error:null};
   case 'buy_kg_item':{const it=find(args.p_item_key);if(!it||it.price>balance)return {data:null,error:{message:'Zu wenig Coins'}};
    balance-=it.price;owned.add(it.key);history.unshift({amount:-it.price,reason:'purchase',note:'Gekauft: '+it.name,created_at:new Date().toISOString()});
    return {data:{key:it.key,name:it.name,price:it.price,balance},error:null}}
   case 'equip_kg_item':eq[args.p_slot]=args.p_item_key;return {data:{look:look()},error:null};
   case 'admin_kg_overview':return {data:{enabled:!cfg.preview,settings:{start_coins:100,coins_per_training:10},
     wallets:[{id:'p-anna',display_name:'Anna',role:'boxer',balance:230,earned:240,spent:10,items:1,level:7,preview_coins:cfg.preview?240:null},
      {id:'p-admin',display_name:'Owner',role:'admin',balance:100,earned:100,spent:0,items:0,level:1,preview_coins:cfg.preview?100:null}],
     items:cfg.items.map(i=>Object.assign({},i,{is_active:true,owners:0}))},error:null};
   case 'admin_update_kg_item':{const it=find(args.p_item_key);return {data:Object.assign({},it,{price:args.p_price,min_rank:args.p_min_rank,is_active:args.p_is_active}),error:null}}
   case 'admin_adjust_coins':return {data:{profile:'Anna',amount:args.p_amount,balance:230+args.p_amount},error:null};
   case 'get_kg_look':return {data:Object.assign(look(),{name:'Anna'},{titel:find('t_unerm'),avatar:find('a_nia'),aura:find('u_kirsch'),banner:find('b_sakura'),rahmen:find('f_kirsch')}),error:null};
   case 'get_performance_card':return {data:null,error:null};
   case 'get_my_week_plan':case 'get_my_quests':return {data:{enabled:false},error:null};
   case 'admin_update_kg_settings':return {data:{start_coins:args.p_start_coins,coins_per_training:args.p_coins_per_training},error:null};
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
 const shots=process.env.KG_SHOTS||'';
 async function open(cfg,file){
  const context=await browser.newContext({viewport:{width:390,height:844},reducedMotion:'reduce'});
  await context.addInitScript({content:'('+injected.toString()+')('+JSON.stringify(Object.assign({items:ITEMS,balance:230,exp:1010,level:7,rankIdx:0},cfg))+')'});
  const p=await context.newPage();const errors=[];p.on('pageerror',e=>errors.push(e.message));p.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
  await p.route('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm',r=>r.fulfill({status:200,contentType:'text/javascript',body:'export const createClient=()=>window.__takeoverMockClient;'}));
  await p.route('https://iqarjivcrddcixrvqbfb.supabase.co/**',r=>{const u=r.request().url();
   const body=u.includes('get_public_levels')?[{boxer_name:'Anna',lifetime_exp:2600}]:u.includes('get_public_leaderboard')?[{boxer_name:'Anna',rank_position:1,monthly_points:100,approved_sessions:4,points_training:100,points_bonus:0}]:[];
   r.fulfill({status:200,contentType:'application/json',body:JSON.stringify(body)})});
  await p.goto(base+file);
  return {p,errors,context};
 }
 const calls=p=>p.evaluate(()=>window.__calls);
 const shot=async(p,n,full)=>{if(shots)await p.screenshot({path:path.join(shots,n+'.png'),fullPage:!!full})};
 const done=async({p,errors,context})=>{assert.ok(await p.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth),'no horizontal scroll');assert.deepEqual(errors.filter(e=>!/favicon|404/.test(e)),[]);await context.close()};

 // Boxer: Shop ansehen, kaufen, ausrüsten
 let x=await open({role:'boxer'},'shop.html');
 await x.p.waitForSelector('.kg-item');
 let t=await x.p.textContent('#app');
 assert.match(t,/230/);assert.match(t,/Rang F/);assert.match(t,/Level 7/);
 assert.equal(await x.p.locator('.kg-rankhead').count(),7,'7 rank sections');
 assert.equal(await x.p.locator('.kg-item').count(),93,'all 93 shop items');
 assert.equal(await x.p.locator('.kg-item .kg-disc svg').count()>=40,true,'avatars drawn');
 await shot(x.p,'kg-shop',true);
 await x.p.click('[data-cat="avatar"]');assert.equal(await x.p.locator('.kg-item').count(),23);
 await x.p.click('[data-item="a_tomas"]');
 t=await x.p.textContent('#layer');assert.match(t,/Erst ab Rang E/);assert.equal(await x.p.locator('[data-buy]').count(),0,'locked: no buy');
 await x.p.click('#layer button[data-close]');
 await x.p.click('[data-item="a_lina"]');await x.p.waitForSelector('[data-buy="a_lina"]');
 await shot(x.p,'kg-sheet');
 await x.p.click('[data-buy="a_lina"]');
 await x.p.waitForSelector('[data-equip="a_lina"]');
 assert.match(await x.p.textContent('#status'),/Gekauft: Lina/);assert.match(await x.p.textContent('#app'),/30/);
 await x.p.click('[data-equip="a_lina"]');
 await x.p.waitForFunction(()=>window.__calls.some(c=>c[0]==='equip_kg_item'&&c[1].p_slot==='avatar'&&c[1].p_item_key==='a_lina'));
 await x.p.click('[data-cat="aura"]');await x.p.click('[data-item="u_glut"]');
 assert.match(await x.p.textContent('#layer'),/Dir fehlen noch/);assert.equal(await x.p.locator('[data-buy]').count(),0);
 await x.p.keyboard.press('Escape');
 await x.p.click('[data-tab="inv"]');await x.p.waitForSelector('.kg-slot');
 assert.equal(await x.p.locator('.kg-slot').count(),8);assert.ok(await x.p.locator('.kg-item.equipped').count()>=6,'equipped marked');
 assert.match(await x.p.textContent('#app'),/Belohnung Rang E/);
 await shot(x.p,'kg-inventar',true);
 await x.p.click('[data-tab="coins"]');t=await x.p.textContent('#app');assert.match(t,/Startguthaben/);assert.match(t,/Gekauft: Lina/);assert.match(t,/keine Zufallsboxen/);
 assert.equal(await x.p.locator('[data-tab="admin"]').count(),0,'boxer has no admin tab');
 await done(x);

 // Flag aus für Boxer
 x=await open({role:'boxer',off:true},'shop.html');
 await x.p.waitForFunction(()=>/noch nicht freigeschaltet/.test(document.getElementById('app').textContent));
 await done(x);
 x=await open({role:'boxer',off:true},'roadmap.html');
 await x.p.waitForFunction(()=>/Geduld/.test(document.getElementById('app').textContent));
 await done(x);

 // Admin (Vorschau): Kaufen gesperrt, Verwaltung mit Konten, Regeln, Items
 x=await open({role:'admin',preview:true,balance:100,exp:0,level:1},'shop.html');
 await x.p.waitForSelector('.tlp-callout');
 await x.p.click('[data-item="t_frueh"]');assert.match(await x.p.textContent('#layer'),/nach dem Freischalten/);assert.equal(await x.p.locator('[data-buy]').count(),0);
 await x.p.keyboard.press('Escape');
 await x.p.click('[data-tab="admin"]');await x.p.waitForFunction(()=>/Start/.test(document.getElementById('app').textContent)&&/Anna/.test(document.getElementById('app').textContent));
 assert.equal(await x.p.locator('form.kg-adjust').count(),0,'no adjust in preview');
 await x.p.click('[data-atab="items"]');await x.p.waitForSelector('form.kg-aitem[data-key="a_lina"]');
 await x.p.fill('form.kg-aitem[data-key="a_lina"] [name="price"]','180');
 await x.p.click('form.kg-aitem[data-key="a_lina"] button[type="submit"]');
 await x.p.waitForFunction(()=>window.__calls.some(c=>c[0]==='admin_update_kg_item'));
 const up=(await calls(x.p)).find(c=>c[0]==='admin_update_kg_item')[1];
 assert.deepEqual(up,{p_item_key:'a_lina',p_price:180,p_min_rank:'F',p_is_active:true});
 await shot(x.p,'kg-admin-items');
 await x.p.click('[data-atab="regeln"]');await x.p.fill('#rulesForm [name="per"]','12');await x.p.click('#rulesForm button[type="submit"]');
 await x.p.waitForFunction(()=>window.__calls.some(c=>c[0]==='admin_update_kg_settings'&&c[1].p_coins_per_training===12));
 await done(x);

 // Admin (Shop an): Coins buchen
 x=await open({role:'admin'},'shop.html');
 await x.p.waitForSelector('[data-tab="admin"]');await x.p.click('[data-tab="admin"]');
 await x.p.waitForSelector('form.kg-adjust[data-id="p-anna"]');
 assert.equal(await x.p.locator('form.kg-adjust[data-id="p-admin"]').count(),0,'admin cannot book own coins');
 await x.p.fill('form.kg-adjust[data-id="p-anna"] [name="amount"]','50');await x.p.fill('form.kg-adjust[data-id="p-anna"] [name="note"]','Turnier-Helferin');
 await x.p.click('form.kg-adjust[data-id="p-anna"] button[type="submit"]');
 await x.p.waitForFunction(()=>/Gebucht: 50 Coins für Anna/.test(document.getElementById('status').textContent));
 await done(x);

 // Roadmap: 99 Levels, 7 Ränge, Stand
 x=await open({role:'boxer',exp:2600,level:12,rankIdx:1},'roadmap.html');
 await x.p.waitForSelector('.kg-step');
 assert.equal(await x.p.locator('.kg-step').count(),7);
 t=await x.p.textContent('#app');
 assert.match(t,/99 Levels/);assert.match(t,/Level 12/);assert.match(t,/ab 2’125 EXP|ab 2'125 EXP/);assert.match(t,/Level 61–99/);assert.match(t,/ab 128’625 EXP|ab 128'625 EXP/);
 assert.equal(await x.p.locator('.kg-step.now').count(),1);assert.match(await x.p.locator('.kg-step.now').textContent(),/Prospect/);
 assert.equal(await x.p.locator('.kg-step').nth(6).locator('.kg-levels i').count(),39,'S = Level 61–99');
 await shot(x.p,'kg-roadmap',true);
 await done(x);

 // Boxerprofil: Kampfgeist-Karte (nur angemeldet), Mein Studio: Shop-Kachel
 x=await open({role:'boxer'},'boxer-profile.html?name=Anna');
 // Etappe 11: Kampfgeist-Figur (Avatar mit Aura und Rahmen) neben der Spielerkarte; Titel steht beim Namen oben im Profil
 await x.p.waitForSelector('.tlp-profile .tlp-figure .kg-ava');
 assert.ok((await calls(x.p)).some(c=>c[0]==='get_kg_look'&&c[1].p_display_name==='Anna'));
 await x.p.locator('.tlp-profile .tlp-figure').scrollIntoViewIfNeeded();await shot(x.p,'kg-profile');
 assert.ok(await x.p.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth),'no horizontal scroll on profile');
 await x.context.close();
 x=await open({role:'boxer'},'boxer.html');
 await x.p.waitForSelector('.tlp-tile[href="./shop.html"]',{timeout:15000});
 t=await x.p.textContent('.tlp-tile[href="./shop.html"]');assert.match(t,/230/);assert.match(t,/Rang F/);
 assert.ok((await calls(x.p)).some(c=>c[0]==='get_my_kampfgeist'&&c[1]&&c[1].p_full===false),'studio uses light request');
 await shot(x.p,'kg-studio');
 await x.context.close();

 await browser.close();server.close();
 console.log('PASS: Kampfgeist-Shop im Browser – 93 Items in 7 Rängen, Kaufen/Ausrüsten, Rang-Sperre, zu wenig Coins, Inventar, Verlauf, Flag aus, Admin-Vorschau/Items/Regeln/Coins buchen, Level-Roadmap 99 Levels, Profilkarte, Studio-Kachel');
})().catch(e=>{console.error(e);process.exit(1)});
