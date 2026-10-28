'use strict';
// Chromium test with mocked Supabase (no real account, no server writes) for Etappe 12:
// neue Designs im Katalog, eigenes Design gestalten (Vorschau live, Speichern, Auswählen), Admin schaltet frei/entzieht.
const assert=require('node:assert/strict'),fs=require('node:fs'),http=require('node:http'),path=require('node:path');
const {chromium}=require('playwright');
const root=process.cwd();
const server=http.createServer((req,res)=>{
 const u=new URL(req.url,'http://127.0.0.1');
 const file=path.resolve(root,decodeURIComponent(u.pathname.slice(1))||'index.html');
 if(!file.startsWith(root+path.sep)){res.writeHead(403);res.end();return}
 fs.readFile(file,(err,data)=>{if(err){res.writeHead(404);res.end();return}
  const ext=path.extname(file);res.setHeader('Content-Type',ext==='.js'?'text/javascript':ext==='.html'?'text/html':ext==='.css'?'text/css':ext==='.svg'?'image/svg+xml':'application/octet-stream');res.end(data)});
});
function injected(cfg){
 const calls=[];window.__calls=calls;
 const D=(key,name,unlock,extra,design)=>({key,name,description:name+' Design',unlock,min_rank:null,price:null,award_kind:null,design,...extra});
 const designs=[D('classic','Klassisch','start',{},{tier:true}),D('stahl','Stahl','rank',{min_rank:'E'},{a:'#c9d1db',b:'#3b434f',ink:'#10151c',edge:'#ffffff',pattern:'stripes'}),
  D('kosmos','Kosmos','rank',{min_rank:'A'},{a:'#3b4dff',b:'#070720',ink:'#f5f3ff',edge:'#c9b8ff',pattern:'stars',glow:true}),
  D('comic','Comic','shop',{price:450},{a:'#ffe14d',b:'#e8432e',ink:'#141414',edge:'#141414',pattern:'halftone'}),
  D('inferno','Inferno','shop',{price:1500},{a:'#ffcf3f',b:'#7a0d00',ink:'#fff1e0',edge:'#ff7a1a',pattern:'flames',glow:true}),
  D('eigen','Eigenes Design','personal',{},{a:'#f2c14e',b:'#0b1327',ink:'#ffffff',edge:'#f2c14e',pattern:'rays'})];
 let pd=cfg.granted?{granted:true,name:'Eigenes Design',design:{a:'#f2c14e',b:'#0b1327',ink:'#ffffff',edge:'#f2c14e',pattern:'rays'},equipped:false,
  patterns:['carbon','waves','sparks','aurora','crown','rays','grid','petals','bolts','diamond','stripes','stars','halftone','dots','marble','camo','hex','circuit','tiger','flames']}:{granted:false};
 let equipped='classic';
 let list=[{profile_id:'p-anna',display_name:'Anna',active:false,name:null},{profile_id:'p-ben',display_name:'Ben',active:true,name:'Bens Karte'}];
 const lookOf=k=>k==='eigen'?{key:'eigen',name:pd.name,design:pd.design,awards:[]}:(d=>({key:d.key,name:d.name,design:d.design,awards:[]}))(designs.find(x=>x.key===k));
 const rpc=async(name,args)=>{
  calls.push([name,args]);
  if(name==='get_my_card_designs')return {data:{enabled:true,preview:false,display_name:'Ben',rank:'E',shop:true,coins:500,look:lookOf(equipped),
   designs:designs.map(d=>({...d,available:d.unlock==='start'||(d.unlock==='rank'&&d.min_rank==='E')||(d.unlock==='personal'&&pd.granted)}))},error:null};
  if(name==='get_my_personal_design')return {data:pd,error:null};
  if(name==='save_my_personal_design'){
   if(!/^#[0-9a-f]{6}$/i.test(args.p_design.a))return {data:null,error:{message:'Bitte für alle vier Farben einen Farbcode wählen'}};
   pd={...pd,name:args.p_name.trim(),design:args.p_design};return {data:{name:pd.name,design:pd.design,look:lookOf(equipped)},error:null}}
  if(name==='equip_card_design'){equipped=args.p_key;if(args.p_key==='eigen')pd={...pd,equipped:true};return {data:lookOf(equipped),error:null}}
  if(name==='get_card_awards')return {data:{enabled:true,latest:{},history:[]},error:null};
  if(name==='get_my_performance')return {data:{profile:{id:'p-me',display_name:'Ben',role:cfg.role},ratings_enabled:true,style_enabled:true,rating:null,style:{current:null}},error:null};
  if(name==='staff_card_award_overview')return {data:{today:'2026-10-29',boxers:[],kinds:[]},error:null};
  if(name==='admin_list_personal_designs')return {data:list.map(x=>({...x})),error:null};
  if(name==='admin_set_personal_design'){const x=list.find(y=>y.profile_id===args.p_profile_id);x.active=args.p_active;return {data:{profile_id:x.profile_id,display_name:x.display_name,active:x.active},error:null}}
  if(/looks|get_public_boxer_looks/.test(name))return {data:name==='get_public_boxer_looks'?[]:{},error:null};
  return {data:null,error:{message:'unexpected rpc '+name}};
 };
 const q={select(){return q},eq(){return q},order(){return q},limit(){return q},maybeSingle:async()=>({data:{role:cfg.role,is_active:true},error:null}),then:(r)=>Promise.resolve({data:[],error:null}).then(r)};
 window.__takeoverMockClient={auth:{getSession:async()=>({data:{session:{access_token:'x'}}}),getUser:async()=>({data:{user:{id:'u1'}},error:null}),onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}})},from:()=>q,rpc};
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
  const p=await context.newPage();const errors=[];p.on('pageerror',e=>errors.push(e.message));p.on('dialog',d=>{errors.push('dialog');d.dismiss()});
  await p.route('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm',r=>r.fulfill({status:200,contentType:'text/javascript',body:'export const createClient=()=>window.__takeoverMockClient;'}));
  await p.route('https://iqarjivcrddcixrvqbfb.supabase.co/**',r=>r.fulfill({status:200,contentType:'application/json',body:'[]'}));
  await p.goto(base+file);return {p,errors};
 }
 const noOverflow=async p=>assert.ok(await p.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth),'no horizontal scroll');

 // A: ohne Freischaltung kein Editor, «Eigenes Design» nicht im Katalog; neue Designs mit neuen Mustern sichtbar
 let {p,errors}=await page({role:'boxer',granted:false},'karten.html');
 await p.waitForSelector('.kd-grid');
 assert.equal(await p.locator('.kd-own').count(),0);assert.equal(await p.locator('.kd-item:has-text("Eigenes Design")').count(),0);
 for(const pat of ['stripes','stars','halftone','flames'])assert.ok(await p.locator(`.kd-item .tlp-card[data-pattern="${pat}"]`).count()>=1,'pattern '+pat);
 assert.match(await p.textContent('.kd-item:has-text("Kosmos")'),/ab Rang A/);
 await shot(p,'12-katalog');await noOverflow(p);assert.deepEqual(errors,[]);

 // B: freigeschaltet – gestalten, Vorschau live, speichern, auswählen
 ({p,errors}=await page({role:'boxer',granted:true},'karten.html'));
 await p.waitForSelector('.kd-own-form');
 assert.equal(await p.locator('.kd-own-form input[type=color]').count(),4);
 assert.equal(await p.locator('.kd-own-form select[name=pattern] option').count(),20);
 await p.fill('[name=dname]','Bens Karte');
 await p.locator('[name=a]').evaluate(e=>{e.value='#ff0055';e.dispatchEvent(new Event('input',{bubbles:true}))});
 await p.selectOption('[name=pattern]','flames');
 await p.fill('[name=badge]','ben');
 await p.check('[name=glow]');
 const prev=p.locator('.kd-own-preview .tlp-card');
 assert.equal(await prev.getAttribute('data-pattern'),'flames','preview follows the form');
 assert.match(await prev.getAttribute('style'),/--ca:#ff0055/);assert.match(await prev.getAttribute('class'),/d-glow/);
 assert.equal(await p.textContent('.kd-own-preview .tlp-badge'),'BEN');
 await shot(p,'12-editor');
 await p.click('.kd-own-form button[type=submit]');
 await p.waitForFunction(()=>window.__calls.some(c=>c[0]==='save_my_personal_design'));
 const sv=(await p.evaluate(()=>window.__calls)).find(c=>c[0]==='save_my_personal_design')[1];
 assert.equal(sv.p_name,'Bens Karte');assert.deepEqual(sv.p_design,{a:'#ff0055',b:'#0b1327',ink:'#ffffff',edge:'#f2c14e',pattern:'flames',badge:'BEN',glow:true});
 await p.waitForFunction(()=>/Design «Bens Karte» gespeichert/.test(document.getElementById('status').textContent));
 await p.click('[data-equip="eigen"]');
 await p.waitForFunction(()=>/Design ausgewählt/.test(document.getElementById('status').textContent));
 assert.match(await p.textContent('.kd-own'),/Deine Karte zeigt dieses Design/);
 assert.match(await p.textContent('.tlp-big'),/Bens Karte/);
 await noOverflow(p);assert.deepEqual(errors,[]);

 // C: Admin schaltet frei und entzieht
 ({p,errors}=await page({role:'admin',granted:false},'karten.html?view=staff'));
 await p.waitForSelector('.kd-pd-list');
 assert.match(await p.textContent('.kd-pd-list'),/Anna[\s\S]*Freischalten[\s\S]*Ben[\s\S]*freigeschaltet · Bens Karte[\s\S]*Entziehen/);
 await p.click('[data-pd="p-anna"]');
 await p.waitForFunction(()=>/Eigenes Design für Anna freigeschaltet/.test(document.getElementById('status').textContent));
 const st=(await p.evaluate(()=>window.__calls)).find(c=>c[0]==='admin_set_personal_design')[1];
 assert.deepEqual(st,{p_profile_id:'p-anna',p_active:true});
 await p.click('[data-pd="p-ben"]');
 await p.waitForFunction(()=>/Eigenes Design für Ben entzogen/.test(document.getElementById('status').textContent));
 await shot(p,'12-admin');assert.deepEqual(errors,[]);

 // D: Trainer sieht den Admin-Bereich nicht
 ({p,errors}=await page({role:'coach',granted:false},'karten.html?view=staff'));
 await p.waitForSelector('.fb-tab.on');await p.waitForTimeout(300);
 assert.equal(await p.locator('.kd-pd-list').count(),0);
 assert.ok(!(await p.evaluate(()=>window.__calls)).some(c=>c[0]==='admin_list_personal_designs'));

 for(const c of ctxs)await c.close();
 await browser.close();server.close();
 console.log('PASS: Etappe 12 im Browser – neue Designs mit neuen Mustern, eigenes Design gestalten mit Live-Vorschau, speichern, auswählen, Admin schaltet frei und entzieht, Trainer ohne Admin-Bereich');
})().catch(e=>{console.error(e);process.exit(1)});
