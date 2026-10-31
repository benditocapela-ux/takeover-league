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
 // The owner explicitly released both merged PR #86 and PR #88 together.
 // Validate the actual public assets, not just a successful Pages workflow.
 const coach=await html('coach.html');
 const admin=await html('admin.html');
 const boxerExperience=await html('boxer-experience.html');
 assert.match(coach,/takeover-staff-experience\.css\?v=/,
   'Coach page still serves the old look (new staff stylesheet missing)');
 assert.match(admin,/takeover-staff-experience\.css\?v=/,
   'Admin page still serves the old look (new staff stylesheet missing)');
 assert.match(boxerExperience,/takeover-boxer-flow\.js\?v=/,
   'Boxer Experience does not load the new in-app routing');
 assert.match(boxerExperience,/id="ex-flow-frame"/,
   'Boxer Experience missing in-app secure functional view');
 const staffStyle=await html('takeover-staff-experience.css');
 const boxerFlow=await html('takeover-boxer-flow.js');
 const embeddedStyle=await html('takeover-boxer-embedded-flow.css');
 assert.match(staffStyle,/Small-screen staff header:/,
   'Compact staff mobile header missing from production stylesheet');
 assert.match(staffStyle,/tl-screen-ribbon>\.tl-help-link/,
   'Staff menu/help overlap fix missing from production stylesheet');
 assert.match(boxerFlow,/frame\.src=url\.href/,
   'In-app navigation code missing from release');
 assert.match(embeddedStyle,/tl-ex-training #trainingFormCard/,
   'Embedded safe training form styling missing');
 console.log('LIVE COMBINED RELEASE OK: PR #86 staff and PR #88 boxer in-app navigation assets');
 const profile=await html('boxer-profile.html');
 assert.ok(profile.includes('boxer-profile.js'),'Public 2.1 boxer profile script missing');
 assert.ok(profile.includes('takeover-navigation.js'),'Public boxer profile menu missing');
 console.log('LIVE 2.1 OK:',origin+'boxer-profile.html');
 console.log('PASS: Public website serves V2 and V2.1 pages, no production writes.');
})().catch(e=>{console.error('LIVE CHECK FAILED:',e.message);process.exitCode=1});
