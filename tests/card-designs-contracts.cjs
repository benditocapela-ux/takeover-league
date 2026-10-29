'use strict';
// Static contracts for Etappe 7d (Karten-Designs, Card of the Week / Month / Player of the Year).
const fs=require('node:fs'),assert=require('node:assert/strict'),vm=require('node:vm');
const read=f=>fs.readFileSync(f,'utf8');
const sql=read('supabase/migrations/20261029120000_card_designs_awards.sql'),rollback=read('supabase/production-prep/rollback_20261029120000_card_designs_awards.sql');
const js=read('takeover-performance.js'),page=read('karten.html'),css=read('takeover-redesign.css'),nav=read('takeover-navigation.js');
for(const f of ['preflight','postflight'])assert.ok(fs.existsSync('supabase/production-prep/'+f+'_20261029120000_card_designs_awards.sql'),f);
const ctx={window:{},document:{readyState:'complete',body:{dataset:{}}},console,URLSearchParams,Intl,location:{search:''}};vm.createContext(ctx);vm.runInContext(js,ctx);
const P=ctx.window.TLPerf;
// Katalog: 13 Designs, jedes Muster hat CSS, Farben gültig
const rows=[...sql.matchAll(/\('([a-z_]+)','([^']+)','[^']*','(start|rank|shop|award)',(NULL|'[A-Z]'),(NULL|\d+),(NULL|'[a-z]+'),'(\{[^']*\})',\d+\)/g)];
assert.equal(rows.length,13,'13 designs');
const by=u=>rows.filter(r=>r[3]===u).length;assert.equal(by('start'),1);assert.equal(by('rank'),6);assert.equal(by('shop'),3);assert.equal(by('award'),3);
for(const r of rows){const d=JSON.parse(r[7]);if(d.pattern)assert.match(css,new RegExp('data-pattern="'+d.pattern+'"'),'css pattern '+d.pattern);
 for(const k of ['a','b','ink','edge'])if(d[k])assert.match(d[k],/^#[0-9a-f]{6}$/i,r[1]+' '+k);}
assert.deepEqual(rows.filter(r=>r[3]==='rank').map(r=>r[4]),["'E'","'D'","'C'","'B'","'A'","'S'"]);
// Karte: Design-Klassen, keine HTML-Injektion über Design-Werte, Badge nur Grossbuchstaben
const base={name:'Anna',overall:70,categories:{OFF:70,DEF:70,BEI:70,KON:70,TAK:70,MEN:70}};
assert.doesNotMatch(P.card(base),/d-design/);
const html=P.card({...base,look:{key:'cotw',name:'Card of the Week',design:{a:'#7be3a0',b:'#0f3b2a',ink:'red;background:url(x)',pattern:'rays"><script>',badge:'COTW'},awards:[{kind:'cotw'},{kind:'cotw'},{kind:'poty'}]}});
assert.match(html,/d-design/);assert.match(html,/--ca:#7be3a0;/);assert.doesNotMatch(html,/url\(x\)|<script>|data-pattern/);
assert.match(html,/<span class="tlp-badge">COTW<\/span>/);assert.match(html,/👑[\s\S]*⭐2/);assert.match(html,/TKL · Card of the Week/);
assert.doesNotMatch(P.card({...base,look:{key:'x',name:'<b>X</b>',design:{a:'#111111',badge:'<i>'}}}),/<b>X<\/b>|<i>/);
// Seiten: nur vorgesehene RPCs
const rpcOf=t=>[...new Set([...t.matchAll(/\brpc\(\s*'([a-z_]+)'/g)].map(m=>m[1]))].sort();
assert.deepEqual(rpcOf(page),['admin_list_personal_designs','admin_set_personal_design','buy_card_design','equip_card_design','get_card_awards','get_my_card_designs','get_my_performance','get_my_personal_design','save_my_personal_design','staff_card_award_overview','staff_confirm_card_award','staff_revoke_card_award','staff_skip_card_award','staff_unskip_card_award']); // Etappe 12: eigenes Design; Etappe 14: nicht vergeben
assert.doesNotMatch(page,/prompt\(|alert\(|confirm\(/,'no blocking dialogs');assert.doesNotMatch(page+js,/service_role|sb_secret_/i);
assert.match(nav,/\['medal','Karten & Auszeichnungen','karten\.html','',true\]/);
// SQL: Flag aus, Vorschlag nur aus bestätigten Trainings, nur nach Ende, nicht sich selbst, eine pro Zeitraum, zurücknehmen statt löschen
assert.match(sql,/VALUES \('card_designs','Karten-Designs & Auszeichnungen',false\)/);
assert.match(sql,/JOIN public\.training_submissions s ON s\.id=t\.submission_id AND s\.status='approved'/);
assert.match(sql,/IF upper\(r\)-1 >= today THEN RAISE EXCEPTION 'Erst nach Ende des Zeitraums/);
assert.match(sql,/IF t\.id=me\.id THEN RAISE EXCEPTION 'Sich selbst auszeichnen geht nicht/);
assert.match(sql,/CREATE UNIQUE INDEX IF NOT EXISTS card_awards_one_active ON public\.card_awards\(kind, period_start\) WHERE revoked_at IS NULL/);
assert.match(sql,/'purchase','card:'\|\|d\.key/,'coins via kg_ledger');
const top=sql.replace(/\$fn\$[\s\S]*?\$fn\$/g,'').replace(/--[^\n]*/g,'');
assert.doesNotMatch(top,/UPDATE public\.(point_transactions|training_submissions|kg_ledger|profiles)|DELETE FROM|TRUNCATE/i);
assert.doesNotMatch(sql,/DELETE FROM public\.card_awards/);
assert.doesNotMatch(rollback.replace(/--[^\n]*/g,''),/DROP TABLE|DELETE FROM/i);
console.log('PASS: Etappe 7d – 13 Designs (Muster/Farben geprüft), Karte sicher gegen Injektion, Auszeichnungen nur aus bestätigten EXP, nach Periodenende, nicht selbst, eine pro Zeitraum, Rücknahme statt Löschen, Flag aus');
