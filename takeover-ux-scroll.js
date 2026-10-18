/* Takeover League 2.0 – session-only scroll restoration. No personal data. */
(function(){
'use strict';
const key='takeover-scroll:'+location.pathname+location.search+location.hash;
function save(){try{sessionStorage.setItem(key,String(Math.max(0,window.scrollY)))}catch{}}
window.addEventListener('pagehide',save,{passive:true});
try{
 const nav=performance.getEntriesByType?.('navigation')?.[0];
 if(nav?.type==='back_forward'){
  const y=Number(sessionStorage.getItem(key));
  if(Number.isFinite(y)&&y>0){
   let cancelled=false;const cancel=()=>{cancelled=true};
   window.addEventListener('wheel',cancel,{once:true,passive:true});
   window.addEventListener('touchstart',cancel,{once:true,passive:true});
   const restore=()=>{if(!cancelled)window.scrollTo({top:y,behavior:'instant'})};
   window.addEventListener('load',restore,{once:true});
   setTimeout(restore,550);setTimeout(restore,1250);
  }
 }
}catch{}
if(location.pathname.endsWith('/index.html')||location.pathname.endsWith('/takeover-league/')){
 const original=window.switchTab;
 if(typeof original==='function'){
  const positions=new Map();
  window.switchTab=function(tab){
   const existing=document.querySelector('.page:not(.hidden)');
   if(existing)positions.set(existing.id,window.scrollY);
   original(tab);
   const saved=positions.get(tab);
   if(Number.isFinite(saved))requestAnimationFrame(()=>window.scrollTo(0,saved));
  };
 }
}
})();