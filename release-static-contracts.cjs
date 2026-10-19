'use strict';
const fs=require('node:fs'),assert=require('node:assert/strict');
function read(path){return fs.readFileSync(path,'utf8')}
const boxer=read('boxer.html'),coach=read('coach.html'),duels=read('duels.html'),challenges=read('challenges.html'),goals=read('goals.html'),arena=read('arena.html'),compare=read('boxer-compare.html'),manager=read('league-manager.html'),choiceCards=read('takeover-choice-cards.js'),trainingChoices=read('takeover-training-choices.js'),redesign=read('takeover-redesign.css'),navigation=read('takeover-navigation.js'),deployWorkflow=read('.github/workflows/takeover-pages-deploy.yml'),sql=read('supabase/migrations/20261018190000_training_drafts_v2.sql');
const cases=[
['Boxer uses real authenticated submission table',()=>assert.match(boxer,/db\.from\('training_submissions'\)\.insert/)],
['Boxer retains submission lock',()=>assert.match(boxer,/trainingSubmitBusy=true/)],
['Boxer supports server-owned draft and local fallback',()=>{assert.match(boxer,/training_drafts_v2/);assert.match(boxer,/sessionStorage\.setItem/)}],
['Draft clears only after successful submission',()=>{assert.ok(boxer.indexOf("sessionStorage.removeItem(sessionDraftKey())")>boxer.indexOf('if(r.error)throw r.error'))}],
['Coach batch delegates to existing authenticated RPC',()=>assert.match(coach,/db\.rpc\('review_training',\{p_submission_id:item\.id,p_decision:decision\}\)/)],
['Coach asks before batch operation',()=>assert.match(coach,/if\(!confirm\('Diese '/)],
['Coach batch is bounded',()=>assert.match(coach,/selected\.length>20/)],
['Coach UI requires active admin or coach',()=>{assert.match(coach,/\['admin','coach'\]\.includes\(p\.role\)/);assert.match(coach,/!p\.is_active/);assert.match(coach,/db\.rpc\('coach_list_boxers'\)/);assert.doesNotMatch(coach,/Promise\.all\(\[db\.from\('profiles'\)/)}],
['Coach SQL is staged and admin-only identity management is retained',()=>{const r=read('supabase/migrations/20261019040000_coach_role_permissions.sql');assert.match(r,/create or replace function public.is_league_coach\(\)/i);assert.match(r,/create or replace function public.coach_list_boxers\(\)/i);assert.doesNotMatch(r,/CREATE OR REPLACE FUNCTION public.is_league_admin\(\)/i);assert.doesNotMatch(r,/CREATE OR REPLACE FUNCTION public.recalculate_boxer_bonuses\(/i)}],
['Profile actions are present',()=>assert.ok(fs.existsSync('boxer-profile.js')&&fs.existsSync('boxer-profile.html'))],
['Real V2 duel and challenge RPCs are wired',()=>{assert.match(duels,/duel_v2_invite/);assert.match(challenges,/coach_challenge_v2_list/)}],
['Private draft RLS and principal check',()=>{assert.match(sql,/enable row level security/i);assert.match(sql,/auth\.uid\(\)/);assert.match(sql,/p\.auth_user_id=/);assert.match(sql,/for all to authenticated/i)}],
['Private draft denies anonymous',()=>assert.match(sql,/revoke all on public\.training_drafts_v2 from public, anon/i)],
['No production database write in CI script',()=>assert.doesNotMatch(read('.github/workflows/release-2-validation.yml'),/apply_migration|execute_sql|supabase db push|deploy-pages/)],
['Audit is limited to an authenticated admin',()=>{const audit=read('supabase/migrations/20261018210000_coach_training_audit_read.sql');assert.match(audit,/actor\.role = 'admin'/);assert.match(audit,/revoke all on function public\.coach_training_audit_recent\(integer\) from public, anon, authenticated/i);assert.match(coach,/db\.rpc\('coach_training_audit_recent'/)}],
['Live duel privileged core is in private schema behind invoker API',()=>{
 const m=read('supabase/migrations/20261018211000_duel_v2_live_scores.sql');
 assert.match(m,/create schema if not exists league_duel_private/i);
 assert.match(m,/create or replace function league_duel_private\.duel_v2_live_scores_core\(p_duel_id uuid\)/i);
 assert.match(m,/create or replace function public\.duel_v2_live_scores\(p_duel_id uuid\)\s+returns jsonb language sql stable security invoker/i);
 assert.match(m,/revoke all on function public\.duel_v2_live_scores\(uuid\) from public,anon,authenticated/i);
 assert.match(m,/revoke all on schema league_duel_private from public, anon, authenticated/i);
 assert.match(m,/actor\.id not in \(duel\.challenger_id,duel\.opponent_id\)/);
}],
['Live duel scores enforce participant authorization',()=>{const duel=read('supabase/migrations/20261018211000_duel_v2_live_scores.sql');assert.match(duel,/actor\.id not in \(duel\.challenger_id,duel\.opponent_id\)/);assert.match(duel,/s\.status='approved'/);assert.match(duel,/s\.created_at<=least\(now\(\),duel\.ends_at\)/);assert.match(duel,/revoke all on function public\.duel_v2_live_scores\(uuid\) from public,anon,authenticated/i);assert.match(duels,/duel_v2_live_scores/)}],
['Duel invitation confirms exact opponent and duration',()=>assert.match(duels,/if\(!confirm\('Duell-Einladung senden\?/)],
['Training calendar uses confirmed Supabase entries',()=>{assert.match(boxer,/historyRows\.filter\(row=>row\.status==='approved'/);assert.match(boxer,/renderTrainingInsights\(\)/)}],
['Server idempotency has a partial unique key',()=>{const idemp=read('supabase/migrations/20261018200000_training_submission_idempotency.sql');assert.match(idemp,/unique index if not exists/i);assert.match(idemp,/client_request_id is not null/);assert.match(boxer,/client_request_id=requestId/)}],
['Menu uses accessible accordion groups and preserves role-scoped destinations',()=>{assert.match(navigation,/icon:'👤',title:'Mein Bereich'/);assert.match(navigation,/icon:'🥊',title:'Kämpfe'/);assert.match(navigation,/icon:'🎯',title:'Herausforderungen'/);assert.match(navigation,/icon:'🏆',title:'Liga & Erfolge'/);assert.match(navigation,/aria-expanded=\"false\" aria-controls=/);assert.match(navigation,/setMenuGroupExpanded/);assert.match(navigation,/Live Challenges/);assert.match(navigation,/Persönliche Challenges/);assert.match(navigation,/Duell starten/)}],
['Horizontal choice cards preserve native form values, multiple selection and dynamic forms',()=>{assert.match(choiceCards,/select\.multiple/);assert.match(choiceCards,/dispatchEvent\(new Event\('change'/);assert.match(choiceCards,/aria-pressed/);assert.match(choiceCards,/new MutationObserver/);assert.match(redesign,/\.tl-choice-track/);assert.match(redesign,/\.tl-choice-hint/);assert.match(redesign,/label:focus-within\+\.tl-choice-field/);assert.match(redesign,/prefers-reduced-motion/)}],
['Training presets ship as a static asset and only update existing inputs',()=>{assert.match(boxer,/takeover-training-choices\.js/);assert.match(deployWorkflow,/test -s _site\/takeover-training-choices\.js/);assert.match(deployWorkflow,/grep -Fq 'takeover-training-choices\.js' _site\/boxer\.html/);assert.match(trainingChoices,/Europe\/Zurich/);assert.match(trainingChoices,/showPicker/);assert.match(trainingChoices,/techniqueMinutes/);assert.doesNotMatch(trainingChoices,/db\.rpc|supabase/)}],
['Shared choice cards cover forms and the two non-form choice screens, never Coach',()=>{for(const page of [boxer,duels,challenges,goals,arena,compare,manager])assert.match(page,/takeover-choice-cards\.js/);assert.match(compare,/data-tl-choice=\"compare-left\"/);assert.match(compare,/data-tl-choice=\"compare-right\"/);assert.match(manager,/id=\"rewardGoal\" data-tl-choice=\"manager-reward-goal\"/);assert.doesNotMatch(coach,/takeover-choice-cards\.js/)}],
['Arena keeps the native multi-select contract and submits only from its submit button',()=>{assert.match(arena,/<select multiple id="boxers"/);assert.match(arena,/selectedOptions/);assert.match(arena,/3 bis 8 Boxer auswählen|3–8 Boxer auswählen/);assert.match(arena,/querySelector\('button\[type=\"submit\"\]'\)/)}],
['No application uses service role credentials',()=>{for(const file of ['boxer.html','coach.html','duels.html','challenges.html','boxer-compare.html'])assert.doesNotMatch(read(file),/sb_secret_|service_role/i)}],
['Undo rejection is admin-only, bounded, audited and has no linked ledger',()=>{
 const u=read('supabase/migrations/20261018213000_admin_undo_recent_rejection.sql');
 assert.match(u,/p.role='admin'/);assert.match(u,/reviewed_by is distinct from actor.id/);
 assert.match(u,/interval '15 minutes'/);assert.match(u,/if exists\(select 1 from public.point_transactions t\s+where t.submission_id=training.id\)/);
 assert.match(u,/insert into public.training_audit/);assert.match(coach,/admin_undo_recent_rejection/);
}],
['Inbox read RPC enforces active boxer ownership, flag and anonymous revocation',()=>{
 const inbox=read('supabase/migrations/20261018230000_notification_mark_read.sql');
 assert.match(inbox,/p.role='boxer'/);
 assert.match(inbox,/n.recipient_id=v_actor/);
 assert.match(inbox,/feature_key='notifications'/);
 assert.match(inbox,/revoke all on function public.mark_my_notification_read\(uuid\) from PUBLIC, anon, authenticated/i);
 assert.match(boxer,/db.rpc\('mark_my_notification_read'/);
 assert.match(boxer,/const base=new URL\('\.\/',location.href\)/);
}],
['Private avatar update cannot be called anonymously after staged migration',()=>{
 const sql=read('supabase/migrations/20261018214000_avatar_rpc_permissions.sql');
 assert.match(sql,/REVOKE ALL ON FUNCTION public.update_my_boxer_avatar\(text,text\) FROM PUBLIC,anon/);
 assert.match(sql,/GRANT EXECUTE ON FUNCTION public.update_my_boxer_avatar\(text,text\) TO authenticated/);
}]
];
let n=0;for(const [label,fn] of cases){try{fn();n++;console.log('PASS',label)}catch(e){console.error('FAIL',label,e.message);process.exitCode=1}}
console.log(n+'/'+cases.length+' static source checks passed. No browser/E2E claims.');