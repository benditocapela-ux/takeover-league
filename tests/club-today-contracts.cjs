'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
const read=f=>fs.readFileSync(f,'utf8');
const migration=read('supabase/migrations/20261031100000_scheduled_club_training_quick_request.sql');
const ui=read('takeover-club-today.js');
const boxer=read('takeover-training-v2.js');
const checkin=read('checkin.html');
test('One-tap uses a strictly authenticated boxer RPC',()=>{
 assert.match(migration,/me\.auth_user_id IS DISTINCT FROM auth\.uid\(\)/);
 assert.match(migration,/me\.role <> 'boxer'/);
 assert.match(migration,/league_private\.flag_on\('training_v2'\)/);
 assert.match(migration,/REVOKE ALL ON FUNCTION public\.submit_scheduled_club_training_today\(integer\) FROM PUBLIC, anon/);
 assert.match(migration,/GRANT EXECUTE ON FUNCTION public\.submit_scheduled_club_training_today\(integer\) TO authenticated/);
});
test('Only scheduled today, no fake type, tier or points',()=>{
 assert.match(migration,/league_private\.zurich_today\(\)/);
 assert.match(migration,/x\.dow=extract\(isodow FROM day_\)::integer/);
 assert.match(migration,/x\.id=p_slot_id/);
 assert.match(migration,/league_private\.training_closed_season\(day_\)/);
 assert.match(migration,/INSERT INTO public\.training_submissions\(/);
 assert.match(migration,/me\.id, sl\.training_type_id, day_, sl\.duration_minutes/);
 assert.doesNotMatch(migration,/INSERT INTO public\.point_transactions|UPDATE public\.point_transactions/);
 assert.doesNotMatch(ui,/\.from\(['"]training_submissions['"]\)/);
});
test('No duplicate request or Gym confirmation',()=>{
 assert.match(migration,/pg_advisory_xact_lock/);
 assert.match(migration,/x\.status IN \('pending','approved'\)/);
 assert.match(migration,/FROM public\.gym_attendance a/);
 assert.match(migration,/g\.status<>'cancelled'/);
 assert.match(migration,/already_pending/);
 assert.match(migration,/already_approved/);
 assert.match(migration,/gym_registered/);
 assert.match(migration,/checkin_required/);
 assert.match(migration,/choose_slot/);
});
test('Question is optional and keeps three training routes',()=>{
 assert.match(ui,/Warst du heute im Vereinstraining\?/);
 assert.match(ui,/Ja, im Verein/);
 assert.match(ui,/Nein, eigenes Training/);
 assert.match(ui,/Anderes Vereinstraining/);
 assert.match(ui,/submit_scheduled_club_training_today/);
 assert.match(ui,/status==='submitted'/);
 assert.match(ui,/role','status'/);
 assert.match(ui,/form\.hidden=true/);
 assert.match(ui,/form\.hidden=false/);
 assert.match(ui,/\?club=1/);
 assert.match(ui,/\?individual/);
 assert.doesNotMatch(ui,/innerHTML/);
 assert.match(boxer,/mountBoxerPrompt/);
 assert.match(boxer,/onIndividual/);
 assert.match(boxer,/onClub/);
});
test('Check-in keeps fixed weekly slots and existing supervised check-ins',()=>{
 assert.match(checkin,/mountCheckinSchedule/);
 assert.match(checkin,/my_gym_sessions_today/);
 assert.match(checkin,/gym_check_in/);
 assert.match(ui,/FIXER VEREINSSTUNDENPLAN/);
 assert.match(ui,/Number\(x\.dow\)===isoDow\(\)/);
});
