'use strict';
// Static contracts for Etappe 5: emotes only at duel and podium, positive predefined texts (no free text),
// monthly Kampfpfad from trainings/quests/duels, all new designs drawable, pages only use intended RPCs.
const fs=require('node:fs'),assert=require('node:assert/strict'),vm=require('node:vm');
const sql=fs.readFileSync('supabase/migrations/20261028220000_kampfgeist_etappe5.sql','utf8');
const js=fs.readFileSync('takeover-kampfgeist.js','utf8'),css=fs.readFileSync('takeover-redesign.css','utf8'),perf=fs.readFileSync('takeover-performance.js','utf8');
const pfad=fs.readFileSync('kampfpfad.html','utf8'),duels=fs.readFileSync('duels.html','utf8'),index=fs.readFileSync('index.html','utf8');
const rollback=fs.readFileSync('supabase/production-prep/rollback_20261028220000_kampfgeist_etappe5.sql','utf8');
const ctx={window:{}};vm.createContext(ctx);vm.runInContext(js,ctx);const K=ctx.window.TLKG;
const code=sql.replace(/--[^\n]*/g,'');
// Neue Items
const ITEMS=[...sql.matchAll(/\('([a-z0-9_]+)','(avatar|aura|banner|rahmen|titel|handschuhe|emote|einlauf)','((?:[^']|'')*)',(NULL|'(?:[^']|'')*'),'(\w+)','([FEDCBAS])','(start|rank|shop|pass)',(NULL|\d+),'(\{[^']*\})',(\d+)\)/g)]
 .map(m=>({key:m[1],category:m[2],name:m[3],rarity:m[5],min_rank:m[6],unlock:m[7],price:m[8]==='NULL'?null:+m[8],design:JSON.parse(m[9])}));
assert.equal(ITEMS.length,31);
const em=ITEMS.filter(i=>i.category==='emote'),ein=ITEMS.filter(i=>i.category==='einlauf'),pass=ITEMS.filter(i=>i.unlock==='pass');
assert.equal(em.length,18);assert.equal(ein.length,10);assert.equal(pass.length,5);
assert.equal(em.filter(i=>i.unlock==='start').length,4,'4 free emotes for everybody');
// Positive Emotes: keine abwertenden Sprüche gegen andere (Jugendliche ab 12)
const BAD=/schwach|langsam|loser|verlierer|zzz|noob|weich|heul|schlecht|dumm|peinlich|lach/i;
for(const e of em){assert.doesNotMatch(e.name+' '+e.design.txt,BAD,'emote must stay positive: '+e.key);assert.ok(['burst','jag','cloud'].includes(e.design.shape));assert.match(e.design.col,/^#[0-9a-f]{6}$/i);
 assert.ok(e.design.txt.length>=1&&e.design.txt.length<=20,'short text '+e.key);assert.match(K.emoteHTML(e.design,60),/kg-emote/)}
for(const e of ein){assert.match(e.design.ic,/^#[0-9a-f]{6}$/i);assert.ok(e.design.word&&e.design.word.length<=20);assert.match(K.einlaufPreview(e.design),/kg-einlauf-pv/)}
for(const p of pass)assert.equal(p.price,null,'pass items are never sold');
assert.ok(css.includes('.kg-bn-pass{')&&css.includes('.kg-fr-pass .kg-disc'),'pass banner/frame css');
assert.match(code,/tier,coins,item_key,substitute_coins/);
// Kein Freitext: Emote-Ereignisse speichern nur einen Item-Schlüssel
const evTable=sql.match(/CREATE TABLE IF NOT EXISTS public\.kg_emote_events\(([\s\S]*?)\n\);/)[1];
assert.doesNotMatch(evTable,/\b(message|note|comment|body|txt)\b/i,'no free text column');
assert.match(evTable,/emote_key text NOT NULL REFERENCES public\.kg_items\(key\)/);
assert.match(evTable,/context text NOT NULL CHECK \(context IN \('duel','podium'\)\)/,'only duel and podium');
// Schutz: nur eigene Duelle, Takt, Limit, eine Podium-Reaktion pro Tag, keine Selbstreaktion, Absender am Podium unsichtbar
assert.match(code,/me\.id NOT IN \(d\.challenger_id,d\.opponent_id\) THEN RAISE EXCEPTION 'Emotes gibt es nur in deinen eigenen Duellen'/);
assert.match(code,/interval '15 seconds'/);assert.match(code,/n>=30/);
assert.match(code,/CREATE UNIQUE INDEX IF NOT EXISTS kg_emote_events_podium_daily ON public\.kg_emote_events\(sender_id, target_id, day\) WHERE context='podium'/);
assert.match(code,/CHECK \(target_id IS NULL OR target_id<>sender_id\)/);
const podium=code.match(/FUNCTION public\.get_podium_kampfgeist\(\)[\s\S]*?\$fn\$;/)[0];
assert.doesNotMatch(podium.replace(/'reacted_today'[\s\S]*?e\.day=today\)/g,''),/'sender'|kg_emote_json/,'podium shows counts, not senders');
// Kampfpfad: pro Monat, aus Trainings, Quests und Duellen; ändert keine Punkte/EXP
const pts=code.match(/FUNCTION league_private\.kg_pass_points[\s\S]*?\$fn\$;/)[0];
for(const src of ['training_submissions','quest_claims','league_duels'])assert.ok(pts.includes('public.'+src),'pass points from '+src);
assert.match(pts,/date_trunc\('month'|kg_month\(p_month\)/);
assert.doesNotMatch(code,/(INSERT INTO|UPDATE|DELETE FROM) public\.(point_transactions|training_submissions|quest_claims|league_duels|profiles)\b/,'no edits of existing data');
assert.doesNotMatch(code,/CREATE TRIGGER|random\(\)/i);
// Rollback stellt Etappe 4 her und löscht keine Daten
assert.match(rollback,/CREATE OR REPLACE FUNCTION league_private\.kg_look/);assert.match(rollback,/CREATE OR REPLACE FUNCTION public\.equip_kg_item/);
assert.doesNotMatch(rollback,/DROP TABLE|DELETE FROM|TRUNCATE|ALTER TABLE/i);
assert.doesNotMatch(rollback.match(/FUNCTION league_private\.kg_look[\s\S]*?\$fn\$;/)[0],/emote|einlauf/,'rollback kg_look is the Etappe 4 version');
// Seiten
const rpcOf=t=>[...new Set([...t.matchAll(/\brpc\(\s*'([a-z_]+)'/g)].map(m=>m[1]))].sort();
assert.deepEqual(rpcOf(pfad),['claim_kampfpfad','get_my_kampfpfad']);
const defined=new Set([...sql.matchAll(/CREATE OR REPLACE FUNCTION public\.([a-z_]+)\(/g)].map(m=>m[1]));
for(const r of ['get_duel_kampfgeist','send_duel_emote','get_podium_kampfgeist','hide_kg_emote','get_my_kampfpfad'])assert.ok(rpcOf(perf).includes(r)&&defined.has(r),r);
// Etappe 8: Reaktionen bleiben in der Datenbank (react_podium), das Podium zeigt nur noch das selbst gewählte Emote.
assert.ok(defined.has('react_podium')&&!rpcOf(perf).includes('react_podium'),'podium reactions no longer shown');
assert.match(duels,/card\.dataset\.duelId=duel\.id\|\|''/);
for(const [n,t] of [['duels.html',duels],['index.html',index]]){assert.match(t,/<script src="\.\/takeover-performance\.js" defer><\/script>/,n+' loads module');assert.doesNotMatch(t,/get_duel_kampfgeist|send_duel_emote|react_podium/,n+' unchanged RPC literals')}
assert.match(perf,/if\(screen==='duels'\)run\(mountDuels\)/);assert.match(perf,/if\(screen==='index'\)(run\(mountPodium\)|\{run\(mountPodium\);run\(mountAwards\)(;run\(mountPodiumCards\))?\})/); // Etappe 11: Podium-Karten
assert.match(perf,/async function mountPodium\(\)\{[\s\S]*?getSession\(\);if\(!s\.data\|\|!s\.data\.session\)return;/,'podium only for signed-in viewers');
for(const t of [pfad,js])assert.doesNotMatch(t,/service_role|sb_secret_|(?<!Array)\.from\(|\.(insert|update|upsert|delete)\(/);
assert.match(css,/body\[data-tl-screen\] \.kg-intro,\.kg-intro\{position:fixed;inset:0;z-index:2147483000;width:100vw/,'Einlauf covers the whole screen');
assert.match(css,/@media \(prefers-reduced-motion:reduce\)\{\.kg-intro \*,\.kg-intro\{animation:none!important\}\}/);
assert.match(fs.readFileSync('takeover-navigation.js','utf8'),/'kampfpfad\.html'/);
console.log('PASS: Etappe 5 – 18 positive Emotes (kein Freitext, nur Duell/Podium, Takt/Limit, 1 Podium-Reaktion pro Tag ohne Absender), 10 Einläufe, 5 Kampfpfad-Items nie käuflich, Kampfpfad aus Trainings/Quests/Duellen pro Monat, keine Datenänderung, Rollback stellt Etappe 4 her');
