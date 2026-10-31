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
 const items=cfg.items.map(i=>Object.assign({},i,{owned:cfg.visualDemo===true||i.unlock==='start'||(i.unlock==='reward'&&i.key==='pose_flex')}));
 const bundles=[{key:'drachen_bundle',name:'Drachen-Bundle',description:'Drachen-Mantel, Flammen-Aura, Glut-Augen und die Pose Ansage.',price:3400,items:['coat_drache','aura_flamme','eyefx_glut','pose_ansage'],value:4700,owned_all:false}];
 let coins=cfg.coins??5000,saved=cfg.saved||null;
 let failSaveOnce=cfg.failSaveOnce===true,failBuyOnce=cfg.failBuyOnce===true;
 const DEF={tone:2,hair:'kurz_glatt',hc:'schwarz',eye:'braun',eyefx:'none',head:'none',headc:'schwarz',top:'none',hood:false,topc:'grau',bottom:'boxer',bottomc:'rot',hands:'wraps',glove:'rot',feet:'boots',feetc:'weiss',coat:'none',aura:'none',scene:'holo',pose_profile:'guard',pose_card:'guard'};
 const rating={categories:{OFF:75,DEF:63,BEI:70,KON:70,TAK:70,MEN:70},overall:72,scale:20,top:[],low:[],rated_at:'2026-10-20T10:00:00Z',delta:0};
 const annaHolo=Object.assign({},DEF,{hair:'afro',tone:6,top:'hoodie',hood:false,topc:'lila',coat:'basic',pose_profile:'sieg',pose_card:'jab',scene:'dojo'});
 const rpc=async(name,args)=>{
  calls.push([name,args]);
  if(name==='get_my_holo')return {data:cfg.off?{enabled:false}:{enabled:true,preview:false,shop:true,display_name:'Ben',coins,saved:!!saved,config:Object.assign({},DEF,saved||{}),items:items.map(i=>Object.assign({},i)),
   bundles:bundles.map(b=>Object.assign({},b,{owned_all:b.items.every(k=>items.find(i=>i.key===k).owned)}))},error:null};
  if(name==='save_my_holo'){
   if(failSaveOnce){failSaveOnce=false;throw Error('Verbindung beim Speichern unterbrochen')}
   if(cfg.saveDelay)await new Promise(resolve=>setTimeout(resolve,cfg.saveDelay));
   const c=Object.assign({},DEF,args.p_config);for(const s of ['coat','aura','eyefx','scene']){const it=items.find(i=>i.slot===s&&i.value===c[s]);if(c[s]!=='none'&&it&&!it.owned)return {data:null,error:{message:'«'+it.name+'» ist für dich noch nicht freigeschaltet'}}}
   saved=c;return {data:c,error:null}}
  if(name==='buy_holo_item'){
   if(failBuyOnce){failBuyOnce=false;throw Error('Verbindung beim Kauf unterbrochen')}
   const it=items.find(i=>i.key===args.p_key);if(coins<it.price)return {data:null,error:{message:'Zu wenig Coins'}};coins-=it.price;it.owned=true;return {data:{key:it.key,name:it.name,price:it.price,balance:coins},error:null}}
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
  const context=await browser.newContext({viewport:{width:cfg.testWidth||390,height:cfg.testHeight||844},reducedMotion:'reduce'});
  await context.addInitScript({content:'('+injected.toString()+')('+JSON.stringify(Object.assign({items:ITEMS},cfg))+')'});
  const p=await context.newPage();const errors=[];p.on('pageerror',e=>errors.push(e.message));
  await p.route('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm',r=>r.fulfill({status:200,contentType:'text/javascript',body:'export const createClient=()=>window.__takeoverMockClient;'}));
  await p.route('https://iqarjivcrddcixrvqbfb.supabase.co/**',r=>{const u=r.request().url();
   const body=u.includes('get_public_levels')?[{boxer_name:'Anna',lifetime_exp:500},{boxer_name:'Ben',lifetime_exp:300}]:u.includes('get_public_leaderboard')?[{boxer_name:'Anna',rank_position:1,monthly_points:100,approved_sessions:4,points_training:100,points_bonus:0},{boxer_name:'Ben',rank_position:2,monthly_points:80,approved_sessions:3,points_training:80,points_bonus:0}]:[];
   r.fulfill({status:200,contentType:'application/json',body:JSON.stringify(body)})});
  return {p,errors,context};
 }
 const noScroll=async p=>assert.ok(await p.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth+1),'no horizontal scroll');

 // Valid 768×1216 RGBA PNG, generated without third-party image libraries.
 const zlib=require('node:zlib');
 const crc=(bytes)=>{
  let n=0xffffffff;
  for(const v of bytes){n^=v;for(let j=0;j<8;j++)n=(n>>>1)^(n&1?0xedb88320:0)}
  return (n^0xffffffff)>>>0;
 };
 const chunk=(type,data)=>{
  const name=Buffer.from(type),len=Buffer.alloc(4),check=Buffer.alloc(4);
  len.writeUInt32BE(data.length);check.writeUInt32BE(crc(Buffer.concat([name,data])));
  return Buffer.concat([len,name,data,check]);
 };
 const makeTransparentReferencePng=()=>{
  const header=Buffer.alloc(13);
  header.writeUInt32BE(768,0);header.writeUInt32BE(1216,4);
  header[8]=8;header[9]=6;
  const blank=Buffer.alloc(1216*(1+768*4));
  return Buffer.concat([
   Buffer.from([137,80,78,71,13,10,26,10]),
   chunk('IHDR',header),chunk('IDAT',zlib.deflateSync(blank)),chunk('IEND',Buffer.alloc(0))
  ]);
 };
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
   height:r.height,viewport:p.height,svgOverflow:getComputedStyle(figure).overflow,previewOverflow:getComputedStyle(preview).overflow,
   statusHidden:document.getElementById('status').hidden};
 });
 assert.ok(previewGeometry.viewport>100,'fixed preview has room for boxer');
 assert.ok(previewGeometry.top>=-1&&previewGeometry.bottom>=-1,
  'boxer must fit vertically inside preview: '+JSON.stringify(previewGeometry));
 assert.ok(previewGeometry.left>=-1&&previewGeometry.right>=-1,
  'boxer must fit horizontally inside preview: '+JSON.stringify(previewGeometry));
 assert.equal(previewGeometry.svgOverflow,'visible','wide pose hands may extend beyond the inner SVG viewbox');
 assert.equal(previewGeometry.previewOverflow,'hidden','outer arena still prevents overlap with save controls');
 assert.ok(previewGeometry.statusHidden,'initial status toast must not obscure equipment');
 // Approved concept translated to DOM/CSS, not flattened into a static screenshot:
 // arena light, two gold banners, elevated platform and a dynamic boxer on top.
 assert.equal(await x.p.locator('.mb-arena').count(),1,'mobile studio has actual arena stage');
 assert.equal(await x.p.locator('.mb-arena-flag').count(),2,'two Takeover arena banners');
 assert.equal(await x.p.locator('.mb-arena-ring').count(),1,'golden fighting platform');
 assert.equal(await x.p.locator('.mb-preview img').count(),0,
  'unapproved artwork may not silently replace the editable boxer with a fixed screenshot');
 assert.equal(await x.p.locator('.mb-save-state').getAttribute('data-save-status'),'saved',
  'editor initially displays saved profile state');
 assert.equal(await x.p.locator('.mb-tab-icon svg').count(),5,
  'each of the five tabs has a real inline vector icon');
 assert.equal(await x.p.locator('.mb-tabs').evaluate(el=>getComputedStyle(el).display),'grid',
  'tab icons occupy equal mobile widths without horizontal scrolling');
 await shot(x.p,'holo-approved-arena-design');

 assert.equal(await x.p.locator('[data-set="hair"]').count(),18,'18 hair styles');
 for(const h of ['Afro','Locs','Box Braids','Cornrows','Twists','Afro-Puffs','Locken','Glatze'])assert.ok(await x.p.locator('[data-set="hair"]',{hasText:h}).count(),h);
 assert.equal(await x.p.locator('[data-set="tone"]').count(),8,'8 skin tones');
 assert.equal(await x.p.locator('[data-set="eye"]').count(),8,'8 eye colours');
 assert.ok(await x.p.isDisabled('#saveBtn'),'nothing to save yet');
 assert.equal(await x.p.locator('.mb-preview svg.tlh .tl-layer-outfit').count(),1,
  'mobile hero uses the layered material kit');
 assert.equal(await x.p.locator('.mb-preview svg.tlh .tl-layer-bottom').count(),1,
  'shorts are a separate configurable layer');
 assert.equal(await x.p.locator('.mb-preview svg.tlh .tl-layer-shoes').count(),1,
  'shoes are a separate configurable layer');
 await x.p.click('[data-set="hair"][data-val="locs"]');
 assert.equal(await x.p.locator('.mb-save-state').getAttribute('data-save-status'),'dirty',
  'visual status changes when a hairstyle selection is unsaved');
 assert.equal(await x.p.evaluate(()=>document.activeElement?.dataset.val),'locs',
  'a selection remains keyboard-focused after changing a hairstyle');
 await x.p.click('[data-set="tone"][data-val="6"]');
 assert.equal(await x.p.evaluate(()=>document.activeElement?.dataset.val),'6',
  'skin-tone selection preserves keyboard focus');
 await x.p.click('[data-set="hc"][data-val="dunkelbraun"]');
 await shot(x.p,'holo-koerper');
 // The five mobile editor tabs have an accessible, arrow-key-driven tab pattern.
 assert.equal(await x.p.locator('.mb-tabs [role="tab"]').count(),5,'five named editor tabs');
 assert.equal(await x.p.locator('.mb-tabs [role="tab"][tabindex="0"]').count(),1,
  'only the selected tab is in the natural keyboard order');
 await x.p.locator('.mb-tabs [data-tab="koerper"]').focus();
 await x.p.keyboard.press('ArrowRight');
 assert.equal(await x.p.locator('.mb-tabs [role="tab"][aria-selected="true"]').getAttribute('data-tab'),
  'kleidung','right arrow moves to clothing');
 assert.equal(await x.p.evaluate(()=>document.activeElement?.dataset.tab),'kleidung',
  'keyboard arrow keeps focus on the active tab');
 await x.p.keyboard.press('End');
 assert.equal(await x.p.locator('.mb-tabs [role="tab"][aria-selected="true"]').getAttribute('data-tab'),
  'shop','End key moves to final tab');
 await x.p.keyboard.press('Home');
 assert.equal(await x.p.locator('.mb-tabs [role="tab"][aria-selected="true"]').getAttribute('data-tab'),
  'koerper','Home key returns to first tab');
 await x.p.click('[data-tab="kleidung"]');
 assert.equal(await x.p.locator('.mb-tabbody[role="tabpanel"]').getAttribute('aria-labelledby'),
  'mb-tab-kleidung','editor panel has correct accessible tab label');
 // Die sichtbaren Itembilder stammen aus exakt demselben SVG-Renderer wie die Boxerfigur.
 assert.equal(await x.p.locator('[data-set="head"] .mb-gear-art svg.mb-item-svg').count(),4,'Kopfbedeckungen mit eigenständigen SVG-Items');
 assert.equal(await x.p.locator('[data-set="top"] .mb-gear-art svg.mb-item-svg').count(),5,'Oberteile als auswählbare SVG-Items');
 assert.equal(await x.p.locator('[data-set="top"][aria-pressed="true"]').count(),1,
  'premium item gallery still displays the active outfit selection');
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
 assert.equal(await x.p.evaluate(()=>document.activeElement?.dataset.val),'hoodie',
  'changing clothing preserves focus for keyboard and assistive input');
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

 // Responsive locked-stage checks on small and tall mobile devices.
 for(const [width,height] of [[360,640],[375,667],[430,932]]){
  const test=await page({testWidth:width,testHeight:height,visualDemo:true,saved:{
   tone:6,hair:'afro',top:'shirt',topc:'schwarz',bottom:'boxer',bottomc:'schwarz',
   coat:'samurai',feet:'boots',feetc:'schwarz',pose_profile:'cool'
  }});
  await test.p.goto(base+'mein-boxer.html');
  await test.p.waitForSelector('.mb-preview svg.tlh');
  await test.p.click('[data-tab="kleidung"]');
  const dimensions=await test.p.evaluate(()=>{
   const stage=document.querySelector('.mb-stage'),panel=document.querySelector('.mb-panel');
   const body=document.querySelector('.mb-tabbody'),figure=document.querySelector('.mb-preview svg.tlh');
   const r=stage.getBoundingClientRect(),p=panel.getBoundingClientRect(),f=figure.getBoundingClientRect();
   const listBefore=body.scrollTop;
   body.scrollTop=145;
   return {stageTop:r.top,stageBottom:r.bottom,panelTop:p.top,panelHeight:p.height,
    figLeft:f.left,figRight:f.right,screenWidth:innerWidth,
    stageStill:stage.getBoundingClientRect().top===r.top,listScrolled:body.scrollTop>listBefore,
    contentOverflow:getComputedStyle(body).overflowY};
  });
  assert.ok(dimensions.stageStill,'boxer fixed at '+width+'×'+height);
  assert.ok(dimensions.panelHeight>=115,'choices remain usable at '+width+'×'+height+': '+JSON.stringify(dimensions));
  assert.ok(dimensions.stageBottom<=dimensions.panelTop+2,'stage never overlays item tabs');
  assert.equal(dimensions.contentOverflow,'auto');
  assert.ok(dimensions.listScrolled,'equipment choices can scroll at '+width+'×'+height);
  assert.ok(dimensions.figLeft>=-1&&dimensions.figRight<=width+1,'figure fits screen at '+width+'×'+height);
  await shot(test.p,'holo-responsive-'+width+'x'+height);
  await done(test);
 }

 // Flag aus
 x=await page({off:true});
 await x.p.goto(base+'mein-boxer.html');
 await x.p.waitForFunction(()=>/noch nicht freigeschaltet/.test(document.getElementById('app').textContent));
 await done(x);

 // Visual-reference fixture: fully configurable black-and-gold outfit using
 // real, dynamic renderer. Mock-owned items avoid purchase banners in the shot.
 x=await page({visualDemo:true,coins:265,saved:{
  tone:6,hair:'afro',hc:'schwarz',eye:'braun',head:'none',
  top:'shirt',topc:'schwarz',bottom:'boxer',bottomc:'schwarz',
  hands:'wraps',feet:'boots',feetc:'schwarz',coat:'samurai',
  aura:'none',pose_profile:'cool',pose_card:'guard'
 }});
 await x.p.goto(base+'mein-boxer.html');
 await x.p.waitForSelector('.mb-preview svg.tlh');
 await shot(x.p,'holo-visual-reference');
 await x.p.click('[data-tab="kleidung"]');
 await shot(x.p,'holo-visual-reference-equipment');
 // The preview-only 3D shoulder detail follows the chosen mantle;
 // release cards deliberately do not inherit this markup.
 assert.equal(await x.p.locator('.mb-preview svg.tlh .tlh-premium-arm').count(),2,
  'two independently shaded shoulders for selected coat');
 assert.equal(await x.p.locator('.mb-preview svg.tlh .tlh-premium-signature').count(),1,
  'premium outfit uses crown and garment signature');
 await shot(x.p,'holo-anime-shoulders-black-gold');
 assert.equal(await x.p.locator('.mb-preview svg.tlh .tl-layer-coat').count(),1,
  'gold-accented outfit has independent coat layer');
 assert.equal(await x.p.locator('.mb-preview svg.tlh .tl-layer-hair').count(),1,
  'afro uses head-aligned hair layer');
 await done(x);

 // A stale/offline mobile PWA can lack optional files; the editor must
 // still allow changing, saving and previewing the SVG boxer.
 x=await page({visualDemo:true});
 for(const optional of ['takeover-mein-boxer-items.js','takeover-mein-boxer-layers.js',
  'takeover-mein-boxer-artpack-manifest.js','takeover-mein-boxer-artpack.js']){
  await x.p.route('**/'+optional,r=>r.abort('failed'));
 }
 await x.p.goto(base+'mein-boxer.html?art=preview',{waitUntil:'domcontentloaded'});
 await x.p.waitForSelector('.mb-preview svg.tlh');
 await x.p.click('[data-tab="kleidung"]');
 assert.equal(await x.p.locator('[data-set="top"] .mb-gear-art svg.tlh').count(),5,
  'missing item sprites fall back to five Holo clothing choices');
 await x.p.click('[data-set="top"][data-val="shirt"]');
 await x.p.click('#saveBtn');
 await x.p.waitForFunction(()=>window.__calls.some(c=>c[0]==='save_my_holo'));
 assert.equal((await calls(x.p)).find(c=>c[0]==='save_my_holo')[1].p_config.top,'shirt',
  'optional art failures never block saving');
 await done(x);

 // Device acceptance for compact phones and tall phones. The hero stays
 // fixed; navigation and gear remain separately accessible without sideways page scroll.
 for(const [width,height] of [[320,568],[375,667],[430,932]]){
  const device=await page({testWidth:width,testHeight:height});
  await device.p.goto(base+'mein-boxer.html');
  await device.p.waitForSelector('.mb-preview svg.tlh');
  const viewport=await device.p.evaluate(()=>{
   const stage=document.querySelector('.mb-stage').getBoundingClientRect();
   const root=document.querySelector('.mb-layout').getBoundingClientRect();
   const nav=document.querySelector('.mb-tabs').getBoundingClientRect();
   const body=document.querySelector('.mb-tabbody');
   const preview=document.querySelector('.mb-preview').getBoundingClientRect();
   return {stage:stage.toJSON(),root:root.toJSON(),nav:nav.toJSON(),
    preview:preview.toJSON(),scrollHeight:body.scrollHeight,clientHeight:body.clientHeight,
    overflowY:getComputedStyle(body).overflowY,scrollWidth:document.documentElement.scrollWidth};
  });
  assert.ok(viewport.stage.height>=180,'stage must fit on '+width+'×'+height);
  assert.ok(viewport.preview.height>=55,'character must remain visible on '+width+'×'+height);
  assert.ok(viewport.nav.width<=viewport.root.width+1,'five tabs never overflow on '+width+'×'+height);
  assert.equal(viewport.overflowY,'auto','gear remains independently scrollable on '+width+'×'+height);
  assert.ok(viewport.clientHeight>=70,'clothing editor keeps usable height on '+width+'×'+height);
  assert.ok(viewport.scrollWidth<=width+1,'page never scrolls horizontally on '+width+'×'+height);
  await device.p.click('[data-tab="kleidung"]');
  assert.equal(await device.p.locator('[data-set="top"][data-val="hoodie"]').count(),1,
   'full clothing selection remains accessible on '+width+'×'+height);
  if(width===375)await shot(device.p,'holo-arena-compact-phone');
  if(width===430)await shot(device.p,'holo-arena-tall-phone');
  await done(device);
 }

 // Network exceptions must never leave saving/purchases stuck in busy state.
 x=await page({failSaveOnce:true});
 await x.p.goto(base+'mein-boxer.html');
 await x.p.waitForSelector('[data-set="tone"][data-val="6"]');
 await x.p.click('[data-set="tone"][data-val="6"]');
 await x.p.click('#saveBtn');
 await x.p.waitForFunction(()=>document.querySelector('#status')?.textContent.includes('Speichern fehlgeschlagen'));
 assert.equal(await x.p.isDisabled('#saveBtn'),false,'save can be retried after network exception');
 await x.p.click('#saveBtn');
 await x.p.waitForSelector('#saveBtn:disabled');
 assert.match(await x.p.textContent('#status'),/Gespeichert/);
 await done(x);

 x=await page({failBuyOnce:true});
 await x.p.goto(base+'mein-boxer.html');
 await x.p.click('[data-tab="shop"]');
 await x.p.click('[data-buy-item="aura_flamme"]');
 await x.p.click('[data-buy-item="aura_flamme"][data-confirm]');
 await x.p.waitForFunction(()=>document.querySelector('#status')?.textContent.includes('Kauf fehlgeschlagen'));
 assert.equal(await x.p.locator('[data-buy-item="aura_flamme"]').isDisabled(),false,
  'purchase is recoverable after network exception');
 await done(x);

 // Save must commit a snapshot but preserve newer unsaved edits while waiting.
 x=await page({saveDelay:550});
 await x.p.goto(base+'mein-boxer.html');
 await x.p.waitForSelector('[data-set="tone"][data-val="6"]');
 await x.p.click('[data-set="tone"][data-val="6"]');
 await x.p.click('#saveBtn');
 await x.p.click('[data-set="tone"][data-val="5"]');
 await x.p.waitForFunction(()=>document.querySelector('#status')?.textContent.includes('neueren Änderungen'));
 const savedSnapshot=(await calls(x.p)).find(v=>v[0]==='save_my_holo')[1].p_config;
 assert.equal(savedSnapshot.tone,6,'RPC receives immutable snapshot selected at save time');
 assert.equal(await x.p.locator('[data-set="tone"][data-val="5"]').getAttribute('aria-pressed'),'true',
  'newer unsaved skin tone remains selected after save resolves');
 assert.equal(await x.p.isDisabled('#saveBtn'),false,'newer changes remain saveable');
 await done(x);


 // The approved single-character reference can be previewed locally without
 // pretending it is a modular outfit or touching player profiles.
 x=await page({visualDemo:true});
 await x.p.goto(base+'mein-boxer.html?art=reference');
 await x.p.waitForSelector('#mb-reference-file');
 assert.equal(await x.p.locator('.mb-reference-figure').count(),0,'no arbitrary reference before upload');
 assert.equal(await x.p.locator('.mb-preview svg.tlh').count(),1,'SVG remains the default figure');
 const validReference=makeTransparentReferencePng();
 await x.p.locator('#mb-reference-file').setInputFiles({
  name:'takeover-reference-cool.png',mimeType:'image/png',buffer:validReference
 });
 await x.p.waitForSelector('.mb-reference-figure');
 assert.equal(await x.p.locator('.mb-reference-figure').getAttribute('alt'),
  'Anime-Referenz nur zum visuellen Vergleich','preview is visibly declared not editable');
 assert.ok((await x.p.locator('.mb-reference-figure').getAttribute('src')).startsWith('blob:'),
  'file stays in the local browser');
 await shot(x.p,'holo-reference-local-upload');
 await x.p.click('[data-tab="kleidung"]');
 assert.equal(await x.p.locator('.mb-reference-figure').count(),1,
  'navigating among tabs does not discard the approved reference');
 await x.p.click('[data-set="top"][data-val="hoodie"]');
 assert.equal(await x.p.locator('.mb-reference-figure').count(),0,
  'changing outfit returns to the truly editable Holo instead of a fake fixed image');
 assert.equal(await x.p.locator('.mb-preview svg.tlh').count(),1);
 assert.equal(await x.p.locator('[data-reference-toggle]').getAttribute('aria-pressed'),'false');
 await x.p.click('[data-reference-toggle]');
 assert.equal(await x.p.locator('.mb-reference-figure').count(),1,
  'editor can compare again without changing saved configuration');
 assert.ok(!(await calls(x.p)).some(c=>c[0]==='save_my_holo'),
  'viewing a reference does not persist a new outfit');
 await done(x);

 x=await page({visualDemo:true});
 await x.p.goto(base+'mein-boxer.html');
 await x.p.waitForSelector('.mb-preview svg.tlh');
 assert.equal(await x.p.locator('.mb-reference-tools,.mb-reference-figure').count(),0,
  'live editor never shows the developer-only local image picker');
 await done(x);

 // First eight locally cut anime layers are a genuine pixel-composited preview,
 // not a claim that invisible skin or new clothing has been painted.
 const draftCool={
  tone:6,hair:'afro',hc:'schwarz',eye:'braun',head:'none',top:'none',topc:'grau',
  bottom:'boxer',bottomc:'schwarz',feet:'boots',feetc:'schwarz',coat:'samurai',
  hands:'wraps',aura:'none',eyefx:'none',scene:'holo',pose_profile:'cool'
 };
 const draftNames=['coatBack','body','bottom','feet','eyes','hair','coatFront','hands'];
 const draftFiles=draftNames.map(name=>({
  name:name+'.png',mimeType:'image/png',buffer:makeTransparentReferencePng()
 }));
 x=await page({visualDemo:true,saved:draftCool});
 await x.p.goto(base+'mein-boxer.html?art=layers');
 await x.p.waitForSelector('#mb-draft-files',{state:'attached'});
 assert.equal(await x.p.locator('.mb-draft-artpack').count(),0,'no fake assets before local selection');
 await x.p.locator('#mb-draft-files').setInputFiles(draftFiles);
 await x.p.waitForSelector('.mb-draft-artpack .mb-artpack-img');
 assert.equal(await x.p.locator('.mb-draft-tools').getAttribute('open'),null,
  'eight-layer inspector is collapsed by default to protect mobile character visibility');
 await x.p.locator('.mb-draft-tools summary').click();
 assert.equal(await x.p.locator('.mb-draft-artpack .mb-artpack-img').count(),8,
  'the draft reference is composed from exactly eight independent local images');
 assert.match(await x.p.locator('#mb-draft-note').textContent(),/Dateien weichen vom Referenzpaket ab/,
  'synthetic graphics must never masquerade as the approved original artwork');
 const draftBounds=await x.p.evaluate(()=>{
  const root=document.querySelector('.mb-draft-artpack').getBoundingClientRect();
  return [...document.querySelectorAll('.mb-draft-artpack img')].every(img=>{
   const r=img.getBoundingClientRect();
   return Math.abs(r.x-root.x)<1&&Math.abs(r.y-root.y)<1&&
    Math.abs(r.width-root.width)<1&&Math.abs(r.height-root.height)<1&&
    img.src.startsWith('blob:');
  });
 });
 assert.equal(draftBounds,true,'all layer canvases overlap exactly; no remote image URLs');
 assert.ok((await calls(x.p)).every(c=>c[0]!=='save_my_holo'),
  'uploading local art does not write a boxer profile');
 await shot(x.p,'holo-eight-layer-draft-preview');
 assert.equal(await x.p.locator('.mb-draft-layer-controls input').count(),8,'every real layer has a visibility switch');
 const coatMask=x.p.locator('[data-draft-layer="coatFront"]');
 await coatMask.uncheck();
 assert.equal(await x.p.locator('.mb-draft-artpack img').count(),7,
  'disabling the front coat reveals missing skin anatomy instead of faking another outfit');
 assert.equal(await x.p.evaluate(()=>document.activeElement?.dataset.draftLayer),'coatFront',
  'layer inspection preserves keyboard focus');
 await shot(x.p,'holo-eight-layer-coat-removed-review');
 // First anatomical tracing fills the missing undercoat silhouette, but only
 // after an explicit reviewer action; it is NOT passed off as anime-quality art.
 assert.equal(await x.p.locator('.mb-draft-underpaint').count(),0,
  'rough sketch is never enabled by default');
 await x.p.locator('[data-draft-anatomy]').check();
 assert.equal(await x.p.locator('.mb-draft-underpaint').count(),1,
  'opt-in editable underpaint appears behind the real pixel layers');
 assert.equal(await x.p.locator('.mb-draft-artpack img').count(),7,
  'tracing sketch does not remove original raster artwork');
 const sketchLayerOrder=await x.p.evaluate(()=>{
  const under=document.querySelector('.mb-draft-underpaint');
  const img=document.querySelector('.mb-draft-artpack img');
  return Number(getComputedStyle(under).zIndex)<Number(getComputedStyle(img).zIndex);
 });
 assert.equal(sketchLayerOrder,true,'reference pixels remain visually above draft anatomy');
 await x.p.locator('#mb-underpaint-file').setInputFiles({
  name:'artist-draft-body.png',mimeType:'image/png',buffer:makeTransparentReferencePng()
 });
 await x.p.waitForSelector('.mb-draft-underpaint-file');
 assert.equal(await x.p.locator('.mb-draft-underpaint-file').getAttribute('src').then(x=>x.startsWith('blob:')),true,
  'artist body remains on local object URL');
 assert.equal(await x.p.locator('.mb-draft-underpaint').count(),1,
  'new PNG replaces vector geometry rather than stacking duplicate bodies');
 assert.equal(await x.p.locator('.mb-draft-artpack .mb-artpack-img').count(),7,
  'new body is still behind seven unchanged original art masks');
 assert.ok(!(await calls(x.p)).some(c=>c[0]==='save_my_holo'),
  'importing a body drawing never saves or purchases an outfit');
 await x.p.locator('.mb-draft-tools summary').click();
 await shot(x.p,'holo-eight-layer-custom-body-png');
 await x.p.locator('.mb-draft-tools summary').click();
 await x.p.locator('[data-clear-underpaint]').click();
 assert.equal(await x.p.locator('.mb-draft-underpaint-file').count(),0,
  'artist may remove new body art with no persistent state change');
 await x.p.locator('[data-draft-anatomy]').check();
 assert.equal(await x.p.locator('.mb-draft-underpaint').count(),1,
  'existing SVG tracing remains available after removing optional PNG');
 await x.p.locator('.mb-draft-tools summary').click();
 assert.equal(await x.p.locator('.mb-draft-tools').getAttribute('open'),null,
  'comparison screenshot must show the complete body instead of covering it with tools');
 await shot(x.p,'holo-eight-layer-underpaint-blockout');
 await x.p.locator('.mb-draft-tools summary').click();
 assert.equal(await x.p.locator('[data-draft-anatomy]').isChecked(),true,
  'temporary anatomy selection survives collapse and reopen');
 await x.p.locator('[data-draft-anatomy]').uncheck();
 assert.equal(await x.p.locator('.mb-draft-underpaint').count(),0,
  'disabling the sketch restores the exact original pixels');
 await coatMask.check();
 assert.equal(await x.p.locator('.mb-draft-artpack img').count(),8,
  'coat masking never destroys the original reference');

 await x.p.click('[data-draft-toggle]');
 assert.equal(await x.p.locator('.mb-draft-tools').getAttribute('open'),'',
  'inspector stays expanded when the character toggles between SVG and sprites');
 assert.equal(await x.p.locator('.mb-draft-artpack').count(),0,
  'reviewer can compare against original dynamic SVG');
 assert.equal(await x.p.locator('.mb-preview svg.tlh').count(),1);
 await x.p.click('[data-draft-toggle]');
 assert.equal(await x.p.locator('.mb-draft-artpack img').count(),8,
  'draft layers reappear without another file upload');
 await x.p.click('[data-tab="kleidung"]');
 await x.p.click('[data-set="top"][data-val="shirt"]');
 assert.equal(await x.p.locator('.mb-draft-artpack').count(),0,
  'different shirt MUST use the genuinely configurable SVG, never the static masked layer');
 assert.equal(await x.p.locator('.mb-preview svg.tlh').count(),1);
 assert.match(await x.p.locator('#mb-draft-note').textContent(),/SVG-Fallback/);
 assert.ok((await calls(x.p)).every(c=>c[0]!=='save_my_holo'),
  'draft image selection is never saved or purchased');
 await done(x);

 // A boxer with different saved gear can still compare the exact approved art
 // in an explicitly labelled temporary review, with NO player data mutation.
 x=await page({visualDemo:true});
 await x.p.goto(base+'mein-boxer.html?art=layers');
 await x.p.waitForSelector('#mb-draft-files',{state:'attached'});
 await x.p.locator('#mb-draft-files').setInputFiles(draftFiles);
 await x.p.waitForSelector('.mb-draft-artpack img');
 await x.p.locator('.mb-draft-tools summary').click();
 assert.match(await x.p.locator('#mb-draft-note').textContent(),/Nur Referenzlook/);
 assert.equal(await x.p.locator('[data-draft-sample]').getAttribute('aria-pressed'),'true',
  'reference override is explicit and clearly labelled');
 await x.p.click('[data-draft-sample]');
 assert.equal(await x.p.locator('.mb-draft-artpack').count(),0,
  'player can switch back to their actual saved gear without replacing it');
 await x.p.click('[data-draft-sample]');
 assert.equal(await x.p.locator('.mb-draft-artpack img').count(),8,
  'approved original look can be inspected again regardless of player gear');
 await x.p.click('[data-set="tone"][data-val="6"]');
 assert.equal(await x.p.locator('.mb-draft-artpack').count(),0,
  'changing skin tone ends the temporary reference override');
 assert.ok(!(await calls(x.p)).some(c=>c[0]==='save_my_holo'),
  'reference override and layer controls never write the user profile');
 await done(x);

 // A committed, but missing or invalid, reference pack never breaks the
 // SVG editor or saves user data. Reviewer can still upload the local ZIP.
 x=await page({visualDemo:true,saved:draftCool});
 await x.p.route('**/assets/boxer-artpacks/v1/cool/*.png',r=>r.fulfill({status:404,body:'Not Found'}));
 await x.p.goto(base+'mein-boxer.html?art=layers');
 await x.p.locator('.mb-draft-tools summary').click();
 assert.equal(await x.p.locator('.mb-draft-artpack').count(),0);
 await x.p.locator('[data-draft-repo]').click();
 await x.p.waitForFunction(()=>document.querySelector('#status')?.textContent.includes('Branch-Grafiken nicht verfügbar'));
 assert.equal(await x.p.locator('.mb-preview svg.tlh').count(),1,
  'missing committed raster files must preserve the real editable Holo');
 assert.equal(await x.p.locator('[data-draft-repo]').isEnabled(),true,
  'failed attempt leaves retry possible');
 assert.equal(await x.p.locator('#mb-draft-files').count(),1,
  'local file picker remains as fallback');
 assert.ok(!(await calls(x.p)).some(c=>c[0]==='save_my_holo'),
  'a missing branch art pack never touches saved boxer configuration');
 await done(x);


 // Real repository artwork acceptance: once the eight exact PNGs have been
 // committed to this PR, exercise the entire button -> real HTTP -> WebCrypto
 // -> decoded alpha layers -> browser stage route. Never mock these files.
 const originalNames=['coatback','body','bottom','feet','eyes','hair','coatfront','hands'];
 const installed=originalNames.filter(n=>fs.existsSync(
  path.join(root,'assets/boxer-artpacks/v1/cool',n+'.png')));
 if(installed.length){
  assert.equal(installed.length,8,
   'a partially committed original artpack must not pass Chromium acceptance');
  x=await page({visualDemo:true,saved:draftCool});
  await x.p.goto(base+'mein-boxer.html?art=layers');
  await x.p.waitForSelector('.mb-preview svg.tlh');
  await x.p.locator('.mb-draft-tools summary').click();
  await x.p.locator('[data-draft-repo]').click();
  await x.p.waitForSelector('.mb-draft-artpack .mb-artpack-img',{timeout:12000});
  assert.equal(await x.p.locator('.mb-draft-artpack img').count(),8,
   'all eight original repository image files decode as a single art stack');
  assert.match(await x.p.locator('#mb-draft-note').textContent(),
   /Originaldateien per SHA-256 bestätigt/,
   'loaded real files must match every confirmed original SHA-256 digest');
  const originalsAligned=await x.p.evaluate(()=>{
   const stack=document.querySelector('.mb-draft-artpack').getBoundingClientRect();
   return [...document.querySelectorAll('.mb-draft-artpack img')].every(img=>{
    const b=img.getBoundingClientRect();
    return img.complete&&img.naturalWidth===768&&img.naturalHeight===1216&&
     Math.abs(b.x-stack.x)<1&&Math.abs(b.y-stack.y)<1&&
     Math.abs(b.width-stack.width)<1&&Math.abs(b.height-stack.height)<1;
   });
  });
  assert.ok(originalsAligned,'original sprite layers must decode, center and align identically');
  await x.p.locator('.mb-draft-tools summary').click();
  await shot(x.p,'holo-original-8-repository-art');
  await x.p.click('[data-tab="kleidung"]');
  await x.p.click('[data-set="top"][data-val="hoodie"]');
  assert.equal(await x.p.locator('.mb-draft-artpack').count(),0,
   'real original art must fall back to editable Holo for unsupported outfits');
  assert.equal(await x.p.locator('.mb-preview svg.tlh').count(),1);
  assert.ok(!(await calls(x.p)).some(c=>c[0]==='save_my_holo'),
   'real sprite inspection must never save a user configuration');
  await done(x);
 }else{
  console.log('PENDING ARTWORK: no original PNGs are committed to this PR; real raster Chromium acceptance is not yet possible.');
 }

 // A missing or malformed draft cannot create an incomplete visible costume.
 x=await page({visualDemo:true,saved:draftCool});
 await x.p.goto(base+'mein-boxer.html?art=layers');
 await x.p.waitForSelector('#mb-draft-files',{state:'attached'});
 await x.p.locator('#mb-draft-files').setInputFiles(draftFiles.slice(0,7));
 await x.p.waitForFunction(()=>document.querySelector('#status')?.textContent.includes('genau acht'));
 assert.equal(await x.p.locator('.mb-draft-artpack').count(),0,'seven assets never create a partial costume');
 await done(x);

 x=await page({visualDemo:true,saved:draftCool});
 await x.p.goto(base+'mein-boxer.html');
 await x.p.waitForSelector('.mb-preview svg.tlh');
 assert.equal(await x.p.locator('.mb-draft-tools,.mb-draft-artpack').count(),0,
  'ordinary boxer editor never exposes draft sprites');
 await done(x);

 // Art-pack integration is opt-in and can never show a partial costume.
 // Fixture PNG data stays in the browser test, not in the repository or site.
 const artConfig={
  tone:6,hair:'afro',hc:'schwarz',eye:'braun',head:'none',top:'shirt',topc:'schwarz',
  bottom:'boxer',bottomc:'schwarz',feet:'boots',feetc:'schwarz',coat:'samurai',
  hands:'wraps',aura:'none',eyefx:'none',scene:'holo',pose_profile:'cool'
 };
 const partNames={
  coatBack:{samurai:'coats/back.png'},
  body:{'6':'body/tone6.png'},
  bottom:{'boxer/schwarz':'bottom/shorts.png'},
  feet:{'boots/schwarz':'feet/boots.png'},
  top:{'shirt/schwarz':'top/shirt.png'},
  eyes:{braun:'eyes/brown.png'},
  hair:{'afro/schwarz':'hair/afro.png'},
  coatFront:{samurai:'coats/front.png'},
  hands:{wraps:'hands/wraps.png'}
 };
 const testManifest={version:1,approved:true,canvas:{width:768,height:1216},poses:{cool:partNames}};
 const fixtureArt='window.TLBoxerArtPackManifest='+JSON.stringify(testManifest)+';';
 const pixel=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO/uAKQAAAAASUVORK5CYII=','base64');
 // Even with an explicit preview URL, the shipping manifest is not approved.
 x=await page({visualDemo:true,saved:artConfig});
 await x.p.goto(base+'mein-boxer.html?art=preview');
 await x.p.waitForSelector('.mb-preview svg.tlh');
 assert.equal(await x.p.locator('.mb-art-debug').getAttribute('data-art-state'),'unapproved',
  'preview explains that no production artpack has been approved');
 assert.equal(await x.p.locator('[data-art-compare]').count(),0,
  'unapproved art must not show an inert comparison control');
 await shot(x.p,'holo-artpack-debug-unapproved');
 assert.equal(await x.p.locator('.mb-preview .mb-artpack-img').count(),0,'unapproved art cannot appear');
 await done(x);

 // If a preview manifest is approved but its renderer is unavailable offline,
 // users must not see a comparison button that does nothing.
 x=await page({visualDemo:true,saved:artConfig});
 await x.p.route('**/takeover-mein-boxer-artpack-manifest.js',r=>
  r.fulfill({status:200,contentType:'text/javascript',body:fixtureArt}));
 await x.p.route('**/takeover-mein-boxer-artpack.js',r=>r.abort('failed'));
 await x.p.goto(base+'mein-boxer.html?art=preview',{waitUntil:'domcontentloaded'});
 await x.p.waitForSelector('.mb-preview svg.tlh');
 assert.equal(await x.p.locator('.mb-art-debug').getAttribute('data-art-state'),'unavailable',
  'preview explains missing graphics renderer');
 assert.equal(await x.p.locator('[data-art-compare]').count(),0,
  'missing artpack module never exposes an inert comparison button');
 await done(x);

 // Release rollout has TWO explicit guards: approved artwork and enabled launch.
 // Approved but disabled: even the ordinary studio shows the original SVG.
 x=await page({visualDemo:true,saved:artConfig});
 await x.p.route('**/takeover-mein-boxer-artpack-manifest.js',r=>r.fulfill({
  status:200,contentType:'text/javascript',body:fixtureArt
 }));
 await x.p.route('**/assets/boxer-artpacks/v1/**',r=>r.fulfill({
  status:200,contentType:'image/png',body:pixel
 }));
 await x.p.goto(base+'mein-boxer.html');
 await x.p.waitForSelector('.mb-preview svg.tlh');
 assert.equal(await x.p.locator('.mb-preview .mb-artpack-img').count(),0,
  'approved graphics remain off until release-enabled');
 assert.equal(await x.p.locator('.mb-art-debug,[data-art-compare]').count(),0,
  'production never exposes developer-only diagnostics or artwork comparison');
 await done(x);

 // Approved AND release-enabled: ordinary studio displays the new artpack.
 const liveFixtureArt='window.TLBoxerArtPackManifest='+JSON.stringify({...testManifest,enabled:true})+';';
 x=await page({visualDemo:true,saved:artConfig});
 await x.p.route('**/takeover-mein-boxer-artpack-manifest.js',r=>r.fulfill({
  status:200,contentType:'text/javascript',body:liveFixtureArt
 }));
 await x.p.route('**/assets/boxer-artpacks/v1/**',r=>r.fulfill({
  status:200,contentType:'image/png',body:pixel
 }));
 await x.p.goto(base+'mein-boxer.html');
 await x.p.waitForSelector('.mb-preview .mb-artpack-img');
 assert.equal(await x.p.locator('.mb-preview .mb-artpack-img').count(),9,
  'release enabled artwork draws exactly nine aligned layers');
 assert.equal(await x.p.locator('.mb-art-debug,[data-art-compare]').count(),0,
  'release never shows preview-only diagnostics or comparison');
 await x.p.click('[data-tab="kleidung"]');
 await x.p.click('[data-set="top"][data-val="hoodie"]');
 assert.equal(await x.p.locator('.mb-preview svg.tlh').count(),1,
  'production falls back to SVG for missing clothing artwork');
 await done(x);

 // Release-enabled alone is never sufficient when the asset is unapproved.
 x=await page({visualDemo:true,saved:artConfig});
 await x.p.route('**/takeover-mein-boxer-artpack-manifest.js',r=>r.fulfill({
  status:200,contentType:'text/javascript',
  body:'window.TLBoxerArtPackManifest='+JSON.stringify({...testManifest,approved:false,enabled:true})+';'
 }));
 await x.p.goto(base+'mein-boxer.html');
 await x.p.waitForSelector('.mb-preview svg.tlh');
 assert.equal(await x.p.locator('.mb-preview .mb-artpack-img').count(),0,
  'unapproved artwork cannot go live despite enabled flag');
 await done(x);

 // A complete, approved fixture composes image layers on the fixed stage.
 x=await page({visualDemo:true,saved:artConfig});
 await x.p.route('**/takeover-mein-boxer-artpack-manifest.js',r=>r.fulfill({status:200,contentType:'text/javascript',body:fixtureArt}));
 await x.p.route('**/assets/boxer-artpacks/v1/**',r=>r.fulfill({status:200,contentType:'image/png',body:pixel}));
 await x.p.goto(base+'mein-boxer.html?art=preview');
 await x.p.waitForSelector('.mb-preview .mb-artpack-img');
 assert.equal(await x.p.locator('.mb-art-debug').getAttribute('data-art-state'),'ready',
  'preview reports a complete and loaded artpack');
 const alignment=await x.p.evaluate(()=>{
  const host=document.querySelector('.mb-preview').getBoundingClientRect();
  const art=document.querySelector('.mb-artpack').getBoundingClientRect();
  const images=[...document.querySelectorAll('.mb-artpack-img')].map(el=>el.getBoundingClientRect());
  return {host:host.toJSON(),art:art.toJSON(),aligned:images.every(r=>Math.abs(r.x-art.x)<1&&
   Math.abs(r.y-art.y)<1&&Math.abs(r.width-art.width)<1&&Math.abs(r.height-art.height)<1)};
 });
 assert.ok(alignment.art.width>40&&alignment.art.height>80,
  'painted character must occupy a visible stage area: '+JSON.stringify(alignment));
 assert.ok(Math.abs(alignment.art.left+alignment.art.width/2-alignment.host.left-alignment.host.width/2)<2,
  'painted character stays horizontally centered on phone');
 assert.ok(alignment.art.top>=alignment.host.top-2&&alignment.art.bottom<=alignment.host.bottom+2,
  'painted character does not spill beyond its fixed preview');
 assert.ok(alignment.aligned,'all png layers share identical drawn viewport');
 await shot(x.p,'holo-artpack-debug-ready');
 const artCompare=x.p.locator('[data-art-compare]');
 assert.equal(await artCompare.count(),1,'comparison control appears only for approved preview assets');
 await x.p.click('[data-tab="kleidung"]');
 const configBefore=await x.p.locator('[data-set="top"][data-val="shirt"]').getAttribute('aria-pressed');
 const tabBefore=await x.p.locator('.mb-panel').getAttribute('data-active-tab');
 assert.equal(configBefore,'true','the reference outfit has a selected shirt');
 await artCompare.focus();
 await x.p.keyboard.press('Enter');
 assert.equal(await x.p.locator('.mb-preview .mb-artpack-img').count(),0,
  'reviewer can switch to original SVG without modifying gear');
 assert.equal(await x.p.locator('.mb-preview svg.tlh').count(),1,
  'same character uses original Holo in comparison mode');
 assert.equal(await x.p.locator('.mb-art-debug').getAttribute('data-art-state'),'manual-svg',
  'preview identifies the manually chosen SVG comparison');
 assert.equal(await x.p.evaluate(()=>document.activeElement?.hasAttribute('data-art-compare')),true,
  'comparison remains keyboard-focusable after switching art');
 await shot(x.p,'holo-artpack-compare-svg');
 await artCompare.click();
 assert.equal(await x.p.locator('.mb-preview .mb-artpack-img').count(),9,
  'reviewer can switch back to preloaded premium layers immediately');
 assert.equal(await x.p.locator('[data-set="top"][data-val="shirt"]').getAttribute('aria-pressed'),configBefore,
  'art comparison preserves the selected outfit');
 assert.equal(await x.p.locator('.mb-panel').getAttribute('data-active-tab'),tabBefore,
  'art comparison preserves the clothing tab');
 assert.ok(!(await calls(x.p)).some(c=>c[0]==='save_my_holo'),
  'reviewing graphics never writes the user configuration');
 assert.equal(await x.p.locator('.mb-preview .mb-artpack-img').count(),9,'all nine required canvas layers');
 assert.equal(await x.p.locator('.mb-preview svg.tlh').count(),0,'complete art pack replaces SVG');
 await x.p.click('[data-tab="kleidung"]');
 await x.p.click('[data-set="top"][data-val="hoodie"]');
 assert.equal(await x.p.locator('.mb-preview .mb-artpack-img').count(),0,'unpainted hoodie must not use shirt art');
 assert.equal(await x.p.locator('.mb-art-debug').getAttribute('data-art-state'),'missing-layer',
  'preview identifies unsupported clothing variant');
 assert.match(await x.p.locator('.mb-art-debug').textContent(),/top:hoodie/);
 await shot(x.p,'holo-artpack-debug-missing-outfit');
 assert.equal(await x.p.locator('.mb-preview svg.tlh').count(),1,'missing outfit returns whole SVG');
 await done(x);

 // Atomic preview test: while the last equipment layer loads, ONLY the
 // existing SVG may be visible. The complete painted character swaps in once.
 x=await page({visualDemo:true,saved:artConfig});
 await x.p.route('**/takeover-mein-boxer-artpack-manifest.js',r=>r.fulfill({status:200,contentType:'text/javascript',body:fixtureArt}));
 await x.p.route('**/assets/boxer-artpacks/v1/**',async r=>{
  if(r.request().url().endsWith('/coats/front.png'))await new Promise(resolve=>setTimeout(resolve,1500));
  await r.fulfill({status:200,contentType:'image/png',body:pixel});
 });
 await x.p.goto(base+'mein-boxer.html?art=preview',{waitUntil:'domcontentloaded'});
 await x.p.waitForSelector('.mb-preview svg.tlh');
 assert.equal(await x.p.locator('.mb-art-debug').getAttribute('data-art-state'),'loading',
  'preview identifies a still-incomplete image preload');
 assert.equal(await x.p.locator('.mb-preview .mb-artpack-img').count(),0,
  'unloaded image layers may never appear as a partial outfit');
 await x.p.click('[data-tab="kleidung"]');
 const shirt=x.p.locator('[data-set="top"][data-val="shirt"]');
 await shirt.focus();
 await x.p.evaluate(()=>{document.querySelector('.mb-tabbody').scrollTop=110});
 const scrollBefore=await x.p.locator('.mb-tabbody').evaluate(el=>el.scrollTop);
 assert.ok(scrollBefore>50,'equipment list is independently scrolled during the pending load');
 await x.p.waitForSelector('.mb-preview .mb-artpack-img',{timeout:7000});
 assert.equal(await x.p.locator('.mb-preview .mb-artpack-img').count(),9,
  'the finished outfit appears as one image stack');
 assert.equal(await x.p.evaluate(()=>document.activeElement?.dataset.val),'shirt',
  'async image completion does not steal focus or rebuild the editor');
 assert.ok(Math.abs(await x.p.locator('.mb-tabbody').evaluate(el=>el.scrollTop)-scrollBefore)<2,
  'async image completion preserves independent equipment scrolling');
 await done(x);

 // A single failed external image also recovers to full SVG automatically.
 x=await page({visualDemo:true,saved:artConfig});
 await x.p.route('**/takeover-mein-boxer-artpack-manifest.js',r=>r.fulfill({status:200,contentType:'text/javascript',body:fixtureArt}));
 await x.p.route('**/assets/boxer-artpacks/v1/**',r=>{
  if(r.request().url().endsWith('/coats/front.png'))return r.fulfill({status:404,contentType:'text/plain',body:'missing'});
  return r.fulfill({status:200,contentType:'image/png',body:pixel});
 });
 await x.p.goto(base+'mein-boxer.html?art=preview');
 await x.p.waitForSelector('.mb-preview svg.tlh');
 await x.p.waitForSelector('.mb-art-debug[data-art-state="load-failed"]');
 await shot(x.p,'holo-artpack-debug-load-failed');
 assert.equal(await x.p.locator('.mb-preview .mb-artpack-img').count(),0,'failed sprite removes entire partial art');
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
