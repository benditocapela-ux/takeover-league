// Optional hosted Supabase Auth/PostgREST smoke test. NOT run without explicit
// test-only credentials. Never touches production, never writes to database.
const assert=require('node:assert/strict');
const allowed='https://cfgdvcccsqwfjajuizsr.supabase.co';
const target=(process.env.TAKEOVER_TEST_SUPABASE_URL||allowed).replace(/\/$/,'');
assert.equal(target,allowed,'Refusing anything except the isolated Takeover test project');
const key=process.env.TAKEOVER_TEST_PUBLISHABLE_KEY;
const actors=['BOXER','COACH','ADMIN'].map(role=>({
 role,
 email:process.env['TAKEOVER_TEST_'+role+'_EMAIL'],
 password:process.env['TAKEOVER_TEST_'+role+'_PASSWORD']
}));
if(!key||actors.some(x=>!x.email||!x.password)){
 console.error('BLOCKED: test publishable key and all 3 role-specific email/password pairs are required. No changes made.');
 process.exit(2);
}
async function request(path,{token,method='GET',body}={}){
 const headers={'apikey':key,'Accept':'application/json'};
 if(token)headers.Authorization='Bearer '+token;
 if(body!==undefined)headers['Content-Type']='application/json';
 const response=await fetch(target+path,{method,headers,body:body===undefined?undefined:JSON.stringify(body),redirect:'error'});
 const text=await response.text();
 let result;try{result=JSON.parse(text)}catch{result=null}
 return {status:response.status,ok:response.ok,result};
}
async function authenticate(actor){
 const login=await request('/auth/v1/token?grant_type=password',{
 method:'POST',body:{email:actor.email,password:actor.password}
 });
 assert.equal(login.status,200,actor.role+' login failed');
 const token=login.result?.access_token;
 assert.ok(token,actor.role+' token missing');
 const user=await request('/auth/v1/user',{token});
 assert.equal(user.status,200,actor.role+' token verification failed');
 const uid=user.result?.id;assert.ok(uid,'Auth identity missing');
 // Profile lookup must be for the signed-in user, never an unscoped roster.
 const p=await request('/rest/v1/profiles?select=role,is_active&auth_user_id=eq.'+
 encodeURIComponent(uid),{token});
 assert.equal(p.status,200,actor.role+' profile not readable with its own JWT');
 assert.equal(p.result?.length,1,actor.role+' must have exactly one matching profile');
 assert.equal(p.result[0].role,actor.role.toLowerCase(),'Profile role mismatch');
 assert.equal(p.result[0].is_active,true,'Inactive account');
 return {role:actor.role,uid,token};
}
async function checkedReadRpc(name,token){
 return await request('/rest/v1/rpc/'+name,{
 method:'POST',token,body:{}
 });
}
(async()=>{
 const anon=await checkedReadRpc('coach_challenge_v2_list');
 assert.equal(anon.ok,false,'Anonymous clients must not invoke private challenge RPCs');
 const anonDuel=await checkedReadRpc('duel_v2_eligible_boxers');
 assert.equal(anonDuel.ok,false,'Anonymous clients must not invoke private duel roster RPC');
 const sessions=[];
 for(const actor of actors)sessions.push(await authenticate(actor));
 assert.equal(new Set(sessions.map(s=>s.uid)).size,3,'Test roles must use separate real Auth users');
 // Default safe mode: test project V2 feature flags are disabled until test-only
 // rollout; therefore authenticated callers must be blocked by feature gates.
 for(const s of sessions){
  const challenge=await checkedReadRpc('coach_challenge_v2_list',s.token);
  const duel=await checkedReadRpc('duel_v2_eligible_boxers',s.token);
  assert.equal(challenge.ok,false,s.role+' bypassed disabled challenge feature flag');
  assert.equal(duel.ok,false,s.role+' bypassed disabled duel feature flag');
 }
 console.log('HOSTED AUTH PASS: real login/profile/JWT for 3 separate roles, anonymous denial and disabled V2 gates. No writes.');
})().catch(e=>{console.error('HOSTED AUTH FAIL:',e.message);process.exitCode=1});
