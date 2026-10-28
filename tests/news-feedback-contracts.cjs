'use strict';
// Static contracts for Etappe 7b (Neuigkeiten aus PRs, Feedback-Portal mit Screenshots).
const fs=require('node:fs'),assert=require('node:assert/strict');
const read=f=>fs.readFileSync(f,'utf8');
const {parseNews,build}=require('../tools/build-news.cjs');
const sql=read('supabase/migrations/20261029100000_feedback_portal.sql'),rollback=read('supabase/production-prep/rollback_20261029100000_feedback_portal.sql');
const fb=read('feedback.html'),news=read('news.html'),nav=read('takeover-navigation.js'),deploy=read('.github/workflows/takeover-pages-deploy.yml');
for(const f of ['preflight','postflight'])assert.ok(fs.existsSync('supabase/production-prep/'+f+'_20261029100000_feedback_portal.sql'),f);

// News: nur der Abschnitt «## News», kurz, ohne Markdown, höchstens 5 Zeilen, nur PRs nach main
assert.deepEqual(parseNews('Intro\n## News\n- Neu: **Karten** im [Vergleich](x)\n- Behoben: `Speichern` hängt\n* Verbessert – schneller\n- ok\n## Prüfung\n- nicht'),
 [{type:'neu',text:'Karten im Vergleich'},{type:'behoben',text:'Speichern hängt'},{type:'verbessert',text:'schneller'}]);
assert.deepEqual(parseNews('## Was\n- Neu: x'),[],'no News section → no entry');
assert.equal(parseNews('## News\n'+Array.from({length:8},(_,i)=>'- Neu: Punkt '+i).join('\n')).length,5);
assert.ok(parseNews('## News\n- Neu: '+'x '.repeat(200))[0].text.length<=222);
assert.deepEqual(parseNews('### news\n- <img src=x onerror=alert(1)>Hallo Welt'),[{type:'info',text:'Hallo Welt'}],'HTML stripped');
const built=build([{number:5,merged_at:'2026-10-20T10:00:00Z',base:{ref:'main'},body:'## News\n- Neu: Alpha'},{number:6,merged_at:null,base:{ref:'main'},body:'## News\n- Neu: Bravo'},
 {number:7,merged_at:'2026-10-22T10:00:00Z',base:{ref:'etappe'},body:'## News\n- Neu: Charlie'},{number:8,merged_at:'2026-10-28T10:00:00Z',base:{ref:'main'},body:'## News\n- Behoben: Delta'}]);
assert.deepEqual(built.map(e=>e.n),[8,5],'merged into main only, newest first');
assert.match(deploy,/node tools\/build-news\.cjs \/tmp\/prs\.json _site\/news\.json/);assert.match(deploy,/pull-requests: read/);
assert.match(deploy,/\|\| echo '\[\]' > \/tmp\/prs\.json/,'deploy never fails because of news');
assert.match(news,/fetch\('\.\/news\.json'/);assert.match(news,/esc\(i\.text\)/);assert.doesNotMatch(news,/rpc\(/);
assert.match(news,/localStorage\.setItem\('tl\.news\.seen'/);assert.match(news,/try\{localStorage/);

// Feedback: nur vorgesehene RPCs und der private Speicher, Ausgaben escaped, keine Tabellenzugriffe
const rpcOf=t=>[...new Set([...t.matchAll(/\brpc\(\s*'([a-z_]+)'/g)].map(m=>m[1]))].sort();
assert.deepEqual(rpcOf(fb),['admin_list_app_feedback','admin_update_app_feedback','my_app_feedback','submit_app_feedback']);
assert.match(fb,/BUCKET='feedback-shots'/);assert.match(fb,/upsert:false/);assert.match(fb,/createSignedUrls\(paths,600\)/);
assert.doesNotMatch(fb,/\.from\('app_feedback'\)|getPublicUrl|service_role|sb_secret_/i);
for(const f of ['x.title','x.message','x.reply','x.author','x.device','x.page'])assert.ok(fb.includes('P.esc('+f),'escaped '+f);
assert.match(fb,/\^\[a-z0-9-\]\+\\\.html/,'from= parameter restricted to simple page names');
// Navigation: neue Gruppe, Feedback nur für Angemeldete, Ungelesen-Punkt
assert.match(nav,/\['scroll','Neuigkeiten','news\.html',''\]/);assert.match(nav,/\['bolt','Feedback & Fehler melden','feedback\.html','',true\]/);
assert.match(nav,/'league-manager\.html','feedback\.html'\]\.includes\(item\[2\]\)\?' data-tl-private hidden'/);
assert.match(nav,/'\.\/checkin\.html','\.\/feedback\.html'\]\.includes\(href\.split\('\?'\)\[0\]\)/);
assert.match(nav,/trigger\.classList\.add\('tl-has-news'\)/);

// SQL: Flag aus, privater Speicher, nur eigener Ordner, Admin liest, keine Änderung/Löschung, Tageslimit, Antwort als Benachrichtigung
assert.match(sql,/VALUES \('app_feedback','Feedback-Portal',false\)/);
assert.match(sql,/VALUES \('feedback-shots','feedback-shots',false,5242880,ARRAY\['image\/png','image\/jpeg','image\/webp'\]\)/);
assert.match(sql,/\(storage\.foldername\(name\)\)\[1\]=\(SELECT auth\.uid\(\)\)::text/);
assert.doesNotMatch(sql,/ON storage\.objects FOR (UPDATE|DELETE|ALL)/);
assert.match(sql,/>=10 THEN/);assert.match(sql,/'general'/);assert.match(sql,/'\/feedback\.html'/);
assert.match(sql,/IF me\.id IS NULL OR me\.role<>'admin' THEN RAISE EXCEPTION 'Nur für den Admin'/);
assert.doesNotMatch(rollback.replace(/--[^\n]*/g,''),/DROP TABLE|DELETE FROM|storage\.buckets/i,'rollback keeps reports and screenshots');
console.log('PASS: Etappe 7b – News nur aus «## News» gemergter PRs (kurz, ohne Markdown/HTML), Feedback nur über RPCs und privaten Speicher, Navigation, Flag aus, Rollback behält Daten');
