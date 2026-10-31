/* Run with: node --test tests/boxer-experience-contract.cjs
 * Contract tests (Takeover 3.0): the experience shell itself never writes rows; requests go through the scheduled-training RPC or the integrated form module.
 */
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const root=path.resolve(__dirname,'..');
const html=fs.readFileSync(path.join(root,'boxer-experience.html'),'utf8');
const js=fs.readFileSync(path.join(root,'boxer-experience.js'),'utf8');

test('separate shell and valid JS syntax',()=>{
  assert.match(html,/<main class="ex-scroll"/);
  assert.doesNotThrow(()=>new vm.Script(js,{filename:'boxer-experience.js'}));
});
test('exactly five main navigation destinations',()=>{
  assert.deepEqual([...html.matchAll(/data-tab="([^"]+)"/g)].map(m=>m[1]),['heute','training','kaempfe','liga','boxer']);
});
test('personal holo and fixed FUT only render on their own sections',()=>{
  assert.match(js,/\$\('ex-home-stage'\)\.hidden=name!=='heute'/);
  assert.match(js,/\$\('ex-card-stage'\)\.hidden=name!=='boxer'/);
  assert.match(html,/data-view="boxer"/);
  assert.match(html,/id="ex-radar"/);
});
test('server-authorized one-tap club request; integrated form; no direct row mutations in the shell',()=>{
  assert.doesNotMatch(js,/\.(?:insert|upsert|update|delete)\s*\(/);
  assert.doesNotMatch(js,/boxer\.html/,'no route back to the old studio');
  assert.match(html,/id="ex-training-options"/);
  assert.match(html,/id="ex-training-form"/);
  assert.match(js,/TLTrainingForm\.mount/);
  assert.match(js,/get_training_v2_config/);
  assert.match(js,/cfg\?\.enabled===true/);
  assert.match(js,/club_checkin_only/);
  assert.match(js,/submit_scheduled_club_training_today/);
  assert.match(js,/Warst du heute im Vereinstraining\?/);
  assert.match(js,/Ja, im Verein/);
  assert.match(js,/Nein, eigenes Training/);
  assert.match(js,/go\('training','eigenes',true\)/);
  assert.match(js,/go\('training','verein',true\)/);
  assert.match(js,/already_pending/);
  assert.match(js,/already_checked_in/);
  assert.match(js,/checked_in/);
  assert.match(js,/gym_not_open/);
  assert.match(js,/choose_gym_session/);
  assert.match(js,/choose_slot/);
  assert.match(js,/\['submitted','checked_in'\]\.includes\(r\.data\?\.status\)/);
  assert.match(js,/trainingFallback\(host\)/);
  assert.match(js,/\.\/checkin\.html/);
  assert.match(js,/if\(state\.quickBusy\)return/,'one-tap request cannot be sent twice');
});
test('real data reads, no imaginary scores or podium participants',()=>{
  for(const key of ['get_my_performance','get_public_leaderboard','get_holo_looks','get_boxer_exp_level_rank','training_submissions']) assert.ok(js.includes(key),key);
  assert.match(js,/safeHolo\(config/);
  assert.doesNotMatch(html,/Boxer A|Boxer B|Boxer C|1'260 P|DEMO-PUNKTE/);
});
test('every referenced element exists in document',()=>{
 const ids=new Set([...html.matchAll(/\bid="([^"]+)"/g)].map(x=>x[1]));
 for(const [,id] of js.matchAll(/\$\('([^']+)'\)/g)) assert.ok(ids.has(id),'missing id '+id);
});
test('roles are restricted to active authenticated boxer profiles',()=>{
  assert.match(js,/state\.db\.auth\.getUser\(\)/);
  assert.match(js,/!profile\.is_active/);
  assert.match(js,/profile\.role!=='boxer'/);
});
