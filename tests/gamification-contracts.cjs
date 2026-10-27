'use strict';
// Pure-logic checks for takeover-gamification.js (weekly quests, week streak, achievement
// progress, rival hint, level curve) plus page wiring. No network, no browser.
const assert=require('node:assert/strict'),fs=require('node:fs');
const src=fs.readFileSync('takeover-gamification.js','utf8');
(async()=>{
 const m=await import('data:text/javascript,'+encodeURIComponent(src));
 const types=new Map([['1','Reguläres Boxtraining'],['2','Sparring'],['3','Techniktraining'],['4','Krafttraining'],['5','Sprint-Intervalle'],['6','Joggen']]);
 const row=(d,t,s='approved',extra={})=>({training_date:d,training_type_id:t,status:s,...extra});
 // Tuesday 27.10.2026; week starts Monday 26.10.
 const today=new Date(2026,9,27);
 assert.equal(m.weekStart(today),'2026-10-26');
 const rows=[row('2026-10-27',6,'pending'),row('2026-10-26',1),
  row('2026-10-24',3),row('2026-10-22',1),row('2026-10-17',4),row('2026-10-15',1),row('2026-10-08',2),row('2026-10-06',6)];
 const w=m.weeklyState(rows,types,today);
 assert.deepEqual(w.quests.map(q=>[q.key,q.done,q.waiting]),[['sessions',1,1],['boxing',1,0],['engine',0,1]]);
 assert.equal(w.currentMet,false,'Unfinished week is not counted yet');
 assert.equal(w.streak,3,'Three completed weeks in a row; the running week never breaks the streak');
 assert.equal(w.missing,1);
 const gap=m.weeklyState([row('2026-10-26',1),row('2026-10-27',1),row('2026-10-08',2),row('2026-10-06',6)],types,today);
 assert.equal(gap.streak,1,'A week below the goal breaks the streak');
 const p=m.achievementProgress([row('2026-10-01',6,'approved',{jogging_km:7.5}),row('2026-10-02',6,'approved',{jogging_km:'5'}),
  row('2026-10-02',3,'approved',{technique_minutes:45}),row('2026-10-03',6,'pending',{jogging_km:20})],types);
 assert.equal(p.training,3);assert.equal(p.consistent,2);assert.equal(p.road,12.5);assert.equal(p.technician,45);assert.equal(p.complete,0);
 const defs=[{id:'a',code:'road_25',title:'Road King – Bronze'},{id:'b',code:'road_75',title:'Road King – Silber'},
  {id:'c',code:'training_10',title:'Training Warrior – Bronze'},{id:'d',code:'technician_300',title:'The Technician – Bronze'},
  {id:'e',code:'flash_5',title:'The Flash – Bronze'}];
 const next=m.nextAchievements(p,new Set(),defs);
 assert.deepEqual(next.map(x=>x.title),['Road King – Bronze','Training Warrior – Bronze','The Technician – Bronze'],'Closest next tier per family first, no 0-progress families');
 assert.equal(next[0].missing,12.5);
 const board=[{rank_position:1,boxer_name:'Matteo',monthly_points:96},{rank_position:2,boxer_name:'Lea',monthly_points:70},{rank_position:3,boxer_name:'Boxer D',monthly_points:70}];
 assert.deepEqual(m.rivalHint(board,'Boxer D'),{rank:3,leader:false,name:'Lea',targetRank:2,gap:0});
 assert.equal(m.rivalHint(board,'Matteo').leader,true);assert.equal(m.rivalHint(board,'Matteo').gap,26);
 assert.equal(m.rivalHint([...board,{rank_position:4,boxer_name:'Lea',monthly_points:1}],'Lea'),null,'Ambiguous names show no rival');
 assert.equal(m.rivalHint(board,'Unbekannt'),null);
 // Same curve as league_level_from_exp_v2: level L starts at 100(L-1)+12.5(L-1)(L-2).
 for(const [xp,level,letter] of [[0,1,'F'],[99,1,'F'],[100,2,'F'],[2124,10,'F'],[2125,11,'E'],[2470,11,'E'],[2475,12,'E']])
  assert.deepEqual([m.levelFromExp(xp).level,m.levelFromExp(xp).letter],[level,letter],'Level curve at '+xp);
 // Wiring: loaded lazily with the page version, no new script tag, no new RPC literal in boxer.html.
 const boxer=fs.readFileSync('boxer.html','utf8');
 assert.match(boxer,/import\('\.\/takeover-gamification\.js'\+version\)/);
 assert.match(boxer,/document\.dispatchEvent\(new Event\('takeover:history-loaded'\)\)/);
 assert.match(boxer,/'league-challenges\.html','league-history\.html','goals\.html','arena\.html'\]/);
 assert.doesNotMatch(src,/\.(insert|update|upsert|delete)\(/,'Gamification layer must stay read-only');
 const duels=fs.readFileSync('duels.html','utf8');
 assert.match(duels,/Revanche fordern/);assert.match(duels,/appendRivalry\(card,duel\)/);
 // Season close in the League Manager: German errors, button only after the last season day.
 const manager=fs.readFileSync('league-manager.html','utf8');
 assert.match(manager,/if\(s\.status==='active'&&s\.ends_on>=today\)button\.disabled=true/);
 assert.match(manager,/Pending season trainings require coach review/);
 assert.match(manager,/seasonError\(r\.error\.message\)/);
 assert.match(manager,/if\(s\.status==='draft'&&running\)\{\n    button\.disabled=true;/);
 console.log('PASS: weekly quests, week streak, achievement progress, rival hint, level curve and read-only wiring');
})().catch(e=>{console.error(e);process.exitCode=1});
