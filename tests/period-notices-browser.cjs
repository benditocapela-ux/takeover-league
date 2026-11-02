'use strict';
const assert=require('node:assert/strict'),pw=require('playwright'),H=require('./takeover3-harness.cjs');
const config=`{users:[{id:'a',email:'a@example.invalid'},{id:'b',email:'b@example.invalid'}],rpc:{league_period_notices:async()=>{
 const uid=JSON.parse(localStorage.getItem('${H.KEY}')||'null')?.user?.id;window.__noticeReads=(window.__noticeReads||0)+1;
 const phase=window.__phase||'awaiting_close';const rows=[{kind:'month',period_key:'2026-10',title:'2026-10',phase,event_key:'period:month:2026-10:'+phase,result_path:'league-history.html?month=2026-10'},
 {kind:'season',period_key:'30000000-0000-0000-0000-000000000001',title:'Herbst abgeschlossen',phase:'closed',event_key:'period:season:30000000-0000-0000-0000-000000000001:closed',result_path:'league-history.html?season=30000000-0000-0000-0000-000000000001'}];
 const items=rows.filter(n=>!window.__dismissed?.[uid]?.includes(n.event_key));if(window.__slow)await new Promise(r=>setTimeout(r,100));return {data:{version:1,enabled:true,items},error:null}},
 league_period_notice_dismiss:async a=>{if(window.__error)return {data:null,error:{message:'offline'}};const uid=JSON.parse(localStorage.getItem('${H.KEY}')).user.id;window.__dismissed=window.__dismissed||{};window.__dismissed[uid]=[...(window.__dismissed[uid]||[]),a.p_event_key];return {data:true,error:null}}}}`;
(async()=>{const {server,base}=await H.serve();try{for(const engine of ['chromium','webkit']){const browser=await pw[engine].launch();try{for(const width of [320,390,1280]){
 const context=await H.context(browser,{config,viewport:{width,height:844}}),page=await context.newPage(),errors=[];page.on('pageerror',e=>errors.push(e.message));
 try{await page.goto(base+'/index.html');await page.waitForTimeout(150);assert.equal(await page.locator('.tl-period-notice').count(),0);assert.equal(await page.evaluate(()=>window.__noticeReads||0),0,'guest has no personal RPC');
 const signIn=email=>page.evaluate(async email=>{const m=await import('./takeover-client.js');await m.createClient('https://iqarjivcrddcixrvqbfb.supabase.co','x').auth.signInWithPassword({email,password:'pw'})},email);
 await signIn('a@example.invalid');await page.waitForFunction(()=>document.querySelectorAll('.tl-period-notice').length===2);
 const month=page.locator('.tl-period-notice').filter({hasText:'Oktober 2026'});assert.match(await month.innerText(),/Auswertung läuft/);assert.match(await month.locator('a').getAttribute('href'),/month=2026-10/);
 await month.getByRole('button').click();await page.waitForFunction(()=>document.querySelectorAll('.tl-period-notice').length===1);
 await signIn('b@example.invalid');await page.waitForFunction(()=>document.querySelectorAll('.tl-period-notice').length===2);
 await signIn('a@example.invalid');await page.waitForFunction(()=>document.querySelectorAll('.tl-period-notice').length===1);
 await page.evaluate(()=>{window.__phase='closed';document.dispatchEvent(new Event('visibilitychange'))});await page.waitForFunction(()=>document.querySelectorAll('.tl-period-notice').length===2);
 assert.match(await month.innerText(),/abgeschlossen – Ergebnis ansehen/);assert.equal(await page.locator('.tl-period-notice a').count(),2);
 await page.evaluate(()=>window.__error=true);await month.getByRole('button').click();await month.getByText(/konnte nicht gespeichert/).waitFor();assert.equal(await page.locator('.tl-period-notice').count(),2);
 await page.evaluate(async()=>{window.__slow=true;document.dispatchEvent(new Event('visibilitychange'));const m=await import('./takeover-client.js');await m.createClient('https://iqarjivcrddcixrvqbfb.supabase.co','x').auth.signOut()});await page.waitForTimeout(180);assert.equal(await page.locator('.tl-period-notice').count(),0,'old async response suppressed on logout');
 assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));assert.deepEqual(errors,[]);console.log('PASS '+engine+' '+width+' period banners: personal dismissal, new-phase resurfacing, separate periods, exact links, logout and failure');
 }finally{await context.close()}
 }}finally{await browser.close()}}}finally{server.close()}})().catch(e=>{console.error(e);process.exitCode=1});
