'use strict';
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const {JSDOM}=require('jsdom');
const read=p=>fs.readFileSync(p,'utf8');
function documentOf(p){const dom=new JSDOM(read(p),{url:'https://example.test/takeover-league/'+p,runScripts:'outside-only'});return dom}
function parseScripts(p){
 const s=read(p);
 for(const script of [...s.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/g)]){
  const code=script[1];if(!code.trim())continue;
  const stripped=code.replace(/^\s*import\s+[^;]+;\s*$/gm,'');
  assert.doesNotThrow(()=>new vm.Script('(async()=>{'+stripped+'})()'),p+' syntax');
 }
}
for(const p of ['boxer.html','coach.html','index.html','challenges.html','duels.html','boxer-compare.html'])parseScripts(p);
for(const p of ['takeover-ux-scroll.js','takeover-quick-actions.js','index-my-position.js','boxer-profile.js','takeover-navigation.js']){
 assert.doesNotThrow(()=>new vm.Script(read(p)),p+' syntax');
}
const boxer=documentOf('boxer.html');
for(const id of ['trainingInsights','trainingCalendar','trainingStreak','trainingWeeklyChart','boxerNotificationSection','repeatTraining','cloudDraftSave'])assert.ok(boxer.window.document.getElementById(id),'Boxer UX missing '+id);
boxer.window.close();
const coach=documentOf('coach.html');
for(const id of ['coachBoxerQuick','coachBoxerQuickBody','pendingSearch','bulkApprove','bulkReject','recentBoxers'])assert.ok(coach.window.document.getElementById(id),'Coach UX missing '+id);
coach.window.close();
const compare=documentOf('boxer-compare.html');
assert.ok(compare.window.document.getElementById('left'));
assert.ok(compare.window.document.getElementById('right'));
compare.window.close();
assert.match(read('boxer-compare.html'),/get_public_leaderboard/);
assert.match(read('index-my-position.js'),/auth\.getUser/);
assert.match(read('boxer.html'),/client_request_id/);
assert.match(read('supabase\/migrations\/20261018200000_training_submission_idempotency.sql'),/unique index/i);
for(const p of ['boxer.html','boxer-profile.js','index.html'])assert.match(read(p),/Math\.floor\((?:\(level-1\)|n)\/10\)/,'Ten levels per rank in '+p);
assert.match(read('boxer.html'),/function renderMyTasks\(/,'boxer task source');
assert.match(read('boxer.html'),/schedulePrivateDraftSave\(/,'private cloud autosave source');
assert.match(read('challenges.html'),/myAutomaticGoalProgress\(/,'authenticated automatic progress');
assert.match(read('challenges.html'),/\.eq\('status','approved'\)/,'confirmed challenge training only');
for(const p of ['boxer.html','coach.html','challenges.html','duels.html']){
 assert.match(read(p),/takeover-quick-actions\.js/,'shared quick actions on '+p);
}
assert.match(read('takeover-quick-actions.js'),/showModal\(\)/,'accessible bottom-sheet dialog');
const deployment=read('.github/workflows/takeover-pages-deploy.yml');
assert.match(deployment,/rm -f[^\n]*league2-preview\.html/);
assert.doesNotMatch(read('boxer-compare.html'),/service_role|sb_secret_/i);
console.log('PASS: Staging UX structure, script syntax, public comparison, private forms, 10-level ranks, deploy separation.');
