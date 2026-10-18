'use strict';
const fs=require('node:fs'),assert=require('node:assert/strict');
function read(path){return fs.readFileSync(path,'utf8')}
const boxer=read('boxer.html'),coach=read('coach.html'),duels=read('duels.html'),challenges=read('challenges.html'),sql=read('supabase/migrations/20261018190000_training_drafts_v2.sql');
const cases=[
['Boxer uses real authenticated submission table',()=>assert.match(boxer,/db\.from\('training_submissions'\)\.insert/)],
['Boxer retains submission lock',()=>assert.match(boxer,/trainingSubmitBusy=true/)],
['Boxer supports server-owned draft and local fallback',()=>{assert.match(boxer,/training_drafts_v2/);assert.match(boxer,/sessionStorage\.setItem/)}],
['Draft clears only after successful submission',()=>{assert.ok(boxer.indexOf("sessionStorage.removeItem(sessionDraftKey())")>boxer.indexOf('if(r.error)throw r.error'))}],
['Coach batch delegates to existing authenticated RPC',()=>assert.match(coach,/db\.rpc\('review_training',\{p_submission_id:item\.id,p_decision:decision\}\)/)],
['Coach asks before batch operation',()=>assert.match(coach,/if\(!confirm\('Diese '/)],
['Coach batch is bounded',()=>assert.match(coach,/selected\.length>20/)],
['Coach does not silently unlock non-admin reviewer role',()=>assert.match(coach,/p\.role!=='admin'/)],
['Profile actions are present',()=>assert.ok(fs.existsSync('boxer-profile.js')&&fs.existsSync('boxer-profile.html'))],
['Real V2 duel and challenge RPCs are wired',()=>{assert.match(duels,/duel_v2_invite/);assert.match(challenges,/coach_challenge_v2_list/)}],
['Private draft RLS and principal check',()=>{assert.match(sql,/enable row level security/i);assert.match(sql,/auth\.uid\(\)/);assert.match(sql,/p\.auth_user_id=/);assert.match(sql,/for all to authenticated/i)}],
['Private draft denies anonymous',()=>assert.match(sql,/revoke all on public\.training_drafts_v2 from public, anon/i)],
['No production database write in CI script',()=>assert.doesNotMatch(read('.github/workflows/release-2-validation.yml'),/apply_migration|execute_sql|supabase db push|deploy-pages/)]
];
let n=0;for(const [label,fn] of cases){try{fn();n++;console.log('PASS',label)}catch(e){console.error('FAIL',label,e.message);process.exitCode=1}}
console.log(n+'/'+cases.length+' static source checks passed. No browser/E2E claims.');