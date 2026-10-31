/* Run with: node --test tests/boxer-experience-contract.cjs
 * Contract tests: only the approved scheduled-training RPC may create a pending request; no direct row or point writes.
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
test('server-authorized one-tap club request; no direct row mutations',()=>{
  assert.doesNotMatch(js,/\.(?:insert|upsert|update|delete)\s*\(/);
  assert.match(js,/\.\/boxer\.html#trainingFormCard/);
  assert.match(html,/id="ex-training-options"/);
  assert.match(js,/get_training_v2_config/);
  assert.match(js,/cfg\?\.enabled!==true/);
  assert.match(js,/club_checkin_only/);
  assert.match(js,/submit_scheduled_club_training_today/);
  assert.match(js,/Warst du heute im Vereinstraining\?/);
  assert.match(js,/JA, IM VEREIN/);
  assert.match(js,/NEIN, EIGENES TRAINING/);
  assert.match(js,/\?club=1#trainingFormCard/);
  assert.match(js,/\?individual=1#trainingFormCard/);
  assert.match(js,/already_pending/);
  assert.match(js,/already_checked_in/);
  assert.match(js,/checked_in/);
  assert.match(js,/gym_not_open/);
  assert.match(js,/choose_gym_session/);
  assert.match(js,/\['submitted','checked_in'\]/);
  assert.match(js,/choose_slot/);
  assert.match(js,/\['submitted','checked_in'\]\.includes\(r\.data\?\.status\)/);
  assert.match(js,/trainingFallback\(host\)/);
  assert.match(js,/\.\/checkin\.html/);
  assert.doesNotMatch(js,/Object\.assign\(payload|training_location\s*:/,'Trainingseintrag und Tier bleiben in boxer.html');
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
