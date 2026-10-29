'use strict';
// Static contracts for Etappe 17a: jede Trainingsart selbst eintragen, solange «Vereinstrainings nur per Gym-Check-in» aus ist.
const fs=require('node:fs'),assert=require('node:assert/strict');
const read=f=>fs.readFileSync(f,'utf8');
const sql=read('supabase/migrations/20261029230000_club_types_selfservice.sql'),code=sql.replace(/--[^\n]*/g,'');
const rollback=read('supabase/production-prep/rollback_20261029230000_club_types_selfservice.sql'),old=read('supabase/migrations/20261028230000_club_schedule_tiers.sql');
for(const f of ['preflight','postflight'])assert.ok(fs.existsSync('supabase/production-prep/'+f+'_20261029230000_club_types_selfservice.sql'),f);
const fn=(t,n)=>t.slice(t.indexOf('CREATE OR REPLACE FUNCTION '+n),t.indexOf('$fn$;',t.indexOf('CREATE OR REPLACE FUNCTION '+n))+5);
assert.match(code,/VALUES \('club_checkin_only','Vereinstrainings nur per Gym-Check-in',false\)\s*ON CONFLICT \(feature_key\) DO NOTHING;/,'switch starts off, existing switch untouched');
const g=fn(sql,'league_private.training_insert_guard'),o=fn(old,'league_private.training_insert_guard');
assert.equal(g.replace(" AND league_private.flag_on('club_checkin_only')",''),o,'only the extra switch condition differs');
assert.match(g,/NEW\.club_tier := NULL;[\s\S]*NEW\.recorded_by := NULL;/,'boxers still cannot set tier or recorded_by');
assert.doesNotMatch(code,/UPDATE public\.training_types|UPDATE public\.training_submissions|DELETE/i,'no data changes');
assert.equal(fn(rollback,'league_private.training_insert_guard'),o,'rollback verbatim');
const boxer=read('boxer.html'),plan=read('wochenplan.html'),help=read('takeover-help.js');
assert.match(boxer,/\.in\('feature_key',\['gym_training','club_checkin_only'\]\)/);
assert.match(plan,/feature_key','club_checkin_only'/);assert.match(plan,/können im Moment auch selbst eingetragen werden/);
assert.doesNotMatch(help,/laufen nur noch über den Check-in/);
console.log('PASS: Etappe 17a – neuer Schalter startet aus, Sperre nur mit beiden Schaltern (sonst identisch), Stufe weiter nicht selbst setzbar, keine Datenänderung, Rücknahme wörtlich, Formular/Wochenplan/Hilfe angepasst');
