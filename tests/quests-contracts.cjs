'use strict';
// Static contracts for Etappe 3 (Wochen-Quests): page only calls intended RPCs, no table access,
// rewards stay moderate and never touch ranking points, quest EXP cannot collide with challenge payouts.
const fs=require('node:fs'),assert=require('node:assert/strict');
const sql=fs.readFileSync('supabase/migrations/20261028200000_weekly_quests.sql','utf8');
const page=fs.readFileSync('quests.html','utf8'),js=fs.readFileSync('takeover-performance.js','utf8');
const rollback=fs.readFileSync('supabase/production-prep/rollback_20261028200000_weekly_quests.sql','utf8');
const rpcOf=t=>[...new Set([...t.matchAll(/\brpc\(\s*'([a-z_]+)'/g)].map(m=>m[1]))].sort();
assert.deepEqual(rpcOf(page),['admin_list_quests','admin_update_quest','claim_quest','get_my_performance','get_my_quests','list_training_groups','staff_quest_overview']);
const defined=new Set([...sql.matchAll(/CREATE OR REPLACE FUNCTION public\.([a-z_]+)\(/g)].map(m=>m[1]).concat(['get_my_performance','list_training_groups']));
for(const r of rpcOf(page))assert.ok(defined.has(r),'RPC not defined: '+r);
assert.doesNotMatch(page,/service_role|sb_secret_/i);
assert.doesNotMatch(page,/\.from\(/,'quests page reads no tables directly');
assert.doesNotMatch(page,/\.(insert|update|upsert|delete)\(/,'no direct table writes');
assert.ok(page.indexOf('takeover-performance.js')<page.indexOf('<script type="module">'),'library before page script');
assert.match(page,/data-tl-screen="quests"/);assert.match(page,/takeover-navigation\.js/);
assert.match(js,/rpc\('get_my_quests'\)/,'studio tile uses get_my_quests');

// Seeds: 5 Wochenquests, Truhe, 4 Tagesquests, moderat (max. 175 EXP/Woche)
const seed=sql.match(/INSERT INTO public\.quest_definitions\([^)]*\) VALUES([\s\S]*?)ON CONFLICT/)[1];
const rows=[...seed.matchAll(/\('([a-z_]+)','(weekly|daily|chest)','[^']*',(?:'[^']*'|NULL),'([a-z_]+)',(\d+),\s*'(\{[^']*\})',(\d+),(\d+),(\d+)\)/g)]
 .map(m=>({key:m[1],kind:m[2],metric:m[3],target:+m[4],groups:JSON.parse(m[5]),exp:+m[6],coins:+m[7]}));
assert.equal(rows.length,10,'10 seeded quests');
const by=k=>rows.filter(r=>r.kind===k);
assert.equal(by('weekly').length,5);assert.equal(by('chest').length,1);assert.equal(by('daily').length,4);
const maxWeek=[...by('weekly'),...by('chest')].reduce((t,r)=>t+r.exp,0)+7*Math.max(...by('daily').map(r=>r.exp));
assert.equal(maxWeek,175,'moderat: max. 175 EXP pro Woche');
assert.ok(by('weekly').every(r=>r.exp<=30)&&by('chest')[0].exp<=40&&by('daily').every(r=>r.exp<=5));
const box=rows.find(r=>r.key==='box_sessions');
assert.deepEqual(box.groups,{newcomer:2,fortgeschritten:3,wettkampf:4},'Trainingsanspruch steigt je Gruppe');
for(const r of rows)for(const g of Object.keys(r.groups))assert.ok(['newcomer','fortgeschritten','wettkampf'].includes(g),'unknown group '+g);

// Belohnung: nur EXP (points=0), eigene Beschreibung, keine Kollision mit Challenge-/Ziel-Auszahlungen
assert.match(sql,/VALUES \(me\.id,NULL,0,d\.exp,'challenge_exp','Quest-Belohnung: '/);
for(const prefix of ['Coach Challenge: ','Challenge reward: ','Personal goal reward: ','Global challenge reward: '])
 assert.ok(!'Quest-Belohnung: '.startsWith(prefix)&&!prefix.startsWith('Quest'),'description prefix must not collide with '+prefix);
// Fortschritt nur aus bestätigten Trainings
assert.match(sql,/s\.status='approved' AND s\.training_date BETWEEN p_from AND p_to/);
assert.doesNotMatch(sql.replace(/--[^\n]*/g,''),/status\s*(=|IN)\s*\(?'pending'/,'pending trainings never count');
// Admin-Grenzen, keine Selbstabholung durch den Admin, Abholung serialisiert
assert.match(sql,/WHEN 'weekly' THEN 100 WHEN 'chest' THEN 200 ELSE 50/);
assert.match(sql,/me\.role NOT IN \('boxer','coach'\)/);
assert.match(sql,/pg_advisory_xact_lock/);
assert.match(sql,/UNIQUE\(profile_id, quest_key, period_start\)/);
assert.match(sql,/INSERT INTO public\.league_feature_flags[\s\S]*'weekly_quests'[\s\S]*false\)/);
// Rollback entfernt nur Funktionen, nie Daten
assert.doesNotMatch(rollback,/DROP TABLE|DELETE FROM|TRUNCATE|UPDATE /i,'rollback keeps data');
const nav=fs.readFileSync('takeover-navigation.js','utf8');
assert.match(nav,/'quests\.html'/,'menu entry');
console.log('PASS: Wochen-Quests – nur vorgesehene RPCs, moderate Belohnungen (max. 175 EXP/Woche, 0 Rangpunkte), Gruppenziele, nur bestätigte Trainings, Rollback behält Daten');
