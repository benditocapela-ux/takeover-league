'use strict';
// Full Chromium UI smoke with simulated API; never uses a production login.
const assert=require('node:assert/strict'),fs=require('node:fs'),http=require('node:http'),path=require('node:path');
const {chromium}=require('playwright');
const root=process.cwd(),mime={'.html':'text/html','.js':'text/javascript','.css':'text/css','.webp':'image/webp'};
const server=http.createServer((req,res)=>{
 const rel=(new URL(req.url,'http://localhost').pathname.slice(1)||'index.html');
 const file=path.resolve(root,decodeURIComponent(rel));
 if(!file.startsWith(root+path.sep)){res.writeHead(403);res.end();return}
 fs.readFile(file,(err,buf)=>{if(err){res.writeHead(404);res.end();return}
 res.setHeader('Content-Type',mime[path.extname(file)]||'application/octet-stream');res.end(buf)});
});
function mockSupabase(){
 const id='11111111-1111-4111-8111-111111111111';
 const prof={id,auth_user_id:'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',display_name:'Boxer Alpha',role:window.__testRole||'boxer',is_active:true};
 const boxers=[
  {id,display_name:'Boxer Alpha',role:'boxer',is_active:true,is_listed:true,archived_at:null},
  {id:'22222222-2222-4222-8222-222222222222',display_name:'Boxer Beta',role:'boxer',is_active:true,is_listed:true,archived_at:null},
  {id:'33333333-3333-4333-8333-333333333333',display_name:'Boxer Gamma',role:'boxer',is_active:true,is_listed:true,archived_at:null}
 ];
 const goals=[],progress=[];
 window.__testCalls=[];
 const league={
  id:'dddddddd-dddd-4ddd-8ddd-dddddddddddd',title:'TEST Team Arena',
  status:'active',duration_days:7,
  participants:boxers.map(p=>({boxer_id:p.id,name:p.display_name,status:'accepted'})),results:[]
 };
 function from(table){
  const constraints=[];
  const builder={
   select(){return builder},
   eq(key,value){constraints.push([key,value]);return builder},
   is(key,value){constraints.push([key,value]);return builder},
   in(key,values){constraints.push([key,{in:values}]);return builder},
   range(){return builder},
   neq(){return builder},
   order(){return builder},
   limit(){return builder},
   maybeSingle:async()=>({data:table==='profiles'?{...prof,role:window.__testRole||'boxer'}:null,error:null}),
   then(resolve,reject){
    let data=[];
    if(table==='profiles')data=boxers;
    if(table==='league_boxer_goals_v21')data=goals;
    if(table==='league_goal_progress_v21')data=progress;
    if(table==='training_submissions')data=[];
    data=data.filter(row=>constraints.every(([key,value])=>value&&value.in?value.in.includes(row[key]):row[key]===value));
    return Promise.resolve({data,error:null}).then(resolve,reject)
   }
  };
  return builder;
 }
 window.__testDb={
  auth:{getUser:async()=>({data:{user:{id:prof.auth_user_id}},error:null})},
  from,
  async rpc(name,args={}){
   window.__testCalls.push({name,args});
   if(name==='league_v21_arena_list_mine')return {data:[league],error:null};
   if(name==='league_v21_arena_live_scores')return {data:{status:'active',provisional:true,
    participants:[{name:'Boxer Alpha',score:50,rank:1,pending:1},{name:'Boxer Beta',score:20,rank:2,pending:0},{name:'Boxer Gamma',score:0,rank:3,pending:0}]},error:null};
   if(name==='league_v21_arena_create')return {data:'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',error:null};
   if(name==='league_v21_save_goal'){
    goals.push({id:'ffffffff-ffff-4fff-8fff-ffffffffffff',boxer_id:id,title:args.p_title,metric:args.p_metric,
    target_value:args.p_target,starts_on:'2026-10-18',ends_on:args.p_end_date,status:'active',reward_exp:0});
    return {data:goals[0].id,error:null};
   }
   if(name==='league_v21_admin_create_season')return {data:'ssssssss-aaaa-4aaa-8aaa-aaaaaaaaaaaa',error:null};
   return {data:null,error:{message:'Mock RPC not configured: '+name}};
  }
 };
}
async function main(){
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 const base='http://127.0.0.1:'+server.address().port;
 const browser=await chromium.launch({headless:true,args:['--no-sandbox']});
 try{
  for(const width of [375,1240]){
   const context=await browser.newContext({viewport:{width,height:850}});
   try{
    await context.addInitScript({content:mockSupabase.toString().replace(/^function mockSupabase\(\)/,'function mockSupabase()')+';mockSupabase();'});
    await context.route('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm',route=>
      route.fulfill({status:200,contentType:'text/javascript',body:'export const createClient=()=>window.__testDb;'}));
    await context.route('https://iqarjivcrddcixrvqbfb.supabase.co/rest/v1/**',async route=>{
     const url=route.request().url();
     const response=url.includes('/rpc/get_public_levels')?[
       {boxer_name:'Boxer Alpha',lifetime_exp:1200},{boxer_name:'Boxer Beta',lifetime_exp:800}]
      :url.includes('/rpc/get_public_leaderboard')?[
       {boxer_name:'Boxer Alpha',monthly_points:120,rank_position:1,approved_sessions:10,points_training:300,points_bonus:20},
       {boxer_name:'Boxer Beta',monthly_points:80,rank_position:2,approved_sessions:6,points_training:190,points_bonus:0}]
      :url.includes('/league_public_duel_history_v21')?[{
        challenger_id:'11111111-1111-4111-8111-111111111111',
        opponent_id:'22222222-2222-4222-8222-222222222222',
        challenger_name:'Boxer Alpha',opponent_name:'Boxer Beta',
        challenger_score:100,opponent_score:80,
        winner_id:'11111111-1111-4111-8111-111111111111',
        settled_at:'2026-10-15T18:00:00Z'
       }]
      :url.includes('/rpc/get_public_boxer_avatars')?[{boxer_name:'Boxer Alpha',avatar_key:null,avatar_url:null}]:[];
     await route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(response)});
    });
    for(const [route,role] of [['goals.html','boxer'],['arena.html','admin'],['league-manager.html','admin'],
       ['league-challenges.html','boxer'],['league-history.html','boxer'],['boxer-profile.html?name=Boxer%20Alpha','boxer'],['boxer-compare.html?left=Boxer%20Alpha&right=Boxer%20Beta','boxer']]){
     const page=await context.newPage();const errors=[],network=[];
     page.on('pageerror',e=>errors.push(e.message));
     page.on('response',r=>{if(/get_public_(leaderboard|levels)|league_public_duel_history_v21/.test(r.url()))network.push({url:r.url(),status:r.status()})});
     await page.addInitScript({content:'window.__testRole='+JSON.stringify(role)});
     await page.addInitScript({content:'window.__initialCompareSearch=location.search'});
     await page.goto(base+'/'+route,{waitUntil:'domcontentloaded'});
     if(route.startsWith('goals')) {
      await page.locator('#app').waitFor({state:'visible'});
      await page.fill('#title','TEST Zwanzig Trainings');
      await page.fill('#target','20');
      await page.locator('#goalForm button[type=submit]').click();
      await page.waitForFunction(()=>window.__testCalls.some(x=>x.name==='league_v21_save_goal'));
      await page.locator('#goals article').first().waitFor();
     }else if(route.startsWith('arena')){
      await page.locator('#adminPanel').waitFor({state:'visible'});
      await page.waitForFunction(()=>document.querySelector('#list')?.textContent.includes('50 Punkte'));
      assert.match(await page.locator('#list').innerText(),/50 Punkte/);
      await page.fill('#title','TEST Mehrgegner Arena');
      await page.locator('#boxers').selectOption([
       '11111111-1111-4111-8111-111111111111',
       '22222222-2222-4222-8222-222222222222',
       '33333333-3333-4333-8333-333333333333']);
      await page.locator('#create button[type="submit"]').click();
      await page.waitForFunction(()=>window.__testCalls.some(x=>x.name==='league_v21_arena_create'));
     }else if(route.startsWith('league-manager')){
      await page.locator('#dashboard').waitFor({state:'visible'});
      await page.fill('#seasonTitle','TEST Herbst 2026');
      await page.locator('#seasonForm button').click();
      await page.waitForFunction(()=>window.__testCalls.some(x=>x.name==='league_v21_admin_create_season'));
     }else if(route.startsWith('league-history')){
      await page.waitForFunction(()=>document.querySelector('#seasons')?.textContent.includes('Noch keine'));
     }else if(route.startsWith('boxer-profile')){
      await page.locator('#profileCard').waitFor({state:'visible'});
      assert.ok(await page.locator('#sportRadar svg polygon').count()>0,'Radar not rendered');
     }else if(route.startsWith('boxer-compare')){
      try{await page.waitForFunction(()=>document.querySelector('#directDuelsStatus')?.textContent.includes('Direkte Duelle: 1'))}catch(e){console.log('DEBUG boxer-compare',JSON.stringify({url:page.url(),initialSearch:await page.evaluate(()=>window.__initialCompareSearch),left:await page.locator('#left').inputValue(),right:await page.locator('#right').inputValue(),leftOptions:await page.locator('#left option').evaluateAll(es=>es.map(e=>({text:e.textContent,value:e.value}))),rightOptions:await page.locator('#right option').evaluateAll(es=>es.map(e=>({text:e.textContent,value:e.value}))),chooserHidden:await page.locator('#chooser').evaluate(el=>el.hidden),status:await page.locator('#status').innerText(),duelStatus:await page.locator('#directDuelsStatus').innerText(),network,errors}));throw e}
      assert.match(await page.locator('#directDuelsStatus').innerText(),/Boxer Alpha 1 Siege/);
      assert.match(await page.locator('#directDuelsStatus').innerText(),/Boxer Beta 0 Siege/);
      assert.equal(await page.locator('#directDuelsRows .h2h-row').count(),1);
      const leftValue=await page.locator('#left').inputValue();
      assert.equal(await page.locator('[data-choice-for="compare-left"] .tl-choice-card[aria-pressed="true"]').getAttribute('data-value'),leftValue,'Comparison card should reflect selected boxer');
      await page.locator('#swap').click();
      const swappedLeft=await page.locator('#left').inputValue();
      const swappedRight=await page.locator('#right').inputValue();
      assert.equal(await page.locator('[data-choice-for="compare-left"] .tl-choice-card[aria-pressed="true"]').getAttribute('data-value'),swappedLeft,'Swap should synchronize left comparison card');
      assert.equal(await page.locator('[data-choice-for="compare-right"] .tl-choice-card[aria-pressed="true"]').getAttribute('data-value'),swappedRight,'Swap should synchronize right comparison card');
     }else if(route.startsWith('league-challenges')){
      await page.waitForFunction(()=>document.querySelector('#status')?.textContent.includes('Neue Wettbewerbe'));
     }
     const overflow=await page.evaluate(()=>document.documentElement.scrollWidth-innerWidth);
     assert.ok(overflow<=5,'Horizontal overflow at '+width+' on '+route+': '+overflow);
     assert.deepEqual(errors,[],'Runtime exception '+route+' '+width);
     console.log('PASS V2.1 browser '+route+' '+width+'px');
     await page.close();
    }
   }finally{await context.close()}
  }
 }finally{await browser.close();server.close()}
}
main().catch(e=>{console.error(e);server.close();process.exit(1)});
