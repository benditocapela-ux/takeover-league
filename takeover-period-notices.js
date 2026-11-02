// Personal period notices; server owns eligibility, period state and dismissal.
export async function mountPeriodNotices({db,hosts}){
 const targets=hosts.filter(Boolean);if(!targets.length)return {refresh(){}};
 const node=(tag,text)=>{const e=document.createElement(tag);e.textContent=String(text??'');return e};
 let epoch=0,actor=null,items=[];
 function clear(){for(const h of targets){h.replaceChildren();h.hidden=true}items=[]}
 function valid(n){return n&&['month','season'].includes(n.kind)&&['awaiting_close','closed'].includes(n.phase)&&typeof n.title==='string'
  &&(n.kind==='month'?/^\d{4}-(0[1-9]|1[0-2])$/:/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i).test(n.period_key)
  &&n.event_key==='period:'+n.kind+':'+n.period_key+':'+n.phase&&n.result_path==='league-history.html?'+n.kind+'='+n.period_key}
 function render(){for(const host of targets){host.replaceChildren();host.hidden=!items.length;for(const n of items){
  const card=node('article','');card.className='ex-card tl-period-notice';card.style.cssText='padding:16px;margin:12px 0;border:1px solid var(--gold,#f2c14e);border-radius:12px;overflow-wrap:anywhere';
  const label=n.kind==='month'?new Date(n.period_key+'-01T12:00:00Z').toLocaleDateString('de-CH',{month:'long',year:'numeric'}):n.title;
  card.append(node('strong',label+(n.phase==='closed'?' abgeschlossen – Ergebnis ansehen':' beendet – Auswertung läuft')));
  const p=node('p',n.phase==='closed'?'Der offizielle Endstand ist gespeichert.':'Dieser Rückblick ist noch kein offizieller Endstand.');card.append(p);
  const link=node('a',n.phase==='closed'?'Ergebnis ansehen':'Rückblick ansehen');link.href='./'+n.result_path;link.className='ex-btn ex-btn-ghost';link.style.cssText='display:inline-flex;align-items:center;min-height:44px;padding:8px 12px';
  const dismiss=node('button','Hinweis schliessen');dismiss.type='button';dismiss.className='ex-btn ex-btn-ghost';dismiss.style.cssText='min-height:44px;margin:4px;padding:8px 12px';
  dismiss.onclick=async()=>{
   const request=epoch,expected=actor;dismiss.disabled=true;
   try{const {data,error}=await db.auth.getUser();if(request!==epoch||actor!==expected)return;if(error||data?.user?.id!==expected)throw Error('Bitte erneut anmelden.');
    const r=await db.rpc('league_period_notice_dismiss',{p_event_key:n.event_key});if(request!==epoch)return;
    if(r.error||r.data!==true)throw Error('Der Hinweis konnte nicht gespeichert werden. Bitte erneut versuchen.');
    items=items.filter(x=>x.event_key!==n.event_key);render();document.dispatchEvent(new Event('takeover:notice-read'));
   }catch(e){if(request===epoch){p.textContent=e.message;dismiss.disabled=false}}
  };card.append(link,dismiss);host.append(card);
 }}}
 async function refresh(){const request=++epoch;clear();actor=null;
  try{const {data,error}=await db.auth.getUser();if(request!==epoch||error||!data?.user)return;const expected=data.user.id;
   const r=await db.rpc('league_period_notices');if(request!==epoch)return;
   if(r.error||r.data?.version!==1||!Array.isArray(r.data.items)||r.data.items.length>4||!r.data.items.every(valid))return;
   actor=expected;items=r.data.enabled===true?r.data.items:[];render();
  }catch(_){/* Missing release API does not claim a period has closed. */}
 }
 db.auth.onAuthStateChange?.((event)=>{if(['SIGNED_IN','SIGNED_OUT','USER_UPDATED'].includes(event)){epoch++;actor=null;clear();setTimeout(refresh,0)}});
 document.addEventListener('visibilitychange',()=>{if(!document.hidden)refresh()});
 await refresh();return {refresh};
}
