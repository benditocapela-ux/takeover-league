'use strict';
// Statische Verträge Training 2.0 / Trainer-Dashboard 2.0: Sicherheit der Wertung, keine Stufe vom Client, keine HTML-Injektion.
const assert=require('node:assert/strict'),fs=require('node:fs');
const read=f=>fs.readFileSync(f,'utf8');
const sql=read('supabase/migrations/20261031090000_training_v2_classification.sql');
const coach=read('coach.html'),boxer=read('boxer.html'),v2=read('takeover-training-v2.js'),css=read('takeover-coach-v2.css');
// Datenbank
assert.match(sql,/VALUES \('training_v2','[^']+',false\)/,'Schalter startet aus');
assert.match(sql,/NEW\.club_tier := NULL;/,'Boxer setzen keine Stufe');
assert.match(sql,/CREATE TRIGGER league_training_request_update_guard BEFORE UPDATE/,'Antrag nach dem Einreichen gesperrt');
assert.match(sql,/FUNCTION public\.staff_review_training[\s\S]*?league_private\.require_staff\(\)/,'Bestätigung nur Trainer');
assert.match(sql,/FUNCTION public\.staff_correct_training[\s\S]*?league_private\.require_staff\(\)/);
assert.match(sql,/SELECT \* INTO s FROM public\.training_submissions x WHERE x\.id=p_submission_id FOR UPDATE;[\s\S]*?'already',true/,'Sperre + idempotent');
assert.match(sql,/PERFORM public\.review_training\(s\.id,'approved'\)/,'eine bestehende Punktebuchung');
assert.match(sql,/USING ERRCODE='23505'/,'Duplikate nur bewusst');
assert.match(sql,/league_private\.training_value\(p_sub uuid\)[\s\S]*?training_reward\(s\.training_type_id, s\.club_tier\)/,'eine Bewertungsregel');
assert.match(sql,/REVOKE ALL ON FUNCTION league_private\.training_reward\(bigint,text\)/);
assert.match(sql,/FROM PUBLIC, anon;\nGRANT EXECUTE ON FUNCTION public\.staff_review_training/);
assert.doesNotMatch(sql,/UPDATE public\.point_transactions|DELETE FROM public\.(training_submissions|point_transactions|kg_ledger)/,'Migration bucht nichts um');
assert.match(read('supabase/production-prep/training_v2_dry_run_read_only.sql'),/^-- Read-only/);
assert.doesNotMatch(read('supabase/production-prep/training_v2_dry_run_read_only.sql'),/\b(UPDATE|INSERT|DELETE|ALTER|CREATE)\b/);
// Boxer-Formular
assert.match(boxer,/Object\.assign\(payload,window\.TLTrainingV2\?\.payload\?\.\(\)\|\|\{\}\)/);
assert.doesNotMatch(v2,/club_tier|points\s*:|exp\s*:/,'Client sendet keine Stufe und keine Werte');
assert.match(v2,/get_training_v2_config/);assert.match(v2,/Die endgültige Gutschrift erfolgt nach Bestätigung durch deinen Trainer\./);
assert.doesNotMatch(v2,/innerHTML/);
// Trainer-Dashboard
assert.match(coach,/db\.rpc\('staff_review_training'/);assert.match(coach,/db\.rpc\('staff_correct_training'/);
assert.match(coach,/if\(inflight\.has\(s\.id\)\)return;inflight\.add\(s\.id\)/,'kein Doppelklick');
assert.doesNotMatch(coach,/innerHTML/,'Texte nur als textContent');
assert.doesNotMatch(coach,/\.limit\(1000\)/);
assert.match(coach,/p_limit:10,p_offset:reset\?0:pendingOffset/,'Pagination 10');
assert.match(css,/min-height:44px/);assert.match(css,/safe-area-inset-bottom/);assert.match(css,/prefers-reduced-motion:reduce/);
console.log('PASS: Training 2.0 Verträge – Schalter aus, Stufe nur serverseitig, gesperrte Anträge, idempotente Bestätigung, eine Bewertungsregel, keine Umbuchung durch die Migration, Dry-Run nur lesend, Client sendet nur Antrag, kein innerHTML, Pagination 10, Touchflächen');
