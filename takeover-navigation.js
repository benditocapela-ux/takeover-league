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
     const match=rules.find(([pattern])=>pattern.test(text));
     if(!match)return;
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
   // Single shared drawer. The home page supplies its existing four-item footer.
   const entries=[
     ['🏆 Liga & Erfolge',[
       ['trophy','Podium','index.html#podium','podium'],
       ['chart','Monatsranking','index.html#ranking','ranking'],
       ['boxing-glove','Levels & EXP','index.html#levels','levels'],
       ['scroll','Punkteverlauf','index.html#history','history'],
       ['medal','Monatsauszeichnungen','awards.html',''],
       ['scale','Boxer-Vergleich','boxer-compare.html',''],
       ['trophy','Saisons & Hall of Fame','league-history.html','']
     ]],
     ['🥊 Kämpfe & Herausforderungen',[
       ['boxing-glove','Duell starten','duels.html','',true],
       ['arena','Mehrgegner-Arena','arena.html','',true],
       ['bolt','Liga-Challenges','league-challenges.html','',true],
       ['target','Challenges verwalten','challenges.html','',true]
     ]],
     ['👤 Mein Bereich',[
       ['user','Anmelden / Mein Account','login.html',''],
       ['dumbbell','Mein Training','boxer.html',''],
       ['target','Meine Ziele','goals.html',''],
       ['medal','Trainer-Dashboard','coach.html',''],
       ['goal','League Manager 2.1','league-manager.html',''],
       ['user','Clubverwaltung','admin.html','',false,true]
     ]]
   ];
   const contents=entries.map((group,index)=>
     '<details class="tl-menu-group"'+(index===1?' open':'')+'>'+
     '<summary class="tl-menu-group-title"><span>'+group[0]+'</span><span class="tl-menu-group-chevron" aria-hidden="true">⌄</span></summary>'+
     '<div class="tl-menu-group-items">'+
     group[1].map(item=>
       '<a class="tl-menu-link" href="./'+item[2]+'"'+(item[3]?' data-tl-section="'+item[3]+'"':'')+(item[5]?' data-tl-admin hidden':'')+(['boxer.html','goals.html','coach.html','league-manager.html'].includes(item[2])?' data-tl-private hidden':'')+'>'+
         '<span class="tl-menu-icon" aria-hidden="true">'+emoji(item[0])+'</span>'+
         '<span class="tl-menu-label">'+item[1]+(item[4]?' <span class="tl-menu-pill">2.0</span>':'')+'</span>'+
         '<span class="tl-menu-arrow" aria-hidden="true">↗</span>'+
       '</a>').join('')+'</div></details>').join('');
   document.body.insertAdjacentHTML('beforeend',
      '<div id="tl-menu-backdrop" class="tl-menu-backdrop" hidden aria-hidden="true"></div>'+
      '<aside id="tl-menu-panel" class="tl-menu-panel" role="dialog" aria-modal="true" aria-label="Alle Takeover League Bereiche" aria-hidden="true" inert>'+
      '<div class="tl-menu-head"><div><div class="tl-menu-overline">TAKEOVER LEAGUE 2.0</div><div class="tl-menu-title">'+emoji('menu')+' Alle Bereiche</div></div>'+
      '<button type="button" class="tl-menu-close" id="tl-menu-close" aria-label="Menü schliessen">×</button></div>'+
      '<p class="tl-menu-intro">Gleiche Liga. Alle Funktionen an einem Ort.</p>'+
      contents+
      '<div class="tl-menu-foot">Deine Punkte, Ranglisten und Trainings bleiben erhalten.</div></aside>');
   const panel=document.getElementById('tl-menu-panel');
   const backdrop=document.getElementById('tl-menu-backdrop');
   const close=document.getElementById('tl-menu-close');
   const menuEntries=Array.from(panel.querySelectorAll('a.tl-menu-link'));
   const adminEntry=panel.querySelector('a[data-tl-admin]');
   const privateEntries=Array.from(panel.querySelectorAll('a[data-tl-private]'));
   const bottomItems=Array.from(document.querySelectorAll(atHome?'.bottom .nav':'.tl-global-bottom .tl-nav-item'));
  // Rollenbasierte Navigation: Admin-Eintrag + Dashboard fuehrt direkt zum eigenen Bereich.
  // Keine neue Abhaengigkeit: gleicher gepinnter Supabase-CDN Endpoint wie zuvor.
  const ROLE_NAV={
    admin:{href:'./admin.html',label:'Clubverwaltung',emoji:'🛡️'},
    coach:{href:'./coach.html',label:'Coach',emoji:'🧑‍🏫'},
    boxer:{href:'./boxer.html',label:'Mein Studio',emoji:'🥊'}
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
      const boxerLink=panel.querySelector('a[href="./boxer.html"]');
      if(boxerLink) boxerLink.classList.add('tl-current');
    }
  }
  async function resolveRoleLinks(){
    if(adminEntry) adminEntry.hidden=true;
    privateEntries.forEach(a=>a.hidden=true);
    try{
      const {createClient}=await import('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm');
      const db=createClient('https://iqarjivcrddcixrvqbfb.supabase.co','sb_publishable_o--Z21P8Q08lMvIOask_Fw__SRRX7_R');
      const sess=await db.auth.getSession();if(!sess.data.session)return;
      const {data:{user},error}=await db.auth.getUser();if(error||!user)return;
      const p=await db.from('profiles').select('role,is_active').eq('auth_user_id',user.id).maybeSingle();
      if(p.error||!p.data||p.data.is_active!==true) return;
      const role=p.data.role; // p.data?.role==='admin' pattern kept for static compatibility
      if(role==='admin'&&adminEntry) adminEntry.hidden=false;
      privateEntries.forEach(anchor=>{
        const href=anchor.getAttribute('href');
        anchor.hidden=!(['./boxer.html','./goals.html'].includes(href) ||
          ((role==='admin'||role==='coach')&&['./coach.html','./league-manager.html'].includes(href)));
      });
      // static check sentinel: p.data?.role==='admin'
      if(ROLE_NAV[role]) applyDashboardLink(role);
    }catch{
      if(adminEntry) adminEntry.hidden=true;
      privateEntries.forEach(a=>a.hidden=true);
    }
  }
  void resolveRoleLinks();
   let restoreFocus=null;
   let open=false;
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
         (item.classList.contains('tl-dashboard-nav')||item.classList.contains('dashboard-nav'))&&['login.html','boxer.html','coach.html','admin.html'].includes(page) ||
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
     if(open)close.focus();
     else if(focusBack && restoreFocus && typeof restoreFocus.focus==='function')restoreFocus.focus();
   }
   trigger.addEventListener('click',()=>toggleMenu(!open));
   close.addEventListener('click',()=>toggleMenu(false));
   backdrop.addEventListener('click',()=>toggleMenu(false));
   panel.addEventListener('click',event=>{
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
       const elements=Array.from(panel.querySelectorAll('button:not([disabled]), a[href]:not([hidden])'));
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
