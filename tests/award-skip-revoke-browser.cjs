'use strict';
// Chromium test with mocked Supabase (no real account, no server writes) for Etappe 14:
// «Diesmal nicht vergeben» wählen und aufheben, frühere Auszeichnungen zurückziehen (nur wer darf), frühere «nicht vergeben» sichtbar.
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
 const designs=[{key:'classic',name:'Klassisch',description:'',unlock:'start',design:{tier:true},available:true}];
 const aw=(id,kind,ps,pe,name,by,can)=>({id,kind,period_start:ps,period_end:pe,display_name:name,awarded_by:by,exp:100,note:null,revoked:false,can_revoke:can});
 const st={skips:{cotw:null,cotm:{id:3,kind:'cotm',period_start:'2026-09-01',period_end:'2026-09-30',note:'Ferien',skipped_by:'Marco',can_undo:true},poty:null},
  recent:[aw(9,'poty','2025-01-01','2025-12-31','Ben','Marco',true),aw(11,'cotw','2026-09-28','2026-10-04','Anna','Marco',true),aw(12,'cotm','2026-07-01','2026-07-31','Ben','Bendo',false)],
  older:[{id:4,kind:'cotw',period_start:'2026-10-05',period_end:'2026-10-11',note:null,skipped_by:'Bendo',can_undo:false}]};
 const per={cotw:['2026-10-19','2026-10-25','2026-10-26','2026-11-01'],cotm:['2026-09-01','2026-09-30','2026-10-01','2026-10-31'],poty:['2025-01-01','2025-12-31','2026-01-01','2026-12-31']};
 const overview=()=>({today:'2026-10-29',boxers:[{id:'p-anna',display_name:'Anna'},{id:'p-ben',display_name:'Ben'}],
  kinds:['cotw','cotm','poty'].map(k=>({kind:k,periods:[
   {start:per[k][0],end:per[k][1],completed:true,candidates:[{profile_id:'p-anna',display_name:'Anna',exp:120,trainings:2}],
    award:k==='poty'?st.recent.find(a=>a.id===9)||null:null,skip:st.skips[k]},
   {start:per[k][2],end:per[k][3],completed:false,candidates:[],award:null,skip:null}]})),
  recent:st.recent,skips:[...Object.values(st.skips).filter(Boolean),...st.older]});
 const rpc=async(name,args)=>{
  calls.push([name,args]);
  if(name==='get_my_card_designs')return {data:{enabled:true,preview:false,display_name:'Marco',rank:'E',shop:false,coins:null,look:{key:'classic',name:'Klassisch',design:{tier:true},awards:[]},designs},error:null};
  if(name==='get_my_personal_design')return {data:{granted:false},error:null};
  if(name==='get_card_awards')return {data:{enabled:true,latest:{},history:[]},error:null};
  if(name==='get_my_performance')return {data:{profile:{id:'p-me',display_name:'Marco',role:cfg.role},ratings_enabled:true,style_enabled:true,rating:null,style:{current:null}},error:null};
  if(name==='staff_card_award_overview')return {data:overview(),error:null};
  if(name==='staff_skip_card_award'){st.skips[args.p_kind]={id:20,kind:args.p_kind,period_start:args.p_period_start,period_end:per[args.p_kind][1],note:args.p_note,skipped_by:'Marco',can_undo:true};return {data:st.skips[args.p_kind],error:null}}
  if(name==='staff_unskip_card_award'){for(const k of Object.keys(st.skips))if(st.skips[k]&&st.skips[k].id===args.p_skip_id)st.skips[k]=null;return {data:{id:args.p_skip_id,undone:true},error:null}}
  if(name==='staff_revoke_card_award'){st.recent=st.recent.filter(a=>a.id!==args.p_award_id);return {data:{id:args.p_award_id,revoked:true},error:null}}
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

 // Trainer: Woche nicht vergeben, Monat wieder aufheben, frühere Auszeichnung zurückziehen
 let {p,errors}=await page({role:'coach'},'karten.html?view=staff');
 await p.waitForSelector('.kd-confirm');
 const sec=k=>p.locator('section.tlp-panel:has(.kd-period)').nth(['cotw','cotm','poty'].indexOf(k));
 // Monat: «nicht vergeben» sichtbar mit Grund, «Doch vergeben»
 assert.match(await sec('cotm').textContent(),/Nicht vergeben · von Marco · «Ferien»[\s\S]*Doch vergeben/);
 assert.equal(await p.locator('.kd-confirm[data-kind="cotm"]').count(),0,'no confirm while skipped');
 // Jahr: vergeben → Zurückziehen eingeklappt
 assert.match(await sec('poty').textContent(),/Ben[\s\S]*Zurückziehen/);
 // Frühere Zeiträume: Anna (darf zurückziehen), Ben von Bendo (nur Anzeige), frühere Woche nicht vergeben ohne Knopf
 const older=p.locator('section.tlp-panel:has(h2:text("Frühere Zeiträume"))');
 const ot=await older.textContent();
 assert.match(ot,/Anna · Card of the Week[\s\S]*Zurückziehen/);assert.match(ot,/Ben · Card of the Month[\s\S]*vergeben von Bendo/);
 assert.match(ot,/Card of the Week · 05\.10\.2026 – 11\.10\.2026 · nicht vergeben/);
 assert.equal(await older.locator('.kd-revoke').count(),1,'only own awards revocable');assert.equal(await older.locator('[data-unskip]').count(),0);
 assert.doesNotMatch(ot,/Ben · Player of the Year/,'award shown above is not repeated');
 await shot(p,'14-vergeben');await noOverflow(p);
 // Woche: diesmal nicht vergeben (mit Grund)
 const wk=p.locator('.kd-period').first();
 await wk.locator('.kd-more:has(.kd-skip) > summary').click();
 await wk.locator('.kd-skip input[name="note"]').fill('Ferienwoche');await wk.locator('.kd-skip button').click();
 await p.waitForFunction(()=>/Card of the Week: diesmal nicht vergeben/.test(document.getElementById('status').textContent));
 assert.deepEqual((await p.evaluate(()=>window.__calls)).find(c=>c[0]==='staff_skip_card_award')[1],{p_kind:'cotw',p_period_start:'2026-10-19',p_note:'Ferienwoche'});
 assert.match(await p.locator('.kd-period').first().textContent(),/Nicht vergeben · von Marco · «Ferienwoche»/);
 assert.equal(await p.locator('.kd-confirm[data-kind="cotw"]').count(),0);
 // Monat: doch vergeben
 await p.click('[data-unskip="3"]');
 await p.waitForFunction(()=>/aufgehoben/.test(document.getElementById('status').textContent));
 assert.deepEqual((await p.evaluate(()=>window.__calls)).find(c=>c[0]==='staff_unskip_card_award')[1],{p_skip_id:3});
 assert.equal(await p.locator('.kd-confirm[data-kind="cotm"]').count(),1,'confirm form back');
 // Frühere Auszeichnung zurückziehen: ohne Grund nicht, mit Grund schon
 const ol=p.locator('section.tlp-panel:has(h2:text("Frühere Zeiträume"))');
 await ol.locator('.kd-more > summary').first().click();
 await ol.locator('.kd-revoke button').click();await p.waitForTimeout(200);
 assert.ok(!(await p.evaluate(()=>window.__calls)).some(c=>c[0]==='staff_revoke_card_award'),'no revoke without reason');
 await ol.locator('.kd-revoke input').fill('Falsch eingetragen');await ol.locator('.kd-revoke button').click();
 await p.waitForFunction(()=>/zurückgezogen/.test(document.getElementById('status').textContent));
 assert.deepEqual((await p.evaluate(()=>window.__calls)).find(c=>c[0]==='staff_revoke_card_award')[1],{p_award_id:11,p_reason:'Falsch eingetragen'});
 assert.doesNotMatch(await p.textContent('#app'),/Anna · Card of the Week/);
 await noOverflow(p);assert.deepEqual(errors,[]);

 for(const c of ctxs)await c.close();
 await browser.close();server.close();
 console.log('PASS: Etappe 14 im Browser – «Diesmal nicht vergeben» mit Grund, «Doch vergeben», frühere Auszeichnungen zurückziehen (nur eigene bzw. als Admin, Grund nötig), frühere «nicht vergeben» sichtbar');
})().catch(e=>{console.error(e);process.exit(1)});
