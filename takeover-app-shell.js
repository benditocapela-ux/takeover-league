/* Takeover League 3.0 · App Shell
 * Eine Kopfzeile, ein «Mein Account»-Menü und eine rollenbezogene Fussnavigation für alle Seiten.
 * Die Seiten behalten ihre geprüfte Geschäftslogik (RPCs, Validierung, Rechteprüfung); die Shell ersetzt nur
 * die alten Kopf-/Fussleisten und Menüs. Kein iframe. Nicht sicherheitsrelevant: Rechte prüft immer der Server.
 * Zentrale Weiterleitung alter Boxer-Links (boxer.html …) in die neue Boxer Experience: TLShell.legacyTarget().
 */
(function(){
 'use strict';
 if(window.TLShell)return;
 const SB_URL='https://iqarjivcrddcixrvqbfb.supabase.co',SB_KEY='sb_publishable_o--Z21P8Q08lMvIOask_Fw__SRRX7_R';
 const SESSION_KEY='sb-iqarjivcrddcixrvqbfb-auth-token';
 const page=(location.pathname.split('/').pop()||'index.html').toLowerCase();
 const EXCLUDED=new Set(['challenges-v2-preview.html','duels-v2-preview.html','league2-preview.html']);
 if(EXCLUDED.has(page))return;
 const BX='./boxer-experience.html';

 // Seite → Bereich (für Titel, aktiven Tab und Zurück-Ziel)
 const PAGES={
  'boxer-experience.html':{area:'heute',title:'Mein Takeover',native:'full'},
  'boxer.html':{area:'training',title:'Training'},
  'wochenplan.html':{area:'training',title:'Wochenplan'},'goals.html':{area:'training',title:'Meine Ziele'},
  'praesenz.html':{area:'training',title:'Präsenz'},'checkin.html':{area:'training',title:'Gym-Check-in'},
  'duels.html':{area:'kaempfe',title:'Duelle'},'league-challenges.html':{area:'kaempfe',title:'Live-Challenges'},
  'challenges.html':{area:'kaempfe',title:'Challenges'},'arena.html':{area:'kaempfe',title:'Arena'},'quests.html':{area:'kaempfe',title:'Wochen-Quests'},
  'index.html':{area:'liga',title:'Liga'},'boxer-compare.html':{area:'liga',title:'Boxer-Vergleich'},'awards.html':{area:'liga',title:'Auszeichnungen'},
  'league-history.html':{area:'liga',title:'Hall of Fame'},'boxer-profile.html':{area:'liga',title:'Boxerprofil'},'guest.html':{area:'liga',title:'Gastansicht'},
  'stil-test.html':{area:'boxer',title:'Boxstil-Test'},'mein-boxer.html':{area:'boxer',title:'Boxer gestalten'},'shop.html':{area:'boxer',title:'Kampfgeist-Shop'},
  'karten.html':{area:'boxer',title:'Spielerkarten'},'bewertung.html':{area:'boxer',title:'Bewertung'},'kampfpfad.html':{area:'boxer',title:'Kampfpfad'},
  'roadmap.html':{area:'boxer',title:'Level-Roadmap'},
  'news.html':{area:'mehr',title:'Neuigkeiten'},'feedback.html':{area:'mehr',title:'Feedback'},'hilfe.html':{area:'mehr',title:'Hilfe'},
  'features.html':{area:'mehr',title:'Funktionen'},'coming-soon.html':{area:'mehr',title:'Demnächst'},'login.html':{area:'account',title:'Mein Account'},
  'coach.html':{area:'coach',title:'Trainer-Dashboard',native:'nav'},'league-manager.html':{area:'manager',title:'League Manager'},
  'admin.html':{area:'admin',title:'Clubverwaltung',native:'nav'}
 };
 const AREA_LABEL={heute:'Heute',training:'Training',kaempfe:'Kämpfe',liga:'Liga',boxer:'Mein Boxer',mehr:'Mehr',account:'Account',
  coach:'Trainer',manager:'Liga-Verwaltung',admin:'Admin'};
 const NAV={
  boxer:[['heute','⌂','Heute',BX+'#heute'],['training','♜','Training',BX+'#training'],['kaempfe','⚔','Kämpfe',BX+'#kaempfe'],
   ['liga','🏆','Liga',BX+'#liga'],['boxer','🥊','Mein Boxer',BX+'#boxer']],
  coach:[['coach','🏠','Start','./coach.html#start'],['review','✅','Prüfen','./coach.html#bestaetigen'],['gym','🏟️','Gym','./coach.html#gym'],
   ['boxers','👥','Boxer','./coach.html#boxer'],['manager','🎯','Liga','./league-manager.html'],['liga','🏆','Ranking','./index.html#ranking']],
  admin:[['admin','🛡️','Club','./admin.html'],['coach','🧑‍🏫','Trainer','./coach.html#start'],['manager','🎯','Manager','./league-manager.html'],
   ['liga','🏆','Liga','./index.html#ranking']],
  guest:[['podium','🏆','Podium','./index.html#podium'],['liga','📊','Ranking','./index.html#ranking'],['awards','🏅','Awards','./awards.html'],
   ['mehr','❓','Hilfe','./hilfe.html'],['account','👤','Anmelden','./login.html']]
 };
 const LINKS={
  boxer:[
   ['Training',[['♜','Training erfassen',BX+'#training/eigenes'],['🗂️','Trainingshistorie',BX+'#training/historie'],['🗓️','Wochenplan','./wochenplan.html'],['🎯','Meine Ziele','./goals.html'],['✅','Präsenz','./praesenz.html'],['📍','Gym-Check-in','./checkin.html']]],
   ['Kämpfe & Challenges',[['⚔️','Duelle','./duels.html'],['⚡','Live-Challenges','./league-challenges.html'],['🎯','Challenges','./challenges.html'],['🥊','Arena','./arena.html'],['🏆','Wochen-Quests','./quests.html']]],
   ['Liga',[['📊','Rangliste','./index.html#ranking'],['🏆','Podium','./index.html#podium'],['📈','Levels & EXP','./index.html#levels'],['🗓️','Punkteverlauf','./index.html#history'],['⚖️','Boxer-Vergleich','./boxer-compare.html'],['🏅','Auszeichnungen','./awards.html'],['👑','Saisons & Hall of Fame','./league-history.html']]],
   ['Mein Boxer',[['🥊','Boxer gestalten','./mein-boxer.html'],['🛍️','Kampfgeist-Shop','./shop.html'],['🃏','Spielerkarten','./karten.html'],['📐','Boxstil-Test','./stil-test.html'],['⭐','Bewertung','./bewertung.html'],['🗺️','Kampfpfad','./kampfpfad.html'],['📈','Level-Roadmap','./roadmap.html'],['👤','Profil & Statistik',BX+'#boxer/profil']]],
   ['Info',[['🔔','Mitteilungen',BX+'#heute/mitteilungen'],['📰','Neuigkeiten','./news.html'],['💬','Feedback','./feedback.html'],['❓','Hilfe & Tutorial','./hilfe.html']]]
  ],
  coach:[
   ['Trainer',[['🏠','Start','./coach.html#start'],['✅','Trainings prüfen','./coach.html#bestaetigen'],['🏟️','Gym','./coach.html#gym'],['👥','Boxer','./coach.html#boxer'],['🗓️','Historie','./coach.html#historie'],['☰','Mehr','./coach.html#mehr']]],
   ['Liga-Verwaltung',[['🎯','League Manager','./league-manager.html'],['🎯','Challenges','./challenges.html'],['⚡','Live-Challenges','./league-challenges.html'],['⭐','Bewertungen','./bewertung.html'],['🗓️','Wochenplan','./wochenplan.html'],['✅','Präsenz','./praesenz.html'],['🏆','Wochen-Quests','./quests.html'],['🛍️','Shop','./shop.html'],['🃏','Karten','./karten.html']]],
   ['Eigenes Training',[['♜','Eigenes Training erfassen','./boxer.html#trainingFormCard'],['⚔️','Duelle','./duels.html']]],
   ['Liga',[['📊','Rangliste','./index.html#ranking'],['🏅','Auszeichnungen','./awards.html'],['👑','Hall of Fame','./league-history.html'],['⚖️','Boxer-Vergleich','./boxer-compare.html']]],
   ['Info',[['📰','Neuigkeiten','./news.html'],['💬','Feedback','./feedback.html'],['❓','Hilfe','./hilfe.html']]]
  ],
  guest:[
   ['Liga',[['🏆','Podium','./index.html#podium'],['📊','Rangliste','./index.html#ranking'],['📈','Levels & EXP','./index.html#levels'],['🗓️','Punkteverlauf','./index.html#history'],['🏅','Auszeichnungen','./awards.html'],['👑','Hall of Fame','./league-history.html'],['⚖️','Boxer-Vergleich','./boxer-compare.html'],['👀','Gastansicht','./guest.html']]],
   ['Info',[['📰','Neuigkeiten','./news.html'],['❓','Hilfe','./hilfe.html']]]
  ]
 };
 LINKS.admin=[['Admin',[['🛡️','Clubverwaltung','./admin.html'],['🧑‍🏫','Trainer-Dashboard','./coach.html#start'],['🎯','League Manager','./league-manager.html']]],...LINKS.coach.slice(1)];
 const HELP={'boxer-experience.html':'experience','goals.html':'ziele','bewertung.html':'bewertung','stil-test.html':'stil','wochenplan.html':'wochenplan','quests.html':'quests',
  'praesenz.html':'praesenz','checkin.html':'checkin','shop.html':'shop','mein-boxer.html':'meinboxer','kampfpfad.html':'kampfpfad','roadmap.html':'roadmap','duels.html':'duelle','arena.html':'arena',
  'league-challenges.html':'challenges','challenges.html':'challenges','index.html':'ranking','boxer-compare.html':'vergleich','awards.html':'awards','league-history.html':'awards',
  'boxer-profile.html':'profil','news.html':'news','feedback.html':'feedback','karten.html':'karten','coach.html':'coach','league-manager.html':'manager','admin.html':'manager','boxer.html':'studio'};

 /** Alte Boxer-Links → Ansicht in der neuen Boxer Experience (null = keine Weiterleitung). */
 function legacyTarget(href,role){
  if(role!=='boxer')return null;
  let url;try{url=new URL(href,location.href)}catch{return null}
  const file=(url.pathname.split('/').pop()||'').toLowerCase();
  if(file!=='boxer.html')return null;
  const q=url.searchParams,h=url.hash.replace(/^#/,'');
  const map={trainingFormCard:'training/eigenes',entriesCard:'training/historie',trainingInsights:'training/historie',boxerAuditSection:'training/historie',
   studioPanelHistory:'training/historie',profileCard:'boxer/profil',trainingStats:'boxer/profil',expRankSection:'boxer/profil',performance30Section:'boxer/profil',
   achievementsV2:'boxer/profil',boxerFeedbackSection:'boxer/profil',boxerNotificationSection:'heute/mitteilungen',boxerTaskCenter:'heute/mitteilungen'};
  let view=map[h]||'training';
  if(q.get('club')==='1')view='training/verein';
  else if(q.get('individual')==='1')view='training/eigenes';
  return BX+'#'+view;
 }

 const el=(tag,cls,text)=>{const n=document.createElement(tag);if(cls)n.className=cls;if(text!=null)n.textContent=text;return n};
 const state={news:false,role:null,profile:null,user:null,db:null,dbPromise:null,drawer:null,nav:null,header:null};
 const cfg=PAGES[page]||{area:'mehr',title:document.title.split('·')[0].trim()||'Takeover'};

 function hintRole(){
  // Schneller Hinweis für die erste Darstellung (lesend, kein Schreiben in den Sitzungsschlüssel).
  try{const s=JSON.parse(localStorage.getItem(SESSION_KEY)||'null');const id=s&&s.user&&s.user.id;if(!id)return null;
   const a=window.TLAccount&&window.TLAccount.read().find(x=>x.id===id);return a&&a.role?a.role:'pending'}catch{return null}
 }
 function client(){
  if(!state.dbPromise)state.dbPromise=import('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm')
   .then(m=>m.createClient(SB_URL,SB_KEY,{auth:{autoRefreshToken:false,detectSessionInUrl:false,persistSession:true}}))
   .then(db=>(state.db=db));
  return state.dbPromise;
 }
 function navRole(){return state.role==='boxer'||state.role==='coach'||state.role==='admin'?state.role:(state.role==='pending'?null:'guest')}
 function areaUrl(){
  const r=navRole();if(r==='boxer'){const n=NAV.boxer.find(x=>x[0]===cfg.area);return n?n[3]:BX}
  if(r==='coach')return './coach.html#start';if(r==='admin')return './admin.html';return './index.html#podium';
 }

 function renderHeader(){
  if(cfg.native==='full'){state.header=null;return}
  let h=document.getElementById('tla-header');
  if(!h){
   h=el('header','tla-header');h.id='tla-header';
   const back=el('a','tla-back','‹');back.id='tla-back';back.setAttribute('aria-label','Zurück');
   back.addEventListener('click',e=>{
    try{const ref=document.referrer&&new URL(document.referrer);if(ref&&ref.origin===location.origin&&history.length>1){e.preventDefault();history.back()}}catch{}
   });
   const brand=el('a','tla-brand');brand.id='tla-brand';
   const logo=el('span','tla-logo','T');logo.setAttribute('aria-hidden','true');
   const copy=el('span','tla-brand-copy');copy.append(el('span','tla-eyebrow'),el('span','tla-title'));
   brand.append(logo,copy);
   const actions=el('div','tla-head-actions');
   if(HELP[page]){const help=el('a','tla-icon-btn tla-help','?');help.href='./hilfe.html#'+HELP[page];help.setAttribute('aria-label','Hilfe zu dieser Seite');actions.append(help)}
   const menu=el('button','tla-account-btn');menu.type='button';menu.id='tla-account-btn';
   menu.setAttribute('aria-haspopup','dialog');menu.setAttribute('aria-expanded','false');menu.setAttribute('aria-controls','tla-drawer');
   menu.setAttribute('aria-label','Menü und Mein Account öffnen');
   menu.append(el('span','tla-avatar','?'),el('span','tla-burger','☰'));
   menu.addEventListener('click',()=>openDrawer());
   actions.append(menu);
   h.append(back,brand,actions);document.body.prepend(h);
  }
  const r=navRole();
  h.querySelector('.tla-eyebrow').textContent='TAKEOVER · '+(AREA_LABEL[cfg.area]||'League').toUpperCase();
  h.querySelector('.tla-title').textContent=cfg.title;
  const brand=h.querySelector('#tla-brand');brand.href=r==='boxer'?BX+'#heute':areaUrl();
  brand.setAttribute('aria-label','Takeover League – '+cfg.title+' (Startseite)');
  const back=h.querySelector('#tla-back');back.href=areaUrl();
  back.hidden=page==='index.html'&&r==='guest'||page==='coach.html'||page==='admin.html';
  const av=h.querySelector('.tla-avatar');
  const name=state.profile&&state.profile.display_name;
  av.textContent=name?name.trim().split(/\s+/).slice(0,2).map(x=>x[0]).join('').toUpperCase():'👤';
  state.header=h;
 }
 function renderNav(){
  const r=navRole();
  let nav=document.getElementById('tla-nav');
  if(cfg.native||!r){if(nav)nav.remove();document.documentElement.classList.remove('tla-has-nav');return}
  if(!nav){nav=el('nav','tla-nav');nav.id='tla-nav';document.body.append(nav)}
  nav.setAttribute('aria-label',r==='guest'?'Liga-Navigation':r==='boxer'?'Boxer Hauptnavigation':r==='coach'?'Trainer-Navigation':'Admin-Navigation');
  nav.replaceChildren();
  const hash=location.hash.replace('#','');
  for(const [key,icon,label,href] of NAV[r]){
   const a=el('a');a.href=href;a.dataset.area=key;
   const ic=el('strong','',icon);ic.setAttribute('aria-hidden','true');a.append(ic,document.createTextNode(label));
   let current=key===cfg.area||(r==='boxer'&&key==='heute'&&(cfg.area==='mehr'||cfg.area==='account'));
   if(r==='guest'&&page==='index.html')current=key==='podium'?(!hash||hash==='podium'):key==='liga'?hash==='ranking':false;
   else if(r==='guest')current=(key==='awards'&&page==='awards.html')||(key==='mehr'&&cfg.area==='mehr')||(key==='account'&&page==='login.html');
   if(r!=='boxer'&&r!=='guest'&&key==='liga')current=cfg.area==='liga';
   if(current)a.setAttribute('aria-current','page');
   nav.append(a);
  }
  document.documentElement.classList.add('tla-has-nav');
  state.nav=nav;
 }
 function drawerLinks(host){
  const r=navRole()||'guest';
  for(const [title,items] of LINKS[r]||LINKS.guest){
   const sec=el('section','tla-section');sec.append(el('h3','',title));
   const ul=el('ul','tla-links');
   for(const [icon,label,href] of items){
    const li=el('li'),a=el('a');a.href=href;
    // Feedback merkt sich die Seite, von der aus gemeldet wird (wie bisher).
    if(href==='./feedback.html'){const here=page+(location.hash||'');if(/^[a-z0-9-]+\.html(#[a-z0-9_\/-]*)?$/i.test(here)&&page!=='feedback.html')a.href='./feedback.html?from='+encodeURIComponent(here)}const ic=el('span','ic',icon);ic.setAttribute('aria-hidden','true');a.append(ic,document.createTextNode(label));
    try{const u=new URL(href,location.href);if(u.pathname===location.pathname&&(!u.hash||u.hash===location.hash))a.setAttribute('aria-current','page')}catch{}
    a.addEventListener('click',()=>{const u=new URL(a.href);if(u.pathname===location.pathname){closeDrawer(false)}});
    if(state.news&&/news\.html$/.test(href)){const pill=el('span','tla-pill','Neu');a.append(pill)}
    li.append(a);ul.append(li);
   }
   sec.append(ul);host.append(sec);
  }
 }
 let restoreFocus=null;
 function openDrawer(){
  let d=document.getElementById('tla-drawer');
  if(!d){
   d=el('div','tla-drawer');d.id='tla-drawer';d.hidden=true;
   const panel=el('aside','tla-drawer-panel');panel.setAttribute('role','dialog');panel.setAttribute('aria-modal','true');panel.setAttribute('aria-label','Menü und Mein Account');
   const top=el('div','tla-drawer-top');top.append(el('h2','','Menü'));
   const close=el('button','tla-icon-btn','×');close.type='button';close.id='tla-drawer-close';close.setAttribute('aria-label','Menü schliessen');
   close.addEventListener('click',()=>closeDrawer(true));top.append(close);
   const acc=el('div');acc.id='tla-account';
   const areas=el('div');areas.id='tla-areas';
   panel.append(top,acc,areas);d.append(panel);
   d.addEventListener('click',e=>{if(e.target===d)closeDrawer(true)});
   document.addEventListener('keydown',e=>{if(e.key==='Escape'&&!d.hidden){e.preventDefault();closeDrawer(true)}});
   d.addEventListener('keydown',e=>{
    if(e.key==='Tab'){const f=[...panel.querySelectorAll('a[href],button:not([disabled])')];if(!f.length)return;const a=f[0],b=f[f.length-1];
     if(e.shiftKey&&document.activeElement===a){e.preventDefault();b.focus()}else if(!e.shiftKey&&document.activeElement===b){e.preventDefault();a.focus()}}
   });
   document.body.append(d);state.drawer=d;
  }
  const areas=d.querySelector('#tla-areas');areas.replaceChildren();drawerLinks(areas);
  const acc=d.querySelector('#tla-account');
  if(window.TLAccount)window.TLAccount.render(acc,{db:state.db,profile:state.profile,user:state.user});
  restoreFocus=document.activeElement;
  d.hidden=false;document.documentElement.classList.add('tla-drawer-open');
  for(const n of document.body.children)if(n!==d&&!n.inert){n.inert=true;n.dataset.tlaInert='1'}
  document.querySelectorAll('#tla-account-btn,#ex-settings').forEach(b=>b.setAttribute('aria-expanded','true'));
  d.querySelector('#tla-drawer-close').focus();
  // Konto-Daten nachladen, falls die Verbindung erst jetzt bereit ist
  if(!state.db&&window.TLAccount)client().then(()=>{if(!d.hidden)window.TLAccount.render(acc,{db:state.db,profile:state.profile,user:state.user})}).catch(()=>{});
 }
 function closeDrawer(focus){
  const d=document.getElementById('tla-drawer');if(!d||d.hidden)return;
  d.hidden=true;document.documentElement.classList.remove('tla-drawer-open');
  document.querySelectorAll('[data-tla-inert]').forEach(n=>{n.inert=false;delete n.dataset.tlaInert});
  document.querySelectorAll('#tla-account-btn,#ex-settings').forEach(b=>b.setAttribute('aria-expanded','false'));
  if(focus&&restoreFocus&&typeof restoreFocus.focus==='function')restoreFocus.focus();
 }
 function bindNative(){
  // Boxer Experience: eigene Kopf-/Fussleiste im gleichen Design; das Menü oben rechts öffnet «Mein Account».
  const btn=document.getElementById('ex-settings');
  if(btn&&!btn.dataset.tlaBound){btn.dataset.tlaBound='1';btn.setAttribute('aria-controls','tla-drawer');btn.setAttribute('aria-haspopup','dialog');
   btn.addEventListener('click',e=>{e.preventDefault();e.stopImmediatePropagation();openDrawer()},true)}
  document.querySelectorAll('[data-stf-global-menu]').forEach(b=>{if(b.dataset.tlaBound)return;b.dataset.tlaBound='1';
   b.addEventListener('click',e=>{e.preventDefault();e.stopImmediatePropagation();openDrawer()},true)});
  // Alte «← Mein Studio»-Rücklinks entfallen (die Kopfzeile hat «Zurück»); andere Studio-Links führen Boxer in die neue Ansicht.
  if(cfg.native!=='full')document.querySelectorAll('a[href]:not([data-tla-done])').forEach(a=>{
   if(a.closest('#tla-drawer,.tla-nav,#tla-header'))return;
   if(/^\s*←/.test(a.textContent||'')){a.dataset.tlaDone='1';a.hidden=true;a.classList.add('tla-legacy-back')}
   else if(!/boxer\.html/.test(a.getAttribute('href')||''))a.dataset.tlaDone='1';
  });
  document.querySelectorAll('a[href*="boxer.html"]:not([data-tla-done])').forEach(a=>{
   const raw=a.getAttribute('href')||'';if(!/(^|\/)boxer\.html([?#]|$)/.test(raw))return;
   if(a.closest('#tla-drawer,.tla-nav'))return;
   if(/^\s*←/.test(a.textContent||'')){a.dataset.tlaDone='1';a.hidden=true;a.classList.add('tla-legacy-back');return}
   if(state.role!=='boxer')return;
   const t=legacyTarget(a.href,'boxer');if(!t)return;
   a.dataset.tlaDone='1';a.setAttribute('href',t);
   for(const n of a.childNodes)if(n.nodeType===3&&/Mein Studio|Studio/.test(n.textContent))n.textContent=n.textContent.replace(/Mein Studio|Studio/,'Mein Takeover');
   if(a.getAttribute('aria-label'))a.setAttribute('aria-label',a.getAttribute('aria-label').replace(/Mein Studio|Studio/,'Mein Takeover'));
  });
  // Alte Abmelde-Knöpfe: Konto zuerst aus dem Umschalter entfernen, dann wie bisher abmelden.
  document.querySelectorAll('#logout,#logoutBtn').forEach(b=>{if(b.dataset.tlaBound)return;b.dataset.tlaBound='1';
   b.addEventListener('click',()=>{try{const s=JSON.parse(localStorage.getItem(SESSION_KEY)||'null');if(s&&s.user&&window.TLAccount)window.TLAccount.forget(s.user.id)}catch{}},true)});
 }
 // Neuigkeiten: Punkt am Menüknopf und «Neu» im Menü, solange die neueste Meldung ungelesen ist (wie bisher, tl.news.seen).
 async function checkNews(){
  try{
   const r=await fetch('./news.json',{cache:'no-cache'});if(!r.ok)return;
   const d=await r.json(),top=d&&Array.isArray(d.entries)&&d.entries[0]?Number(d.entries[0].n)||0:0;
   let seen=0;try{seen=Number(localStorage.getItem('tl.news.seen'))||0}catch{}
   state.news=top>seen&&page!=='news.html';
   document.querySelectorAll('#tla-account-btn,#ex-settings').forEach(b=>b.classList.toggle('tla-has-news',state.news));
  }catch{}
 }
 function trackTyping(){
  const field=t=>t&&t.matches&&t.matches('input:not([type=checkbox]):not([type=radio]):not([type=button]):not([type=submit]),textarea,select,[contenteditable="true"]');
  document.addEventListener('focusin',e=>{if(field(e.target))document.documentElement.classList.add('tla-typing')});
  document.addEventListener('focusout',e=>{if(field(e.target))setTimeout(()=>{if(!field(document.activeElement))document.documentElement.classList.remove('tla-typing')},60)});
 }
 // Konto in einem anderen Tab gewechselt oder abgemeldet bzw. Seite aus dem Zurück-Cache: neu laden,
 // damit nie Daten eines anderen Kontos unter dem falschen Namen stehen.
 function sessionUser(){try{const x=JSON.parse(localStorage.getItem(SESSION_KEY)||'null');return x&&x.user&&x.user.id||null}catch{return null}}
 let loadedUser;
 function watchAccount(){
  loadedUser=sessionUser();
  addEventListener('storage',e=>{if(e.key===SESSION_KEY&&sessionUser()!==loadedUser)location.reload()});
  addEventListener('pageshow',e=>{if(e.persisted&&sessionUser()!==loadedUser)location.reload()});
 }
 async function resolve(){
  try{
   const db=await client();
   const s=await db.auth.getSession();const session=s&&s.data&&s.data.session;
   if(!session){state.role='guest';state.user=null;state.profile=null;return}
   const u=await db.auth.getUser();const user=u&&u.data&&u.data.user;
   if(u.error||!user){state.role='guest';return}
   state.user=user;
   const p=await db.from('profiles').select('id,display_name,role,is_active').eq('auth_user_id',user.id).maybeSingle();
   state.profile=p.data||null;
   state.role=p.data&&p.data.is_active?p.data.role:'guest';
   if(window.TLAccount)await window.TLAccount.track(db,state.profile);
  }catch(err){console.warn('[takeover-shell] Anmeldung konnte nicht geprüft werden',err);if(!state.role||state.role==='pending')state.role='guest'}
 }
 function redirectLegacy(){
  const target=legacyTarget(location.href,state.role);
  if(target){location.replace(target);return true}
  return false;
 }
 async function start(){
  document.documentElement.classList.add('tla-on');
  if(cfg.native==='full')document.documentElement.classList.add('tla-native-full');
  if(page==='index.html'||document.querySelector('body > .bottom, .bottom [data-tab]'))document.documentElement.classList.add('tla-index-tabs');
  state.role=hintRole();
  if(page==='boxer.html'&&state.role==='boxer'&&redirectLegacy())return;
  renderHeader();renderNav();bindNative();trackTyping();void checkNews();watchAccount();
  let queued=false;new MutationObserver(()=>{if(queued)return;queued=true;requestAnimationFrame(()=>{queued=false;bindNative()})}).observe(document.body,{childList:true,subtree:true});
  // Auch dynamisch erzeugte Links (z. B. Mitteilungen) auf alte Boxer-Ansichten landen in der neuen Oberfläche.
  document.addEventListener('click',e=>{
   if(state.role!=='boxer'||e.defaultPrevented||e.button!==0||e.metaKey||e.ctrlKey||e.shiftKey||e.altKey)return;
   const a=e.target instanceof Element&&e.target.closest('a[href]');if(!a||a.target==='_blank')return;
   const t=legacyTarget(a.href,'boxer');if(t){e.preventDefault();location.assign(t)}
  },true);
  window.addEventListener('hashchange',()=>{renderNav();renderHeader()});
  await resolve();
  if(redirectLegacy())return;
  document.documentElement.style.visibility='';
  renderHeader();renderNav();bindNative();
  document.dispatchEvent(new CustomEvent('takeover:shell-ready',{detail:{role:state.role,profile:state.profile}}));
 }
 window.TLShell={openDrawer,closeDrawer,legacyTarget,homeFor:r=>window.TLAccount?window.TLAccount.homeFor(r):BX,get role(){return state.role},
  get profile(){return state.profile},client,_pages:PAGES};
 if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});else start();
})();
