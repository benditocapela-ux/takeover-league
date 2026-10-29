'use strict';
// Static contracts for Etappe 19: Kampfgeist-Anzeige in Ranking, Podium, Profil und Studio.
const fs=require('node:fs'),assert=require('node:assert/strict');
const read=f=>fs.readFileSync(f,'utf8');
const id='20261030090000_kg_cards_everywhere';
const sql=read('supabase/migrations/'+id+'.sql'),code=sql.replace(/--[^\n]*/g,'');
for(const f of ['preflight','postflight','rollback'])assert.ok(fs.existsSync('supabase/production-prep/'+f+'_'+id+'.sql'),f);
// Nur lesend, gleiche Sichtbarkeit wie get_public_boxer_looks, nur Design-Daten
assert.match(code,/CREATE OR REPLACE FUNCTION public\.get_public_boxer_cards\(\)\s*RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=''/);
assert.doesNotMatch(code,/\b(INSERT|UPDATE|DELETE|TRUNCATE|DROP|ALTER)\b/i,'read-only');
assert.match(code,/IF NOT league_private\.flag_on\('kampfgeist_shop'\) THEN RETURN '\[\]'::jsonb; END IF;/);
assert.match(code,/AND \(p\.is_listed IS TRUE OR p\.id=me\.id OR staff\)/);
assert.match(code,/q\.is_active AND q\.archived_at IS NULL\)=1/,'only unique names');
const items=[...code.matchAll(/'(avatar|aura|banner|rahmen|titel|handschuhe)',\(SELECT pg_catalog\.jsonb_build_object\('key',i->>'key','name',i->>'name','rarity',i->>'rarity','design',i->'design'\)/g)].map(m=>m[1]);
assert.deepEqual(items,['avatar','aura','banner','rahmen','titel','handschuhe'],'only key/name/rarity/design per item');
assert.doesNotMatch(code,/'(price|description|unlock|min_rank|emote|einlauf|coins|balance)'/);
assert.match(code,/GRANT EXECUTE ON FUNCTION public\.get_public_boxer_cards\(\) TO anon, authenticated;/);
assert.match(read('supabase/production-prep/rollback_'+id+'.sql'),/DROP FUNCTION IF EXISTS public\.get_public_boxer_cards\(\);/);
// Frontend: ein Aufruf, nur auf Liga-, Profil- und Studio-Seite, Profilbild bleibt ohne eigene Avatar-Wahl, ohne Daten unverändert
const perf=read('takeover-performance.js'),kg=read('takeover-kampfgeist.js'),css=read('takeover-redesign.css');
assert.equal((perf.match(/rpc\('get_public_boxer_cards'\)/g)||[]).length,1);
assert.match(perf,/if\(!\['index','boxer-profile','boxer'\]\.includes\(screen\)\)return;/);
assert.match(perf,/const kgPhoto=\(el,lk\)=>\{if\(lk\.own_avatar\)return null;/);
assert.match(perf,/if\(map\.size\)\{if\(!K\)K=await kampfgeist\(\);apply\(\)\}/);
assert.match(perf,/run\(mountLooks\);\n run\(mountKgCards\);/);
assert.match(kg,/const photoOk=u=>typeof u==='string'&&\/\^\(https:/,'photo URL allowlist');
assert.match(kg,/<img src="\$\{esc\(photo\)\}" alt="" loading="lazy">/,'photo escaped');
assert.match(css,/Etappe 19: Kampfgeist-Anzeige/);assert.match(css,/\.tl-kg-src\{display:none!important\}/);
console.log('PASS: Etappe 19 – Kartenliste nur lesend, Sichtbarkeit wie öffentliche Looks, nur Design-Daten, Gäste erlaubt, Rücknahme; Frontend lädt einmal, nur Liga/Profil/Studio, Profilbild ohne eigene Avatar-Wahl, ohne Daten unverändert');
