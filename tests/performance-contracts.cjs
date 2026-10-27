'use strict';
// Static contracts for Etappe 1 (Coach-Bewertung + Boxstil-Test): JS and SQL stay in sync,
// pages only call the intended RPCs and never ship privileged keys.
const fs=require('node:fs'),assert=require('node:assert/strict'),vm=require('node:vm');
const sql=fs.readFileSync('supabase/migrations/20261028180000_coach_ratings_style_test.sql','utf8');
const js=fs.readFileSync('takeover-performance.js','utf8');
const ctx={window:{},document:{readyState:'complete',body:{dataset:{}}},console,URLSearchParams,Intl,location:{search:''}};
vm.createContext(ctx);vm.runInContext(js,ctx);
const P=ctx.window.TLPerf,J=x=>JSON.parse(JSON.stringify(x));
assert.ok(P,'TLPerf exported');

// 1. Skill-Schlüssel und Gewichte identisch zur SQL-Definition
const cats=[...sql.matchAll(/\('([A-Z]{3})',(\d+),ARRAY\[([^\]]+)\]\)/g)].map(m=>({k:m[1],w:+m[2],keys:m[3].split(',').map(x=>x.trim().replace(/'/g,''))}));
assert.equal(cats.length,6,'six SQL categories');
assert.deepEqual(cats.map(c=>c.k),J(P.CATS.map(c=>c.k)),'category order');
assert.deepEqual(cats.map(c=>c.w),J(P.CATS.map(c=>c.w)),'category weights');
assert.deepEqual(cats.map(c=>c.keys),J(P.CATS.map(c=>c.s.map(s=>s[0]))),'skill keys per category');
assert.equal(P.SKILL_KEYS.length,25);

// 2. Boxstil-Fragen passen zu den Server-Gewichten (8 Fragen × 3 Antworten)
const wm=sql.match(/SELECT '(\[\[[\s\S]*?\]\])'::jsonb/);assert.ok(wm,'style weights literal');
const weights=JSON.parse(wm[1]);
assert.equal(weights.length,8);assert.equal(P.QUESTIONS.length,8);
weights.forEach((q,i)=>{assert.equal(q.length,3,'3 weights q'+(i+1));assert.equal(P.QUESTIONS[i].o.length,3,'3 answers q'+(i+1));});
for(const q of weights)for(const o of q)for(const k of Object.keys(o))assert.ok(P.AX.some(a=>a.k===k),'unknown axis '+k);

// 3. Live-Vorschau rechnet wie league_private.rating_summary (gleiche Beispiele wie im SQL-Test)
const base=Object.fromEntries(P.SKILL_KEYS.map(k=>[k,7]));
let s=P.summary(base);assert.equal(s.overall,70);
s=P.summary({...base,jab:10,slip:3});assert.equal(s.categories.OFF,75);assert.equal(s.categories.DEF,63);assert.equal(s.overall,70);
s=P.summary(Object.fromEntries(P.SKILL_KEYS.map(k=>[k,10])));assert.equal(s.overall,99,'cap 99');
assert.deepEqual(P.tier(85)[0],'elite');assert.deepEqual(P.tier(74)[0],'silber');

// 4. Boxstil-Typ
assert.equal(P.styleType({o:20,v:45,c:18,p:80,s:20,a:75}).title,'Druck-Boxer + Angreifer');
assert.equal(P.styleType({o:50,v:55,c:50,p:60,s:50,a:52}).title,'Allrounder');
assert.equal(P.styleType({o:90,v:20,c:60,p:10,s:40,a:20}).title,'Distanz-Boxer');

// 5. Seiten rufen nur die vorgesehenen RPCs auf, keine privilegierten Schlüssel
const rpcOf=t=>[...new Set([...t.matchAll(/\brpc\(\s*'([a-z_]+)'/g)].map(m=>m[1]))].sort();
const bew=fs.readFileSync('bewertung.html','utf8'),stil=fs.readFileSync('stil-test.html','utf8');
assert.deepEqual(rpcOf(bew),['get_my_performance','staff_get_rating','staff_list_performance','staff_rate_boxer']);
assert.deepEqual(rpcOf(stil),['get_my_performance','staff_list_performance','staff_unlock_style_test','submit_style_test']);
assert.deepEqual(rpcOf(js),['get_my_performance','get_performance_card']);
for(const [n,t] of [['bewertung.html',bew],['stil-test.html',stil],['takeover-performance.js',js]]){
 assert.doesNotMatch(t,/service_role|sb_secret_/i,n+' must not contain privileged keys');
 assert.doesNotMatch(t,/\.from\(\s*'(boxer_ratings|style_tests|style_test_unlocks)'/,n+' must use RPCs, not tables');
}
for(const [n,t] of [['bewertung.html',bew],['stil-test.html',stil]]){
 assert.ok(t.indexOf('takeover-performance.js')<t.indexOf('<script type="module">'),n+': library before page script');
 assert.match(t,/takeover-navigation\.js/);assert.match(t,/takeover-redesign\.css/);
}
for(const page of ['boxer.html','boxer-profile.html'])assert.match(fs.readFileSync(page,'utf8'),/takeover-performance\.js/,page+' loads the module');
const nav=fs.readFileSync('takeover-navigation.js','utf8');
assert.match(nav,/'bewertung\.html'/);assert.match(nav,/'stil-test\.html'/);
// 6. Ausgaben werden escaped (Namen, Kommentare)
assert.equal(P.esc('<img src=x onerror=alert(1)>'),'&lt;img src=x onerror=alert(1)&gt;');
assert.doesNotMatch(P.card({name:'<b>X</b>',overall:70,categories:{OFF:70,DEF:70,BEI:70,KON:70,TAK:70,MEN:70}}),/<b>X<\/b>/);
console.log('PASS: Bewertung/Boxstil – Skills, Gewichte und Fragen synchron mit SQL, Vorschau rechnet wie der Server, nur vorgesehene RPCs, Ausgaben escaped');
