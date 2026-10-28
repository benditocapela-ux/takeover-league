'use strict';
// Static contracts for Etappe 12: 12 neue FUT-Designs mit 10 neuen Mustern, eigenes Design (Admin schaltet frei, Boxer gestaltet).
const fs=require('node:fs'),assert=require('node:assert/strict'),vm=require('node:vm');
const read=f=>fs.readFileSync(f,'utf8');
const sql=read('supabase/migrations/20261029180000_card_designs_more_personal.sql'),code=sql.replace(/--[^\n]*/g,'');
const rollback=read('supabase/production-prep/rollback_20261029180000_card_designs_more_personal.sql'),old=read('supabase/migrations/20261029120000_card_designs_awards.sql');
const css=read('takeover-redesign.css'),page=read('karten.html'),js=read('takeover-performance.js');
for(const f of ['preflight','postflight'])assert.ok(fs.existsSync('supabase/production-prep/'+f+'_20261029180000_card_designs_more_personal.sql'),f);
// Katalog
const rows=[...sql.matchAll(/\('([a-z_]+)','([^']+)','[^']*','(start|rank|shop|award|personal)',(NULL|'[A-Z]'),(NULL|\d+),(NULL|'[a-z]+'),'(\{[^']*\})',\d+\)/g)];
assert.equal(rows.length,13,'12 neue + eigenes');
assert.equal(rows.filter(r=>r[3]==='shop').length,10);assert.equal(rows.filter(r=>r[3]==='rank').length,2);assert.equal(rows.filter(r=>r[3]==='personal').length,1);
const patterns=[...code.match(/ARRAY\['carbon'[^\]]*\]/)[0].matchAll(/'([a-z]+)'/g)].map(m=>m[1]);
assert.equal(patterns.length,20);
for(const p of patterns)assert.match(css,new RegExp('\\.tlp-card\\[data-pattern="'+p+'"\\]::before'),'css for pattern '+p);
for(const r of rows){const d=JSON.parse(r[7]);assert.ok(patterns.includes(d.pattern),r[1]+' pattern');for(const k of ['a','b','ink','edge'])assert.match(d[k],/^#[0-9a-f]{6}$/i,r[1]+' '+k)}
// Prüfung des eigenen Designs: nur bekannte Felder, Farbcodes, Muster aus der Liste, Abzeichen A–Z, Name ohne < >
const clean=code.slice(code.indexOf('FUNCTION league_private.card_personal_clean'),code.indexOf('FUNCTION league_private.card_personal_name'));
assert.match(clean,/k NOT IN \('a','b','ink','edge','pattern','badge','glow'\)/);assert.match(clean,/'\^#\[0-9a-fA-F\]\{6\}\$'/);
assert.match(clean,/ANY\(league_private\.card_patterns\(\)\)/);assert.match(clean,/'\^\[A-Z\]\{3,5\}\$'/);
assert.match(clean,/coalesce\(pg_catalog\.jsonb_typeof\(p->k\),''\)<>'string'/,'missing fields are rejected (NULL-safe)');
assert.match(code,/n ~ '\[<>\\x00-\\x1f\]'/);
assert.match(code,/IF me\.id IS NULL OR me\.role<>'admin' THEN RAISE EXCEPTION 'Nur für den Admin'/);
assert.match(code,/UPDATE public\.card_personal_designs SET is_active=false/,'entziehen behält die Gestaltung');
assert.doesNotMatch(code,/DELETE FROM/i);
// Rücknahme: Funktionen wie 7d wörtlich, geschützt
const fn=(t,n)=>t.slice(t.indexOf('CREATE OR REPLACE FUNCTION '+n),t.indexOf('$fn$;',t.indexOf('CREATE OR REPLACE FUNCTION '+n))+5);
for(const n of ['league_private.card_design_available','league_private.card_look'])assert.equal(fn(rollback,n),fn(old,n),n);
assert.match(rollback,/Rücknahme abgebrochen: neue Designs gekauft oder eigene Designs gespeichert/);
// Oberfläche: Karte zeigt eigenes Design sicher; Editor nur mit vorgesehenen RPCs, keine Dialoge
const ctx={window:{},document:{readyState:'complete',body:{dataset:{}}},console,URLSearchParams,Intl,location:{search:''}};vm.createContext(ctx);vm.runInContext(js,ctx);
const P=ctx.window.TLPerf;
const h=P.card({name:'Ben',overall:70,categories:{OFF:70,DEF:70,BEI:70,KON:70,TAK:70,MEN:70},look:{key:'eigen',name:'<b>Bens</b>',design:{a:'#ff0055',b:'#101010',ink:'#ffffff',edge:'#00ffcc',pattern:'flames',badge:'BEN',glow:true}}});
assert.match(h,/data-pattern="flames"/);assert.match(h,/<span class="tlp-badge">BEN<\/span>/);assert.match(h,/d-glow/);assert.doesNotMatch(h,/<b>Bens<\/b>/);
assert.doesNotMatch(page,/prompt\(|alert\(|confirm\(/);
assert.match(page,/elements\.namedItem\('dname'\)/,'form field not shadowed by form.name');
assert.match(page,/type="color" name="\$\{k\}" value="\$\{hexOk\(d\[k\]\)\?P\.esc/);
console.log('PASS: Etappe 12 – 12 neue Designs, 20 Muster mit CSS, eigenes Design streng geprüft (NULL-sicher), nur Admin schaltet frei, Entziehen behält Gestaltung, Rücknahme wörtlich und geschützt, Karte sicher');
