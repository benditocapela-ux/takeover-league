'use strict';
// Static contracts for Etappe 9 (Boxer-Holo): renderer and database share the same keys and colour lists,
// unknown or hostile values never reach the SVG, the page uses only the intended RPCs, server functions are locked down.
const fs=require('node:fs'),assert=require('node:assert/strict'),vm=require('node:vm');
const sql=fs.readFileSync('supabase/migrations/20261029140000_boxer_holo.sql','utf8');
const code=sql.replace(/--[^\n]*/g,'');
const js=fs.readFileSync('takeover-holo.js','utf8'),page=fs.readFileSync('mein-boxer.html','utf8'),perf=fs.readFileSync('takeover-performance.js','utf8');
const nav=fs.readFileSync('takeover-navigation.js','utf8'),help=fs.readFileSync('takeover-help.js','utf8'),css=fs.readFileSync('takeover-redesign.css','utf8');
const rollback=fs.readFileSync('supabase/production-prep/rollback_20261029140000_boxer_holo.sql','utf8');
const ctx={window:{}};vm.createContext(ctx);vm.runInContext(js,ctx);const H=ctx.window.TLHolo;
// Katalog aus der Migration
const ins=sql.slice(sql.indexOf('INSERT INTO public.holo_items'),sql.indexOf('ON CONFLICT (key) DO NOTHING;'));
const ITEMS=[...ins.matchAll(/\('([a-z_]+)','([a-z]+)','((?:[^']|'')*)','([a-z]+)','([a-z]+)',(NULL|\d+),(NULL|'\{[^']*\}'),(\d+)\)/g)].map(m=>({key:m[1],slot:m[2],value:m[1].slice(m[2].length+1),unlock:m[5]}));
assert.equal(ITEMS.length,58);
const vals=s=>ITEMS.filter(i=>i.slot===s).map(i=>i.value).sort();
assert.deepEqual([...H.HAIR_KEYS].sort(),vals('hair'),'every hair style in DB is drawable and vice versa');
assert.equal(vals('hair').length,18);
for(const h of ['afro','afro_puffs','locs','box_braids','cornrows','twists','locken','wellig','high_top','glatze'])assert.ok(vals('hair').includes(h),'hair type '+h);
assert.ok(ITEMS.filter(i=>i.slot==='hair').every(i=>i.unlock==='start'),'all hair styles are free');
assert.deepEqual([...H.POSES].sort(),vals('pose'));
assert.deepEqual(Object.keys(H.GL).sort(),vals('glove'));
for(const [slot,list] of [['coat',['basic','samurai','neon','drache']],['aura',['flamme','sakura','blitz','schatten']],['eyefx',['kristall','glut','stern','mond']],['scene',['holo','dojo','neon','arena']],['head',['cap','band','hijab']],['top',['tank','shirt','hoodie','jacke']],['bottom',['boxer','kurz','jogger','track']],['feet',['boots','sneaker']]])
 assert.deepEqual(vals(slot),[...list].sort(),slot);
// Farblisten identisch mit der Server-Prüfung
const arr=n=>{const m=code.match(new RegExp(n+" text\\[\\] := ARRAY\\[([^\\]]*)\\]"));return m[1].match(/'([a-z]+)'/g).map(x=>x.slice(1,-1)).sort()};
assert.deepEqual(Object.keys(H.CL).sort(),arr('cols'));
assert.deepEqual(Object.keys(H.HC).sort(),arr('hcs'));
assert.deepEqual(Object.keys(H.EYE).sort(),arr('eyes'));
assert.equal(H.TONES.length,8);assert.match(code,/\^\[0-7\]\$/);
// Standardwerte identisch
const def=JSON.parse(code.match(/DECLARE o jsonb := '(\{[^']*\})'/)[1]);
assert.deepEqual(JSON.parse(JSON.stringify(H.DEF)),def,'renderer defaults equal server defaults');
// Feindliche Werte landen nie im SVG
const evil={hair:'"><script>alert(1)</script>',hc:'red;"',topc:'#f00" onload="x',eye:'<img>',tone:'7"',pose_profile:'x" y="1',scene:'javascript:x',coat:'</svg>'};
const out=H.svg(evil,{label:'<b>"x"</b>'});
assert.doesNotMatch(out,/script|onload|<img|javascript|<b>|red;/i);
assert.equal(H.svg(evil,{}).replace(/tlh\d+/g,'ID'),H.svg({},{}).replace(/tlh\d+/g,'ID'),'hostile config renders like the default');
assert.ok(H.svg({head:'hijab',hair:'afro'}).length>1000);
// Seite und Module: nur vorgesehene RPCs, keine Tabellen, keine geheimen Schlüssel
const rpcOf=t=>[...new Set([...t.matchAll(/\brpc\(\s*'([a-z_]+)'/g)].map(m=>m[1]))].sort();
assert.deepEqual(rpcOf(page),['buy_holo_bundle','buy_holo_item','get_my_holo','get_my_performance','save_my_holo']);
assert.doesNotMatch(page,/\.from\(|service_role|sb_secret_/);
assert.doesNotMatch(js,/fetch\(|XMLHttpRequest|innerHTML|service_role/);
assert.match(page,/data-confirm/,'purchases need a second confirming click');
assert.doesNotMatch(page,/confirm\(|alert\(|prompt\(/,'no blocking browser dialogs');
assert.match(page,/esc\(i\.name\)/);assert.match(page,/esc\(b\.name\)/);
assert.match(perf,/get_holo_looks/);assert.match(perf,/tlp-holo/);
const defined=new Set([...code.matchAll(/CREATE OR REPLACE FUNCTION public\.([a-z_]+)\(/g)].map(m=>m[1]));
for(const r of ['get_my_holo','save_my_holo','buy_holo_item','buy_holo_bundle','get_holo_looks'])assert.ok(defined.has(r),r);
// Server: alle Funktionen gesperrt und mit leerem search_path
const fns=[...code.matchAll(/CREATE OR REPLACE FUNCTION (public|league_private)\.([a-z_]+)\([^)]*\)\s*RETURNS[^$]*?\$fn\$/g)];
assert.ok(fns.length>=11);
for(const f of fns)assert.match(f[0],/SET search_path=''/,f[2]);
for(const f of fns.filter(f=>f[1]==='public'))assert.match(f[0],/SECURITY DEFINER/,f[2]);
assert.match(code,/REVOKE ALL ON public\.holo_items, public\.holo_bundles, public\.holo_owned, public\.holo_config FROM PUBLIC, anon, authenticated;/);
assert.match(code,/REVOKE ALL ON FUNCTION public\.get_my_holo\(\)[\s\S]*FROM PUBLIC, anon;/);
assert.match(code,/'boxer_holo','Boxer-Holo[^']*',false\)/,'flag starts off');
assert.match(code,/'purchase','holo:'\|\|it\.key/);assert.match(code,/'purchase','holo_bundle:'\|\|b\.key/);
assert.match(sql,/PERFORM league_private\.kg_sync\(me\.id\);  -- nimmt auch die Sperre/);
assert.match(rollback,/ledger_id IS NOT NULL[\s\S]*Rücknahme abgebrochen/,'rollback protects purchases');
// Navigation, Hilfe, Stil
assert.match(nav,/\['user','Mein Boxer','mein-boxer\.html','',true\]/);
assert.match(nav,/'mein-boxer\.html':'meinboxer'/);
assert.match(help,/key:'meinboxer',page:'mein-boxer\.html'[^}]*flag:'boxer_holo'/);
assert.match(css,/@media \(prefers-reduced-motion:reduce\)\{\.tlh \.tlh-scan/);
assert.match(page,/data-tl-screen="mein-boxer"/);
console.log('PASS: Boxer-Holo – 18 Frisuren und alle Items zeichenbar und identisch mit der Datenbank, Farben/Standard gleich wie Server, feindliche Werte fallen auf Standard, Seite nur mit vorgesehenen RPCs, Käufe mit Bestätigung, Server gesperrt, Rollback schützt Käufe');
