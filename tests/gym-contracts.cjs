'use strict';
// Static contracts for Etappe 2 (Gruppen, Gym-Check-in, Präsenz, Wochenplan).
const fs=require('node:fs'),assert=require('node:assert/strict');
const sql=fs.readFileSync('supabase/migrations/20261028190000_training_groups_gym.sql','utf8');
const types=fs.readFileSync('supabase/migrations/20261028150000_training_types_duration_notes.sql','utf8');
const rpcOf=t=>[...new Set([...t.matchAll(/\brpc\(\s*'([a-z_]+)'/g)].map(m=>m[1]))].sort();
const page=n=>fs.readFileSync(n,'utf8');
const checkin=page('checkin.html'),praesenz=page('praesenz.html'),plan=page('wochenplan.html');
assert.deepEqual(rpcOf(checkin),['get_my_performance','get_my_presence','gym_check_in','list_training_groups','my_gym_sessions_today',
 'staff_cancel_gym_session','staff_confirm_gym_session','staff_get_gym_session','staff_list_gym_sessions','staff_open_gym_session','staff_set_gym_attendance']);
assert.deepEqual(rpcOf(praesenz),['get_my_performance','get_my_presence','gym_check_in','list_training_groups','my_gym_sessions_today','staff_presence_overview']);
assert.deepEqual(rpcOf(plan),['admin_set_group_target','get_my_performance','get_my_week_plan','list_training_groups','staff_get_training_plan',
 'staff_list_group_members','staff_save_training_plan','staff_set_training_group']);
// Jede aufgerufene RPC existiert in der Migration (oder in Etappe 1)
const defined=new Set([...sql.matchAll(/CREATE OR REPLACE FUNCTION public\.([a-z_]+)\(/g)].map(m=>m[1]).concat(['get_my_performance']));
for(const r of [...rpcOf(checkin),...rpcOf(praesenz),...rpcOf(plan)])assert.ok(defined.has(r),'RPC not defined: '+r);
for(const [n,t] of [['checkin.html',checkin],['praesenz.html',praesenz],['wochenplan.html',plan]]){
 assert.doesNotMatch(t,/service_role|sb_secret_/i,n+': privileged key');
 const tables=[...t.matchAll(/\.from\('([a-z_0-9]+)'\)/g)].map(m=>m[1]);
 assert.ok(tables.every(x=>x==='training_types'),n+': only training_types may be read directly, got '+tables);
 assert.doesNotMatch(t,/\.(insert|update|upsert|delete)\(/,n+': no direct table writes');
 assert.ok(t.indexOf('takeover-performance.js')<t.indexOf('<script type="module">'),n+': library before page script');
 assert.match(t,/data-tl-screen="/);assert.match(t,/takeover-navigation\.js/);
}
// Vorlagen nutzen nur existierende Trainingsarten
const known=new Set([...types.matchAll(/\('([^']+)',(?:\d+|'[A-Za-zÄÖÜäöü &]+')/g)].map(m=>m[1]));
const tpl=plan.match(/const TEMPLATES=\{([\s\S]*?)\n\};/)[1];
const used=new Set([...tpl.matchAll(/\[\d,'([^']+)',\d+\]/g)].map(m=>m[1]));
assert.ok(used.size>=10,'templates parsed');
for(const n of used)assert.ok(known.has(n)||['Joggen','Alternative Ausdauer'].includes(n),'unknown training type in template: '+n);
// Gym-Check-in bestätigt über den bestehenden Weg und schützt vor Doppeltrainings
assert.match(sql,/public\.staff_record_training\(a\.profile_id/);
assert.match(sql,/hat dieses Training schon eingereicht/);
assert.match(sql,/t\.name='Joggen'/);
assert.match(sql,/('newcomer','Newcomer',2[\s\S]*'fortgeschritten','Fortgeschrittene',3[\s\S]*'wettkampf','Wettkämpfer',5)/);
const nav=page('takeover-navigation.js');
for(const p of ['wochenplan.html','praesenz.html','checkin.html'])assert.match(nav,new RegExp("'"+p.replace('.','\\.')+"'"),'menu entry '+p);
console.log('PASS: Gruppen, Check-in, Präsenz und Wochenplan – nur vorgesehene RPCs, keine Tabellenschreibzugriffe, Vorlagen mit echten Trainingsarten');
