/* Shared, dependency-free Takeover League navigation.
   Injected into every publicly deployed HTML page, with no auth or data mutations. */
(function(){
 'use strict';
 const sections=new Set(['podium','ranking','levels','history']);
 const emojis={trophy:'🏆',chart:'📊',menu:'🧭',user:'👤', 'boxing-glove':'🥊',scroll:'🗓️',medal:'🏅',scale:'⚖️',target:'🎯',bolt:'⚡',arena:'🥊',dumbbell:'🥊',goal:'🎯'};
 const emoji=(id)=>'<span class="tl-emoji" aria-hidden="true">'+(emojis[id]||(/\p{Extended_Pictographic}/u.test(id)?id:'✨'))+'</span>';
 function addSectionWayfinders(){
   const rules=[[/podium/i,'🏆'],[/rangliste|ranking/i,'📊'],[/level|exp|punkteverlauf|progress|fortschritt/i,'📈'],[/challenge|ziel/i,'🎯'],[/duell|duel|training|boxen/i,'🥊'],[/coach|trainer|freigabe|offen[e]? trainings/i,'🧑‍🏫'],[/award|auszeichnung|saison|hall of fame/i,'🏅'],[/profil|account|anmelden|mein bereich/i,'👤'],[/verwaltung|manager|einstellung/i,'🛡️'],[/mitteilung|aufgabe|feedback/i,'💬'],[/historie|verlauf|history/i,'🗓️']];
   document.querySelectorAll('h1,h2,h3').forEach(el=>{
     if(el.dataset.tlWayfinder)return;
     const text=(el.textContent||'').trim();
     // One symbol per heading: the emoji wayfinder replaces a decorative SVG icon
     // instead of being added next to it; an existing leading emoji is reused.
     const icon=el.querySelector('svg.tl-icon[aria-hidden="true"]');
     const lead=text.match(/^(\p{Extended_Pictographic}(?:️|‍\p{Extended_Pictographic})*)/u);
     if(lead){
       const node=[...el.childNodes].find(n=>n.nodeType===3&&n.textContent.trim());
       if(node&&node.textContent.trimStart().startsWith(lead[1])){
         node.textContent=node.textContent.trimStart().slice(lead[1].length).replace(/^\s+/,'');
         const mark=document.createElement('span');mark.className='tl-section-emoji';mark.setAttribute('aria-hidden','true');mark.textContent=lead[1]+' ';
         el.insertBefore(mark,node);el.dataset.tlWayfinder='true';
         if(icon)icon.remove();
       }
       return;
     }
     const match=rules.find(([pattern])=>pattern.test(text));
     if(!match)return;
     if(icon)icon.remove();
     const mark=document.createElement('span');mark.className='tl-section-emoji';mark.setAttribute('aria-hidden','true');mark.textContent=match[1]+' ';
     el.prepend(mark);el.dataset.tlWayfinder='true';
   });
 }

 function start(){
   if(document.getElementById('tl-menu-panel'))return;
   const pathname=window.location.pathname;
   const page=pathname.substring(pathname.lastIndexOf('/')+1)||'index.html';
   const atHome=page==='index.html';
   const footerMarkup='<nav class="tl-global-bottom" aria-label="Takeover League Navigation"><div class="tl-global-nav-items">'+
     '<a class="tl-nav-item" data-tl-tab="podium" href="./index.html#podium">'+emoji('trophy')+' Podium</a>'+
     '<a class="tl-nav-item" data-tl-tab="ranking" href="./index.html#ranking">'+emoji('chart')+' Ranking</a>'+
     '<button type="button" class="tl-nav-item" id="takeover-menu-open" aria-controls="tl-menu-panel" aria-haspopup="dialog" aria-expanded="false">'+emoji('menu')+' Menü</button>'+
     '<a class="tl-nav-item tl-dashboard-nav" href="./login.html">'+emoji('user')+' Dashboard</a>'+
     '</div></nav>';
   if(!atHome){
     document.body.classList.add('tl-global-nav-page');
     document.body.insertAdjacentHTML('beforeend',footerMarkup);
   }
   const trigger=document.getElementById('takeover-menu-open');
   if(!trigger)return;
   if(atHome){
     const homeNav=[['.bottom [data-tab="podium"]','trophy'],['.bottom [data-tab="ranking"]','chart'],['.bottom #takeover-menu-open','menu'],['.bottom .dashboard-nav','user']];
     homeNav.forEach(([selector,id])=>{const link=document.querySelector(selector);if(!link)return;const label=(link.textContent||'').trim();link.innerHTML=emoji(id)+' '+label;});
   }
   addSectionWayfinders();
   // Etappe 7c: «?» oben auf jeder Seite öffnet das passende Hilfe-Register; Tour beim nächsten Login in Mein Studio.
   const HELP_KEY={'boxer.html':'studio','boxer-experience.html':'experience','goals.html':'ziele','bewertung.html':'bewertung','stil-test.html':'stil','wochenplan.html':'wochenplan','quests.html':'quests',
     'praesenz.html':'praesenz','checkin.html':'checkin','shop.html':'shop','mein-boxer.html':'meinboxer','kampfpfad.html':'kampfpfad','roadmap.html':'roadmap','duels.html':'duelle','arena.html':'arena',
     'league-challenges.html':'challenges','challenges.html':'challenges','index.html':'ranking','boxer-compare.html':'vergleich','awards.html':'awards',
     'league-history.html':'awards','boxer-profile.html':'profil','news.html':'news','feedback.html':'feedback','karten.html':'karten','coach.html':'coach','league-manager.html':'manager','admin.html':'manager'};
   const pageName=location.pathname.split('/').pop()||'index.html',helpKey=HELP_KEY[pageName];
   const ribbon=document.querySelector('.tl-screen-ribbon');
   if(helpKey&&ribbon&&!ribbon.querySelector('.tl-help-link'))
     ribbon.insertAdjacentHTML('beforeend','<a class="tl-help-link" href="./hilfe.html#'+helpKey+'" aria-label="Hilfe zu dieser Seite" title="Hilfe zu dieser Seite">?</a>');
   if(pageName==='boxer.html'&&!window.TLHelp){const sc=document.createElement('script');sc.src='./takeover-help.js';sc.defer=true;document.head.appendChild(sc)}
   // Single shared drawer. The home page supplies its existing four-item footer.
   const entries=[
     {icon:'👤',title:'Mein Bereich',summary:'Profil, Training und persönliche Ziele',items:[
       ['user','Anmelden / Mein Account','login.html',''],
       ['user','Mein Takeover','boxer-experience.html','',true],
       ['dumbbell','Training erfassen (Studio)','boxer.html',''],
       ['target','Meine Ziele','goals.html',''],
       ['medal','Bewertung','bewertung.html','',true],
       ['chart','Boxstil-Test','stil-test.html','',true],
       ['medal','Karten & Auszeichnungen','karten.html','',true],
       ['season','Wochenplan','wochenplan.html','',true],
       ['target','Wochen-Quests','quests.html','',true],
       ['user','Mein Boxer','mein-boxer.html','',true],
       ['medal','Kampfgeist-Shop','shop.html','',true],
       ['chart','Level-Roadmap','roadmap.html','',true],
       ['season','Kampfpfad','kampfpfad.html','',true],
       ['run','Präsenz','praesenz.html','',true],
       ['bolt','Gym-Check-in','checkin.html','',true],
       ['medal','Trainer-Dashboard','coach.html',''],
       ['goal','League Manager','league-manager.html',''],
       ['user','Clubverwaltung','admin.html','',false,true]
     ]},
     {icon:'🥊',title:'Kämpfe',summary:'Duelle starten und in der Arena antreten',items:[
       ['boxing-glove','Duell starten','duels.html','',true],
       ['arena','Mehrgegner-Arena','arena.html','',true]
     ]},
     {icon:'🎯',title:'Herausforderungen',summary:'Persönliche und Liga-Challenges entdecken',items:[
       ['bolt','Live Challenges','league-challenges.html','',true],
       ['target','Persönliche Challenges','challenges.html','',true]
     ]},
     {icon:'🏆',title:'Liga & Erfolge',summary:'Ranglisten, Fortschritt und Auszeichnungen',items:[
       ['trophy','Podium','index.html#podium','podium'],
       ['chart','Monatsranking','index.html#ranking','ranking'],
       ['boxing-glove','Levels & EXP','index.html#levels','levels'],
       ['scroll','Punkteverlauf','index.html#history','history'],
       ['medal','Monatsauszeichnungen','awards.html',''],
       ['scale','Boxer-Vergleich','boxer-compare.html',''],
       ['trophy','Saisons & Hall of Fame','league-history.html','']
     ]},
     {icon:'💬',title:'Hilfe & Neuigkeiten',summary:'Tutorial, was ist neu, Fehler melden, Ideen teilen',items:[
       ['❓','Hilfe & Tutorial','hilfe.html',''],
       ['scroll','Neuigkeiten','news.html',''],
       ['bolt','Feedback & Fehler melden','feedback.html','',true]
     ]}
   ];
   const contents=entries.map((group,index)=>{
     const groupId='tl-menu-group-'+index;
     return '<section class="tl-menu-group">'+
       '<button type="button" class="tl-menu-group-title tl-menu-group-toggle" id="'+groupId+'-toggle" aria-expanded="false" aria-controls="'+groupId+'-links">'+
         '<span class="tl-menu-group-mark" aria-hidden="true">'+group.icon+'</span>'+
         '<span class="tl-menu-group-copy"><span class="tl-menu-group-name">'+group.title+'</span><span class="tl-menu-group-summary">'+group.summary+'</span></span>'+
         '<span class="tl-menu-group-chevron" aria-hidden="true">⌄</span>'+
       '</button><div class="tl-menu-group-links" id="'+groupId+'-links" hidden>'+
         group.items.map(item=>
           '<a class="tl-menu-link" href="./'+item[2]+'"'+(item[3]?' data-tl-section="'+item[3]+'"':'')+(item[5]?' data-tl-admin hidden':'')+(['boxer.html','goals.html','bewertung.html','stil-test.html','wochenplan.html','quests.html','shop.html','roadmap.html','kampfpfad.html','praesenz.html','checkin.html','coach.html','league-manager.html','feedback.html','karten.html','mein-boxer.html'].includes(item[2])?' data-tl-private hidden':'')+'>'+
             '<span class="tl-menu-icon" aria-hidden="true">'+emoji(item[0])+'</span>'+
             '<span class="tl-menu-label">'+item[1]+(item[4]?' <span class="tl-menu-pill">Neu</span>':'')+'</span>'+
             '<span class="tl-menu-arrow" aria-hidden="true">↗</span>'+
           '</a>').join('')+'</div></section>';
   }).join('');
   document.body.insertAdjacentHTML('beforeend',
      '<div id="tl-menu-backdrop" class="tl-menu-backdrop" hidden aria-hidden="true"></div>'+
      '<aside id="tl-menu-panel" class="tl-menu-panel" role="dialog" aria-modal="true" aria-label="Alle Takeover League Bereiche" aria-hidden="true" inert>'+
      '<div class="tl-menu-head"><div><div class="tl-menu-overline">TAKEOVER LEAGUE</div><div class="tl-menu-title">'+emoji('menu')+' Alle Bereiche</div></div>'+
      '<button type="button" class="tl-menu-close" id="tl-menu-close" aria-label="Menü schliessen">×</button></div>'+
      '<p class="tl-menu-intro">Tippe auf eine Rubrik, um die passenden Bereiche zu öffnen.</p>'+
      contents+
      '<div class="tl-menu-foot">Deine Punkte, Ranglisten und Trainings bleiben erhalten.</div></aside>');
   const panel=document.getElementById('tl-menu-panel');
   const backdrop=document.getElementById('tl-menu-backdrop');
   const close=document.getElementById('tl-menu-close');
   const menuEntries=Array.from(panel.querySelectorAll('a.tl-menu-link'));
   const adminEntry=panel.querySelector('a[data-tl-admin]');
   const privateEntries=Array.from(panel.querySelectorAll('a[data-tl-private]'));
   // Etappe 7b: «Feedback» merkt sich, von welcher Seite aus gemeldet wird; «Neuigkeiten» zeigt einen Punkt bei Ungelesenem.
   const feedbackLink=panel.querySelector('a.tl-menu-link[href="./feedback.html"]');
   const here=(location.pathname.split('/').pop()||'index.html')+(location.hash||'');
   if(feedbackLink&&/^[a-z0-9-]+\.html(#[a-z0-9_-]*)?$/i.test(here)&&!here.startsWith('feedback.html'))feedbackLink.href='./feedback.html?from='+encodeURIComponent(here);
   (async()=>{
     try{
       const r=await fetch('./news.json',{cache:'no-cache'});if(!r.ok)return;
       const d=await r.json(),top=d&&Array.isArray(d.entries)&&d.entries[0]?Number(d.entries[0].n)||0:0;
       let seen=0;try{seen=Number(localStorage.getItem('tl.news.seen'))||0}catch(_){}
       if(top>seen&&!/news\.html$/.test(location.pathname)){
         const link=panel.querySelector('a.tl-menu-link[href="./news.html"] .tl-menu-label');
         if(link&&!link.querySelector('.tl-menu-pill'))link.insertAdjacentHTML('beforeend',' <span class="tl-menu-pill">Neu</span>');
         trigger.classList.add('tl-has-news');
       }
     }catch(_){}
   })();
   const bottomItems=Array.from(document.querySelectorAll(atHome?'.bottom .nav':'.tl-global-bottom .tl-nav-item'));
  // Rollenbasierte Navigation: Admin-Eintrag + Dashboard fuehrt direkt zum eigenen Bereich.
  // Keine neue Abhaengigkeit: gleicher gepinnter Supabase-CDN Endpoint wie zuvor.
  const ROLE_NAV={
    admin:{href:'./admin.html',label:'Clubverwaltung',emoji:'🛡️'},
    coach:{href:'./coach.html',label:'Coach',emoji:'🧑‍🏫'},
    boxer:{href:'./boxer-experience.html',label:'Mein Takeover',emoji:'🥊'}
  };
  function applyDashboardLink(role){
    const target=ROLE_NAV[role];if(!target)return;
    const dashLinks=document.querySelectorAll('a.tl-dashboard-nav, a.dashboard-nav, .bottom .nav.dashboard-nav');
    dashLinks.forEach(el=>{
      const href=el.getAttribute('href');if(!href)return;
      if(href.includes('login.html')){
        el.setAttribute('href',target.href);
        el.setAttribute('aria-label',target.label+' oeffnen');
        el.innerHTML=emoji(target.emoji)+' '+target.label;
      }
    });
    if(role==='coach'||role==='admin'){
      const coachLink=panel.querySelector('a[href="./coach.html"]');
      if(coachLink) coachLink.classList.add('tl-current');
    }else if(role==='boxer'){
      const boxerLink=panel.querySelector('a[href="./boxer-experience.html"]');
      if(boxerLink) boxerLink.classList.add('tl-current');
    }
  }
  // Konto-Umschalter: seit Takeover 3.0 in takeover-account.js (Menü «Mein Account» der App-Shell).
  // Kein Eingriff in Storage.prototype mehr; gewechselt wird nur über die offizielle Supabase-API.
  async function resolveRoleLinks(){
    if(adminEntry) adminEntry.hidden=true;
    privateEntries.forEach(a=>a.hidden=true);
    try{
      const {createClient}=await import('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm');
      const db=createClient('https://iqarjivcrddcixrvqbfb.supabase.co','sb_publishable_o--Z21P8Q08lMvIOask_Fw__SRRX7_R',{auth:{autoRefreshToken:false,detectSessionInUrl:false}});
      const sess=await db.auth.getSession();if(!sess.data.session)return;
      const {data:{user},error}=await db.auth.getUser();if(error||!user)return;
      const p=await db.from('profiles').select('role,is_active,display_name').eq('auth_user_id',user.id).maybeSingle();
      if(p.error||!p.data||p.data.is_active!==true) return;
      const role=p.data.role; // p.data?.role==='admin' pattern kept for static compatibility
      if(role==='admin'&&adminEntry) adminEntry.hidden=false;
      privateEntries.forEach(anchor=>{
        const href=anchor.getAttribute('href');
        anchor.hidden=(role!=='boxer'&&href==='./boxer-experience.html') || !(['./boxer-experience.html','./boxer.html','./goals.html','./bewertung.html','./stil-test.html','./wochenplan.html','./quests.html','./shop.html','./roadmap.html','./kampfpfad.html','./praesenz.html','./checkin.html','./feedback.html','./karten.html','./mein-boxer.html'].includes(href.split('?')[0]) ||
          ((role==='admin'||role==='coach')&&['./coach.html','./league-manager.html'].includes(href)));
      });
      // static check sentinel: p.data?.role==='admin'
      if(ROLE_NAV[role]) applyDashboardLink(role);
      // PWA/start URL opens index.html. Boxer default home is now their experience;
      // explicit public sections (#ranking, #podium, #levels, #history) remain accessible.
      if(role==='boxer'&&atHome&&!location.hash){location.replace('./boxer-experience.html');return;}
      // Takeover 3.0: Trainer und Admins landen beim Öffnen der installierten App (nicht im Browser) in ihrem Bereich.
      const standalone=(window.matchMedia&&matchMedia('(display-mode: standalone)').matches)||navigator.standalone===true;
      if((role==='coach'||role==='admin')&&standalone&&atHome&&!location.hash){location.replace(ROLE_NAV[role].href);return;}
    }catch{
      if(adminEntry) adminEntry.hidden=true;
      privateEntries.forEach(a=>a.hidden=true);
    }
  }
  void resolveRoleLinks();
   let restoreFocus=null;
   let open=false;
   function setMenuGroupExpanded(group,expanded){
     if(!group)return;
     if(expanded){
       panel.querySelectorAll('.tl-menu-group').forEach(other=>{
         if(other===group)return;
         const toggle=other.querySelector('.tl-menu-group-toggle');
         const links=other.querySelector('.tl-menu-group-links');
         if(toggle)toggle.setAttribute('aria-expanded','false');
         if(links)links.hidden=true;
         other.classList.remove('tl-menu-group--open');
       });
     }
     const toggle=group.querySelector('.tl-menu-group-toggle');
     const links=group.querySelector('.tl-menu-group-links');
     if(!toggle||!links)return;
     toggle.setAttribute('aria-expanded',String(expanded));
     links.hidden=!expanded;
     group.classList.toggle('tl-menu-group--open',expanded);
   }
   function currentTab(){
     const hash=window.location.hash.substring(1);
     if(atHome && sections.has(hash))return hash;
     if(atHome){
       const current=Array.from(document.querySelectorAll('.page:not(.hidden)')).find(x=>sections.has(x.id));
       return current?current.id:'podium';
     }
     return null;
   }
   function syncCurrent(tab){
     menuEntries.forEach(anchor=>{
       const section=anchor.dataset.tlSection;
       const target=anchor.getAttribute('href').split('#')[0].replace(/^\.\//,'');
       const active=!!section&&atHome&&section===tab || !section&&target===page;
       anchor.classList.toggle('tl-current',active);
       if(active)anchor.setAttribute('aria-current','page');
       else anchor.removeAttribute('aria-current');
     });
     bottomItems.forEach(item=>{
       const tabname=item.dataset.tlTab||item.dataset.tab;
       const isMenu=item===trigger;
       const active=!!tabname&&atHome&&tabname===tab ||
         isMenu&&(open || atHome&&(tab==='levels'||tab==='history') || ['challenges.html','duels.html','awards.html','features.html','coming-soon.html','boxer-profile.html'].includes(page)) ||
         (item.classList.contains('tl-dashboard-nav')||item.classList.contains('dashboard-nav'))&&['login.html','boxer.html','boxer-experience.html','coach.html','admin.html'].includes(page) ||
         (item.getAttribute&&item.getAttribute('href')&&item.getAttribute('href').replace(/^\.\//,'')===page);
       item.classList.toggle(atHome?'active':'tl-active',!!active);
       if(active && item.tagName==='A')item.setAttribute('aria-current','page');
       else item.removeAttribute('aria-current');
     });
   }
   function toggleMenu(shouldOpen,focusBack=true){
     if(open===shouldOpen)return;
     open=shouldOpen;
     if(open)restoreFocus=document.activeElement;
     backdrop.hidden=!open;
     panel.inert=!open;
     panel.setAttribute('aria-hidden',open?'false':'true');
     trigger.setAttribute('aria-expanded',open?'true':'false');
     document.body.classList.toggle('tl-menu-visible',open);
     syncCurrent(currentTab());
     if(open){
       const current=menuEntries.find(anchor=>anchor.classList.contains('tl-current')&&!anchor.hidden);
       if(current)setMenuGroupExpanded(current.closest('.tl-menu-group'),true);
       close.focus();
     }else if(focusBack && restoreFocus && typeof restoreFocus.focus==='function')restoreFocus.focus();
   }
   trigger.addEventListener('click',()=>toggleMenu(!open));
   close.addEventListener('click',()=>toggleMenu(false));
   backdrop.addEventListener('click',()=>toggleMenu(false));
   panel.addEventListener('click',event=>{
     const groupToggle=event.target.closest('button.tl-menu-group-toggle');
     if(groupToggle){
       const group=groupToggle.closest('.tl-menu-group');
       setMenuGroupExpanded(group,groupToggle.getAttribute('aria-expanded')!=='true');
       return;
     }
     const anchor=event.target.closest('a.tl-menu-link');
     if(!anchor)return;
     const tab=anchor.dataset.tlSection;
     if(atHome && sections.has(tab)){
       event.preventDefault();
       if(typeof window.switchTab==='function')window.switchTab(tab);
       window.history.replaceState(null,'','#'+tab);
       toggleMenu(false,false);
       syncCurrent(tab);
     }
   });
   if(atHome){
     document.querySelectorAll('.bottom button.nav[data-tab]').forEach(button=>{
       button.addEventListener('click',()=>{
         // Existing event handler controls which league view is shown.
         window.history.replaceState(null,'','#'+button.dataset.tab);
         syncCurrent(button.dataset.tab);
       });
     });
     const startTab=window.location.hash.substring(1);
     if(sections.has(startTab)&&typeof window.switchTab==='function')window.switchTab(startTab);
     syncCurrent(sections.has(startTab)?startTab:currentTab());
     window.addEventListener('hashchange',()=>{
       const tab=window.location.hash.substring(1);
       if(sections.has(tab) && typeof window.switchTab==='function'){
         window.switchTab(tab);
         syncCurrent(tab);
       }
     });
   }else{
     syncCurrent(null);
   }
   document.addEventListener('keydown',event=>{
     if(!open)return;
     if(event.key==='Escape'){
       event.preventDefault();
       toggleMenu(false);
     }else if(event.key==='Tab'){
       const elements=Array.from(panel.querySelectorAll('button:not([disabled]), a[href]:not([hidden])')).filter(element=>!element.closest('[hidden]'));
       if(!elements.length)return;
       const first=elements[0],last=elements[elements.length-1];
       if(event.shiftKey&&document.activeElement===first){event.preventDefault();last.focus()}
       else if(!event.shiftKey&&document.activeElement===last){event.preventDefault();first.focus()}
     }
   });
 }
 if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});
 else start();
})();
