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
// Senden über RPC (Coaches sehen fremde Profile nicht): Verfasser = Aufrufer, nur aktive Boxer, Rollback entfernt sie
assert.match(sql,/FUNCTION public\.staff_send_feedback\(p_boxer_id uuid, p_title text, p_message text, p_visible_until date DEFAULT NULL\)/);
assert.match(sql,/VALUES \(p_boxer_id, me\.id, btrim\(p_title\), btrim\(p_message\), p_visible_until\)/);
assert.match(sql,/p\.id=p_boxer_id AND p\.role='boxer' AND p\.is_active/);
assert.match(rollback,/DROP FUNCTION IF EXISTS public\.staff_send_feedback\(uuid,text,text,date\)/);
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
assert.match(coach,/db\.rpc\('staff_send_feedback',\{p_boxer_id:boxer_id,p_title:title,p_message:message,p_visible_until:visible_until\}\)/);
assert.doesNotMatch(coach,/from\('boxer_coach_feedback'\)\.insert/,'coaches cannot insert directly (profiles RLS)');
assert.match(coach,/db\.rpc\('staff_list_feedback'/);assert.match(coach,/db\.rpc\('staff_update_feedback'/);
assert.match(coach,/p_visible_until:addDaysIso\(swissToday\(\),-1\)/,'archive now = yesterday');
assert.doesNotMatch(coach,/innerHTML\s*=\s*[^;]*item\.(title|message)/,'feedback text never as HTML');
// Dashboard (Training 2.0 ersetzt die zuklappbaren Abschnitte durch Bereiche mit Navigation): Bereiche, Filter pro Sitzung, 10 pro Seite
assert.match(coach,/COACH_VIEWS=\[\['home','Start','🏠','start'\],\['review','Prüfen','✅','bestaetigen'\],\['gym','Gym','🏟️','gym'\],\['boxers','Boxer','👥','boxer'\],\['history','Historie','🗓️','historie'\],\['more','Mehr','☰','mehr'\]\]/);
assert.match(coach,/sessionStorage\.getItem\('tl\.coach\.filters'\)/);assert.match(coach,/catch\{\}/);
assert.match(coach,/coach_training_audit_recent',\{p_limit:5\}/);assert.match(coach,/p_limit:10,p_offset:historyOffset/);
assert.match(read('takeover-coach-v2.css'),/#content\.cv2-content\{display:block!important\}/);
console.log('PASS: Etappe 6b – Feedback sichtbar bis (7 Tage Vorgabe, max. 90), Archiv, Zurückziehen nur durch Verfasser/Admin und für Boxer unsichtbar, Inhalte unverändert; Trainer-Dashboard 2.0 mit Bereichen, Filter bleiben erhalten, 10 pro Seite');
