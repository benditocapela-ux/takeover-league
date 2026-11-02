/* Staff-only duel closure view. RPCs remain the sole scoring and reward authority. */
(function(global){
 'use strict';
 const integer=value=>Number.isSafeInteger(value);
 const nonnegative=value=>integer(value)&&value>=0;
 const missing=error=>['PGRST202','42883'].includes(error?.code)||/could not find the function|does not exist/i.test(String(error?.message||''));
 function validatePreview(value,duel){
  if(!value||value.duel_id!==duel.id||!['active','awaiting_reviews','settled'].includes(value.status)||value.provisional!==true||typeof value.revision!=='string'||!value.revision.trim())return false;
  if(typeof value.can_close!=='boolean'||typeof value.can_correct!=='boolean'||value.can_close&&value.can_correct||!Array.isArray(value.blockers)||!Array.isArray(value.rewards))return false;
  const metric=value.rule?.metric,isMetric=metric==='jogging_km'||metric==='training_count',none=value.rule?.reward_rule==='none';
  if(isMetric){if(!global.TLDuelMetrics?.validRule(value.rule)||value.rule.end_exclusive!==true)return false}
  else if(metric!=='points'||value.rule.unit!=='Trainingspunkte'||value.rule.timezone!=='Europe/Zurich'||value.rule.time_rule!=='legacy_inclusive_zurich_dates'||!['legacy_v2','rank_snapshot_v21','ranked_v21'].includes(value.rule.reward_rule))return false;
  if(value.rule?.version===3&&!global.TLDuelMetrics?.validRule(value.rule))return false;
  if(duel.rule?.version===3&&['version','metric','unit','timezone','time_rule','reward_rule','visibility','training_type_id','training_type_name'].some(key=>(duel.rule[key]??null)!==(value.rule[key]??null)))return false;
  const validScore=n=>isMetric?typeof n==='number'&&Number.isFinite(n)&&n>=0&&(metric!=='training_count'||integer(n)):nonnegative(n);
  if(!value.starts_at||!value.ends_at||!Number.isFinite(Date.parse(value.starts_at))||!Number.isFinite(Date.parse(value.ends_at)))return false;
  const scores=value.scores;
  if(!scores||!['pending','approved','rejected'].every(key=>nonnegative(scores[key]))||!['challenger_score','opponent_score'].every(key=>scores[key]===null||validScore(scores[key])))return false;
  if(value.blockers.some(row=>!row||typeof row.code!=='string'||typeof row.message!=='string'))return false;
  const participants=[duel.challenger_id,duel.opponent_id];
  if(!participants.every(id=>typeof id==='string'&&id)||participants[0]===participants[1])return false;
  if(value.winner_id!==null&&!participants.includes(value.winner_id))return false;
  if(value.tie!==null&&typeof value.tie!=='boolean')return false;
  if(new Set(value.rewards.map(row=>row?.boxer_id)).size!==value.rewards.length)return false;
  if(value.rewards.some(row=>!row||!participants.includes(row.boxer_id)||!['planned_exp','booked_exp','delta_exp'].every(key=>row[key]===null||integer(row[key]))||(row.transaction_id!==null&&typeof row.transaction_id!=='string')))return false;
  if(none&&value.rewards.some(row=>row.transaction_id!==null||['planned_exp','booked_exp','delta_exp'].some(key=>row[key]!==null&&row[key]!==0)))return false;
  if(value.can_close||value.can_correct){
   if(value.blockers.length||scores.pending||value.rewards.length!==2||scores.challenger_score===null||scores.opponent_score===null)return false;
   if(value.rewards.some(row=>!['planned_exp','booked_exp','delta_exp'].every(key=>integer(row[key]))))return false;
   if(value.rewards.some(row=>row.delta_exp!==row.planned_exp-row.booked_exp))return false;
   if(value.tie!==(scores.challenger_score===scores.opponent_score))return false;
   const expected=value.tie?null:(scores.challenger_score>scores.opponent_score?duel.challenger_id:duel.opponent_id);
   if(value.winner_id!==expected)return false;
  }
  return true;
 }
 function create({dialog,rpc,getActor,getEpoch,onClosed,verifyActor}){
  let request=0,selection=null,preview=null,busy=false,opener=null;
  const doc=dialog.ownerDocument;
  const node=(tag,text,cls)=>{const el=doc.createElement(tag);el.textContent=String(text??'');if(cls)el.className=cls;return el};
  const title=dialog.querySelector('[data-close-title]'),body=dialog.querySelector('[data-close-body]'),status=dialog.querySelector('[data-close-status]'),confirm=dialog.querySelector('[data-close-confirm]'),refresh=dialog.querySelector('[data-close-refresh]'),dismiss=dialog.querySelector('[data-close-dismiss]');
  const staff=()=>['coach','admin'].includes(getActor()?.role);
  const validRequest=(id,epoch)=>id===request&&epoch===getEpoch()&&staff();
  const say=(text,bad=false)=>{status.textContent=text;status.classList.toggle('error',bad)};
  const exp=n=>n===null?'Nicht berechenbar':(n>0?'+':'')+n.toLocaleString('de-CH')+' EXP';
  const date=s=>new Date(s).toLocaleString('de-CH',{timeZone:'Europe/Zurich',day:'2-digit',month:'2-digit',year:'numeric',hour:'2-digit',minute:'2-digit'});
  function render(value){
   preview=value;body.replaceChildren();
   const names=new Map([[selection.challenger_id,selection.challenger_name||'Herausforderer'],[selection.opponent_id,selection.opponent_name||'Gegner']]);
   body.append(node('h3',names.get(selection.challenger_id)+' vs. '+names.get(selection.opponent_id)));
   if(value.rule?.version===3){for(const text of global.TLDuelMetrics.ruleLines(value.rule,selection.duration_days,value.starts_at,value.ends_at))body.append(node('p',text))}
   else{body.append(node('p','Wertung: bestätigte Trainingspunkte · '+date(value.starts_at)+' bis '+date(value.ends_at)+' (Europe/Zurich).'));body.append(node('p','Es gilt die bestehende Wertung mit eingeschlossenen Zürcher Kalendertagen und rechtzeitig erfassten Trainings.','meta'))}
   const s=value.scores;
   body.append(node('p',s.challenger_score===null||s.opponent_score===null?'Wertung nicht verlässlich berechenbar.':'Geprüfter Stand: '+s.challenger_score.toLocaleString('de-CH',{maximumFractionDigits:12})+' : '+s.opponent_score.toLocaleString('de-CH',{maximumFractionDigits:12})+' '+value.rule.unit+'.','close-score'));
   body.append(node('p',s.approved+' bestätigte · '+s.pending+' offene · '+s.rejected+' abgelehnte Trainings.'));
   if(value.tie===true)body.append(node('p','Ergebnis: Unentschieden.'));
   else if(value.winner_id)body.append(node('p','Ergebnis: '+names.get(value.winner_id)+(value.status==='settled'?' gewinnt.':' liegt vorne.')));
   if(value.blockers.length){
    const list=node('ul','');list.className='close-blockers';
    for(const blocker of value.blockers)list.append(node('li',blocker.message));
    body.append(node('h3','Abschluss gesperrt'),list);
    if(s.pending){const link=node('a','Offene Trainings prüfen');link.href='./coach.html#bestaetigen';body.append(link)}
   }
   const table=node('table','');table.className='close-rewards';
   table.append(node('caption',value.rule.reward_rule==='none'?'Keine zusätzliche Belohnung · kein EXP-Umsatz':'EXP-Vorschau · '+(['rank_snapshot_v21','ranked_v21'].includes(value.rule.reward_rule)?'Rangregel bei Duellannahme':'Bestehende Duellregel')));
   const head=node('thead',''),header=node('tr','');
   for(const label of ['Boxer','Geplant','Bereits gebucht','Änderung']){const th=node('th',label);th.scope='col';header.append(th)}head.append(header);table.append(head);
   const rows=node('tbody','');
   for(const row of value.rewards){const tr=node('tr','');for(const text of [names.get(row.boxer_id),exp(row.planned_exp),exp(row.booked_exp),exp(row.delta_exp)])tr.append(node('td',text));rows.append(tr)}
   table.append(rows);body.append(table);
   if(!value.rewards.length)body.append(node('p','Keine verlässliche Prämienvorschau verfügbar.'));
   for(const row of value.rewards.filter(row=>row.transaction_id))body.append(node('p','Buchungsbeleg '+names.get(row.boxer_id)+': '+row.transaction_id,'close-receipt'));
   body.append(node('p',value.rule.reward_rule==='none'?'Diese Vorschau bucht nichts. Die ausdrückliche Bestätigung speichert das Ergebnis. Für diese Vereinbarung gibt es keine zusätzliche Belohnung.':'Diese Vorschau bucht nichts. Erst der Abschluss prüft die Daten erneut und bucht die serverseitig berechnete Änderung.','meta'));
   confirm.textContent=value.can_correct?'Korrektur ausdrücklich buchen':'Duell ausdrücklich abschliessen';
   confirm.hidden=!(value.can_close||value.can_correct);confirm.disabled=busy;
  }
  async function read(){
   if(!selection||!staff()||busy)return;
   const id=++request,epoch=getEpoch(),duel=selection;
   preview=null;confirm.hidden=true;refresh.disabled=true;body.replaceChildren();say('Schreibfreie Abschlussvorschau wird geladen …');
   try{
    const value=await rpc(duel.rule?.version===3?'duel_v3_close_preview':'duel_v2_close_preview',{p_duel_id:duel.id});
    if(!validRequest(id,epoch))return;
    if(!validatePreview(value,duel))throw Error('Die Abschlussvorschau ist unvollständig oder widersprüchlich. Es kann nichts gebucht werden.');
    render(value);say(value.can_close||value.can_correct?'Vorschau geprüft. Noch nichts gebucht.':value.status==='settled'&&!value.blockers.length?'Bereits abgeschlossen. Keine neue Buchung erforderlich.':'Kein Abschluss möglich. Bitte Hinweise prüfen.');
   }catch(error){if(validRequest(id,epoch)){preview=null;confirm.hidden=true;say(missing(error)?'Die sichere Abschlussvorschau ist noch nicht freigeschaltet. Es wurde nichts gebucht.':String(error?.message||error),true)}}
   finally{if(validRequest(id,epoch))refresh.disabled=false}
  }
  async function submit(){
   if(busy||!staff()||!selection||!preview||!(preview.can_close||preview.can_correct))return;
   const id=request,epoch=getEpoch(),duel=selection;
   busy=true;confirm.disabled=true;refresh.disabled=true;dismiss.disabled=true;say('Abschluss wird auf dem Server erneut geprüft …');
   try{
    const reviewedRevision=preview.revision;
    if(verifyActor&&!await verifyActor()||!validRequest(id,epoch))return;
    const result=await rpc(duel.rule?.version===3?'duel_v3_close_confirm':'duel_v2_close_confirm',{p_duel_id:duel.id,p_confirm:true,p_expected_revision:reviewedRevision});
    if(!validRequest(id,epoch))return;
    if(!result||!['settled','awaiting_reviews','pending_correction','in_progress','preview_changed','blocked'].includes(result.outcome)||typeof result.unchanged!=='boolean'||!validatePreview(result.preview,duel)||!Array.isArray(result.bookings))throw Error('Die Abschlussantwort ist unvollständig. Bitte die Vorschau neu laden, um den Buchungsstand zu prüfen.');
    const participants=[duel.challenger_id,duel.opponent_id];
    if(result.bookings.some(row=>!row||!participants.includes(row.boxer_id)||!integer(row.awarded_exp)||typeof row.transaction_id!=='string'||!row.transaction_id))throw Error('Der Buchungsnachweis ist unvollständig. Bitte den Stand neu laden.');
    if(new Set(result.bookings.map(row=>row.boxer_id)).size!==result.bookings.length||result.bookings.some(row=>!result.preview.rewards.some(reward=>reward.boxer_id===row.boxer_id&&reward.booked_exp===row.awarded_exp&&reward.transaction_id===row.transaction_id)))throw Error('Der Buchungsnachweis passt nicht zur Vorschau. Bitte den Stand neu laden.');
    if(result.outcome==='settled'&&(result.preview.status!=='settled'||result.bookings.length!==(result.preview.rule.reward_rule==='none'?0:2)))throw Error('Der Abschluss ist nicht vollständig belegt. Bitte den Stand neu laden.');
    render(result.preview);if(result.outcome!=='preview_changed')confirm.hidden=true;
    if(result.outcome==='preview_changed')say('Der geprüfte Stand hat sich geändert. Dieser Aufruf hat nichts gebucht. Bitte die neue Vorschau prüfen und bei Bedarf erneut bestätigen.',true);
    else if(result.outcome==='settled')say(result.unchanged?'Bereits unverändert abgeschlossen. Keine zusätzliche Buchung.':result.preview.rule.reward_rule==='none'?'Abschluss gespeichert. Keine zusätzliche Belohnung; keine EXP-Buchung.':'Abschluss gespeichert. Die aufgeführten Belege zeigen den aktuellen Buchungsstand.');
    else say('Noch nicht abgeschlossen. Die Daten haben sich geändert oder benötigen weitere Prüfung.',true);
    try{await onClosed?.()}catch{say(status.textContent+' Die Duellliste konnte nicht aktualisiert werden. Bitte die Übersicht neu laden.',true)}
   }catch(error){if(validRequest(id,epoch)){preview=null;confirm.hidden=true;say(missing(error)?'Der sichere Abschluss ist noch nicht freigeschaltet. Bitte später neu prüfen.':String(error?.message||error),true)}}
   finally{busy=false;if(validRequest(id,epoch)){confirm.disabled=false;refresh.disabled=false;dismiss.disabled=false}}
  }
  function invalidate(){request++;selection=null;preview=null;body.replaceChildren();say('');confirm.hidden=true;refresh.disabled=false;dismiss.disabled=false;if(dialog.open)dialog.close()}
  confirm.addEventListener('click',submit);refresh.addEventListener('click',read);
  dismiss.addEventListener('click',()=>{if(busy)return;invalidate();opener?.focus()});
  dialog.addEventListener('cancel',event=>{if(busy)event.preventDefault();else invalidate()});
  return {async open(duel){if(!staff()||busy)return;selection={...duel};opener=doc.activeElement;title.textContent=duel.status==='settled'?'Abschluss und Buchungen prüfen':'Duell-Abschluss prüfen';if(!dialog.open)dialog.showModal();await read()},invalidate};
 }
 global.TLDuelClose={create,validatePreview};
})(window);
