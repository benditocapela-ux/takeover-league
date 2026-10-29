'use strict';
// Static contracts for Etappe 16: Kartengalerie (RPC) und Kartenarena im Boxervergleich.
const fs=require('node:fs'),assert=require('node:assert/strict'),vm=require('node:vm');
const read=f=>fs.readFileSync(f,'utf8');
const sql=read('supabase/migrations/20261029220000_card_gallery.sql'),code=sql.replace(/--[^\n]*/g,'');
const e15=read('supabase/migrations/20261029210000_card_scale_92.sql'),js=read('takeover-performance.js'),page=read('boxer-compare.html'),css=read('takeover-redesign.css');
for(const f of ['preflight','postflight','rollback'])assert.ok(fs.existsSync('supabase/production-prep/'+f+'_20261029220000_card_gallery.sql'),f);
assert.match(sql,/^BEGIN;$/m);assert.match(sql,/^COMMIT;$/m);
// Galerie: nur lesen, gleiche Sichtbarkeit und gleiche Werte wie die Profilkarte (Etappe 15)
assert.match(code,/RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=''/);
assert.match(code,/IF me\.id IS NULL THEN RETURN '\[\]'::jsonb; END IF;/);
assert.match(code,/AND \(p\.id=me\.id OR staff OR p\.is_listed IS TRUE\)/);
assert.match(code,/q\.is_active AND q\.archived_at IS NULL AND q\.role IN \('boxer','coach'\)\)=1/,'unique names only');
assert.match(code,/r_on := league_private\.flag_on\('coach_ratings'\) OR staff;/);assert.match(e15,/r_on := league_private\.flag_on\('coach_ratings'\) OR staff;/);
assert.match(code,/league_private\.rating_public\(league_private\.rating_summary\(cur\.scores,cur\.scale\),best\)/);
assert.match(code,/ORDER BY x\.ov DESC NULLS LAST/);
assert.doesNotMatch(code,/'top'|'low'|'scores',cur|note/,'no single notes or comments');
assert.match(code,/REVOKE ALL ON FUNCTION public\.get_card_gallery\(\) FROM PUBLIC, anon;/);assert.doesNotMatch(code,/TO anon|TO PUBLIC/);
assert.doesNotMatch(code,/\b(INSERT|UPDATE|DELETE|TRUNCATE|ALTER TABLE)\b/i,'read only');
// Punktzettel: jede Kategorie eine Runde, 10 für den besseren Wert, 9 für den anderen, gleich 10:10
const ctx={window:{},document:{readyState:'complete',body:{dataset:{}}},console,URLSearchParams,Intl,location:{search:''}};vm.createContext(ctx);vm.runInContext(js,ctx);
const P=ctx.window.TLPerf;
let sc=P.scorecard({categories:{OFF:92,DEF:89,BEI:99,KON:81,TAK:92,MEN:88}},{categories:{OFF:61,DEF:64,BEI:68,KON:61,TAK:61,MEN:90}});
assert.equal(sc.ta,59);assert.equal(sc.tb,55);assert.equal(sc.wa,5);assert.equal(sc.wb,1);assert.equal(sc.rounds.length,6);
sc=P.scorecard({categories:{OFF:50,DEF:50,BEI:50,KON:50,TAK:50,MEN:50}},{categories:{OFF:50,DEF:50,BEI:50,KON:50,TAK:50,MEN:50}});
assert.equal(sc.ta,60);assert.equal(sc.tb,60);
assert.match(P.cardHex({OFF:1,DEF:2,BEI:3,KON:4,TAK:5,MEN:6},{OFF:1,DEF:2,BEI:3,KON:4,TAK:5,MEN:6},'<b>x</b>','y'),/&lt;b&gt;x&lt;\/b&gt;/,'names escaped in the hexagon');
// Arena: Namen immer escaped, keine Dialoge, Rückfall ohne Galerie, Links und Auswahl-Listen bleiben gültig
const m=js.slice(js.indexOf('async function mountCompare'),js.indexOf('async function mountAwards'));
assert.doesNotMatch(m,/\$\{(a|b|n|win)\}/,'names always escaped');
assert.doesNotMatch(m,/alert\(|confirm\(|prompt\(/);
assert.match(m,/db\.rpc\('get_card_gallery'\)/);assert.match(m,/db\.rpc\('get_performance_card',\{p_display_name:n\}\)/);
assert.match(m,/const q0=new URLSearchParams\(location\.search\)/,'links read before the page rewrites the URL');
assert.match(m,/kein echtes Duell/);
for(const id of ['left','right','headToHead','directDuels','directDuelsStatus','results','chooser'])assert.match(page,new RegExp('id="'+id+'"'),id);
assert.match(page,/function renderHeadToHead\(/);assert.match(page,/function renderDirectDuels\(/);assert.match(page,/'Direkte Duelle: '\+matches\.length/);
assert.match(page,/\.tla-mode #chooser\{display:none!important\}/);
// Bewegung nur ohne «Bewegung reduzieren»
assert.match(css,/@media \(prefers-reduced-motion:no-preference\)\{\n \.tla-poster\.go/);
assert.doesNotMatch(css.slice(css.indexOf('Etappe 16')),/animation:[^;]*infinite/);
console.log('PASS: Etappe 16 – Kartengalerie nur lesend mit gleicher Sichtbarkeit und gleichen Werten wie die Profilkarte, Punktzettel 10:9 je Kategorie, Namen escaped, Rückfall ohne Galerie, Seite und Links unverändert gültig, Bewegung nur ohne reduzierte Bewegung');
