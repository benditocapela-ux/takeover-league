'use strict';
// Real browser / synthetic read-only RPCs. SQL authorization is tested separately.
const pw=require('playwright'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),H=require('./takeover3-harness.cjs');
const sid='30000000-0000-0000-0000-000000000001';
const config=`{rpc:{league_archive_period:async args=>{
 window.__archiveCalls=window.__archiveCalls||[];window.__archiveCalls.push(args);
 const scenario=window.__archiveScenario||'ok';
 if(scenario==='missing')return {data:null,error:{code:'PGRST202'}};
 const official=args.p_kind==='season',prefix=official?'Saison Alpha ':'Monat '+args.p_key+' ',count=scenario==='empty'?0:42;
 const rows=Array.from({length:count},(_,i)=>({id:'row-'+i,name:prefix+i,rank:i+1,points:100-i,exp:30+i,captured_at:official?'2026-10-01T00:00:00Z':null}));
 const data={version:1,kind:args.p_kind,key:scenario==='wrongperiod'?'2020-01':args.p_key,title:official?'September offiziell':args.p_key,
 starts_on:official?'2026-09-01':args.p_key+'-01',ends_on:official?'2026-09-30':args.p_key+'-28',status:official?'official':'reconstructed',official,source:official?'season_snapshot':'current_ledger_reconstruction',
 rows:rows.slice(args.p_offset,args.p_offset+args.p_limit),top:rows.slice(0,3),honors:official?[{name:'Saison Alpha 0',title:'Saisonmeister',description:'Gespeicherte Ehrung'}]:[],total:count,
 next_offset:args.p_offset+args.p_limit<count?args.p_offset+args.p_limit:null,my_result:window.__archiveMine?rows[35]:null,reward:{additional_payout:false,status:'not_configured'}};
 if(scenario==='slow'){const delay=args.p_key==='2026-09'?150:10;await new Promise(r=>setTimeout(r,delay))}return {data,error:null};
 }}}`;
(async()=>{const {server,base}=await H.serve();try{for(const engine of ['chromium','webkit']){const browser=await pw[engine].launch();try{for(const width of [320,390,1280]){
 const context=await H.context(browser,{viewport:{width,height:844},config});
 await context.route('**/rest/v1/league_seasons_v21?**',route=>route.fulfill({contentType:'application/json',body:JSON.stringify([{id:sid,title:'September offiziell',starts_on:'2026-09-01',ends_on:'2026-09-30',status:'closed'}])}));
 const page=await context.newPage(),errors=[];page.on('pageerror',e=>errors.push(e.message));
 try{
  await page.goto(base+'/league-history.html?month=2026-10');await page.locator('#results article').first().waitFor();
  assert.equal(await page.locator('#results article').count(),20);assert.match(await page.locator('#periodSummary').innerText(),/Kein offizieller Abschluss/);assert.match(await page.locator('#periodTitle').innerText(),/Oktober 2026/i);
  assert.equal(await page.locator('#periodMine').isVisible(),false);await page.click('#moreResults');await page.waitForFunction(()=>document.querySelectorAll('#results article').length===40);await page.click('#moreResults');await page.waitForFunction(()=>document.querySelectorAll('#results article').length===42);assert.equal(await page.locator('#moreResults').isVisible(),false);
  const requests=await page.evaluate(()=>window.__archiveCalls);assert.deepEqual(requests.map(r=>r.p_offset),[0,20,40]);assert.ok(requests.every(r=>r.p_key==='2026-10'&&r.p_limit===20));
  await page.selectOption('#periodKind','season');await page.selectOption('#periodSeason',sid);await page.click('#periodForm button');await page.waitForFunction(()=>document.querySelector('#periodSummary').textContent.includes('Gespeicherter Saisonendstand'));
  assert.equal(await page.locator('#results article').count(),20);assert.doesNotMatch(await page.locator('#results').innerText(),/Monat/);assert.match(page.url(),new RegExp('season='+sid));assert.match(await page.locator('#honors').innerText(),/Saisonmeister/);
  await page.goto(base+'/league-history.html?season='+sid);await page.locator('#results article').first().waitFor();assert.match(await page.locator('#periodTitle').innerText(),/September offiziell/i);
  await page.evaluate(()=>window.__archiveMine=true);await page.click('#periodForm button');await page.locator('#periodMine:not([hidden])').waitFor();assert.match(await page.locator('#periodMine').innerText(),/#36/);
  await page.evaluate(async()=>{window.__archiveMine=false;const m=await import('./takeover-client.js');await m.createClient('https://iqarjivcrddcixrvqbfb.supabase.co','x').auth.signOut()});await page.waitForFunction(()=>document.querySelector('#periodMine').hidden);assert.equal(await page.locator('#periodMine').innerText(),'');
  for(const scenario of ['missing','wrongperiod','empty']){await page.evaluate(s=>window.__archiveScenario=s,scenario);await page.click('#periodForm button');await page.waitForFunction(()=>!document.querySelector('#periodStatus').textContent.startsWith('Lade'));
   assert.equal(await page.locator('#results article').count(),0,scenario+' clears stale rows');assert.equal(await page.locator('#moreResults').isVisible(),false);
  }
  await page.evaluate(()=>window.__archiveScenario='slow');await page.selectOption('#periodKind','month');await page.fill('#periodMonth','2026-09');await page.click('#periodForm button');await page.fill('#periodMonth','2026-10');await page.click('#periodForm button');await page.waitForFunction(()=>document.querySelector('#results').textContent.includes('Monat 2026-10'));await page.waitForTimeout(180);assert.doesNotMatch(await page.locator('#results').innerText(),/2026-09/);
  assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),'no overflow '+width);
  if(width===390){const out=path.join(H.root,'output/seven-hour/archive');fs.mkdirSync(out,{recursive:true});await page.screenshot({path:path.join(out,engine+'-month.png'),fullPage:true})}
  await page.goto(base+'/league-history.html?season=invalid');await page.getByText(/Ungültiger Zeitraum-Link/).waitFor();assert.equal(await page.evaluate(()=>window.__archiveCalls?.length||0),0);
  await page.goto(base+'/league-history.html?month=2026-10&season='+sid);await page.getByText(/Der Link enthält zwei Perioden/).waitFor();assert.equal(await page.evaluate(()=>window.__archiveCalls?.length||0),0);
  assert.deepEqual(errors,[]);console.log('PASS '+engine+' '+width+' archive deep links/pagination/read-only/provenance/stale session/errors');
 }finally{await context.close()}
 }}finally{await browser.close()}}}finally{server.close()}})().catch(e=>{console.error(e);process.exitCode=1});
