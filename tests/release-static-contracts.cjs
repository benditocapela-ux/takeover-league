'use strict';
const fs=require('node:fs'),assert=require('node:assert/strict');
function read(path){return fs.readFileSync(path,'utf8')}
const boxer=read('boxer.html'),coach=read('coach.html'),duels=read('duels.html'),challenges=read('challenges.html'),liveChallenges=read('league-challenges.html'),challengeEdit=read('supabase/migrations/20261021223000_admin_challenge_editing.sql'),sql=read('supabase/migrations/20261018190000_training_drafts_v2.sql');
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
['Coach boxer quick view shows latest five approved trainings',()=>{assert.match(coach,/approvedEntries=entries\.filter\(t=>t\.status==='approved'\)\.sort/);assert.match(coach,/approvedEntries\.slice\(0,5\)/);assert.ok(coach.includes("String(b.training_date||'').localeCompare(String(a.training_date||''))"))}],
['Server idempotency has a partial unique key',()=>{const idemp=read('supabase/migrations/20261018200000_training_submission_idempotency.sql');assert.match(idemp,/unique index if not exists/i);assert.match(idemp,/client_request_id is not null/);assert.match(boxer,/client_request_id=requestId/)}],
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
}],
['Admin can edit existing coach challenges through a role-checked RPC',()=>{
 assert.match(challenges,/role==='admin'&&\['draft','open','active','awaiting_reviews'\]\.includes\(c\.status\)/);
 assert.match(challenges,/coach_challenge_v2_admin_edit/);
 assert.match(challengeEdit,/a->>'role' IS DISTINCT FROM 'admin'/);
 assert.match(challengeEdit,/c\.status NOT IN \('draft','open','active','awaiting_reviews'\)/);
 assert.match(challengeEdit,/c\.status IN \('active','awaiting_reviews'\) OR has_entries/);
}],
['Live league challenges have an admin editor with server-side fairness guards',()=>{
 assert.match(liveChallenges,/isAdmin&&c\.status==='active'/);
 assert.match(liveChallenges,/league_v21_admin_edit_global_challenge/);
 assert.match(challengeEdit,/create or replace function public\.league_v21_admin_edit_global_challenge\([\s\S]*?security invoker/i);
 assert.match(challengeEdit,/feature_key='league_challenges' AND f\.is_enabled IS TRUE/);
 assert.match(challengeEdit,/c\.starts_at<=pg_catalog\.now\(\)/);
 assert.match(challengeEdit,/EXISTS\(SELECT 1 FROM public\.league_global_entries_v21 e WHERE e\.challenge_id=c\.id\)/i);
 assert.match(challengeEdit,/REVOKE ALL ON FUNCTION public\.league_v21_admin_edit_global_challenge[\s\S]*?FROM PUBLIC,anon,authenticated/i);
}],
['Challenge editing migration leaves feature flags and score ledgers unchanged',()=>{
 assert.doesNotMatch(challengeEdit,/UPDATE public\.league_feature_flags/i);
 assert.doesNotMatch(challengeEdit,/DELETE\s+FROM\s+public\.(profiles|point_transactions|league_global_entries_v21|league_coach_challenges)/i);
 assert.ok(require('node:fs').existsSync('supabase/production-prep/rollback_20261021223000_admin_challenge_editing.sql'));
 assert.ok(require('node:fs').existsSync('supabase/production-prep/20261021223000_admin_challenge_editing_preflight_read_only.sql'));
 assert.ok(require('node:fs').existsSync('supabase/production-prep/20261021223000_admin_challenge_editing_postflight_read_only.sql'));
 assert.ok(require('node:fs').existsSync('tests/admin-challenge-editing-schema.sql'));
 assert.ok(require('node:fs').existsSync('tests/admin-challenge-editing-browser.cjs'));
 assert.match(read('.github/workflows/coach-challenges-v2.yml'),/tests\/admin-challenge-editing-browser\.cjs/);
 assert.match(read('.github/workflows/coach-challenges-v2.yml'),/admin-challenge-editing-schema/);
}],
['Clubverwaltung archiviert Profile reversibel ohne Datenlöschung',()=>{
 const archive=read('supabase/migrations/20261021230000_club_profile_archive.sql');
 const rollback=read('supabase/production-prep/rollback_20261021230000_club_profile_archive.sql');
 const admin=read('admin.html');
 assert.match(archive,/ADD COLUMN IF NOT EXISTS archived_at timestamptz/i);
 assert.match(archive,/CREATE OR REPLACE FUNCTION public\.admin_archive_profile/i);
 assert.match(archive,/CREATE OR REPLACE FUNCTION public\.admin_restore_profile/i);
 assert.match(archive,/role = 'admin' AND p\.is_active IS TRUE/i);
 assert.match(archive,/target\.role = 'admin'/i);
 assert.doesNotMatch(archive,/DELETE FROM public\.(profiles|training_submissions|point_transactions)/i);
 assert.match(rollback,/DROP COLUMN IF EXISTS archived_at/i);
 assert.match(rollback,/Rollback refused: restore all archived profiles/i);
 assert.match(admin,/admin_list_profile_archive_state/);
 assert.match(admin,/admin_archive_profile/);
 assert.match(admin,/admin_restore_profile/);
 assert.match(admin,/Archivierte Profile anzeigen/);
 assert.ok(fs.existsSync('supabase/production-prep/20261021230000_club_profile_archive_preflight_read_only.sql'));
 assert.ok(fs.existsSync('supabase/production-prep/20261021230000_club_profile_archive_postflight_read_only.sql'));
 assert.ok(fs.existsSync('tests/club-profile-archive-contracts.cjs'));
}] 
];
let n=0;for(const [label,fn] of cases){try{fn();n++;console.log('PASS',label)}catch(e){console.error('FAIL',label,e.message);process.exitCode=1}}
console.log(n+'/'+cases.length+' static source checks passed. No browser/E2E claims.');