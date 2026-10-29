'use strict';
// Static contracts for Etappe 13: Auszeichnungs-Designs gelten nur im Folgezeitraum; Symbole bleiben; Rücknahme wörtlich.
const fs=require('node:fs'),assert=require('node:assert/strict');
const read=f=>fs.readFileSync(f,'utf8');
const sql=read('supabase/migrations/20261029190000_award_designs_limited.sql'),code=sql.replace(/--[^\n]*/g,'');
const rollback=read('supabase/production-prep/rollback_20261029190000_award_designs_limited.sql');
const e7=read('supabase/migrations/20261029120000_card_designs_awards.sql'),e12=read('supabase/migrations/20261029180000_card_designs_more_personal.sql');
const page=read('karten.html'),help=read('takeover-help.js');
for(const f of ['preflight','postflight'])assert.ok(fs.existsSync('supabase/production-prep/'+f+'_20261029190000_award_designs_limited.sql'),f);
assert.match(sql,/^BEGIN;$/m);assert.match(sql,/^COMMIT;$/m);
// Fenster = Zeitraum direkt nach dem gewonnenen; gilt nur heute (Zürich) im Fenster
assert.match(code,/SELECT league_private\.card_period\(a\.kind, a\.period_end\+1\)/);
assert.match(code,/\(now\(\) AT TIME ZONE 'Europe\/Zurich'\)::date <@ league_private\.card_award_window\(a\)/);
assert.match(code,/WHEN 'award' THEN league_private\.card_award_until\(p,d\.award_kind\) IS NOT NULL/);
assert.match(code,/WHEN 'personal' THEN EXISTS/,'Etappe 12 bleibt');
// Symbole bleiben: card_look wird nicht angefasst
assert.doesNotMatch(code,/FUNCTION league_private\.card_look/);
// Sicherheit: alle Funktionen SECURITY DEFINER oder rein, leerer search_path, Helfer gesperrt, nichts für anon
for(const m of code.matchAll(/CREATE OR REPLACE FUNCTION ([a-z_.]+)\([^]*?\$fn\$/g))assert.match(m[0],/SET search_path=''/,m[1]);
assert.match(code,/REVOKE ALL ON FUNCTION league_private\.card_award_window\(public\.card_awards\), league_private\.card_award_until\(uuid,text\)[^;]*FROM PUBLIC, anon, authenticated;/);
assert.doesNotMatch(code,/TO anon|TO PUBLIC/);
const outsideConfirm=code.replace(/CREATE OR REPLACE FUNCTION public\.staff_confirm_card_award[^]*?\$fn\$;/,'');
assert.doesNotMatch(outsideConfirm,/\b(DELETE|UPDATE|INSERT|TRUNCATE)\b/i,'keine Datenänderung durch die Migration');
assert.match(code,/Dein Spezial-Design gilt bis '\|\|to_char\(upper\(w\)-1,'DD\.MM\.YYYY'\)/);
// staff_confirm_card_award: Prüfungen identisch mit 7d (nur Mitteilung anders)
const fn=(t,n)=>t.slice(t.indexOf('CREATE OR REPLACE FUNCTION '+n),t.indexOf('$fn$;',t.indexOf('CREATE OR REPLACE FUNCTION '+n))+5);
const checks=t=>fn(t,'public.staff_confirm_card_award').split('\n').filter(l=>/RAISE EXCEPTION/.test(l)).join('\n');
assert.equal(checks(sql),checks(e7),'gleiche Prüfungen beim Vergeben');
// Rücknahme wörtlich
assert.equal(fn(rollback,'league_private.card_design_available'),fn(e12,'league_private.card_design_available'));
for(const n of ['league_private.card_award_json','public.get_my_card_designs','public.staff_confirm_card_award'])assert.equal(fn(rollback,n),fn(e7,n),n);
assert.match(rollback,/DROP FUNCTION league_private\.card_award_until\(uuid,text\);/);
// Oberfläche
assert.doesNotMatch(page,/bleibt dir für immer/);
assert.match(page,/gilt bis '\+P\.fmtDate\(d\.valid_until\)/);assert.match(page,/Spezial-Design bis \$\{P\.esc\(P\.fmtDate\(a\.design_until\)\)\}/);
assert.match(page,/abgelaufen – gilt wieder nach der nächsten/);
assert.match(help,/Spezial-Design einer Auszeichnung gilt im Zeitraum danach/);
console.log('PASS: Etappe 13 – Auszeichnungs-Designs nur im Folgezeitraum (Zürich), Symbole unverändert, Helfer gesperrt, keine Datenänderung, Prüfungen beim Vergeben wie 7d, Rücknahme wörtlich, Karten-Seite und Hilfe angepasst');
