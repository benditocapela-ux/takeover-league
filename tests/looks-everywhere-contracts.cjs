'use strict';
// Static contracts for Etappe 11: Rahmen und Titel überall, Podium-FUT-Karten, Boxerprofil übersichtlich, Vergleichen-Knöpfe.
const fs=require('node:fs'),assert=require('node:assert/strict');
const read=f=>fs.readFileSync(f,'utf8');
const sql=read('supabase/migrations/20261029170000_looks_everywhere.sql'),code=sql.replace(/--[^\n]*/g,'');
const rollback=read('supabase/production-prep/rollback_20261029170000_looks_everywhere.sql');
const etappe5=read('supabase/migrations/20261028220000_kampfgeist_etappe5.sql');
const perf=read('takeover-performance.js'),css=read('takeover-redesign.css'),index=read('index.html'),guest=read('guest.html');
const profileHtml=read('boxer-profile.html'),profileJs=read('boxer-profile.js'),bew=read('bewertung.html');
for(const f of ['preflight','postflight'])assert.ok(fs.existsSync('supabase/production-prep/'+f+'_20261029170000_looks_everywhere.sql'),f);
// kg_look: nur der Rang-Standard kommt dazu; Rücknahme stellt den Etappe-5-Text wörtlich wieder her
const fn=t=>t.slice(t.indexOf('CREATE OR REPLACE FUNCTION league_private.kg_look'),t.indexOf('$fn$;',t.indexOf('CREATE OR REPLACE FUNCTION league_private.kg_look'))+5);
assert.equal(fn(rollback),fn(etappe5),'rollback restores kg_look of 20261028220000 verbatim');
assert.match(fn(sql),/IF ri>=1 THEN/);assert.match(fn(sql),/'f_rang_e','f_rang_d','f_rang_c','f_rang_b','f_rang_a','f_rang_s'/);
assert.match(fn(sql),/'t_prospect','t_contender','t_challenger','t_elite','t_champion','t_legend'/);
assert.doesNotMatch(code,/UPDATE public\.|DELETE FROM|INSERT INTO|TRUNCATE/i,'no data changes');
// öffentliche Looks: nur Design-Daten, sichtbare Profile, eindeutige Namen, Shop-Flag
const pub=code.slice(code.indexOf('FUNCTION public.get_public_boxer_looks'));
assert.match(pub,/SECURITY DEFINER SET search_path=''/);assert.match(pub,/flag_on\('kampfgeist_shop'\)/);
assert.match(pub,/p\.is_listed IS TRUE OR p\.id=me\.id OR staff/);assert.match(pub,/\)=1\)/);
assert.doesNotMatch(pub.slice(0,pub.indexOf('$fn$;')),/'avatar'|'aura'|'banner'|'level'|balance|coins|price/,'only name, rank, frame and title');
assert.match(code,/GRANT EXECUTE ON FUNCTION public\.get_public_boxer_looks\(\) TO anon, authenticated;/);
// Jeder Rahmen aus dem Shop hat eine Profilbild-Variante
const frames=[...read('supabase/migrations/20261028210000_kampfgeist_shop.sql').matchAll(/'\{"fr":"([a-z]+)"/g),...etappe5.matchAll(/'\{"fr":"([a-z]+)"/g)].map(m=>m[1]).filter(f=>f!=='none');
assert.ok(frames.length>=10);
for(const f of new Set(frames))assert.ok(css.includes('.kg-fr-'+f+'.tl-framed'),'frame on profile pictures: '+f);
assert.match(css,/\.kg-fr-blitz\.tl-framed,\.kg-fr-abgrund\.tl-framed,\.kg-fr-srang\.tl-framed\{animation:none!important\}/,'reduced motion');
// Seiten markieren Profilbilder; Titel nur als Text bzw. escapter Titel-Baustein
assert.match(index,/data-tl-boxer="'\+safe\(who\)\+'"/);assert.match(guest,/data-tl-boxer="'\+safe\(who\)\+'"/);
assert.match(guest,/tag\.textContent=lk\.titel\.name/);assert.doesNotMatch(guest.slice(guest.indexOf('function decorateLooks'),guest.indexOf('/* Start */')),/innerHTML/);
assert.match(perf,/t\.innerHTML=K\.titleTag\(lk\.titel\)/);assert.match(read('takeover-kampfgeist.js'),/const titleTag=it=>it\?`<span class="kg-title r-\$\{cls\(it\.rarity\)\}">\$\{esc\(it\.name\)\}<\/span>`:''/);
assert.match(perf,/run\(mountLooks\)/);assert.match(perf,/run\(mountPodiumCards\)/);
assert.match(profileJs,/\$\('profilePhoto'\)\.dataset\.tlBoxer=name/);assert.match(profileHtml,/<h1 id="profileName" data-tl-name>/);
assert.match(perf,/av\.dataset\.tlBoxer=myName/,'studio photo');
// Podium-Karten nur angemeldet
const pc=perf.slice(perf.indexOf('async function mountPodiumCards'),perf.indexOf('function alertBox'));
assert.match(pc,/getSession\(\);if\(!s\.data\|\|!s\.data\.session\)return;/);assert.match(pc,/get_performance_card/);
// Boxerprofil: Diagramm ausgeblendet, Funktion bleibt; Reihenfolge; Vergleichen
assert.match(profileHtml,/id="sportProfile"[^>]*hidden/);assert.match(profileJs,/function renderPublicRadar\(/);assert.doesNotMatch(profileJs,/^\s*renderPublicRadar\(/m);
assert.match(profileHtml,/#profileCard>\.tlp-profile\{order:6/);assert.match(profileHtml,/#profileCard>\.actions\{order:7\}/);
assert.match(perf,/'\.\/boxer-compare\.html\?left='\+enc\(myName\)\+'&right='\+enc\(shown\)/);
assert.match(bew,/boxer-compare\.html\?left=\$\{encodeURIComponent\(data\.profile\.display_name\)\}/);
console.log('PASS: Etappe 11 – Rang-Rahmen/-Titel als Standard, Rücknahme wörtlich, öffentliche Looks nur Design-Daten, jeder Rahmen auch am Profilbild, Titel escaped, Podium-Karten nur angemeldet, Profil ohne Diagramm mit Vergleichen');
