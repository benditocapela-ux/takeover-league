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
['No production database write in CI script',()=>assert.doesNotMatch(read('.github/workflows/release-2-validation.yml'),/apply_migration|execute_sql|supabase db push|deploy-pages/)],
['Audit is limited to an authenticated admin',()=>{const audit=read('supabase/migrations/20261018210000_coach_training_audit_read.sql');assert.match(audit,/actor\.role = 'admin'/);assert.match(audit,/revoke all on function public\.coach_training_audit_recent\(integer\) from public, anon, authenticated/i);assert.match(coach,/db\.rpc\('coach_training_audit_recent'/)}],
['Live duel scores enforce participant authorization',()=>{const duel=read('supabase/migrations/20261018211000_duel_v2_live_scores.sql');assert.match(duel,/actor\.id not in \(duel\.challenger_id,duel\.opponent_id\)/);assert.match(duel,/s\.status='approved'/);assert.match(duel,/s\.created_at<=least\(now\(\),duel\.ends_at\)/);assert.match(duel,/revoke all on function public\.duel_v2_live_scores\(uuid\) from public,anon,authenticated/i);assert.match(duels,/duel_v2_live_scores/)}],
['Duel invitation confirms exact opponent and duration',()=>assert.match(duels,/if\(!confirm\('Duell-Einladung senden\?/)],
['Training calendar uses confirmed Supabase entries',()=>{assert.match(boxer,/historyRows\.filter\(row=>row\.status==='approved'/);assert.match(boxer,/renderTrainingInsights\(\)/)}],
['Server idempotency has a partial unique key',()=>{const idemp=read('supabase/migrations/20261018200000_training_submission_idempotency.sql');assert.match(idemp,/unique index if not exists/i);assert.match(idemp,/client_request_id is not null/);assert.match(boxer,/client_request_id=requestId/)}],
['No application uses service role credentials',()=>{for(const file of ['boxer.html','coach.html','duels.html','challenges.html','boxer-compare.html'])assert.doesNotMatch(read(file),/sb_secret_|service_role/i)}]
];
let n=0;for(const [label,fn] of cases){try{fn();n++;console.log('PASS',label)}catch(e){console.error('FAIL',label,e.message);process.exitCode=1}}
console.log(n+'/'+cases.length+' static source checks passed. No browser/E2E claims.');