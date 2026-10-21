// Browser-like admin editor smoke test. Supabase is fully mocked; no live data is accessed.
'use strict';
const fs=require('node:fs');
const assert=require('node:assert/strict');
const {JSDOM}=require('jsdom');
const html=fs.readFileSync('league-challenges.html','utf8');
const source=html.match(/<script type="module">([\s\S]*?)<\/script>/)[1].replace(/^import .*;\s*$/gm,'');
const tick=()=>new Promise(resolve=>setTimeout(resolve,0));

(async()=>{
 const dom=new JSDOM(html,{url:'https://example.test/league-challenges.html',runScripts:'outside-only'});
 const calls=[];
 const challenge={
  id:'future-challenge',title:'Original Challenge',description:'Original description',
  metric:'training_sessions',target_value:10,
  starts_at:'2026-11-01T00:00:00+01:00',ends_at:'2026-11-08T23:59:59+01:00',status:'active'
 };
 const db={
  auth:{getUser:async()=>({data:{user:{id:'admin-auth'}},error:null})},
  from(name){
   if(name==='profiles')return {select:()=>({eq:()=>({maybeSingle:async()=>({data:{id:'admin-profile',role:'admin',is_active:true},error:null})})})};
   if(name==='league_global_challenges_v21')return {select:()=>({order:async()=>({data:[{...challenge}],error:null})})};
   throw new Error('Unexpected table query: '+name);
  },
  rpc:async(name,args)=>{calls.push({name,args});return {data:{id:challenge.id,rules_updated:!!args?.p_update_rules},error:null}}
 };
 dom.window.createClient=()=>db;
 dom.window.confirm=()=>true;
 dom.window.eval(source.replace('init();','window.__ready=init();'));
 await dom.window.__ready;
 const details=dom.window.document.querySelector('.admin-editor');
 assert.ok(details,'active challenge should show admin editor to an active admin');
 details.querySelector('summary').click();
 const form=details.querySelector('form');
 assert.ok(form&&!form.hidden,'admin editor should open');
 form.querySelector('input').value='Updated Challenge';
 form.dispatchEvent(new dom.window.Event('submit',{bubbles:true,cancelable:true}));
 await tick();await tick();await tick();
 const titleCall=calls.find(c=>c.name==='league_v21_admin_edit_global_challenge');
 assert.ok(titleCall,'title edit must call the admin RPC');
 assert.equal(titleCall.args.p_title,'Updated Challenge');
 assert.equal(titleCall.args.p_update_rules,false,'title-only edit must not alter rules');

 const refreshed=dom.window.document.querySelector('.admin-editor form');
 refreshed.querySelector('input[type="number"]').value='20';
 refreshed.dispatchEvent(new dom.window.Event('submit',{bubbles:true,cancelable:true}));
 await tick();await tick();await tick();
 const ruleCall=calls.filter(c=>c.name==='league_v21_admin_edit_global_challenge').at(-1);
 assert.equal(ruleCall.args.p_target,20);
 assert.equal(ruleCall.args.p_update_rules,true,'future challenge rule edit must be explicitly marked');
 dom.window.close();
 console.log('PASS: Admin live-challenge editor renders, saves title-only changes, and sends rule edits through the guarded RPC.');
})().catch(error=>{console.error(error);process.exitCode=1});
