'use strict';
// Static contracts for Etappe 15: öffentliche Kartenwerte nach der besten Karte (= 92).
const fs=require('node:fs'),assert=require('node:assert/strict'),vm=require('node:vm');
const read=f=>fs.readFileSync(f,'utf8');
const sql=read('supabase/migrations/20261029210000_card_scale_92.sql'),code=sql.replace(/--[^\n]*/g,'');
const rollback=read('supabase/production-prep/rollback_20261029210000_card_scale_92.sql'),old=read('supabase/migrations/20261029090000_rating_scale_20.sql');
const js=read('takeover-performance.js'),bew=read('bewertung.html'),karten=read('karten.html'),help=read('takeover-help.js');
for(const f of ['preflight','postflight'])assert.ok(fs.existsSync('supabase/production-prep/'+f+'_20261029210000_card_scale_92.sql'),f);
assert.match(sql,/^BEGIN;$/m);assert.match(sql,/^COMMIT;$/m);
const fn=(t,n)=>t.slice(t.indexOf('CREATE OR REPLACE FUNCTION '+n),t.indexOf('$fn$;',t.indexOf('CREATE OR REPLACE FUNCTION '+n))+5);
// Formel: × 92 / beste, gerundet, höchstens 99; beste = letzte echte Coach-Bewertung aktiver Boxer/Trainer
const pub=fn(sql,'league_private.rating_public');
assert.match(pub,/LEAST\(99, round\(\(sm->>'overall'\)::numeric\*92\/best\)\)/);assert.match(pub,/LEAST\(99, round\(c\.value::numeric\*92\/best\)\)/);
const best=fn(sql,'league_private.rating_card_best');
assert.match(best,/league_private\.rating_row\(p\.id,0\)/);assert.match(best,/p\.is_active AND p\.archived_at IS NULL AND p\.role IN \('boxer','coach'\)/);
assert.doesNotMatch(best,/rating_self_reviews/,'self ratings never set the scale');
// Öffentliche Karte: nur umgerechnete Werte, kein Rohwert-Block; eigene Sicht: echt plus public
const card=fn(sql,'public.get_performance_card');
assert.match(card,/'overall',pub->'overall','categories',pub->'categories'/);assert.doesNotMatch(card,/'public'/);
assert.match(fn(sql,'league_private.rating_full'),/jsonb_build_object\('public',league_private\.rating_public/);
assert.match(fn(sql,'public.staff_list_performance'),/'public_overall'/);
// Sonst unverändert gegenüber 20261029090000 (nur die markierten Stellen)
const strip=t=>t.replace(/\s+/g,' ');
assert.ok(strip(fn(sql,'public.get_performance_card')).includes(strip(`IF t.id<>me.id AND NOT staff AND t.is_listed IS NOT TRUE THEN RETURN NULL; END IF;`)),'visibility unchanged');
// Sicherheit
for(const m of code.matchAll(/CREATE OR REPLACE FUNCTION ([a-z_.]+)\([^]*?\$fn\$/g))assert.match(m[0],/SET search_path=''/,m[1]);
assert.match(code,/REVOKE ALL ON FUNCTION league_private\.rating_card_best\(uuid\), league_private\.rating_public\(jsonb,integer\) FROM PUBLIC, anon, authenticated;/);
assert.match(fn(sql,'public.get_rating_card_scale'),/IF who<>me\.id AND me\.role NOT IN \('admin','coach'\) THEN RAISE EXCEPTION/);
assert.doesNotMatch(code,/TO anon|TO PUBLIC/);assert.doesNotMatch(code,/\b(INSERT|UPDATE|DELETE|TRUNCATE)\b/i,'keine Datenänderung');
// Rücknahme wörtlich
for(const n of ['public.get_performance_card','league_private.rating_full','public.staff_list_performance'])assert.equal(fn(rollback,n),fn(old,n),n);
// JS rechnet wie SQL
const ctx={window:{},document:{readyState:'complete',body:{dataset:{}}},console,URLSearchParams,Intl,location:{search:''}};vm.createContext(ctx);vm.runInContext(js,ctx);
const P=ctx.window.TLPerf;assert.equal(P.CARD_TARGET,92);
const r=P.publicSummary({overall:65,categories:{OFF:65,BEI:71,KON:57}},65);
assert.equal(r.overall,92);assert.equal(r.categories.BEI,99);assert.equal(r.categories.KON,81);
assert.equal(P.publicSummary({overall:45,categories:{OFF:43}},65).overall,64);assert.equal(P.publicSummary({overall:45,categories:{OFF:43}},65).categories.OFF,61);
assert.equal(P.publicSummary({overall:40,categories:{}},null).overall,40);
assert.equal(P.pubOf({overall:1,public:{overall:2,categories:{}}}).overall,2);assert.equal(P.pubOf({overall:1}),null);
// Oberfläche
assert.match(bew,/in Klammern den öffentlichen Wert/);assert.match(bew,/db\.rpc\('get_rating_card_scale',id\?\{p_boxer_id:id\}:\{\}\)/);
assert.match(bew,/Math\.max\(Number\(edit\.bestOthers\)\|\|0,s\.overall\)/);
assert.match(karten,/r=raw\?\(P\.pubOf\(raw\)\|\|raw\):null/,'design preview shows the public card');
assert.match(help,/Die beste Karte der Liga hat 92/);
console.log('PASS: Etappe 15 – beste Karte = 92, alle Werte × 92/beste (gerundet, höchstens 99), nur echte Coach-Bewertungen aktiver Profile, öffentlich nur umgerechnet, eigene/Trainer-Sicht echt plus public, Vorschau wie SQL, Rücknahme wörtlich, keine Datenänderung');
