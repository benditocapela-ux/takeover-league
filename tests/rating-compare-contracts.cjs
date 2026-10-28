'use strict';
// Static contracts for Etappe 7a (Bewertungsregler 1–20 mit Stufentexten, Spielerkarte und Boxstil im Boxervergleich).
const fs=require('node:fs'),assert=require('node:assert/strict'),vm=require('node:vm');
const read=f=>fs.readFileSync(f,'utf8');
const sql=read('supabase/migrations/20261029090000_rating_scale_20.sql'),rollback=read('supabase/production-prep/rollback_20261029090000_rating_scale_20.sql');
const js=read('takeover-performance.js'),bew=read('bewertung.html'),cmp=read('boxer-compare.html');
for(const f of ['preflight','postflight'])assert.ok(fs.existsSync('supabase/production-prep/'+f+'_20261029090000_rating_scale_20.sql'),f);
const ctx={window:{},document:{readyState:'complete',body:{dataset:{}}},console,URLSearchParams,Intl,location:{search:''}};
vm.createContext(ctx);vm.runInContext(js,ctx);
const P=ctx.window.TLPerf;

// Stufentexte: alle 25 Kriterien, je 5 Stufen (1–4, 5–8, 9–12, 13–16, 17–20)
assert.deepEqual(Object.keys(P.BANDS).sort(),[...P.SKILL_KEYS].sort(),'texts for every criterion');
for(const k of P.SKILL_KEYS){assert.equal(P.BANDS[k].length,5,k);for(const t of P.BANDS[k])assert.ok(t.length>=8&&t.length<=90,k+': '+t)}
assert.equal(P.band('jab',1).i,0);assert.equal(P.band('jab',4).i,0);assert.equal(P.band('jab',5).i,1);assert.equal(P.band('jab',12).i,2);
assert.equal(P.band('jab',13).i,3);assert.equal(P.band('jab',17).i,4);assert.equal(P.band('jab',20).i,4);
assert.deepEqual([...P.BAND_NAMES],['Anfang','Grundlagen','Solide','Stark','Elite']);

// Vorschau rechnet wie league_private.rating_summary(p, scale) (gleiche Beispiele wie im SQL-Test)
const all=v=>Object.fromEntries(P.SKILL_KEYS.map(k=>[k,v]));
let s=P.summary({...all(14),jab:20,slip:6},20);assert.equal(s.categories.OFF,75);assert.equal(s.categories.DEF,63);assert.equal(s.overall,70);
assert.equal(P.summary(all(13),20).overall,65);assert.equal(P.summary(all(20),20).overall,99);assert.equal(P.summary(all(1),20).overall,5);
assert.equal(P.summary({...all(7),jab:10,slip:3}).overall,70,'scale 10 unchanged');
assert.equal(P.to20(7,10),14);assert.equal(P.to20(7,20),7);assert.equal(P.to20(7,undefined),14,'missing scale = old 10 scale');
assert.equal(P.similarity({o:50,v:50,c:50,p:50,s:50,a:50},{o:50,v:50,c:50,p:50,s:50,a:50}),100);
assert.equal(P.similarity({o:100,v:0,c:0,p:0,s:0,a:0},{o:0,v:100,c:0,p:0,s:0,a:0}),0);

// SQL: neue Bewertungen 1–20, bisherige bleiben unverändert (kein UPDATE), alte Oberfläche bleibt gültig
assert.match(sql,/ADD COLUMN IF NOT EXISTS scale smallint NOT NULL DEFAULT 10/);
assert.match(sql,/CHECK \(scale IN \(10,20\)\)/);
assert.match(sql,/round\(pg_catalog\.avg\(\(p->>k\)::numeric\)\*100\/p_scale\)/);
assert.match(sql,/staff_rate_boxer\(p_boxer_id uuid, p_scores jsonb, p_note text DEFAULT NULL, p_scale integer DEFAULT 10\)/);
assert.match(sql,/DROP FUNCTION IF EXISTS public\.staff_rate_boxer\(uuid,jsonb,text\);/);
const top=sql.replace(/\$fn\$[\s\S]*?\$fn\$/g,'').replace(/--[^\n]*/g,'');
assert.doesNotMatch(top,/UPDATE public\.boxer_ratings|DELETE FROM|TRUNCATE/i,'migration does not touch rating data');
assert.match(rollback,/IF EXISTS \(SELECT 1 FROM public\.boxer_ratings WHERE scale<>10\)/,'rollback refuses with 20-scale ratings');
assert.doesNotMatch(rollback.replace(/--[^\n]*/g,''),/DELETE FROM|UPDATE public\.boxer_ratings|DROP COLUMN/i);

// Oberfläche: Regler 1–20, speichert mit p_scale 20, keine − / + mehr
assert.match(bew,/type="range" min="1" max="20" step="1"/);
assert.match(bew,/p_scale:20\}/);assert.doesNotMatch(bew,/data-step|tlp-step/);
assert.match(bew,/aria-valuetext/);
assert.match(bew,/P\.to20\(cur\.scores\[k\],baseScale\)/,'old ratings doubled when editing');
// Vergleich: nur über get_performance_card, Namen escaped, nur für Angemeldete
assert.match(cmp,/takeover-performance\.js/);
const m=js.slice(js.indexOf('async function mountCompare'),js.indexOf('function alertBox'));
assert.deepEqual([...new Set([...m.matchAll(/rpc\('([a-z_]+)'/g)].map(x=>x[1]))],['get_performance_card']);
assert.match(m,/if\(!signedIn\)/);assert.doesNotMatch(m,/\$\{x\.n\}|\$\{a\}|\$\{b\}/,'names always escaped');
console.log('PASS: Etappe 7a – Regler 1–20 mit 25×5 Stufentexten, Vorschau = Server, bisherige 10er-Bewertungen unverändert, Rollback geschützt, Vergleich nur für Angemeldete über get_performance_card');
