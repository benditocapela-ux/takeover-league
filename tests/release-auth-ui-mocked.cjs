'use strict';
// Real Chromium DOM/interaction test with mocked Supabase SDK. NO real account,
// credentials, service keys, server updates or production data.
const assert=require('node:assert/strict'),fs=require('node:fs'),http=require('node:http'),path=require('node:path');
const {chromium}=require('playwright');
const root=process.cwd();
const server=http.createServer((req,res)=>{
 const u=new URL(req.url,'http://127.0.0.1'),file=path.resolve(root,(u.pathname==='/'?'index.html':decodeURIComponent(u.pathname.slice(1))));
 if(!file.startsWith(root+path.sep)){res.writeHead(403);res.end();return}
 fs.readFile(file,(err,data)=>{if(err){res.writeHead(404);res.end();return}
 const ext=path.extname(file);res.setHeader('Content-Type',ext==='.js'?'text/javascript':ext==='.html'?'text/html':ext==='.css'?'text/css':'application/octet-stream');res.end(data)});
});
function injected(role){
 const boxerId='11111111-1111-4111-8111-111111111111',adminId='22222222-2222-4222-8222-222222222222',userId='33333333-3333-4333-8333-333333333333';
 const boxer={id:boxerId,auth_user_id:'44444444-4444-4444-8444-444444444444',display_name:'Test Boxer',role:'boxer',is_active:true,avatar_key:'boxing',avatar_url:null};
 const admin={id:adminId,auth_user_id:'33333333-3333-4333-8333-333333333333',display_name:'Test Admin',role:'admin',is_active:true};
 const trainer=[{id:1,name:'Reguläres Boxtraining',points:50,is_active:true},{id:2,name:'Joggen',points:20,is_active:true}];
 let submissions=role==='boxer'?[]:[
  {id:'a1111111-1111-4111-8111-111111111111',boxer_id:boxerId,training_type_id:1,training_date:'2026-10-17',notes:'',status:'pending',created_at:'2026-10-17T10:00:00Z',reviewed_at:null,reviewed_by:null},
  {id:'a2222222-2222-4222-8222-222222222222',boxer_id:boxerId,training_type_id:2,training_date:'2026-10-17',notes:'',status:'rejected',created_at:'2026-10-17T11:00:00Z',reviewed_at:new Date().toISOString(),reviewed_by:adminId}
 ];
 const stats={submitted:[],reviewed:[],undo:0};
 window.__mockStats=stats;
 const all={profiles:[boxer,admin],training_types:trainer,training_submissions:submissions,league_feature_flags:[
  {feature_key:'notifications',is_enabled:false},{feature_key:'coach_feedback',is_enabled:false},
  {feature_key:'performance_dashboard',is_enabled:false}]};
 function query(table,opts={}){
  const filter=[],ordering=[],self={
   select:(fields,options)=>query(table,{...opts,fields,options}),
   eq:(col,val)=>{filter.push([col,val]);return self},
   order:(col,v)=>{ordering.push([col,v]);return self},
   limit:(n)=>{opts.limit=n;return self},range:(from,to)=>{opts.range=[from,to];return self},
   maybeSingle:async()=>{const r=compute();return {data:r.data?.[0]||null,error:null}},
   single:async()=>{const r=compute();return {data:r.data?.[0]||null,error:null}},
   insert:async(payload)=>{await new Promise(r=>setTimeout(r,100));
    const item={id:'a'+String(submissions.length+3).padStart(7,'0')+'-2222-4222-8222-222222222222',...payload,created_at:new Date().toISOString()};
    submissions.push(item);stats.submitted.push(payload);return {data:item,error:null}},
   delete:()=>({eq:async()=>({data:null,error:null})}),
   upsert:async()=>({data:null,error:null}),
   then:(resolve,reject)=>Promise.resolve(compute()).then(resolve,reject)
  };
  function compute(){
   let items=(all[table]||[]).filter(x=>filter.every(([k,v])=>x[k]===v));
   for(const [k,v] of ordering){items=items.slice().sort((a,b)=>v?.ascending?(a[k]>b[k]?1:-1):(a[k]>b[k]?-1:1))}
   if(opts.range)items=items.slice(opts.range[0],opts.range[1]+1);
   if(opts.limit!=null)items=items.slice(0,opts.limit);
   if(opts.options?.head)return {data:null,count:items.length,error:null};
   return {data:items,error:null};
  }
  return self;
 }
 window.__takeoverMockClient={
  auth:{getUser:async()=>({data:{user:{id:role==='boxer'?boxer.auth_user_id:userId}},error:null}),
    signOut:async()=>({error:null}),onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}})},
  from:table=>query(table),
  storage:{from:()=>({getPublicUrl:()=>({data:{publicUrl:''}})})},
  rpc:async(name,args)=>{
   if(name==='review_training'){stats.reviewed.push(args);submissions=submissions.map(x=>x.id===args.p_submission_id?{...x,status:args.p_decision}:x);all.training_submissions=submissions;return {data:{status:args.p_decision,points_awarded:50},error:null}}
   if(name==='admin_undo_recent_rejection'){stats.undo++;submissions=submissions.map(x=>x.id===args.p_submission_id?{...x,status:'pending',reviewed_at:null,reviewed_by:null}:x);all.training_submissions=submissions;return {data:{status:'pending'},error:null}}
   if(name==='coach_list_unlinked_accounts'||name==='coach_training_audit_recent')return {data:[],error:null};
   if(name==='get_boxer_training_audit')return {data:[],error:null};
   return {data:[],error:null};
  }
 };
}
async function main(){
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const url='http://127.0.0.1:'+server.address().port;
 const browser=await chromium.launch({headless:true,args:['--no-sandbox']});
 for(const role of ['boxer','admin']){
  const context=await browser.newContext({viewport:{width:390,height:780},hasTouch:true,isMobile:true});
  await context.addInitScript({content:'('+injected.toString()+')('+JSON.stringify(role)+')'});
  const page=await context.newPage();
  page.setDefaultTimeout(13000);
  page.on('dialog',d=>d.accept());
  await page.route('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm',async route=>
   route.fulfill({status:200,contentType:'text/javascript',body:'export const createClient=()=>window.__takeoverMockClient;'}));
  if(role==='boxer'){
   await page.goto(url+'/boxer.html');
   await page.waitForFunction(()=>!document.querySelector('#content').classList.contains('hidden'));
   await page.selectOption('#kind','1');
   await page.fill('#notes','Smoke-Test-Notiz');
   await page.evaluate(()=>{const form=document.querySelector('#form');form.requestSubmit();form.requestSubmit()});
   await page.waitForFunction(()=>window.__mockStats.submitted.length>=1);
   await page.waitForTimeout(180);
   const submitted=await page.evaluate(()=>window.__mockStats.submitted);
   assert.equal(submitted.length,1,'Double submit should create just one training');
   assert.equal(submitted[0].status,'pending');
   console.log('PASS boxer form submission; duplicate click suppressed, mobile Chromium');
  } else {
   await page.goto(url+'/coach.html');
   await page.waitForFunction(()=>!document.querySelector('#content').classList.contains('hidden'));
   await page.locator('#selectPending').click();
   await page.locator('#bulkApprove').click();
   await page.waitForFunction(()=>window.__mockStats.reviewed.length===1);
   assert.equal((await page.evaluate(()=>window.__mockStats.reviewed[0])).p_decision,'approved');
   await page.selectOption('#filterStatus','rejected');
   await page.locator('button', {hasText:'Ablehnung rückgängig'}).first().click();
   await page.waitForFunction(()=>window.__mockStats.undo===1);
   console.log('PASS admin bulk review, guarded undo, mobile Chromium');
  }
  const x=await page.evaluate(()=>document.documentElement.scrollWidth-window.innerWidth);
  assert.ok(x<=5,'Unexpected '+role+' horizontal overflow '+x);
  await context.close();
 }
 await browser.close();
}
main().then(()=>server.close()).catch(e=>{console.error(e);server.close();process.exitCode=1});
