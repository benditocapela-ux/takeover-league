/* Boxer Experience in-app subviews. Standalone original pages retain their own
 * RPCs, access checks, validation and form submission. No duplicated training writes. */
(function(){
 'use strict';
 const doc=document;
 const app=doc.getElementById('ex-app');
 const shell=doc.getElementById('ex-flow');
 const frame=doc.getElementById('ex-flow-frame');
 const main=app?.querySelector('.ex-main');
 const tabs=app?.querySelector('.ex-menu');
 const back=doc.getElementById('ex-flow-back');
 const label=doc.getElementById('ex-flow-title');
 const progress=doc.getElementById('ex-flow-loading');
 const fallback=doc.getElementById('ex-flow-direct');
 if(!app||!shell||!frame||!main||!tabs||!back||!label||!progress||!fallback)return;
 const allowed=new Set([
  'boxer.html','checkin.html','wochenplan.html','goals.html','praesenz.html',
  'duels.html','league-challenges.html','challenges.html','arena.html','quests.html',
  'index.html','boxer-compare.html','awards.html','league-history.html',
  'stil-test.html','mein-boxer.html','shop.html','karten.html',
  'bewertung.html','kampfpfad.html','roadmap.html','feedback.html','hilfe.html',
  'boxer-profile.html','news.html','features.html'
 ]);
 const root=new URL('./',location.href);
 let opened=false;
 let currentUrl=null;
 let cssSeq=0;

 function resolve(raw){
  if(!raw||raw.startsWith('#')||/^(mailto:|tel:|javascript:)/i.test(raw))return null;
  let url;try{url=new URL(raw,location.href)}catch(_){return null}
  if(url.origin!==location.origin||!url.pathname.startsWith(root.pathname))return null;
  if(!allowed.has(url.pathname.split('/').pop()))return null;
  return url;
 }
 function titleFor(url,defaultText){
  const page=url.pathname.split('/').pop();
  const titles={
   'boxer.html':'Training erfassen','checkin.html':'Vereinstraining & Check-in',
   'wochenplan.html':'Wochenplan','goals.html':'Meine Ziele','praesenz.html':'Präsenz',
   'duels.html':'Duelle','league-challenges.html':'Live-Challenges',
   'challenges.html':'Challenges','arena.html':'Arena','quests.html':'Wochen-Quests',
   'index.html':'Liga & Ranking','boxer-compare.html':'Boxer-Vergleich',
   'awards.html':'Auszeichnungen','league-history.html':'Hall of Fame',
   'stil-test.html':'Boxstil-Test','mein-boxer.html':'Boxer gestalten',
   'shop.html':'Kampfgeist-Shop','karten.html':'Spielerkarten',
   'bewertung.html':'Bewertung','kampfpfad.html':'Kampfpfad',
   'roadmap.html':'Level-Roadmap','feedback.html':'Feedback','hilfe.html':'Hilfe',
   'boxer-profile.html':'Boxerprofil','news.html':'Neuigkeiten','features.html':'Funktionen'
  };
  return titles[page]||defaultText||'Takeover';
 }
 function setStatus(message,err){
  progress.hidden=!message;
  progress.textContent=message||'';
  progress.dataset.error=err?'true':'false';
 }
 function setParent(open){
  opened=open;
  shell.hidden=!open;
  main.hidden=open;
  // Preserve original five-tab footer at all times. Close via any tab.
  tabs.dataset.flow=open?'open':'closed';
  if(!open){
   frame.style.visibility='hidden';
   frame.removeAttribute('src'); // stop network / avoid outdated role state
   currentUrl=null;
   doc.dispatchEvent(new CustomEvent('takeover:flow-closed'));
  }
 }
 function openFlow(url,description){
  const path=url.pathname.split('/').pop();
  if(path==='boxer.html'&&!url.hash)url.hash='#trainingFormCard';
  currentUrl=url;
  label.textContent=titleFor(url,description);
  fallback.href=url.href;
  setStatus('Bereich wird geöffnet …',false);
  setParent(true);
  frame.style.visibility='hidden';
  frame.src=url.href;
  back.focus({preventScroll:true});
 }
 function closeFlow(){
  if(!opened)return;
  setParent(false);
  const tab=app.querySelector('.ex-menu [data-tab][aria-current="page"]');
  if(tab)tab.focus({preventScroll:true});
 }
 function themedFrame(){
  if(!opened)return;
  const seq=++cssSeq;
  try{
   const win=frame.contentWindow,child=win.document;
   if(win.location.origin!==location.origin)throw Error('Diese externe Seite kann nicht eingebettet werden.');
   const page=win.location.pathname.split('/').pop();
   if(page==='login.html'){
    location.assign('./login.html?next=boxer-experience.html');
    return;
   }
   if(page==='boxer-experience.html'){closeFlow();return}
   if(!allowed.has(page))throw Error('Dieser Bereich wird ausserhalb der Boxer-App geöffnet.');
   const body=child.body;
   if(!body||!child.head)throw Error('Seite nicht vollständig geladen.');
   body.classList.add('tl-ex-embedded');
   if(page==='boxer.html')body.classList.add('tl-ex-training');
   const style=child.createElement('link');
   style.rel='stylesheet';style.href=new URL('./takeover-boxer-embedded-flow.css',root).href;
   let finished=false;
   const ready=()=>{
    if(finished||seq!==cssSeq||!opened)return;
    finished=true;
    // Navigation within the iframe is allowed for the same origin. Every new
    // page load is re-themed and never escapes to the old fullscreen shell.
    frame.style.visibility='visible';
    const newUrl=new URL(win.location.href);
    currentUrl=newUrl;
    label.textContent=titleFor(newUrl);
    fallback.href=newUrl.href;
    setStatus('',false);
    if(page==='boxer.html'){
     // Avoid focus/scrolling to the old dashboard: show only the canonical form.
     body.scrollTop=0;child.documentElement.scrollTop=0;
    }
   };
   style.addEventListener('load',ready,{once:true});
   style.addEventListener('error',()=>setStatus('Darstellung konnte nicht vollständig geladen werden.',true),{once:true});
   child.head.append(style);
   // The stylesheet can resolve synchronously from cache; onload still fires.
  }catch(error){
   setStatus('Dieser Bereich konnte nicht innerhalb der App geöffnet werden. '+String(error.message||error),true);
   frame.style.visibility='hidden';
  }
 }
 frame.addEventListener('load',themedFrame);
 frame.addEventListener('error',()=>setStatus('Der Bereich konnte nicht geladen werden. Du kannst ihn direkt öffnen.',true));
 back.addEventListener('click',closeFlow);
 doc.addEventListener('keydown',event=>{
  if(event.key==='Escape'&&opened&&!doc.getElementById('ex-drawer')?.hidden)return;
  if(event.key==='Escape'&&opened){event.preventDefault();closeFlow()}
 });
 doc.addEventListener('click',event=>{
  const target=event.target;
  if(!(target instanceof Element))return;
  // Changing the active 5-tab context closes the nested flow.
  const tab=target.closest('[data-tab],[data-open-tab]');
  if(tab&&opened){closeFlow();return}
  const a=target.closest('a[href]');
  if(!a||!a.closest('#ex-app,#ex-drawer'))return;
  if(a.closest('#ex-flow'))return;
  if(event.defaultPrevented||event.button!==0||event.ctrlKey||event.metaKey||event.altKey||event.shiftKey||a.hasAttribute('download')||a.target&&a.target!=='_self')return;
  const url=resolve(a.getAttribute('href'));
  if(!url)return; // external, auth/account or unsupported routes work as before
  event.preventDefault();
  const drawer=doc.getElementById('ex-drawer');
  if(drawer&&!drawer.hidden){drawer.hidden=true;doc.getElementById('ex-settings')?.setAttribute('aria-expanded','false')}
  openFlow(url,(a.textContent||'').trim());
 },true);
})();
