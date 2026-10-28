'use strict';
// Static contracts for Etappe 7c (Hilfe-Register pro Seite, «?»-Knopf, Tour beim nächsten Login, FAQ).
const fs=require('node:fs'),assert=require('node:assert/strict'),vm=require('node:vm');
const read=f=>fs.readFileSync(f,'utf8');
const js=read('takeover-help.js'),nav=read('takeover-navigation.js'),page=read('hilfe.html'),sql=read('supabase/migrations/20261029110000_help_tutorial.sql');
const ctx={window:{},document:{readyState:'complete',body:{dataset:{}}},console,setTimeout};vm.createContext(ctx);vm.runInContext(js,ctx);
const H=ctx.window.TLHelp;assert.ok(H,'TLHelp exported');
for(const f of ['preflight','postflight','rollback'])assert.ok(fs.existsSync('supabase/production-prep/'+f+'_20261029110000_help_tutorial.sql'),f);
// Jedes Register zeigt auf eine vorhandene Seite, Schlüssel eindeutig, Gruppen bekannt, Inhalte kurz
const keys=H.REGISTERS.map(r=>r.key);assert.equal(new Set(keys).size,keys.length,'unique keys');
const groups=new Set(H.GROUPS.map(g=>g[0]));
for(const r of H.REGISTERS){
 assert.ok(fs.existsSync(r.page),r.key+': page '+r.page);assert.ok(groups.has(r.group),r.key+': group');
 assert.ok(r.points.length>=2&&r.points.length<=6,r.key+': 2–6 points');for(const p of r.points)assert.ok(p.length<=200,r.key+': short points');
}
// «?»-Knopf: Seite → Register identisch in Navigation und Hilfe, jedes Ziel existiert
const navMap=Function('return '+nav.match(/const HELP_KEY=(\{[\s\S]*?\});/)[1])();
assert.deepEqual(navMap,JSON.parse(JSON.stringify(H.PAGE_KEY)),'same page map');
for(const [p,k] of Object.entries(navMap)){assert.ok(fs.existsSync(p),p);assert.ok(keys.includes(k),p+' → '+k)}
// Jede Menüseite (ausser Anmelden) hat ein Register
for(const m of nav.matchAll(/\['[^']*','[^']*','([a-z0-9-]+\.html)(?:#[a-z]+)?'/g)){const p=m[1];if(['login.html','hilfe.html'].includes(p))continue;assert.ok(navMap[p],'help for menu page '+p)}
assert.match(nav,/\['❓','Hilfe & Tutorial','hilfe\.html',''\]/);
assert.match(nav,/pageName==='boxer\.html'&&!window\.TLHelp/,'tour script only on Mein Studio');
// Tour: Version, Trainer-Schritt nur für Staff, Speichern über RPC
assert.equal(H.TOUR_VERSION,1);
assert.equal(H.tourSteps('boxer').length,H.TOUR.length-1);assert.equal(H.tourSteps('coach').length,H.TOUR.length);
assert.match(js,/rpc\('get_my_onboarding'\)/);assert.match(js,/rpc\('mark_tour_seen',\{p_version:TOUR_VERSION\}\)/);
assert.match(js,/e\.key==='Escape'/,'tour closes with Escape');assert.match(js,/class="tl-tour-card" role="dialog"/);
// Hilfe-Seite: nur vorgesehene RPCs, Ausgaben escaped
const rpcOf=t=>[...new Set([...t.matchAll(/\brpc\(\s*'([a-z_]+)'/g)].map(m=>m[1]))].sort();
assert.deepEqual(rpcOf(page),['admin_save_faq','get_faq','get_my_onboarding','mark_tour_seen']);
for(const f of ['x.question','x.answer','r.title','r.summary'])assert.ok(page.includes('esc('+f),'escaped '+f);
assert.doesNotMatch(page+js,/service_role|sb_secret_/i);
// SQL: Flag aus, FAQ für Gäste lesbar, Pflege nur Admin, keine direkten Tabellenrechte
assert.match(sql,/VALUES \('tutorial','Tutorial beim Login',false\)/);
assert.match(sql,/GRANT EXECUTE ON FUNCTION public\.get_faq\(\) TO anon, authenticated/);
assert.match(sql,/IF me\.id IS NULL OR me\.role<>'admin' THEN RAISE EXCEPTION 'Nur der Admin pflegt die FAQ'/);
assert.match(sql,/WHERE NOT EXISTS \(SELECT 1 FROM public\.faq_entries\)/,'seed only once');
assert.match(sql,/GREATEST\(public\.profile_onboarding\.tour_version,EXCLUDED\.tour_version\)/);
console.log('PASS: Etappe 7c – '+H.REGISTERS.length+' Hilfe-Register (jede Menüseite abgedeckt), «?» auf '+Object.keys(navMap).length+' Seiten, Tour (Staff-Schritt, Escape, einmal pro Version), FAQ nur Admin pflegt, Flag aus');
