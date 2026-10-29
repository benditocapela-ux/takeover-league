'use strict';
// Static contracts for Etappe 6a (Vereins-Stundenplan, Stufen Pflicht/Ergänzung, Umwertung nur über Aktivierungsskript).
const fs=require('node:fs'),assert=require('node:assert/strict');
const read=f=>fs.readFileSync(f,'utf8');
const sql=read('supabase/migrations/20261028230000_club_schedule_tiers.sql');
const quests=read('supabase/migrations/20261028200000_weekly_quests.sql');
const prep='supabase/production-prep/';
const rollback=read(prep+'rollback_20261028230000_club_schedule_tiers.sql'),activate=read(prep+'activate_20261028230000_club_schedule_tiers.sql'),
 deactivate=read(prep+'deactivate_20261028230000_club_schedule_tiers.sql'),preview=read(prep+'preview_20261028230000_club_schedule_tiers.sql');
for(const f of ['preflight','postflight'])assert.ok(fs.existsSync(prep+f+'_20261028230000_club_schedule_tiers.sql'),f);

// Owner-Entscheide: 60/15/15 und 40/12/12, Pflicht nur Wettkämpfer, Stundenplan Mo/Di/Mi/Do/Sa
assert.match(sql,/\('pflicht','Pflichttraining',60,15,15,'\{wettkampf\}'\)/);
assert.match(sql,/\('ergaenzung','Ergänzungstraining',40,12,12,'\{\}'\)/);
assert.match(sql,/\(1,'Technisches Sparring','pflicht','Technisches Sparring'\),\(2,'Sandsack \/ Rundenarbeit','ergaenzung','Sandsack'\),\s*\(3,'Techniktraining','pflicht','Technik \/ Pratzen'\),\(4,'Krafttraining','ergaenzung','Athletik \/ Kraft'\),\s*\(6,'Technisches Sparring','pflicht','Technisches Sparring'\)/);
assert.match(sql,/WHERE name IN \('Reguläres Boxtraining','Techniktraining','Pratzentraining','Sandsack \/ Rundenarbeit'\) AND NOT club_only/);
assert.match(sql,/'Technisches Sparring',30,false,'Boxen',105,true/,'new type stays inactive until activation');
// Gruppennamen bleiben unverändert
assert.doesNotMatch(sql,/UPDATE public\.training_groups/);

// Die Migration selbst ändert keine bestehenden Punkte, Trainings oder Punktwerte (nur innerhalb von Funktionen)
const topLevel=sql.replace(/\$fn\$[\s\S]*?\$fn\$/g,'').replace(/\$function\$[\s\S]*?\$function\$/g,'').replace(/\$types\$[\s\S]*?\$types\$/g,'').replace(/--[^\n]*/g,'');
assert.doesNotMatch(topLevel,/UPDATE public\.(point_transactions|training_submissions|profiles|kg_ledger)\b|DELETE FROM|TRUNCATE|SET points/i);
assert.doesNotMatch(topLevel,/UPDATE public\.league_feature_flags/,'no flag change in migration');

// Stufen wirken erst mit Flag gym_training
assert.match(sql,/IF s\.club_tier IS NOT NULL AND league_private\.flag_on\('gym_training'\) THEN/);
assert.match(sql,/IF NOT league_private\.flag_on\('gym_training'\) THEN RAISE EXCEPTION 'Stufen gelten/);
assert.match(sql,/IF s\.status='confirmed' AND NOT league_private\.flag_on\('gym_training'\) THEN/);
// Boxer: keine Stufe / kein «eingetragen von» selbst setzen, Vereinsarten nur über das Gym
assert.match(sql,/NEW\.club_tier := NULL;\s*NEW\.recorded_by := NULL;/);
assert.match(sql,/IF tname IS NOT NULL AND league_private\.flag_on\('gym_training'\) THEN/);
// Wert = max(Stufe, Trainingsart); genau eine Buchung pro Training; Änderungen in training_audit; abgeschlossene Saisons unverändert
assert.match(sql,/GREATEST\(coalesce\(ct\.exp,0\), t\.points\)/);
assert.match(sql,/INSERT INTO public\.training_audit\(submission_id,changed_by,old_submission,new_submission,old_transaction,new_transaction\)/);
assert.match(sql,/z\.status='closed' AND s\.training_date BETWEEN z\.starts_on AND z\.ends_on\) THEN RETURN NULL/);
assert.match(sql,/v_points := league_private\.training_value\(p_submission_id\);/,'admin corrections keep tier');
assert.match(sql,/Eigene Trainings stuft ein anderer Trainer oder der Admin ein/);

// Umwertung nur über Aktivierung: Punktwerte 30, Sprint 30, Rücknahme stellt 50/40/35/30/40 her
assert.match(sql,/SET points=30 WHERE x\.name IN \('Reguläres Boxtraining','Techniktraining','Pratzentraining','Sandsack \/ Rundenarbeit','Sprint-Intervalle'\)/);
assert.match(sql,/\('Reguläres Boxtraining',50\),\('Techniktraining',40\),\('Pratzentraining',35\),\s*\('Sandsack \/ Rundenarbeit',30\),\('Sprint-Intervalle',40\)/);
assert.match(sql,/IF sl\.id IS NOT NULL AND sl\.tier IS NOT NULL AND \(t\.club_only OR sl\.training_type_id=t\.id\) THEN/);
assert.match(sql,/RAISE EXCEPTION 'Bereits aktiviert'/);
assert.match(activate,/league_private\.activate_club_tiers\(/);assert.match(activate,/feature_key IN \('gym_training','weekly_quests'\)/);
assert.match(deactivate,/league_private\.deactivate_club_tiers\(/);assert.match(deactivate,/is_enabled=false/);
assert.match(preview,/RAISE EXCEPTION E'VORSCHAU \(zurückgerollt\)/);assert.doesNotMatch(preview,/^\s*COMMIT\s*;/m);
assert.match(sql,/REVOKE ALL ON FUNCTION league_private\.activate_club_tiers\(uuid\), league_private\.deactivate_club_tiers\(uuid\) FROM PUBLIC, anon, authenticated/);

// Quests: Pflicht-Quest nur Wettkämpfer, keine Zusatz-EXP → Deckel «Moderat» 175 EXP/Woche gilt für jede Gruppe
assert.match(sql,/\('pflicht','weekly','Alle \{n\} Pflichttrainings',[^)]*'pflicht_days',3,'\{\}',0,80,5,'\{wettkampf\}'\)/);
const qrows=[...(quests+sql).matchAll(/\('([a-z_]+)','(weekly|daily|chest)','[^']*',(?:'[^']*'|NULL),'[a-z_]+',\d+,\s*'[^']*',(\d+),(\d+),\d+(?:,'[^']*')?\)/g)].map(m=>({key:m[1],kind:m[2],exp:+m[3]}));
assert.ok(qrows.length>=11,'quests parsed '+qrows.length);
const maxExp=qrows.filter(q=>q.kind!=='daily').reduce((t,q)=>t+q.exp,0)+7*Math.max(...qrows.filter(q=>q.kind==='daily').map(q=>q.exp));
assert.ok(maxExp<=175,'max EXP/week '+maxExp);
assert.match(sql,/coalesce\(\(league_private\.group_of\(p_profile\)\)\.key,''\) <> ALL\(d\.only_groups\)/);

// Rollback: alte Versionen zurück, neue Funktionen weg, Daten bleiben
for(const f of ['public.staff_confirm_gym_session','public.get_my_week_plan','league_private.kg_sync','league_private.kg_pass_points','league_private.quest_state','public.admin_edit_training'])
 assert.match(rollback,new RegExp('CREATE OR REPLACE FUNCTION '+f.replace('.','\\.')+'\\('),'rollback restores '+f);
assert.doesNotMatch(rollback.replace(/\$fn\$[\s\S]*?\$fn\$/g,'').replace(/\$function\$[\s\S]*?\$function\$/g,'').replace(/--[^\n]*/g,''),/DROP TABLE|DELETE FROM|TRUNCATE|UPDATE public\.(point_transactions|training_submissions)/i);
assert.match(rollback,/DROP TRIGGER IF EXISTS league_training_insert_guard/);
assert.doesNotMatch(rollback.slice(rollback.indexOf('-- Vorherige Versionen'),rollback.indexOf('DROP FUNCTION IF EXISTS league_private.activate_club_tiers')),/training_value|club_tier/,'rollback versions do not use new columns');

// Frontend: nur vorgesehene RPCs, Escape, Stufen im Coach-Dashboard nur bei freigeschaltetem Gym
const rpcOf=t=>[...new Set([...t.matchAll(/\brpc\(\s*'([a-z_]+)'/g)].map(m=>m[1]))];
const coach=read('coach.html'),checkin=read('checkin.html'),plan=read('wochenplan.html'),boxer=read('boxer.html'),praesenz=read('praesenz.html'),questsPage=read('quests.html');
const defined=new Set([...read('supabase/migrations/20261028190000_training_groups_gym.sql').concat(sql).matchAll(/CREATE OR REPLACE FUNCTION public\.([a-z_]+)\(/g)].map(m=>m[1]));
for(const r of ['get_club_schedule','staff_set_training_tier','staff_training_tiers'])assert.ok(rpcOf(coach).includes(r)&&defined.has(r),'coach '+r);
for(const r of ['staff_open_club_session','staff_update_gym_session','get_club_schedule'])assert.ok(rpcOf(checkin).includes(r),'checkin '+r);
for(const r of ['admin_save_club_slot','get_club_schedule'])assert.ok(rpcOf(plan).includes(r),'plan '+r);
assert.match(coach,/clubSched=r\.error\|\|!r\.data\|\|!r\.data\.enabled\|\|r\.data\.preview\?null:r\.data/,'tier controls only when gym is on');
assert.match(boxer,/flagOn\('gym_training'\)&&flagOn\('club_checkin_only'\)&&types\.some\(x=>x\.club_only\)\)\{[\s\S]{0,120}types=types\.filter\(x=>!x\.club_only\)/,'club types hidden only with both switches (Etappe 17a)');
assert.match(questsPage,/filter\(q=>q\.available\|\|q\.claimed\|\|!q\.only_groups\)/,'group-only quests hidden for other groups');
assert.match(questsPage,/pflicht_days:'Pflichttrainings \(Tage\)'/);
for(const [n,t] of [['checkin',checkin],['wochenplan',plan],['praesenz',praesenz]]){
 assert.doesNotMatch(t,/\.(insert|update|upsert|delete)\(/,n);assert.doesNotMatch(t,/service_role|sb_secret_/i,n);
 for(const m of t.matchAll(/\$\{(?:x|s|t)\.(label|tier_label|training_type)\}/g))assert.fail(n+': unescaped '+m[0]);
}
console.log('PASS: Etappe 6a – Stufen 60/40 (Coins 15/12, Kampfpfad 15/12), Stundenplan Mo–Sa, Gruppen unverändert, Migration ändert keine Daten, Stufen erst mit Flag, Umwertung nur per Aktivierung (rücknehmbar), Pflicht-Quest nur Wettkämpfer ohne Zusatz-EXP (max. '+maxExp+' EXP/Woche), Rollback behält Daten');
