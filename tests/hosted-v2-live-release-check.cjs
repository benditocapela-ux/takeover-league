// Post-deployment smoke test, READ-ONLY. Run only after explicit FREIGEBEN
// and after the production feature flags have been deliberately enabled.
// Does not use user credentials or perform training/EXP writes.
const assert=require('node:assert/strict');
const origin='https://benditocapela-ux.github.io/takeover-league/';
async function html(path){
 const r=await fetch(origin+path,{redirect:'follow',signal:AbortSignal.timeout(15000)});
 assert.equal(r.status,200,path+': GitHub Pages returned HTTP '+r.status);
 const data=await r.text();
 assert.ok(data.length>100,'Empty deployment page: '+path);
 return data;
}
(async()=>{
 const homepage=await html('');
 assert.match(homepage,/Takeover League/i,'League homepage branding missing');
 for(const page of ['login.html','boxer.html','coach.html']){
  assert.match(await html(page),/Takeover League/i,page+' missing');
 }
 for(const [page,flag] of [
  ['challenges.html','TAKEOVER_CHALLENGES_V2_ENABLED'],
  ['duels.html','TAKEOVER_DUELS_V2_ENABLED']
 ]){
  const src=await html(page);
  assert.ok(src.includes('window.'+flag+'=true;'),
    page+' still disabled in public GitHub Pages deployment');
  assert.ok(src.includes('https://iqarjivcrddcixrvqbfb.supabase.co'),
    page+' does not target production Supabase');
  assert.ok(!src.includes('cfgdvcccsqwfjajuizsr'),
    page+' unexpectedly targets test Supabase');
  assert.ok(!/sb_secret_|service_role/i.test(src),
    page+' contains server-side credentials');
  console.log('LIVE OK:',origin+page,'(production enabled)');
 }
 for(const page of ['arena.html','goals.html','league-manager.html','league-challenges.html',
                     'boxer-compare.html','league-history.html']){
  const src=await html(page);
  assert.match(src,/Takeover League/i,page+' missing Takeover League branding');
  assert.ok(src.includes('iqarjivcrddcixrvqbfb'),
    page+' has no production Supabase endpoint');
  assert.ok(!src.includes('cfgdvcccsqwfjajuizsr'),
    page+' points to test Supabase');
  assert.ok(src.includes('takeover-navigation.js'),
    page+' does not load the shared menu');
  assert.ok(!/sb_secret_|service_role/i.test(src),
    page+' accidentally exposes a server-side credential');
  console.log('LIVE 2.1 OK:',origin+page);
 }
 const profile=await html('boxer-profile.html');
 assert.ok(profile.includes('boxer-profile.js'),'Public 2.1 boxer profile script missing');
 assert.ok(profile.includes('takeover-navigation.js'),'Public boxer profile menu missing');
 console.log('LIVE 2.1 OK:',origin+'boxer-profile.html');
 console.log('PASS: Public website serves V2 and V2.1 pages, no production writes.');
})().catch(e=>{console.error('LIVE CHECK FAILED:',e.message);process.exitCode=1});
