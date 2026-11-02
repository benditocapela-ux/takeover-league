(function(){
 'use strict';
 const el=(tag,text)=>{const n=document.createElement(tag);n.textContent=String(text??'');return n};
 window.TLPeriodClose={create({host,db,onClosed}){
  let epoch=0,period=null,actor=null,preview=null,busy=false,opener=null;
  const heading=el('h2','Trainerabschluss'),hint=el('p','Monat oder Saison zuerst prüfen. Die Vorschau speichert nichts.'),open=el('button','Abschlussvorschau öffnen');
  open.type='button';host.append(heading,hint,open);host.hidden=true;
  const dialog=el('dialog','');dialog.className='period-close-dialog';dialog.setAttribute('aria-label','Monat oder Saison abschliessen');
  const title=el('h2','Abschlussvorschau'),body=el('div',''),status=el('p',''),confirm=el('button','Ergebnis verbindlich abschliessen'),close=el('button','Schliessen');
  status.setAttribute('role','status');status.setAttribute('aria-live','polite');confirm.type=close.type='button';confirm.hidden=true;
  dialog.append(title,body,status,confirm,close);document.body.append(dialog);
  function dismiss(){epoch++;preview=null;busy=false;dialog.close();opener?.focus()}
  close.onclick=dismiss;dialog.addEventListener('cancel',e=>{e.preventDefault();dismiss()});
  function valid(p){return p&&p.version===1&&p.kind===period?.kind&&p.key===period?.key&&typeof p.title==='string'
   &&/^[a-f0-9]{32}$/.test(p.revision)&&Array.isArray(p.rows)&&p.rows.length<=20&&Array.isArray(p.blockers)
   &&Number.isSafeInteger(p.ranked_count)&&typeof p.can_close==='boolean'&&p.trainings&&Number.isSafeInteger(p.trainings.pending)
   &&p.reward?.additional_payout===false&&p.reward?.status==='not_configured'&&Array.isArray(p.reward?.planned_bookings)&&p.reward.planned_bookings.length===0}
  function show(p){
   if(!valid(p))throw Error('Die Abschlussvorschau ist unvollständig. Es wird nichts abgeschlossen.');
   preview=p;body.replaceChildren();title.textContent=(p.kind==='month'?'Monat ':'Saison ')+p.title;
   body.append(el('p',p.starts_on+' bis '+p.ends_on+' · Europe/Zurich'),
    el('p',p.trainings.approved+' bestätigte, '+p.trainings.pending+' offene und '+p.trainings.rejected+' abgelehnte Trainings.'),
    el('p','Ergebnis-EXP stammen aus vorhandenen Buchungen. Zusätzliche Belohnung noch nicht eingerichtet: Dieser Abschluss erzeugt keine neue Punkte-, EXP- oder Coin-Buchung.'),
    el('p',p.kind==='season'?'Bestehende Saisontitel für positive Top-3-Ergebnisse werden aus dem gespeicherten Endstand vergeben.':'Keine zusätzlichen Monatstitel eingerichtet.'));
   if(p.trainings.pending){const link=el('a','Offene Trainings im Trainerbereich prüfen');link.href='./coach.html';body.append(link)}
   for(const b of p.blockers)body.append(el('p',b.message||'Abschluss derzeit nicht möglich.'));
   const list=el('ol','');for(const r of p.rows){list.append(el('li',(r.points>0?'#'+r.rank_position:'Ohne Podiumsplatz')+' · '+r.boxer_name+' · '+r.points+' Punkte · '+r.exp+' EXP'))}body.append(list);
   body.append(el('p',p.rows.length+' von '+p.ranked_count+' Ergebnissen in dieser Vorschau. Die vollständige Rangliste steht im Archiv.'));
   confirm.hidden=!p.can_close;confirm.disabled=false;
   status.textContent=p.status==='closed'?'Bereits offiziell abgeschlossen.':p.can_close?'Vorschau gelesen? Erst die ausdrückliche Bestätigung speichert den endgültigen Stand.':'Noch nicht abschliessbar.';
  }
  async function sameActor(expected){const {data,error}=await db.auth.getUser();return !error&&data?.user?.id===expected}
  open.onclick=async()=>{
   if(busy||!period||!actor)return;const request=++epoch,expectedActor=actor,expectedPeriod={...period};busy=true;preview=null;confirm.hidden=true;body.replaceChildren();status.textContent='Lese Abschlussvorschau …';opener=open;dialog.showModal();
   try{if(!await sameActor(expectedActor))throw Error('Deine Sitzung hat sich geändert. Bitte den Zeitraum erneut laden.');
    if(request!==epoch||actor!==expectedActor)return;
    const {data,error}=await db.rpc('league_period_close_preview',{p_kind:expectedPeriod.kind,p_key:expectedPeriod.key});if(request!==epoch)return;
    if(error)throw Error(error.code==='PGRST202'?'Der sichere Periodenabschluss ist noch nicht freigegeben.':'Die Abschlussvorschau konnte nicht geladen werden.');show(data);
   }catch(e){if(request===epoch){preview=null;confirm.hidden=true;status.textContent=e.message}}
   finally{if(request===epoch)busy=false}
  };
  confirm.onclick=async()=>{
   if(busy||!preview?.can_close)return;const request=epoch,p=preview,expectedActor=actor;busy=true;confirm.disabled=true;status.textContent='Server prüft und speichert den Ergebnisabschluss …';
   try{if(!await sameActor(expectedActor))throw Error('Deine Sitzung hat sich geändert. Keine weitere Aktion wurde gesendet.');
    if(request!==epoch||actor!==expectedActor)return;
    const {data,error}=await db.rpc('league_period_close_confirm',{p_kind:p.kind,p_key:p.key,p_confirm:true,p_revision:p.revision});if(request!==epoch)return;
    if(error)throw Error('Kein Abschluss bestätigt. Bitte die Vorschau erneut öffnen; Wiederholungen sind serverseitig geschützt.');
    if(['changed','blocked'].includes(data?.status)){show(data.preview);status.textContent=data.status==='changed'?'Die Daten haben sich geändert. Prüfe die neue Vorschau und bestätige erneut.':'Offene Prüfungen oder Buchungsfehler blockieren den Abschluss.';return}
    if(data?.status!=='closed'||data.kind!==p.kind||data.key!==p.key||data.additional_payout!==false||!Array.isArray(data.bookings)||data.bookings.length)throw Error('Der Server hat keinen eindeutigen Ergebnisabschluss bestätigt. Bitte erneut prüfen.');
    preview=null;confirm.hidden=true;status.textContent=(data.unchanged?'Bereits gespeichert.':'Ergebnis offiziell gespeichert.')+' Keine zusätzliche Auszahlung.'+
     (Number.isSafeInteger(data.honor_count)?' '+data.honor_count+' gespeicherte Ehrungen.':'')+
     (Number.isSafeInteger(data.notification_count)?' '+data.notification_count+' Ergebnis-Mitteilungen.':'');
    // Reload public snapshot without closing the explicit server receipt.
    onClosed?.(p.kind,p.key);
   }catch(e){if(request===epoch)status.textContent=e.message}
   finally{if(request===epoch){busy=false;confirm.disabled=false}}
  };
  return {async setPeriod(kind,key){
   const request=++epoch;period={kind,key};host.hidden=true;preview=null;actor=null;busy=false;if(dialog.open)dialog.close();
   try{const {data,error}=await db.auth.getUser();if(error||!data?.user)return;const user=data.user.id;
    const {data:profile,error:failure}=await db.from('profiles').select('role,is_active,archived_at').eq('auth_user_id',user).maybeSingle();
    if(request!==epoch||failure||!profile?.is_active||profile.archived_at||!['coach','admin'].includes(profile.role))return;
    actor=user;host.hidden=false;
   }catch(_){/* A public archive stays readable without staff access. */}
  },clear(){epoch++;actor=null;period=null;preview=null;busy=false;host.hidden=true;if(dialog.open)dialog.close()}};
 }};
})();
