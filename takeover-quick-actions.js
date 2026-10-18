/* Takeover League 2.0 – accessible context actions; navigational shortcuts only.
 * Never bypasses role, RLS, confirmation or server-side mutation checks. */
(function(){
 'use strict';
 const page=(location.pathname.split('/').pop()||'index.html');
 const menus={
  'boxer.html':[['＋ Training eintragen','#trainingFormCard'],['⏳ Offene Trainings','#boxerTaskCenter'],['📅 Trainingskalender','#trainingInsights'],['🎯 Challenges','./challenges.html'],['🥊 Duelle','./duels.html'],['🏅 Ranking','./index.html#ranking']],
  'coach.html':[['⏳ Offene Trainings','#coachBulkControls'],['📋 Trainings bearbeiten','#allEntries'],['📜 Änderungshistorie','#coachAuditSection'],['🎯 Challenges vergeben','./challenges.html'],['🥊 Duelle','./duels.html']],
  'challenges.html':[['🔄 Challenge-Liste','#list'],['＋ Coach-Challenge','#coach'],['🥊 Duelle','./duels.html'],['💪 Mein Training','./boxer.html']],
  'duels.html':[['＋ Duell einladen','#invitePanel'],['📋 Meine Duelle','#duelList'],['🎯 Challenges','./challenges.html'],['💪 Mein Training','./boxer.html']]
 };
 if(!menus[page])return;
 const css=document.createElement('style');
 css.textContent='.tl-quick-open{position:fixed;right:14px;bottom:calc(83px + env(safe-area-inset-bottom));z-index:1020;min-height:46px;padding:9px 16px;border:1px solid #dfbd77;border-radius:999px;background:#dfbd77;color:#101827;font-weight:750;box-shadow:0 7px 30px #0007}.tl-quick-dialog{background:#142238;color:#f4f5f7;border:1px solid #63738b;border-radius:18px;padding:18px;width:min(430px,calc(100% - 28px));max-height:80vh;overflow:auto}.tl-quick-dialog::backdrop{background:#000b}.tl-quick-links{display:grid;gap:9px}.tl-quick-links a{padding:12px 14px;border:1px solid #51657c;border-radius:11px;color:#f4f5f7;text-decoration:none;min-height:44px}.tl-quick-head{display:flex;align-items:center;justify-content:space-between;margin-bottom:14px;gap:14px}.tl-quick-head h2{margin:0;font-size:19px}.tl-quick-close{min-height:44px;min-width:44px;border:1px solid #708197;border-radius:10px;background:#20334c;color:#fff}@media(max-width:700px){.tl-quick-dialog{margin:auto 0 0;width:100%;max-width:none;max-height:80vh;border-radius:20px 20px 0 0;padding-bottom:max(24px,env(safe-area-inset-bottom))}}';
 document.head.append(css);
 const button=document.createElement('button');button.type='button';button.className='tl-quick-open';button.textContent='⚡ Schnellaktionen';button.setAttribute('aria-haspopup','dialog');
 const dialog=document.createElement('dialog');dialog.className='tl-quick-dialog';dialog.setAttribute('aria-labelledby','tlQuickTitle');
 const heading=document.createElement('div');heading.className='tl-quick-head';
 const title=document.createElement('h2');title.id='tlQuickTitle';title.textContent='Wohin möchtest du?';
 const close=document.createElement('button');close.className='tl-quick-close';close.type='button';close.textContent='✕';close.setAttribute('aria-label','Schnellaktionen schliessen');
 heading.append(title,close);const links=document.createElement('nav');links.className='tl-quick-links';links.setAttribute('aria-label','Kontextabhängige Schnellaktionen');
 for(const [text,href] of menus[page]){
  const a=document.createElement('a');a.textContent=text;a.href=href;
  if(href.startsWith('#')){
   const target=document.getElementById(href.slice(1));
   if(!target)continue;
   a.dataset.tlTarget=href.slice(1);
   a.addEventListener('click',e=>{e.preventDefault();dialog.close();target.scrollIntoView({behavior:'smooth',block:'start'});const input=target.querySelector('input:not([disabled]),select:not([disabled]),button:not([disabled])');if(input)input.focus({preventScroll:true})});
  }
  links.append(a);
 }
 dialog.append(heading,links);document.body.append(button,dialog);
 const open=()=>{
  for(const a of links.querySelectorAll('a[data-tl-target]')){
   const target=document.getElementById(a.dataset.tlTarget);
   a.hidden=!target||!target.getClientRects().length||!!target.closest('[hidden]');
  }
  if(!dialog.open)dialog.showModal();
 };
 button.addEventListener('click',open);close.addEventListener('click',()=>dialog.close());
 dialog.addEventListener('click',e=>{if(e.target===dialog)dialog.close()});
 document.addEventListener('keydown',e=>{if((e.ctrlKey||e.metaKey)&&e.key.toLowerCase()==='k'&&!e.altKey){
  const tag=document.activeElement?.tagName;if(['INPUT','TEXTAREA'].includes(tag))return;
  e.preventDefault();open();
 }});
})();
