'use strict';
const fs=require('node:fs'),assert=require('node:assert/strict'),{JSDOM}=require('jsdom');
const read=f=>fs.readFileSync(f,'utf8');
for(const f of ['goals.html','league-history.html','boxer-profile.html']){
 const d=new JSDOM(read(f),{url:'https://example.test/takeover-league/'+f});
 assert.ok(d.window.document.querySelector('meta[name=viewport]'),'responsive viewport '+f);
 assert.ok(d.window.document.querySelector('script[src="./takeover-navigation.js"]'),'site navigation '+f);
 d.window.close();
}
const goals=read('goals.html');
assert.match(goals,/league_v21_save_goal/);
assert.match(goals,/league_v21_record_goal_progress/);
assert.match(goals,/training_submissions/);
assert.match(goals,/\.eq\('status','approved'\)/);
assert.match(goals,/role!=='boxer'/);
const history=read('league-history.html');
for(const table of ['league_seasons_v21','league_season_results_v21','league_hall_of_fame_v21'])
 assert.ok(history.includes(table),'History source '+table);
assert.match(history,/textContent=/,'No unsafe public data markup');
const p=read('boxer-profile.js');
assert.match(p,/function renderPublicRadar\(/);
assert.match(p,/renderPublicRadar\(boxer,leader\[0\]/);
assert.match(p,/get_public_leaderboard/);
assert.doesNotMatch(p,/training_submissions/,'Public radar must not access private training details');
const sql=read('supabase/migrations/20261019010000_league_21_seasons_goals_history_foundation.sql');
assert.match(sql,/enable row level security/);
assert.match(sql,/revoke all on public/);
assert.match(sql,/No client-side INSERT\/UPDATE\/DELETE grants/);
const rpc=read('supabase/migrations/20261019011000_league_21_goal_authorized_rpcs.sql');
assert.match(rpc,/actor\.id<>target\.id/);
assert.match(rpc,/goal\.metric<>'custom' and actor\.role='boxer'/);
assert.match(rpc,/security invoker/);
assert.doesNotMatch(rpc,/insert into public\.point_transactions|update public\.point_transactions/i,'Goal progress must not grant EXP without reconciliation');
console.log('PASS V2.1 profile radar, season/Hall-of-Fame pages, owner goal API and reward isolation');
