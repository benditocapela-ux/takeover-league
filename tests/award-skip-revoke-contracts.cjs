'use strict';
// Static contracts for Etappe 14: «Diesmal nicht vergeben» und Zurückziehen auch früherer Auszeichnungen.
const fs=require('node:fs'),assert=require('node:assert/strict');
const read=f=>fs.readFileSync(f,'utf8');
const sql=read('supabase/migrations/20261029200000_award_skip_revoke.sql'),code=sql.replace(/--[^\n]*/g,'');
const rollback=read('supabase/production-prep/rollback_20261029200000_award_skip_revoke.sql');
const e7=read('supabase/migrations/20261029120000_card_designs_awards.sql'),e13=read('supabase/migrations/20261029190000_award_designs_limited.sql');
const page=read('karten.html'),help=read('takeover-help.js');
for(const f of ['preflight','postflight'])assert.ok(fs.existsSync('supabase/production-prep/'+f+'_20261029200000_award_skip_revoke.sql'),f);
assert.match(sql,/^BEGIN;$/m);assert.match(sql,/^COMMIT;$/m);
const fn=(t,n)=>t.slice(t.indexOf('CREATE OR REPLACE FUNCTION '+n),t.indexOf('$fn$;',t.indexOf('CREATE OR REPLACE FUNCTION '+n))+5);
// Tabelle: RLS, keine direkten Rechte, nur ein aktives «nicht vergeben» pro Zeitraum
assert.match(code,/ALTER TABLE public\.card_award_skips ENABLE ROW LEVEL SECURITY;/);
assert.match(code,/REVOKE ALL ON public\.card_award_skips FROM PUBLIC, anon, authenticated;/);
assert.match(code,/UNIQUE INDEX IF NOT EXISTS card_award_skips_one_active ON public\.card_award_skips\(kind, period_start\) WHERE undone_at IS NULL/);
// Alle Funktionen: leerer search_path; RPCs nur für Trainer/Admin; nichts für anon
for(const m of code.matchAll(/CREATE OR REPLACE FUNCTION ([a-z_.]+)\([^]*?\$fn\$/g))assert.match(m[0],/SET search_path=''/,m[1]);
for(const n of ['public.staff_skip_card_award','public.staff_unskip_card_award','public.staff_card_award_overview','public.staff_confirm_card_award'])
 assert.match(fn(sql,n),/me\.role NOT IN \('admin','coach'\)/,n);
assert.doesNotMatch(code,/TO anon|TO PUBLIC/);
assert.match(fn(sql,'public.staff_unskip_card_award'),/IF me\.role<>'admin' AND s\.skipped_by<>me\.id THEN/);
assert.match(fn(sql,'public.staff_unskip_card_award'),/SET undone_at=now\(\), undone_by=me\.id/,'Verlauf bleibt');
assert.doesNotMatch(code,/\bDELETE\b/i);
// Vergeben und «nicht vergeben» schliessen sich aus, mit gleicher Sperre pro Zeitraum
const lock="pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('card_award:'||p_kind||':'||lower(r)::text))";
for(const n of ['public.staff_skip_card_award','public.staff_confirm_card_award'])assert.ok(fn(sql,n).includes(lock),n+' lock');
assert.match(fn(sql,'public.staff_confirm_card_award'),/card_award_skips x WHERE x\.kind=p_kind AND x\.period_start=lower\(r\) AND x\.undone_at IS NULL/);
assert.match(fn(sql,'public.staff_skip_card_award'),/card_awards x WHERE x\.kind=p_kind AND x\.period_start=lower\(r\) AND x\.revoked_at IS NULL/);
// Vergeben: sonst identisch mit Etappe 13 (nur Sperre + «nicht vergeben»-Prüfung neu)
const strip=t=>fn(t,'public.staff_confirm_card_award').split('\n').filter(l=>!l.includes('pg_advisory_xact_lock')&&!l.includes('card_award_skips')&&!l.includes('«nicht vergeben» gewählt')).join('\n');
assert.equal(strip(sql).replace(/\n END IF;\n END IF;/,'\n END IF;'),strip(e13),'confirm otherwise unchanged');
// Übersicht: Zurückziehen-Liste mit Zeitgrenzen wie beim Vergeben; can_revoke wie staff_revoke_card_award
assert.match(fn(sql,'public.staff_card_award_overview'),/'can_revoke',me\.role='admin' OR a\.awarded_by=me\.id/);
assert.match(fn(e7,'public.staff_revoke_card_award'),/IF me\.role<>'admin' AND a\.awarded_by<>me\.id THEN/);
// Rücknahme wörtlich und geschützt
assert.equal(fn(rollback,'public.staff_card_award_overview'),fn(e7,'public.staff_card_award_overview'));
assert.equal(fn(rollback,'public.staff_confirm_card_award'),fn(e13,'public.staff_confirm_card_award'));
assert.match(rollback,/Rücknahme abgebrochen: «nicht vergeben» wurde schon benutzt/);
// Oberfläche: eingeklappte Formulare, Grund beim Zurückziehen Pflicht, keine Dialoge
assert.match(page,/<summary>Diesmal nicht vergeben<\/summary><form class="kd-skip"/);
assert.match(page,/<summary>Zurückziehen<\/summary><form class="kd-revoke"[^`]*name="reason" maxlength="300" required/);
assert.match(page,/db\.rpc\('staff_skip_card_award',\{p_kind:sk\.dataset\.kind,p_period_start:sk\.dataset\.start,p_note:/);
assert.match(page,/db\.rpc\('staff_unskip_card_award',\{p_skip_id:Number\(b\.dataset\.unskip\)\}\)/);
assert.match(page,/\$\{a\.can_revoke\?revokeForm\(a\)/);assert.match(page,/\$\{s\.can_undo\?/);
assert.doesNotMatch(page,/prompt\(|alert\(|confirm\(/);
assert.match(help,/«Diesmal nicht vergeben»/);
console.log('PASS: Etappe 14 – «nicht vergeben» (RLS, eins pro Zeitraum, Verlauf bleibt, nur Trainer/Admin, aufheben nur wer gewählt hat oder Admin), schliesst Vergeben aus (gleiche Sperre), Vergeben sonst wie Etappe 13, frühere Auszeichnungen zurückziehen wie bisher berechtigt, Rücknahme wörtlich und geschützt, Oberfläche ohne Dialoge');
