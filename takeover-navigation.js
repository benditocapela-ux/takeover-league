/* Shared, dependency-free Takeover League navigation.
   Injected into every publicly deployed HTML page, with no auth or data mutations. */
(function(){
 'use strict';
 const sections=new Set(['podium','ranking','levels','history']);
 function start(){
   if(document.getElementById('tl-menu-panel'))return;
   const pathname=window.location.pathname;
   const page=pathname.substring(pathname.lastIndexOf('/')+1)||'index.html';
   const atHome=page==='index.html';
   const footerMarkup='<nav class="tl-global-bottom" aria-label="Takeover League Navigation"><div class="tl-global-nav-items">'+
     '<a class="tl-nav-item" data-tl-tab="podium" href="./index.html#podium">🏆 Podium</a>'+
     '<a class="tl-nav-item" data-tl-tab="ranking" href="./index.html#ranking">📊 Ranking</a>'+
     '<button type="button" class="tl-nav-item" id="takeover-menu-open" aria-controls="tl-menu-panel" aria-haspopup="dialog" aria-expanded="false">☰ Menü</button>'+
     '<a class="tl-nav-item tl-dashboard-nav" href="./login.html">👤 Dashboard</a>'+
     '</div></nav>';
   if(!atHome){
     document.body.classList.add('tl-global-nav-page');
     document.body.insertAdjacentHTML('beforeend',footerMarkup);
   }
   const trigger=document.getElementById('takeover-menu-open');
   if(!trigger)return;
   // Single shared drawer. The home page supplies its existing four-item footer.
   const entries=[
     ['Die Liga',[
       ['🏆','Podium','index.html#podium','podium'],
       ['📊','Monatsranking','index.html#ranking','ranking'],
       ['🥊','Levels & EXP','index.html#levels','levels'],
       ['📜','Punkteverlauf','index.html#history','history'],
       ['🏅','Monatsauszeichnungen','awards.html',''],
       ['⚖️','Boxer-Vergleich','boxer-compare.html',''],
       ['🏆','Saisons & Hall of Fame','league-history.html','']
     ]],
     ['Neue Funktionen',[
       ['🎯','Challenges','challenges.html','',true],
       ['⚡','Liga-Challenges','league-challenges.html','',true],
       ['🥊','Boxer-Duelle','duels.html','',true]
     ]],
     ['Mein Bereich',[
       ['👤','Anmelden / Mein Account','login.html',''],
       ['💪','Mein Training','boxer.html',''],
       ['🎯','Meine Ziele','goals.html',''],
       ['🥇','Trainer-Dashboard','coach.html','']
     ]]
   ];
   const contents=entries.map(group=>
     '<div class="tl-menu-group"><div class="tl-menu-group-title">'+group[0]+'</div>'+
     group[1].map(item=>
       '<a class="tl-menu-link" href="./'+item[2]+'"'+(item[3]?' data-tl-section="'+item[3]+'"':'')+'>'+
         '<span class="tl-menu-icon" aria-hidden="true">'+item[0]+'</span>'+
         '<span class="tl-menu-label">'+item[1]+(item[4]?' <span class="tl-menu-pill">2.0</span>':'')+'</span>'+
         '<span class="tl-menu-arrow" aria-hidden="true">↗</span>'+
       '</a>').join('')+'</div>').join('');
   document.body.insertAdjacentHTML('beforeend',
      '<div id="tl-menu-backdrop" class="tl-menu-backdrop" hidden aria-hidden="true"></div>'+
      '<aside id="tl-menu-panel" class="tl-menu-panel" role="dialog" aria-modal="true" aria-label="Alle Takeover League Bereiche" aria-hidden="true" inert>'+
      '<div class="tl-menu-head"><div><div class="tl-menu-overline">TAKEOVER LEAGUE 2.0</div><div class="tl-menu-title">☰ Alle Bereiche</div></div>'+
      '<button type="button" class="tl-menu-close" id="tl-menu-close" aria-label="Menü schliessen">×</button></div>'+
      '<p class="tl-menu-intro">Gleiche Liga. Alle Funktionen an einem Ort.</p>'+
      contents+
      '<div class="tl-menu-foot">Deine Punkte, Ranglisten und Trainings bleiben erhalten.</div></aside>');
   const panel=document.getElementById('tl-menu-panel');
   const backdrop=document.getElementById('tl-menu-backdrop');
   const close=document.getElementById('tl-menu-close');
   const menuEntries=Array.from(panel.querySelectorAll('a.tl-menu-link'));
   const bottomItems=Array.from(document.querySelectorAll(atHome?'.bottom .nav':'.tl-global-bottom .tl-nav-item'));
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
         item.classList.contains('tl-dashboard-nav')&&['login.html','boxer.html','coach.html'].includes(page);
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
       const elements=Array.from(panel.querySelectorAll('button:not([disabled]), a[href]'));
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
