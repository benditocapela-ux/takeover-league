// Real hosted PostgREST security checks, read-only and test-Supabase-only.
// The publishable key is already part of the public preview frontend; no secrets.
const fs=require('node:fs');
const assert=require('node:assert/strict');
const preview=fs.readFileSync('challenges-v2-preview.html','utf8');
const match=preview.match(/createClient\('https:\/\/cfgdvcccsqwfjajuizsr\.supabase\.co','(sb_publishable_[A-Za-z0-9_-]+)'\)/);
assert.ok(match,'Isolated test preview must use a public sb_publishable key');
const url='https://cfgdvcccsqwfjajuizsr.supabase.co';
const publicKey=match[1];
async function request(label,path,method='GET',body){
 const r=await fetch(url+path,{
  method,headers:{apikey:publicKey,'content-type':'application/json','accept':'application/json'},
  body:body===undefined?undefined:JSON.stringify(body),
  redirect:'error',signal:AbortSignal.timeout(12000)
 });
 const text=await r.text();
 let parsed;try{parsed=JSON.parse(text)}catch{parsed=null}
 if(r.status>=500||r.ok)throw Error(label+' exposed data or server failed (HTTP '+r.status+')');
 if(![401,403,404].includes(r.status))throw Error(label+' unexpected HTTP '+r.status);
 return {status:r.status,code:parsed?.code||null};
}
(async()=>{
 const results=[];
 results.push(['challenge list',await request('challenge list','/rest/v1/rpc/coach_challenge_v2_list','POST',{})]);
 results.push(['duel roster',await request('duel roster','/rest/v1/rpc/duel_v2_eligible_boxers','POST',{})]);
 results.push(['challenge tables',await request('challenge tables','/rest/v1/league_coach_challenges?select=id&limit=1')]);
 results.push(['duel tables',await request('duel tables','/rest/v1/league_duels?select=id&limit=1')]);
 for(const [name,info] of results)console.log(name+': HTTP '+info.status+(info.code?' ('+info.code+')':''));
 console.log('PASS: Real TEST Supabase PostgREST denies four anonymous V2 API read paths; no writes');
})().catch(e=>{console.error('Hosted anonymous access test failed:',e.message);process.exitCode=1});
