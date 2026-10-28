'use strict';
// Static contracts for Etappe 6b (Feedback mit Ablaufdatum, Archiv, Zurückziehen; kompaktes Coach-Dashboard).
const fs=require('node:fs'),assert=require('node:assert/strict');
const read=f=>fs.readFileSync(f,'utf8');
const sql=read('supabase/migrations/20261028240000_feedback_visibility.sql'),rollback=read('supabase/production-prep/rollback_20261028240000_feedback_visibility.sql');
const coach=read('coach.html'),boxer=read('boxer.html');
for(const f of ['preflight','postflight'])assert.ok(fs.existsSync('supabase/production-prep/'+f+'_20261028240000_feedback_visibility.sql'),f);
// Vorgabe 7 Tage, höchstens 90 Tage, gestern = archivieren; bestehende: Versand + 7
assert.match(sql,/SET DEFAULT \(\(now\(\) AT TIME ZONE 'Europe\/Zurich'\)::date \+ 7\)/);
assert.match(sql,/NEW\.visible_until < today OR NEW\.visible_until > today \+ 90/);
assert.match(sql,/p_visible_until < today - 1 OR p_visible_until > today \+ 90/);
assert.match(sql,/SET visible_until=\(created_at AT TIME ZONE 'Europe\/Zurich'\)::date \+ 7 WHERE visible_until IS NULL/);
// Inhalte der bestehenden Feedbacks werden nicht verändert, nichts gelöscht
assert.doesNotMatch(sql.replace(/\$fn\$[\s\S]*?\$fn\$/g,''),/SET (title|message|boxer_id|coach_id|created_at)|DELETE FROM|TRUNCATE/i);
assert.doesNotMatch(sql,/DELETE FROM public\.boxer_coach_feedback/);
// Zurückgezogen: für Boxer auch über die Tabelle unsichtbar; nur Verfasser/Admin ändern
assert.match(sql,/boxer_coach_feedback\.withdrawn_at IS NULL AND EXISTS/);
assert.match(sql,/me\.role<>'admin' AND f\.coach_id<>me\.id THEN RAISE EXCEPTION 'Nur der Verfasser oder der Admin/);
assert.match(sql,/NEW\.withdrawn_at := NULL/);
assert.match(rollback,/CREATE POLICY feedback_select_enabled/);assert.doesNotMatch(rollback.replace(/--[^\n]*/g,''),/DROP TABLE|DROP COLUMN|DELETE FROM/i);
// Frontend: Boxer liest über die RPC (aktiv/archiviert), Coach sendet mit «sichtbar bis» und ändert über die RPC
assert.match(boxer,/db\.rpc\('get_my_feedback'\)/);assert.doesNotMatch(boxer,/from\('boxer_coach_feedback'\)\.select/);
assert.match(boxer,/Archivierte Feedbacks \('/);
assert.match(coach,/insert\(\{boxer_id,coach_id:me\.id,title,message,visible_until\}\)/);
assert.match(coach,/db\.rpc\('staff_list_feedback'/);assert.match(coach,/db\.rpc\('staff_update_feedback'/);
assert.match(coach,/p_visible_until:addDaysIso\(swissToday\(\),-1\)/,'archive now = yesterday');
assert.doesNotMatch(coach,/innerHTML\s*=\s*[^;]*item\.(title|message)/,'feedback text never as HTML');
// Dashboard: Reihenfolge, Standard offen/zu, Zustand pro Gerät, nur letzte 5
assert.match(coach,/COACH_SECTIONS=\[\['pending','Offene Trainings',true\],\['gym','Gym heute',true\],\['entry','Training eintragen',false\],\['feedback','Feedback',false\],\['edit','Trainings bearbeiten',false\],\['audit','Änderungshistorie',false\]\]/);
assert.match(coach,/localStorage\.getItem\('tl\.coach\.sections'\)/);assert.match(coach,/catch\{return \{\}\}/);
assert.match(coach,/coach_training_audit_recent',\{p_limit:5\}/);assert.match(coach,/p_limit:5,p_offset:historyOffset/);
assert.match(coach,/#content:not\(\.hidden\)\{display:flex/);
console.log('PASS: Etappe 6b – Feedback sichtbar bis (7 Tage Vorgabe, max. 90), Archiv, Zurückziehen nur durch Verfasser/Admin und für Boxer unsichtbar, Inhalte unverändert; Coach-Dashboard geordnet, zuklappbar, letzte 5');
