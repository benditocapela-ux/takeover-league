'use strict';
// Real Chromium test with mocked Supabase SDK for Etappe 9 (Boxer-Holo): body and clothing choices, hood and coat
// toggles, try-on of locked items, buying item and bundle with confirmation, poses for profile and card, saving,
// flag off, holo on the profile and on the FUT card, no horizontal scroll on a phone.
const assert=require('node:assert/strict'),fs=require('node:fs'),http=require('node:http'),path=require('node:path');
const {chromium}=require('playwright');
const root=process.cwd();
const sql=fs.readFileSync('supabase/migrations/20261029140000_boxer_holo.sql','utf8');
const ins=sql.slice(sql.indexOf('INSERT INTO public.holo_items'),sql.indexOf('ON CONFLICT (key) DO NOTHING;'));
const ITEMS=[...ins.matchAll(/\('([a-z_]+)','([a-z]+)','((?:[^']|'')*)','([a-z]+)','([a-z]+)',(NULL|\d+),(NULL|'(\{[^']*\})'),(\d+)\)/g)].map(m=>{
 const r=m[8]?JSON.parse(m[8]):null;
 return {key:m[1],slot:m[2],value:m[1].slice(m[2].length+1),name:m[3].replace(/''/g,"'"),rarity:m[4],unlock:m[5],price:m[6]==='NULL'?null:+m[6],
  reward:r?(r.type==='level'?'Ab Level '+r.min:r.type==='rank'?'Ab Rang '+r.min:r.type==='duel_win'?'Erster Duellsieg':'Card of the Week'):null};
});
assert.equal(ITEMS.length,58,'parsed holo catalogue');
assert.equal(ITEMS.filter(i=>i.slot==='hair').length,18);
const server=http.createServer((req,res)=>{
 const u=new URL(req.url,'http://127.0.0.1');
 if(u.pathname==='/news.json'){res.setHeader('Content-Type','application/json');res.end('{"entries":[]}');return}
 const file=path.resolve(root,decodeURIComponent(u.pathname.slice(1))||'index.html');
 if(!file.startsWith(root+path.sep)){res.writeHead(403);res.end();return}
 fs.readFile(file,(err,data)=>{if(err){res.writeHead(404);res.end();return}
  const ext=path.extname(file);res.setHeader('Content-Type',ext==='.js'?'text/javascript':ext==='.html'?'text/html':ext==='.css'?'text/css':ext==='.svg'?'image/svg+xml':'application/octet-stream');res.end(data)});
});
function injected(cfg){
 const calls=[];window.__calls=calls;
 const items=cfg.items.map(i=>Object.assign({},i,{owned:i.unlock==='start'||(i.unlock==='reward'&&i.key==='pose_flex')}));
 const bundles=[{key:'drachen_bundle',name:'Drachen-Bundle',description:'Drachen-Mantel, Flammen-Aura, Glut-Augen und die Pose Ansage.',price:3400,items:['coat_drache','aura_flamme','eyefx_glut','pose_ansage'],value:4700,owned_all:false}];
 let coins=cfg.coins??5000,saved=cfg.saved||null;
 const DEF={tone:2,hair:'kurz_glatt',hc:'schwarz',eye:'braun',eyefx:'none',head:'none',headc:'schwarz',top:'none',hood:false,topc:'grau',bottom:'boxer',bottomc:'rot',hands:'wraps',glove:'rot',feet:'boots',feetc:'weiss',coat:'none',aura:'none',scene:'holo',pose_profile:'guard',pose_card:'guard'};
 const rating={categories:{OFF:75,DEF:63,BEI:70,KON:70,TAK:70,MEN:70},overall:72,scale:20,top:[],low:[],rated_at:'2026-10-20T10:00:00Z',delta:0};
 const annaHolo=Object.assign({},DEF,{hair:'afro',tone:6,top:'hoodie',hood:false,topc:'lila',coat:'basic',pose_profile:'sieg',pose_card:'jab',scene:'dojo'});
 const rpc=async(name,args)=>{
  calls.push([name,args]);
  if(name==='get_my_holo')return {data:cfg.off?{enabled:false}:{enabled:true,preview:false,shop:true,display_name:'Ben',coins,saved:!!saved,config:Object.assign({},DEF,saved||{}),items:items.map(i=>Object.assign({},i)),
   bundles:bundles.map(b=>Object.assign({},b,{owned_all:b.items.every(k=>items.find(i=>i.key===k).owned)}))},error:null};
  if(name==='save_my_holo'){const c=Object.assign({},DEF,args.p_config);for(const s of ['coat','aura','eyefx','scene']){const it=items.find(i=>i.slot===s&&i.value===c[s]);if(c[s]!=='none'&&it&&!it.owned)return {data:null,error:{message:'«'+it.name+'» ist für dich noch nicht freigeschaltet'}}}
   saved=c;return {data:c,error:null}}
  if(name==='buy_holo_item'){const it=items.find(i=>i.key===args.p_key);if(coins<it.price)return {data:null,error:{message:'Zu wenig Coins'}};coins-=it.price;it.owned=true;return {data:{key:it.key,name:it.name,price:it.price,balance:coins},error:null}}
  if(name==='buy_holo_bundle'){const b=bundles.find(x=>x.key===args.p_key);coins-=b.price;b.items.forEach(k=>{items.find(i=>i.key===k).owned=true});return {data:{key:b.key,name:b.name,price:b.price,new_items:4,balance:coins},error:null}}
  if(name==='get_my_performance')return {data:{profile:{id:'p-me',display_name:'Ben',role:'boxer'},ratings_enabled:true,style_enabled:false,rating:{current:{scores:{},scale:20,summary:rating,created_at:'2026-10-20T10:00:00Z',note:null,rated_by:'Marco'},previous:null},style:null},error:null};
  if(name==='get_holo_looks'){const o={};for(const n of args.p_display_names){if(n==='Anna')o.Anna=annaHolo;if(n==='Ben'&&saved)o.Ben=saved}return {data:o,error:null}}
  if(name==='get_card_looks')return {data:{},error:null};
  if(name==='get_performance_card')return {data:{display_name:args.p_display_name,is_me:false,rating,style:null},error:null};
  if(name==='get_kg_look')return {data:null,error:null};
  return {data:null,error:{message:'unexpected rpc '+name}};
 };
 const q={select(){return q},eq(){return q},order(){return q},limit(){return q},in(){return q},gte(){return q},lte(){return q},maybeSingle:async()=>({data:{role:'boxer',is_active:true,display_name:'Ben'},error:null}),then:r=>Promise.resolve({data:[],error:null}).then(r)};
 window.__takeoverMockClient={auth:{getSession:async()=>({data:{session:{access_token:'x'}}}),getUser:async()=>({data:{user:{id:'u1'}},error:null}),onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}})},from:()=>q,rpc};
}
(async()=>{
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const base='http://127.0.0.1:'+server.address().port+'/';
 const browser=await chromium.launch();
 const shot=async(p,n,full)=>{if(process.env.SHOTS)await p.screenshot({path:process.env.SHOTS+'/'+n+'.png',fullPage:full!==false})};
 async function page(cfg){
  const context=await browser.newContext({viewport:{width:390,height:844},reducedMotion:'reduce'});
  await context.addInitScript({content:'('+injected.toString()+')('+JSON.stringify(Object.assign({items:ITEMS},cfg))+')'});
  const p=await context.newPage();const errors=[];p.on('pageerror',e=>errors.push(e.message));
  await p.route('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm',r=>r.fulfill({status:200,contentType:'text/javascript',body:'export const createClient=()=>window.__takeoverMockClient;'}));
  await p.route('https://iqarjivcrddcixrvqbfb.supabase.co/**',r=>{const u=r.request().url();
   const body=u.includes('get_public_levels')?[{boxer_name:'Anna',lifetime_exp:500},{boxer_name:'Ben',lifetime_exp:300}]:u.includes('get_public_leaderboard')?[{boxer_name:'Anna',rank_position:1,monthly_points:100,approved_sessions:4,points_training:100,points_bonus:0},{boxer_name:'Ben',rank_position:2,monthly_points:80,approved_sessions:3,points_training:80,points_bonus:0}]:[];
   r.fulfill({status:200,contentType:'application/json',body:JSON.stringify(body)})});
  return {p,errors,context};
 }
 const noScroll=async p=>assert.ok(await p.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth+1),'no horizontal scroll');
 const calls=p=>p.evaluate(()=>window.__calls);
 const done=async x=>{await noScroll(x.p);assert.deepEqual(x.errors,[]);await x.context.close()};

 // Körper und Kleidung, Kapuze, Mantel, Speichern
 let x=await page({});
 await x.p.goto(base+'mein-boxer.html');
 await x.p.waitForSelector('.mb-preview svg.tlh');
 // The complete SVG must fit inside the fixed stage; the previous build
 // overflowed behind the save actions and only showed the upper body.
 const previewGeometry=await x.p.evaluate(()=>{
  const preview=document.querySelector('.mb-preview');
  const figure=preview.querySelector('svg.tlh');
  const p=preview.getBoundingClientRect(),r=figure.getBoundingClientRect();
  return {top:r.top-p.top,bottom:p.bottom-r.bottom,left:r.left-p.left,right:p.right-r.right,
   height:r.height,viewport:p.height,svgOverflow:getComputedStyle(figure).overflow,
   statusHidden:document.getElementById('status').hidden};
 });
 assert.ok(previewGeometry.viewport>100,'fixed preview has room for boxer');
 assert.ok(previewGeometry.top>=-1&&previewGeometry.bottom>=-1,
  'boxer must fit vertically inside preview: '+JSON.stringify(previewGeometry));
 assert.ok(previewGeometry.left>=-1&&previewGeometry.right>=-1,
  'boxer must fit horizontally inside preview: '+JSON.stringify(previewGeometry));
 assert.equal(previewGeometry.svgOverflow,'hidden','mobile preview clips SVG to full figure viewbox');
 assert.ok(previewGeometry.statusHidden,'initial status toast must not obscure equipment');

 assert.equal(await x.p.locator('[data-set="hair"]').count(),18,'18 hair styles');
 for(const h of ['Afro','Locs','Box Braids','Cornrows','Twists','Afro-Puffs','Locken','Glatze'])assert.ok(await x.p.locator('[data-set="hair"]',{hasText:h}).count(),h);
 assert.equal(await x.p.locator('[data-set="tone"]').count(),8,'8 skin tones');
 assert.equal(await x.p.locator('[data-set="eye"]').count(),8,'8 eye colours');
 assert.ok(await x.p.isDisabled('#saveBtn'),'nothing to save yet');
 await x.p.click('[data-set="hair"][data-val="locs"]');await x.p.click('[data-set="tone"][data-val="6"]');await x.p.click('[data-set="hc"][data-val="dunkelbraun"]');
 await shot(x.p,'holo-koerper');
 await x.p.click('[data-tab="kleidung"]');
 // Die sichtbaren Itembilder stammen aus exakt demselben SVG-Renderer wie die Boxerfigur.
 assert.equal(await x.p.locator('[data-set="head"] .mb-gear-art svg.mb-item-svg').count(),4,'Kopfbedeckungen mit eigenständigen SVG-Items');
 assert.equal(await x.p.locator('[data-set="top"] .mb-gear-art svg.mb-item-svg').count(),5,'Oberteile als auswählbare SVG-Items');
 assert.equal(await x.p.locator('[data-set="bottom"] .mb-gear-art svg.mb-item-svg').count(),4,'Shorts und Hosen als eigenständige Bilder');
 assert.equal(await x.p.locator('[data-set="coatPick"] .mb-gear-art svg.mb-item-svg').count()>0,true,'Mantel als echtes Itembild');
 const stageBefore=await x.p.locator('.mb-preview svg.tlh').first().evaluate(el=>el.outerHTML);
 // Mobile PWA: the character stays fixed even while the equipment list scrolls.
 const fixedStage=await x.p.evaluate(()=>{
  const stage=document.querySelector('.mb-stage'),list=document.querySelector('.mb-tabbody');
  const first=stage.getBoundingClientRect().top;
  list.scrollTop=180;
  return {first,second:stage.getBoundingClientRect().top,scroll:list.scrollTop,overflow:getComputedStyle(list).overflowY};
 });
 assert.equal(fixedStage.overflow,'auto','equipment editor must scroll independently');
 assert.ok(fixedStage.scroll>40,'equipment editor has real scrolling content');
 assert.ok(Math.abs(fixedStage.second-fixedStage.first)<1,'boxer remains stationary while clothes scroll');
 await shot(x.p,'holo-kleidung-scroll');


 assert.equal(await x.p.locator('[data-toggle="hood"]').count(),0,'no hood toggle without hoodie');
 await x.p.click('[data-set="top"][data-val="hoodie"]');
 assert.notEqual(await x.p.locator('.mb-preview svg.tlh').first().evaluate(el=>el.outerHTML),stageBefore,'Gear selection updates the full boxer');
 assert.equal(await x.p.locator('[data-set="top"][data-val="hoodie"]').getAttribute('aria-pressed'),'true');

 await x.p.click('[data-toggle="hood"]');assert.equal(await x.p.getAttribute('[data-toggle="hood"]','aria-pressed'),'true');
 await x.p.click('[data-set="bottom"][data-val="jogger"]');await x.p.click('[data-set="feet"][data-val="sneaker"]');
 await x.p.click('[data-set="hands"][data-val="gloves"]');
 assert.ok(await x.p.locator('[data-set="glove"][data-val="eisblau"] .mb-lock').count(),'shop glove locked');
 await x.p.click('[data-set="head"][data-val="hijab"]');await x.p.click('[data-set="headc"][data-val="lila"]');
 await x.p.click('[data-toggle="coat"]');assert.equal(await x.p.getAttribute('[data-toggle="coat"]','aria-pressed'),'true');
 await x.p.click('[data-toggle="coat"]');assert.equal(await x.p.getAttribute('[data-toggle="coat"]','aria-pressed'),'false');
 await shot(x.p,'holo-kleidung');
 await x.p.click('#saveBtn');
 await x.p.waitForFunction(()=>window.__calls.some(c=>c[0]==='save_my_holo'));
 let saved=(await calls(x.p)).find(c=>c[0]==='save_my_holo')[1].p_config;
 assert.equal(saved.hair,'locs');assert.equal(saved.tone,6);assert.equal(saved.top,'hoodie');assert.equal(saved.hood,true);assert.equal(saved.head,'hijab');assert.equal(saved.coat,'none');assert.equal(saved.hands,'gloves');
 await x.p.waitForSelector('#saveBtn:disabled');
 assert.match(await x.p.textContent('#status'),/Gespeichert/);

 // Anprobe gesperrter Aura, dann kaufen mit Bestätigung
 await x.p.click('[data-tab="extras"]');
 await x.p.click('[data-set="aura"][data-val="flamme"]');
 await x.p.waitForSelector('.mb-tryon');assert.match(await x.p.textContent('.mb-tryon'),/Flamme/);
 assert.ok(await x.p.isDisabled('#saveBtn'),'locked item blocks saving');
 await shot(x.p,'holo-anprobe',false);
 await x.p.click('.mb-tryon [data-tab="shop"]');
 assert.ok(await x.p.locator('.mb-shop-item-art svg.tlh').count()>0,'Holo-Shop items have real gear thumbnails');
 await x.p.click('[data-buy-item="aura_flamme"]');
 await x.p.waitForSelector('[data-buy-item="aura_flamme"][data-confirm]');
 assert.ok(!(await calls(x.p)).some(c=>c[0]==='buy_holo_item'),'no purchase before confirm');
 await x.p.click('[data-buy-item="aura_flamme"][data-confirm]');
 await x.p.waitForFunction(()=>window.__calls.some(c=>c[0]==='buy_holo_item'&&c[1].p_key==='aura_flamme'));
 await x.p.waitForFunction(()=>!document.querySelector('.mb-tryon'));
 assert.match(await x.p.textContent('#status'),/Gekauft: Flamme/);
 assert.ok(!(await x.p.isDisabled('#saveBtn')),'can save after buying');
 // Bundle anprobieren und kaufen
 await x.p.click('[data-try-bundle="drachen_bundle"]');
 await x.p.waitForSelector('.mb-tryon');assert.match(await x.p.textContent('.mb-tryon'),/Drachen-Mantel/);
 await x.p.click('[data-buy-bundle="drachen_bundle"]');await x.p.click('[data-buy-bundle="drachen_bundle"][data-confirm]');
 await x.p.waitForFunction(()=>window.__calls.some(c=>c[0]==='buy_holo_bundle'));
 await x.p.waitForFunction(()=>!document.querySelector('.mb-tryon'));
 await shot(x.p,'holo-shop');
 // Posen für Profil und Karte; Karte zeigt den Holo
 await x.p.click('[data-tab="posen"]');
 await x.p.click('[data-set="pose_card"][data-val="flex"]');
 assert.match(await x.p.textContent('.mb-stage-bar'),/Karten-Pose/);
 await x.p.waitForSelector('.mb-cardprev .tlp-card .tlp-holo svg.tlh');
 await x.p.click('[data-set="pose_profile"][data-val="ansage"]');
 await shot(x.p,'holo-posen');
 await x.p.click('#saveBtn');
 await x.p.waitForFunction(()=>window.__calls.filter(c=>c[0]==='save_my_holo').length===2);
 saved=(await calls(x.p)).filter(c=>c[0]==='save_my_holo')[1][1].p_config;
 assert.equal(saved.aura,'flamme');assert.equal(saved.coat,'drache');assert.equal(saved.pose_card,'flex');assert.equal(saved.pose_profile,'ansage');
 await done(x);

 // Flag aus
 x=await page({off:true});
 await x.p.goto(base+'mein-boxer.html');
 await x.p.waitForFunction(()=>/noch nicht freigeschaltet/.test(document.getElementById('app').textContent));
 await done(x);

 // Profil: Holo statt Kampfgeist-Karte, Karte mit Holo
 x=await page({});
 await x.p.goto(base+'boxer-profile.html?name=Anna');
 await x.p.waitForSelector('.tlp-player .tlp-figure svg.tlh'); // Etappe 11: Holo-Pose neben der Karte
 await x.p.waitForSelector('.tlp-profile .tlp-card .tlp-holo svg.tlh');
 await shot(x.p,'holo-profil');
 await done(x);

 await browser.close();server.close();
 console.log('PASS: Boxer-Holo im Browser – 18 Frisuren, 8 Hauttöne, Kleidung mit Kapuze und Mantel, Speichern, Anprobe sperrt Speichern, Kauf und Bundle mit Bestätigung, Posen für Profil und Karte, Flag aus, Holo im Profil und auf der Karte');
})().catch(e=>{console.error(e);process.exit(1)});
