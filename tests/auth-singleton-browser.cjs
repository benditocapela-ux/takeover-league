'use strict';
// Real SDK, guest sessions only. The three public routes make read-only requests.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const pw=require('playwright'),H=require('./takeover3-harness.cjs');
async function main(){
 const {server,base}=await H.serve(),results=[];
 try{
  for(const engine of ['chromium','webkit']){
   const browser=await pw[engine].launch({headless:true});
   try{for(const route of ['index.html','duels.html','boxer-profile.html']){
    const context=await browser.newContext(),page=await context.newPage(),warnings=[],errors=[];
    page.on('console',msg=>{if(/Multiple GoTrueClient/.test(msg.text()))warnings.push(msg.text())});
    page.on('pageerror',error=>errors.push(error.message));
    try{
     const response=await page.goto(base+'/'+route);await page.waitForLoadState('networkidle');
     const client=await page.evaluate(async()=>{
      const m=await import('./takeover-client.js');
      const first=m.createClient('https://iqarjivcrddcixrvqbfb.supabase.co','sb_publishable_o--Z21P8Q08lMvIOask_Fw__SRRX7_R');
      const second=m.createClient('https://iqarjivcrddcixrvqbfb.supabase.co','sb_publishable_o--Z21P8Q08lMvIOask_Fw__SRRX7_R',{auth:{autoRefreshToken:false}});
      const session=await first.auth.getSession();
      return {same:first===second,instanceId:first.auth.instanceID,guest:session.data.session===null,sessionError:session.error?.message||null,refresh:first.auth.autoRefreshToken,persist:first.auth.persistSession,detect:first.auth.detectSessionInUrl};
     });
     assert.equal(response.status(),200);assert.equal(client.same,true);assert.equal(client.instanceId,0,'Only one SDK auth instance is constructed');
     assert.equal(client.guest,true);assert.equal(client.sessionError,null);assert.equal(client.refresh,true);assert.equal(client.persist,true);assert.equal(client.detect,true);
     assert.deepEqual(warnings,[]);assert.deepEqual(errors,[]);
     results.push({engine,route,status:response.status(),client,warnings,errors});console.log('PASS real SDK guest singleton',engine,route);
    }finally{await context.close()}
   }}finally{await browser.close()}
  }
  fs.writeFileSync(path.join(__dirname,'../docs/seven-hour/auth-after.json'),JSON.stringify(results,null,2)+'\n');
 }finally{server.close()}
}
main().catch(e=>{console.error(e);process.exitCode=1});
