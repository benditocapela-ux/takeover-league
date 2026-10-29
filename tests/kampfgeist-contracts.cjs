'use strict';
// Static contracts for Etappe 4 (Kampfgeist-Shop): catalogue designs can all be drawn, level formula matches SQL (max 99),
// pages only use intended RPCs, no table access, rewards are earned only (no paid coins, no random boxes).
const fs=require('node:fs'),assert=require('node:assert/strict'),vm=require('node:vm');
const sql=fs.readFileSync('supabase/migrations/20261028210000_kampfgeist_shop.sql','utf8');
const js=fs.readFileSync('takeover-kampfgeist.js','utf8'),css=fs.readFileSync('takeover-redesign.css','utf8');
const shop=fs.readFileSync('shop.html','utf8'),road=fs.readFileSync('roadmap.html','utf8'),perf=fs.readFileSync('takeover-performance.js','utf8');
const rollback=fs.readFileSync('supabase/production-prep/rollback_20261028210000_kampfgeist_shop.sql','utf8');
const ctx={window:{}};vm.createContext(ctx);vm.runInContext(js,ctx);const K=ctx.window.TLKG;assert.ok(K,'TLKG exported');

// Katalog aus der Migration
const ITEMS=[...sql.matchAll(/\('([a-z0-9_]+)','(avatar|aura|banner|rahmen|titel|handschuhe)','((?:[^']|'')*)',(NULL|'(?:[^']|'')*'),'(\w+)','([FEDCBAS])','(start|rank|shop)',(NULL|\d+),'(\{[^']*\})',(\d+)\)/g)]
 .map(m=>({key:m[1],category:m[2],name:m[3],rarity:m[5],min_rank:m[6],unlock:m[7],price:m[8]==='NULL'?null:+m[8],design:JSON.parse(m[9])}));
assert.equal(ITEMS.length,114);assert.equal(new Set(ITEMS.map(i=>i.key)).size,114,'unique keys');
assert.equal(ITEMS.filter(i=>i.unlock==='shop').length,93);
const R='FEDCBAS';
for(const r of R)assert.ok(ITEMS.some(i=>i.unlock==='shop'&&i.min_rank===r),'shop items for rank '+r);
assert.ok(ITEMS.filter(i=>i.unlock==='shop'&&i.min_rank==='F').length>=19,'enough items for beginners');
for(const r of 'EDCBAS'){assert.ok(ITEMS.some(i=>i.unlock==='rank'&&i.min_rank===r&&i.category==='titel'),'rank title '+r);assert.ok(ITEMS.some(i=>i.unlock==='rank'&&i.min_rank===r&&i.category==='rahmen'),'rank frame '+r)}
// Jedes Design lässt sich zeichnen
const HAIRS=[...js.matchAll(/^ ([a-z]+):(?:c|\(\))=>/gm)].map(m=>m[1]);
const hex=/^#[0-9a-fA-F]{6}$/;
for(const it of ITEMS){const d=it.design;
 if(it.category==='avatar'){assert.ok(HAIRS.includes(d.hair),'hair style '+d.hair+' for '+it.key);for(const k of ['hc','skin','eye','hb','brow','marks'])if(d[k])assert.match(d[k],hex,it.key+'.'+k);
  const svg=K.avatarSVG(d,null);assert.match(svg,/^<svg viewBox="0 0 200 200"/);assert.ok(!svg.includes('undefined'),it.key)}
 if(it.category==='aura'&&d.g){d.g.split(',').forEach(c=>assert.match(c,hex,it.key));assert.match(K.avatarBox({aura:it},80),/conic-gradient/)}
 if(it.category==='banner')assert.ok(css.includes('.kg-bn-'+d.bn+'{'),'banner css '+d.bn);
 if(it.category==='rahmen'&&d.fr!=='none')assert.ok(css.includes('.kg-fr-'+d.fr+' .kg-disc'),'frame css '+d.fr);
 if(it.category==='handschuhe'){for(const k of ['base','acc','cuff'])assert.match(d[k],hex,it.key);assert.ok(['none','flame','bolt','star','crack','petal','tiger'].includes(d.pat),'glove pattern '+d.pat)}
 assert.ok(!/<|>/.test(it.name),'plain item names');
}
// Standard-Aussehen = Startitems
const defs=JSON.parse(sql.match(/defaults jsonb := '(\{[^']+\})'/)[1]);
for(const [slot,key] of Object.entries(defs)){const it=ITEMS.find(i=>i.key===key);assert.ok(it&&it.unlock==='start'&&it.category===slot,'default '+slot)}
// Level-Formel identisch zu SQL und den bestehenden Seiten, Maximum 99
assert.match(sql,/LEAST\(99, GREATEST\(0, floor\(\(sqrt\(49\+0\.32\*GREATEST\(xp,0\)\)-7\)\/2\)\)::integer \+ 1\)/);
for(const [xp,l] of [[0,1],[2124,10],[2125,11],[6750,21],[50250,61],[128625,99],[1e7,99]])assert.equal(K.levelOf(xp),l,'levelOf '+xp);
for(let L=1;L<=99;L++)assert.equal(K.levelOf(K.expForLevel(L)),L,'expForLevel '+L);
assert.equal(K.rankOfLevel(61).r,'S');assert.equal(K.rankOfLevel(99).r,'S');assert.equal(K.rankOfLevel(11).r,'E');
for(const f of ['boxer-profile.js','takeover-gamification.js','boxer.html','index.html','guest.html','boxer-compare.html'])
 assert.match(fs.readFileSync(f,'utf8'),/Math\.min\(98,(Math\.max\(0,)?Math\.floor\(\(Math\.sqrt\(49\+0\.32\*xp\)-7\)\/2\)/,'level cap 99 in '+f);
// Seiten: nur vorgesehene RPCs, keine Tabellen, keine Schlüssel
const rpcOf=t=>[...new Set([...t.matchAll(/\brpc\(\s*'([a-z_]+)'/g)].map(m=>m[1]))].sort();
assert.deepEqual(rpcOf(shop),['admin_adjust_coins','admin_give_bonus','admin_kg_overview','admin_kg_social','admin_list_bonuses','admin_revoke_bonus','admin_set_emote_mute','admin_update_kg_item','admin_update_kg_pass','admin_update_kg_settings','buy_kg_item','equip_kg_item','get_my_kampfgeist','get_my_performance','hide_kg_emote']);
assert.deepEqual(rpcOf(road),['get_my_kampfgeist']);
assert.ok(rpcOf(perf).includes('get_kg_look')&&rpcOf(perf).includes('get_my_kampfgeist'));
const sql5=fs.readFileSync('supabase/migrations/20261028220000_kampfgeist_etappe5.sql','utf8');
const sql18=fs.readFileSync('supabase/migrations/20261029240000_admin_bonus_exp.sql','utf8'); // Etappe 18: Bonus-EXP
const defined=new Set([...(sql+sql5+sql18).matchAll(/CREATE OR REPLACE FUNCTION public\.([a-z_]+)\(/g)].map(m=>m[1]).concat(['get_my_performance']));
for(const r of [...rpcOf(shop),...rpcOf(road)])assert.ok(defined.has(r),'RPC not defined: '+r);
for(const [n,t] of [['shop.html',shop],['roadmap.html',road],['takeover-kampfgeist.js',js]]){
 assert.doesNotMatch(t,/service_role|sb_secret_/i,n);assert.doesNotMatch(t,/(?<!Array)\.from\(/,n+' reads no tables');assert.doesNotMatch(t,/\.(insert|update|upsert|delete)\(/,n);
}
for(const [n,t] of [['shop.html',shop],['roadmap.html',road]]){
 assert.ok(t.indexOf('takeover-kampfgeist.js')<t.indexOf('<script type="module">')&&t.indexOf('takeover-performance.js')<t.indexOf('<script type="module">'),n+': libraries first');
 assert.match(t,/takeover-navigation\.js/);
}
// Fairness: Coins nur verdient, keine Zufallsboxen, Admin bucht nie sich selbst, Rollback behält Daten
assert.doesNotMatch(sql.replace(/--[^\n]*/g,''),/random\(\)|lootbox|zufall/i,'no randomness in the economy');
assert.match(sql,/p_profile_id=me\.id THEN RAISE EXCEPTION 'Dem eigenen Konto/);
assert.match(sql,/reason IN \('start','training','training_fix','quest','purchase','admin'\)/);
assert.match(sql,/UNIQUE\(profile_id, reason, ref\)/);
assert.doesNotMatch(sql.replace(/--[^\n]*/g,''),/CREATE TRIGGER|UPDATE public\.(training_submissions|point_transactions|profiles)\b/,'no triggers / no edits of existing data');
assert.doesNotMatch(rollback,/DROP TABLE|DELETE FROM|TRUNCATE|UPDATE /i);
// Ausgaben escaped
assert.equal(K.esc('<img src=x onerror=1>'),'&lt;img src=x onerror=1&gt;');
assert.doesNotMatch(K.card({titel:{name:'<b>x</b>',rarity:'rare'},level:3,rank:'F'},{name:'<i>y</i>'}),/<b>x<\/b>|<i>y<\/i>/);
const nav=fs.readFileSync('takeover-navigation.js','utf8');
assert.match(nav,/'shop\.html'/);assert.match(nav,/'roadmap\.html'/);
console.log('PASS: Kampfgeist – 114 Items zeichenbar (Haare, Auren, Banner, Rahmen, Handschuhe), Level-Formel = SQL, Maximum 99 auf allen Seiten, nur vorgesehene RPCs, keine Zufallsboxen, Rollback behält Daten');
