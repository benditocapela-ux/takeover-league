/* Gastmodus (guest.html): Funktions- und Datenschutzprüfung.
   - rendert die Seite mit simulierten oeffentlichen API-Antworten (offline, keine Live-Daten)
   - prüft, dass ausschliesslich öffentlich lesbare Quellen angefragt werden
   - prüft, dass keine privaten Tabellen oder RPCs abgerufen werden
   Aufruf: node tests/guest-showcase.cjs */

const fs=require('node:fs');
const assert=require('node:assert/strict');
const {JSDOM}=require('jsdom');

const html=fs.readFileSync('guest.html','utf8');
const login=fs.readFileSync('login.html','utf8');

/* ---------- Erwartete Anfragen: ausschliesslich oeffentlich lesbare Quellen ---------- */
const ALLOWED_RPCS=new Set([
  'get_public_leaderboard',
  'get_public_levels',
  'get_monthly_awards',
  'get_public_boxer_avatars',
  'get_public_boxer_looks',        // Etappe 11: nur Rahmen, Rang und Titel sichtbarer Boxer
  'league_v21_public_live_duels'   // optionale, sanitisierte Projektion (nur nach Freigabe)
]);
const ALLOWED_TABLES=new Set([
  'league_global_challenges_v21',
  'league_global_results_v21',
  'league_public_duel_history_v21',
  'league_public_records_v21',
  'league_public_badges_v21',
  'league_hall_of_fame_v21',
  'league_seasons_v21'
]);
/* Niemals anfragen: individuelle oder trainerbezogene Daten. */
const FORBIDDEN=[
  'training_submissions','point_transactions','boxer_coach_feedback','boxer_coach_goals',
  'league_boxer_goals_v21','league_goal_progress_v21','league_global_entries_v21',
  'profiles','boxer_achievements','league_duels','league_arena_duels_v21',
  'review_training','coach_training_audit_recent','get_boxer_exp_level_rank',
  'get_boxer_performance_30d','duel_v2_live_scores','league_v21_arena_live_scores'
];

const LEADERBOARD=[
  {rank_position:1,boxer_name:'Royce',monthly_points:595,lifetime_exp:595},
  {rank_position:2,boxer_name:'Jona',monthly_points:340,lifetime_exp:340},
  {rank_position:3,boxer_name:'Adriano',monthly_points:310,lifetime_exp:310},
  {rank_position:4,boxer_name:'Sascha',monthly_points:295,lifetime_exp:295}
];
const LEVELS=[
  {boxer_name:'Royce',lifetime_exp:595},{boxer_name:'Jona',lifetime_exp:340},
  {boxer_name:'Adriano',lifetime_exp:310},{boxer_name:'Sascha',lifetime_exp:295}
];
const AWARDS=[
  {award_code:'consistent',award_name:'Mr. Consistent',boxer_name:'Jona',award_value:7,award_unit:'Tage'},
  {award_code:'road_king',award_name:'Road King',boxer_name:'Royce',award_value:42.5,award_unit:'km'},
  {award_code:'flash',award_name:'The Flash',boxer_name:'Sascha',award_value:9,award_unit:'Einheiten'},
  {award_code:'technician',award_name:'The Technician',boxer_name:'Adriano',award_value:180,award_unit:'Minuten'}
];

const requests=[];
function respond(url,init){
  const u=String(url);
  const rpcMatch=u.match(/\/rest\/v1\/rpc\/([a-z_0-9]+)/);
  if(rpcMatch){
    const name=rpcMatch[1];
    requests.push({kind:'rpc',name});
    if(name==='get_public_leaderboard')return {ok:true,json:async()=>LEADERBOARD};
    if(name==='get_public_levels')return {ok:true,json:async()=>LEVELS};
    if(name==='get_monthly_awards')return {ok:true,json:async()=>AWARDS};
    if(name==='get_public_boxer_avatars')return {ok:true,json:async()=>[]};
    if(name==='get_public_boxer_looks')return {ok:true,json:async()=>[{name:'Royce',rank:'D',rahmen:{key:'f_rang_d',name:'Emblem Rang D',design:{fr:'rank',rk:'D'}},titel:{key:'t_contender',name:'Contender',rarity:'rare'}}]};
    if(name==='league_v21_public_live_duels')return {ok:false,status:404,text:async()=>'not found'};
    throw new Error('Unerwarteter RPC-Aufruf im Gastmodus: '+name);
  }
  const tableMatch=u.match(/\/rest\/v1\/([a-z_0-9]+)/);
  if(tableMatch){
    const name=tableMatch[1];
    requests.push({kind:'table',name});
    if(ALLOWED_TABLES.has(name))return {ok:true,json:async()=>[]};
    throw new Error('Unerwarteter Tabellen-Zugriff im Gastmodus: '+name);
  }
  requests.push({kind:'unknown',name:u});
  return {ok:true,json:async()=>[]};
}

const dom=new JSDOM(html,{
  url:'https://benditocapela-ux.github.io/takeover-league/guest.html',
  runScripts:'dangerously',
  pretendToBeVisual:true,
  beforeParse(window){
    window.fetch=(url,init)=>Promise.resolve(respond(url,init));
    window.matchMedia=()=>({matches:false,addListener(){},removeListener(){},addEventListener(){},removeEventListener(){}});
  }
});

const doc=dom.window.document;

(async()=>{
  await new Promise(r=>setTimeout(r,400));

  /* ---------- 1) Keine privaten Quellen ---------- */
  for(const r of requests){
    assert.ok(!FORBIDDEN.includes(r.name),'Gastmodus fragt private Quelle ab: '+r.name);
  }
  for(const r of requests){
    if(r.kind==='rpc')assert.ok(ALLOWED_RPCS.has(r.name),'Nicht freigegebener RPC im Gastmodus: '+r.name);
    if(r.kind==='table')assert.ok(ALLOWED_TABLES.has(r.name),'Nicht freigegebene Tabelle im Gastmodus: '+r.name);
  }
  assert.ok(requests.some(r=>r.name==='get_public_leaderboard'),'Podium-Rangliste wurde nicht geladen');
  assert.ok(requests.some(r=>r.name==='get_public_levels'),'Level-Rangliste wurde nicht geladen');
  assert.ok(requests.some(r=>r.name==='get_monthly_awards'),'Awards wurden nicht geladen');

  /* ---------- 2) Inhalt gerendert ---------- */
  const podium=doc.querySelector('#podium').textContent;
  assert.ok(podium.includes('Royce'),'Podium enthaelt keinen Boxer');
  assert.ok(podium.includes('595'),'Podium zeigt keine Punktzahl');
  assert.ok(doc.querySelectorAll('#podium .card').length===3,'Podium zeigt nicht 3 Plaetze');
  assert.ok(doc.querySelectorAll('#ranking .row').length===4,'Rangliste hat nicht 4 Zeilen');
  assert.ok(doc.querySelectorAll('#levels .row').length===4,'Level-Rangliste hat nicht 4 Zeilen');
  assert.ok(doc.querySelector('#levels').textContent.includes('Royce'),'Level-Rangliste ist leer');
  assert.ok(doc.querySelectorAll('#awards .row').length===4,'Awards werden nicht vollstaendig gerendert');
  assert.ok(doc.querySelector('#awards').textContent.includes('Road King'),'Awards fehlen');

  /* ---------- 2b) Etappe 11: Rahmen und Titel auch für Gäste (nur Design-Daten) ---------- */
  const royce=doc.querySelector('#ranking [data-tl-boxer="Royce"]');
  assert.ok(royce&&royce.classList.contains('tl-framed')&&royce.classList.contains('kg-fr-rank'),'Rang-Rahmen fehlt in der Rangliste');
  assert.equal(royce.querySelector('.kg-rkbadge').textContent,'D');
  assert.ok(doc.querySelector('#podium .tl-look-title .kg-title.r-rare').textContent==='Contender','Titel fehlt beim Namen');
  assert.ok(!doc.querySelector('[data-tl-boxer="Jona"]').classList.contains('tl-framed'),'Rahmen nur bei Boxern mit Rahmen');

  /* ---------- 3) Keine Fehlermeldung sichtbar ---------- */
  const visibleErrors=[...doc.querySelectorAll('.err')].filter(n=>n.textContent.trim());
  assert.equal(visibleErrors.length,0,'Sichtbare Fehlermeldung: '+visibleErrors.map(n=>n.textContent).join(' / '));
  assert.ok(!doc.querySelector('#ranking').textContent.includes('werden geladen'),'Ranking blieb im Ladezustand');
  assert.ok(!doc.querySelector('#levels').textContent.includes('werden geladen'),'Levels blieben im Ladezustand');

  /* ---------- 4) Optionale Live-Duelle: graceful fallback ---------- */
  const liveText=doc.querySelector('#live-duels').textContent;
  assert.ok(liveText.includes('nur für die beteiligten Boxer sichtbar'),
    'Fehlender Hinweis, wenn die Live-Duell-Projektion nicht freigegeben ist');

  /* ---------- 5) Gast-Hinweis und Navigation ---------- */
  assert.ok(doc.querySelector('.guestbar'),'Gast-Hinweis fehlt');
  assert.ok(doc.querySelector('.guestbar a[href="./login.html"]'),'Gast-Hinweis verlinkt die Anmeldung nicht');
  const tabs=[...doc.querySelectorAll('.bottom button')].map(b=>b.dataset.page);
  assert.deepEqual(tabs,['overview','ranking','challenges','duels','history'],'Tab-Navigation unvollstaendig');

  /* ---------- 6) Anmeldeseite ---------- */
  assert.ok(login.includes('id="guestBtn"'),'Anmeldeseite hat keinen Gast-Button');
  assert.ok(login.includes("location.href='./guest.html'"),'Gast-Button ist nicht mit guest.html verknuepft');
  assert.ok(login.includes('viewport-fit=cover'),'Anmeldeseite ohne viewport-fit=cover');

  /* ---------- 7) Keine externen Requests ---------- */
  const externals=[...html.matchAll(/(?:src|href)="(https?:\/\/[^"]+)"/g)].map(m=>m[1]);
  assert.equal(externals.length,0,'Gastseite laedt externe Ressourcen: '+externals.join(', '));
  assert.ok(!html.includes('service_role'),'Gastseite enthaelt einen service_role-Key');

  /* ---------- 8) Design Foundation: zentrales Theme statt Doppel-Token ---------- */
  const theme=fs.readFileSync('takeover-theme.css','utf8');
  assert.ok(html.includes('./takeover-theme.css'),'Gastseite bindet das zentrale Theme nicht ein');
  assert.ok(!/:root\{/.test(html),'Gastseite definiert eigene Tokens statt takeover-theme.css zu nutzen');
  const themeTokens=new Set([...theme.matchAll(/(--[a-z0-9-]+)\s*:/g)].map(m=>m[1]));
  const usedTokens=[...new Set([...html.matchAll(/var\((--[a-z0-9-]+)/g)].map(m=>m[1]))];
  const undef=usedTokens.filter(t=>!themeTokens.has(t));
  assert.equal(undef.length,0,'Gastseite nutzt undefinierte Tokens: '+undef.join(', '));
  assert.ok(login.includes('./takeover-theme.css'),'Anmeldeseite bindet das zentrale Theme nicht ein');
  assert.ok(/\.guest-btn\{[^}]*var\(--gold\)/.test(login),'Gast-Button nutzt keine Design-Tokens');

  console.log('PASS Gastmodus: nur oeffentliche Quellen, korrektes Rendering, sauberer Fallback, Anmeldung verknuepft.');
  console.log('     Abgefragt: '+[...new Set(requests.map(r=>r.name))].join(', '));
  console.log('     Keine Browser-/E2E-Aussage.');
})().catch(e=>{console.error('FAIL Gastmodus: '+e.message);process.exitCode=1;});
