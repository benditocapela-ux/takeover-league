'use strict';
const assert=require('node:assert/strict'),pw=require('playwright'),fs=require('node:fs'),path=require('node:path'),H=require('./takeover3-harness.cjs');
const config=`{users:[{id:'staff',email:'coach@example.invalid'}],tables:{profiles:[{id:'coach',auth_user_id:'staff',role:'coach',is_active:true,archived_at:null}]},rpc:{
 league_archive_period:async a=>{const rows=window.__closed?[{id:'result',name:'Synthetischer Boxer mit sehr langem Namen',rank:1,points:20,exp:40}]:[];
  return {data:{version:1,kind:a.p_kind,key:a.p_key,title:a.p_key,starts_on:a.p_key+'-01',ends_on:a.p_key+'-31',status:window.__closed?'official':'reconstructed',official:!!window.__closed,source:window.__closed?'month_snapshot':'current_ledger_reconstruction',rows,top:rows,honors:[],total:rows.length,next_offset:null,my_result:null,reward:{additional_payout:false}},error:null}},
 league_period_close_preview:async a=>{window.__previewCalls=(window.__previewCalls||0)+1;if(window.__mode==='missing')return {data:null,error:{code:'PGRST202'}};
 const p={version:1,kind:a.p_kind,key:a.p_key,title:'Oktober 2026',starts_on:'2026-10-01',ends_on:'2026-10-31',revision:'a'.repeat(32),status:'awaiting_close',can_close:window.__mode!=='pending',trainings:{approved:5,pending:window.__mode==='pending'?1:0,rejected:2},blockers:window.__mode==='pending'?[{message:'Offene Trainings zuerst prüfen.'}]:[],ranked_count:1,rows:[{boxer_name:'Synthetischer Boxer mit sehr langem Namen',rank_position:1,points:20,exp:40}],reward:{status:'not_configured',additional_payout:false,planned_bookings:[]}};window.__preview=p;return {data:window.__mode==='malformed'?{}:p,error:null}},
 league_period_close_confirm:async a=>{window.__confirmCalls=(window.__confirmCalls||0)+1;window.__confirmArgs=a;await new Promise(r=>setTimeout(r,80));if(window.__mode==='error')return {data:null,error:{message:'network'}};
 if(window.__mode==='changed'){window.__mode='ok';return {data:{status:'changed',preview:{...window.__preview,revision:'b'.repeat(32)}},error:null}}
 window.__closed=true;return {data:{status:'closed',kind:a.p_kind,key:a.p_key,additional_payout:false,bookings:[],notification_count:1},error:null}}
}}`;
(async()=>{const {server,base}=await H.serve();try{for(const engine of ['chromium','webkit']){const browser=await pw[engine].launch();try{for(const width of [320,390,1280]){
 const context=await H.context(browser,{viewport:{width,height:844},config});await context.route('**/rest/v1/league_seasons_v21?**',r=>r.fulfill({contentType:'application/json',body:'[]'}));
 const page=await context.newPage(),errors=[];page.on('pageerror',e=>errors.push(e.message));
 try{
  await page.goto(base+'/league-history.html?month=2026-10');await page.waitForFunction(()=>document.querySelector('#periodStatus').textContent.includes('Rekonstruierter'));
  assert.equal(await page.locator('#periodClose').isVisible(),false);assert.equal(await page.evaluate(()=>window.__previewCalls||0),0);
  await page.evaluate(async()=>{const m=await import('./takeover-client.js');await m.createClient('https://iqarjivcrddcixrvqbfb.supabase.co','x').auth.signInWithPassword({email:'coach@example.invalid',password:'pw'})});
  await page.locator('#periodClose:not([hidden])').waitFor();assert.equal(await page.evaluate(()=>window.__previewCalls||0),0,'opening archive is read-only');
  const dialog=page.locator('.period-close-dialog'),confirm=dialog.getByRole('button',{name:'Ergebnis verbindlich abschliessen'});
  for(const mode of ['pending','missing','malformed']){
   await page.evaluate(m=>window.__mode=m,mode);await page.locator('#periodClose button').click();await page.waitForFunction(()=>!document.querySelector('.period-close-dialog [role=status]').textContent.includes('Lese Abschlussvorschau'));
   assert.equal(await confirm.isVisible(),false,mode);assert.equal(await page.evaluate(()=>window.__confirmCalls||0),0);
   await dialog.getByRole('button',{name:'Schliessen',exact:true}).click();
  }
  await page.evaluate(()=>window.__mode='ok');await page.locator('#periodClose button').click();await confirm.waitFor();assert.equal(await page.evaluate(()=>window.__confirmCalls||0),0);
  await page.keyboard.press('Escape');assert.equal(await dialog.isVisible(),false);assert.equal(await page.locator('#periodClose button').evaluate(e=>e===document.activeElement),true);
  await page.evaluate(()=>window.__mode='changed');await page.locator('#periodClose button').click();await confirm.waitFor();await confirm.click();await dialog.getByText(/Die Daten haben sich geändert/).waitFor();
  assert.equal(await page.evaluate(()=>window.__confirmCalls),1,'new revision needs a second explicit action');
  await confirm.evaluate(e=>{e.click();e.click()});await dialog.getByText(/Ergebnis offiziell gespeichert/).waitFor();assert.equal(await page.evaluate(()=>window.__confirmCalls),2,'double click sent once');
  assert.deepEqual(await page.evaluate(()=>window.__confirmArgs),{p_kind:'month',p_key:'2026-10',p_confirm:true,p_revision:'b'.repeat(32)});
  await page.waitForFunction(()=>document.querySelector('#periodSummary').textContent.includes('Gespeicherter Monatsendstand'));assert.equal(await dialog.isVisible(),true,'server receipt retained after snapshot reload');
  assert.match(await page.locator('#results').innerText(),/20 Punkte · 40 EXP/);assert.match(await page.locator('#periodStatus').innerText(),/1 von 1/);
  if(width===390){const out=path.join(H.root,'output/seven-hour/period-close');fs.mkdirSync(out,{recursive:true});await page.screenshot({path:path.join(out,engine+'-receipt.png'),fullPage:true})}
  await dialog.getByRole('button',{name:'Schliessen',exact:true}).click();await page.evaluate(()=>window.__mode='error');await page.locator('#periodClose button').click();await confirm.waitFor();await confirm.click();await dialog.getByText(/Kein Abschluss bestätigt/).waitFor();assert.equal(await confirm.isVisible(),true);
  await page.evaluate(async()=>{const m=await import('./takeover-client.js');await m.createClient('https://iqarjivcrddcixrvqbfb.supabase.co','x').auth.signOut()});await page.waitForFunction(()=>document.querySelector('#periodClose').hidden);assert.equal(await dialog.isVisible(),false);
  assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));assert.deepEqual(errors,[]);
  console.log('PASS '+engine+' '+width+' period preview/explicit close/stale revision/double click/snapshot receipt/guest/account switch/errors');
 }finally{await context.close()}
 }}finally{await browser.close()}}}finally{server.close()}})().catch(e=>{console.error(e);process.exitCode=1});
