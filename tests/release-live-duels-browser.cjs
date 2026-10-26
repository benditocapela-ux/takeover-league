'use strict';
// Chromium UI integration only: simulated Supabase sessions and RPC payloads,
// no external authentication and no writes to production.
const assert=require('node:assert/strict');
const {chromium}=require('playwright');
const fs=require('node:fs'),http=require('node:http'),path=require('node:path');
const root=process.cwd();
const server=http.createServer((req,res)=>{
 const url=new URL(req.url,'http://127.0.0.1');
 const name=url.pathname==='/'?'index.html':decodeURIComponent(url.pathname.slice(1));
 const file=path.resolve(root,name);
 if(!file.startsWith(root+path.sep)){res.writeHead(403);res.end();return}
 fs.readFile(file,(err,body)=>{if(err){res.writeHead(404);res.end();return}
  const ext=path.extname(file);
  res.setHeader('content-type',ext==='.html'?'text/html':ext==='.js'?'text/javascript':ext==='.css'?'text/css':'application/octet-stream');
  res.end(body);
 });
});
function setupFixture(){
 const challenger='aaaa1111-1111-4111-8111-111111111111';
 const opponent='bbbb2222-2222-4222-8222-222222222222';
 const d1='dddd1111-1111-4111-8111-111111111111';
 const d2='dddd2222-2222-4222-8222-222222222222';
 const d3='dddd3333-3333-4333-8333-333333333333';
 const d4='dddd4444-4444-4444-8444-444444444444';
 const next=ms=>new Date(Date.now()+ms).toISOString();
 const base={challenger_id:challenger,opponent_id:opponent,challenger_name:'Boxer Alpha',opponent_name:'Boxer Beta',
   duration_days:7,invited_at:next(-86400000*3),expires_at:next(-86400000*1),
   accepted_at:next(-86400000*2),settled_at:null,challenger_score:0,opponent_score:0,winner_id:null};
 let duels=[
  {...base,id:d1,status:'active',ends_at:next(86400000*5)},
  {...base,id:d2,status:'awaiting_reviews',ends_at:next(-3600000)},
  {...base,id:d3,status:'settled',ends_at:next(-86400000*3),settled_at:next(-3600000),
   challenger_score:80,opponent_score:40,winner_id:challenger},
  {...base,id:d4,status:'pending',ends_at:null,accepted_at:null,invited_at:next(-3600000),
   expires_at:next(86400000),opponent_id:challenger,challenger_id:opponent,
   challenger_name:'Boxer Beta',opponent_name:'Boxer Alpha'}
 ];
 const scores={
  [d1]:{challenger_score:70,opponent_score:40,pending:1,status:'active',provisional:true},
  [d2]:{challenger_score:100,opponent_score:110,pending:2,status:'awaiting_reviews',provisional:true},
  [d4]:{challenger_score:0,opponent_score:0,pending:0,status:'active',provisional:true}
 };
 const clientState={scenario:'ok',calls:[],accepted:0};
 window.__liveDuelsState=clientState;
 const profiles=[{id:challenger,auth_user_id:'abcd0000-0000-4000-8000-000000000001',role:'boxer',is_active:true}];
 window.__liveDuelsSupabase={
  auth:{
   getUser:async()=>({data:{user:{id:profiles[0].auth_user_id}},error:null}),
   onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}}),
   signInWithPassword:async()=>({error:null}),signOut:async()=>({error:null})
  },
  from(name){return {
   select(){return this},
   eq(){return this},
   async maybeSingle(){return {data:name==='profiles'?profiles[0]:null,error:null}}
  }},
  async rpc(name,args){
   clientState.calls.push({name,args});
   if(name==='duel_v2_list_mine')return {data:duels,error:null};
   if(name==='duel_v2_eligible_boxers')return {data:[
     {id:challenger,display_name:'Boxer Alpha'}, {id:opponent,display_name:'Boxer Beta'}],error:null};
   if(name==='duel_v2_live_scores'){
    if(clientState.scenario==='missing')return {data:null,error:{code:'PGRST202',message:'Could not find the function'}};
    if(clientState.scenario==='malformed')return {data:{...scores[args.p_duel_id],challenger_score:-1},error:null};
    return {data:scores[args.p_duel_id]||null,error:null};
   }
   if(name==='duel_v2_respond'){
    clientState.accepted++;
    duels=duels.map(x=>x.id===args.p_duel_id?{...x,status:'active',accepted_at:next(-60000),ends_at:next(86400000*7)}:x);
    return {data:{status:'active'},error:null};
   }
   return {data:null,error:{message:'Unexpected mock RPC '+name}};
  }
 };
}
async function main(){
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 const base='http://127.0.0.1:'+server.address().port;
 const browser=await chromium.launch({headless:true,args:['--no-sandbox']});
 try{
  for(const width of [375,1280]){
   const context=await browser.newContext({viewport:{width,height:850},hasTouch:width===375,isMobile:width===375});
   try{
    await context.addInitScript({content:'('+setupFixture.toString()+')()'});
    const page=await context.newPage();page.setDefaultTimeout(15000);
    page.on('dialog',dialog=>dialog.accept());
    await page.route('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm',route=>
     route.fulfill({status:200,contentType:'text/javascript',body:'export const createClient=()=>window.__liveDuelsSupabase;'}));
    await page.goto(base+'/duels.html',{waitUntil:'domcontentloaded'});
    await page.waitForFunction(()=>document.querySelectorAll('[data-live-duel]').length===2);
    await page.waitForFunction(()=>document.querySelector('[data-live-duel] .live-points')?.textContent.includes('70'));
    assert.equal(await page.locator('#invite label:has(select[name="challenger"]) + .tl-choice-field .tl-choice-card').count(),1,'Boxer should see their own challenger card');
    assert.equal(await page.locator('#invite label:has(select[name="opponent"]) + .tl-choice-field .tl-choice-card').count(),1,'Eligible opponent should be rendered as a choice card');
    assert.equal(await page.locator('#invite label:has(select[name="duration"]) + .tl-choice-field .tl-choice-card').count(),2,'Both supported duel durations should be visible');
    await page.locator('#invite label:has(select[name="opponent"]) + .tl-choice-field .tl-choice-card').click();
    assert.equal(await page.locator('#invite select[name="opponent"]').inputValue(),'bbbb2222-2222-4222-8222-222222222222','Opponent card must update the existing select value');
    await page.locator('#invite label:has(select[name="duration"]) + .tl-choice-field .tl-choice-card[data-value="14"]').click();
    assert.equal(await page.locator('#invite select[name="duration"]').inputValue(),'14','Duration card must update the existing select value');
    await page.locator('#invite label:has(select[name="duration"]) + .tl-choice-field .tl-choice-card[data-value="7"]').click();
    assert.equal(await page.locator('#invite select[name="duration"]').inputValue(),'7','Duration can be changed back using the card');
    assert.equal(await page.locator('[data-live-duel]').count(),2);
    assert.match(await page.locator('[data-live-duel]').first().innerText(),/70 : 40/);
    assert.match(await page.locator('[data-live-duel]').first().innerText(),/1 offenes Training kann/);
    assert.match(await page.locator('[data-live-duel]').nth(1).innerText(),/100 : 110/);
    assert.match(await page.locator('[data-live-duel]').nth(1).innerText(),/Auswertung läuft/);
    assert.match(await page.locator('#duelList').innerText(),/Endstand \(Trainingspunkte\): 80 : 40/);
    assert.equal(await page.locator('[data-live-duel] .live-track[role=img]').count(),2);
    assert.match(await page.locator('#liveOverviewStatus').innerText(),/Aktualisierung alle 90 Sekunden/);
    const overflow=await page.evaluate(()=>document.documentElement.scrollWidth-innerWidth);
    assert.ok(overflow<=4,'Horizontal overflow at '+width+': '+overflow);
    console.log('PASS live dual scores, pending review, settled scores, responsive width '+width);

    await page.evaluate(()=>{window.__liveDuelsState.scenario='missing'});
    await page.locator('#refresh').click();
    await page.waitForFunction(()=>document.querySelector('[data-live-duel]')?.textContent.includes('noch nicht freigeschaltet'));
    assert.equal(await page.locator('[data-live-duel] .live-points').count(),0,'Stale score was displayed after failed update');
    assert.match(await page.locator('#liveOverviewStatus').innerText(),/2 Zwischenstände nicht verfügbar/);
    console.log('PASS missing DB function shows explicit error, stale scores cleared');

    await page.evaluate(()=>{window.__liveDuelsState.scenario='malformed'});
    await page.locator('#refresh').click();
    await page.waitForFunction(()=>document.querySelector('[data-live-duel]')?.textContent.includes('ungültiges Datenformat'));
    assert.equal(await page.locator('[data-live-duel] .live-points').count(),0);
    console.log('PASS malformed server score fails closed');

    await page.evaluate(()=>{window.__liveDuelsState.scenario='ok'});
    await page.locator('#refresh').click();
    await page.waitForFunction(()=>document.querySelector('[data-live-duel] .live-points')?.textContent.includes('70'));
    assert.match(await page.locator('#liveOverviewStatus').innerText(),/0?[0-9]:[0-9][0-9]|Aktualisierung alle 90 Sekunden/);

    await page.getByRole('button',{name:'Annehmen',exact:true}).first().click();
    await page.waitForFunction(()=>window.__liveDuelsState.accepted===1);
    await page.waitForFunction(()=>document.querySelectorAll('[data-live-duel]').length===3);
    assert.match(await page.locator('#duelList').innerText(),/Vorläufiger Zwischenstand: 0 : 0/);
    console.log('PASS accept invitation triggers newly active zero-score duel');
   }finally{await context.close()}
  }
 }finally{await browser.close();server.close()}
}
main().catch(err=>{console.error('LIVE DUEL BROWSER FAILED',err);server.close();process.exit(1)});
