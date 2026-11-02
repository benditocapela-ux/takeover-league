/* Contract-backed duel choices and aggregate views. No configuration or economy writes. */
(function(global){
 'use strict';
 const units={points:'Trainingspunkte',jogging_km:'km',training_count:'Trainings'};
 const number=n=>typeof n==='number'&&Number.isFinite(n)&&n>=0;
 const id=n=>Number.isSafeInteger(n)&&n>0||typeof n==='string'&&/^[1-9]\d*$/.test(n);
 const revision=s=>typeof s==='string'&&s.length>0;
 const date=s=>typeof s==='string'&&Number.isFinite(Date.parse(s));
 const statuses=['pending','active','awaiting_reviews','settled','declined','expired','cancelled'];
 function validRule(rule){
  if(!rule||!Object.hasOwn(units,rule.metric)||rule.unit!==units[rule.metric]||rule.timezone!=='Europe/Zurich'||!['participants','club'].includes(rule.visibility)||typeof rule.label!=='string'||typeof rule.reward_label!=='string')return false;
  if(rule.metric==='points')return rule.time_rule==='legacy_inclusive_zurich_dates'&&['legacy_v2','ranked_v21','rank_snapshot_v21'].includes(rule.reward_rule);
  return rule.version===3&&rule.time_rule==='next_zurich_midnight_full_days'&&['none','ranked_v21'].includes(rule.reward_rule)&&id(rule.training_type_id)&&typeof rule.training_type_name==='string'&&!!rule.training_type_name;
 }
 function validOptions(value){
  if(value?.timezone!=='Europe/Zurich'||!Array.isArray(value.metrics)||value.metrics.length!==3||new Set(value.metrics.map(m=>m?.key)).size!==3||!Array.isArray(value.training_types)||!Array.isArray(value.visibility_options))return false;
  if(value.metrics.some(m=>!m||!Object.hasOwn(units,m.key)||m.unit!==units[m.key]||typeof m.label!=='string'||typeof m.enabled!=='boolean'||!revision(m.revision)||typeof m.reward_label!=='string'||m.enabled&&!['none','ranked_v21'].includes(m.reward_rule)||!m.enabled&&typeof m.disabled_reason!=='string'||m.key==='jogging_km'&&m.enabled&&(!id(m.training_type_id)||!m.training_type_name)))return false;
  if(value.training_types.some(t=>!t||!id(t.id)||typeof t.name!=='string'||!revision(t.revision)))return false;
  return ['participants','club'].every(key=>value.visibility_options.some(v=>v?.key===key&&typeof v.label==='string'));
 }
 function validItem(item){
  if(!item||typeof item.id!=='string'||!item.id||!statuses.includes(item.status)||![7,14].includes(item.duration_days)||!date(item.invited_at)||!validRule(item.rule)||typeof item.challenger_id!=='string'||!item.challenger_id||typeof item.opponent_id!=='string'||!item.opponent_id||item.challenger_id===item.opponent_id)return false;
  if(item.status==='pending'&&!date(item.expires_at))return false;
  if(['active','awaiting_reviews','settled'].includes(item.status)&&(!date(item.starts_at)||!date(item.ends_at)))return false;
  const s=item.scores;
  if(s!==null){if(!s||typeof s.valid!=='boolean'||typeof s.provisional!=='boolean'||!Number.isSafeInteger(s.pending)||s.pending<0)return false;if(s.valid&&(!number(s.challenger_score)||!number(s.opponent_score)||item.rule.metric==='training_count'&&(!Number.isSafeInteger(s.challenger_score)||!Number.isSafeInteger(s.opponent_score))))return false;if(s.provisional!==(item.status!=='settled'))return false}
  return !['active','awaiting_reviews','settled'].includes(item.status)||s!==null;
 }
 const format=n=>n.toLocaleString('de-CH',{maximumFractionDigits:12});
 const dateText=s=>new Date(s).toLocaleString('de-CH',{timeZone:'Europe/Zurich',day:'2-digit',month:'2-digit',year:'numeric',hour:'2-digit',minute:'2-digit'});
 function ruleLines(rule,days,starts,ends){
  const lines=['Wertung: '+rule.label+(rule.training_type_name?' · '+rule.training_type_name:'')+' ('+rule.unit+').',
   rule.time_rule==='next_zurich_midnight_full_days'?days+' volle Kalendertage ab der nächsten Mitternacht nach Annahme (Europe/Zurich). Das Ende ist ausgeschlossen.':days+' Tage ab Annahme nach der bestehenden Punkte-Regel mit eingeschlossenen Zürcher Kalendertagen.',
   'Sichtbarkeit: '+(rule.visibility==='club'?'Angemeldete Vereinsboxer sehen den Gesamtstand nach Annahme; keine Trainingsdetails.':'Nur Beteiligte und Trainer.'),
   'Belohnung: '+rule.reward_label+'.'];
  if(starts&&ends)lines.splice(2,0,'Zeitraum: '+dateText(starts)+' bis '+dateText(ends)+' (Europe/Zurich)'+(rule.metric==='points'?'.':' · Endzeitpunkt ausgeschlossen.'));
  if(rule.metric!=='points')lines.push('Nur rechtzeitig eingereichte und bestätigte Trainings der vereinbarten Art zählen. Offene Trainings blockieren den Abschluss.');
  return lines;
 }
 function create({form,root,view,legacy,getActor,getEpoch,rpc,verifyActor,onChange,onMutation,openClosure,targetDuel}){
  const doc=root.ownerDocument,$=id=>doc.getElementById(id),node=(tag,text)=>{const el=doc.createElement(tag);el.textContent=String(text??'');return el};
  let options=null,request=0,cursor=null,nextCursor=null,history=[],loading=false,mutating=false;
  const list=$('metricDuelList'),status=$('metricDuelStatus'),scope=$('metricDuelScope'),state=$('metricDuelState'),search=$('metricDuelSearch'),prev=$('metricDuelPrev'),next=$('metricDuelNext');
  const current=(token,epoch)=>token===request&&epoch===getEpoch()&&!!getActor();
  const staff=()=>['coach','admin'].includes(getActor()?.role);
  const say=(text,bad=false)=>{status.textContent=text;status.classList.toggle('error',bad)};
  function choice(){
   onChange?.();const metric=options?.metrics.find(m=>m.key===form.elements.metric.value),count=metric?.key==='training_count';
   $('metricTrainingTypeField').hidden=!count;form.elements.training_type.required=count;
   const disabledText=options?.metrics.filter(m=>!m.enabled).map(m=>m.label+': '+m.disabled_reason).join(' · ');
   $('metricChoiceStatus').textContent=(metric?(metric.enabled?metric.reward_label+(metric.key==='jogging_km'?' · '+metric.training_type_name:''):metric.disabled_reason):'Weitere Duellarten sind derzeit nicht verfügbar.')+(disabledText?' · Noch nicht verfügbar: '+disabledText:'');
  }
  function installOptions(value){
   const selected=form.elements.metric.value,type=form.elements.training_type.value,visibility=form.elements.visibility.value;options=value;
   form.elements.metric.replaceChildren();for(const m of value.metrics){const o=node('option',m.label+(m.enabled?'':' · '+m.disabled_reason));o.value=m.key;o.disabled=!m.enabled;form.elements.metric.append(o)}
   form.elements.metric.value=value.metrics.some(m=>m.key===selected&&m.enabled)?selected:'points';
   form.elements.training_type.replaceChildren(node('option','Trainingsart wählen'));form.elements.training_type.firstChild.value='';for(const t of value.training_types){const o=node('option',t.name);o.value=String(t.id);form.elements.training_type.append(o)}form.elements.training_type.value=type;
   form.elements.visibility.replaceChildren();for(const key of ['participants','club']){const item=value.visibility_options.find(v=>v.key===key),o=node('option',item.label);o.value=key;form.elements.visibility.append(o)}form.elements.visibility.value=['participants','club'].includes(visibility)?visibility:'participants';
   $('metricVisibilityField').hidden=false;view.hidden=false;scope.querySelector('[value="staff"]').hidden=!staff();scope.value=staff()?'staff':'mine';choice();
  }
  async function init(){
   const token=++request,epoch=getEpoch();options=null;
   try{const value=await rpc('duel_v3_options');if(!current(token,epoch))return false;if(!validOptions(value))throw Error('Unvollständige Duellregeln');installOptions(value);if(!staff()||targetDuel){view.value='all';root.hidden=false;legacy.hidden=true}return true}
   catch(error){if(current(token,epoch)){view.value='legacy';view.hidden=true;root.hidden=true;legacy.hidden=false;$('metricChoiceStatus').textContent='Weitere Duellarten sind noch nicht verfügbar. Bestehende Punkte-Duelle bleiben nutzbar.';$('metricVisibilityField').hidden=true;$('metricTrainingTypeField').hidden=true;form.elements.training_type.required=false;form.elements.metric.value='points';for(const option of form.elements.metric.options)option.disabled=option.value!=='points'}return false}
  }
  function prepare(challenger,opponent,days){
   if(!options)return null;
   const metric=options.metrics.find(m=>m.key===form.elements.metric.value),type=options.training_types.find(t=>String(t.id)===form.elements.training_type.value),visibility=form.elements.visibility.value;
   if(!metric?.enabled)throw Error(metric?.disabled_reason||'Duellart nicht freigegeben.');
   if(metric.key==='training_count'&&!type)throw Error('Wähle die vereinbarte Trainingsart.');
   if(!['participants','club'].includes(visibility))throw Error('Wähle eine gültige Sichtbarkeit.');
   const rule={version:3,metric:metric.key,label:metric.label,unit:metric.unit,visibility,reward_rule:metric.reward_rule,reward_label:metric.reward_label,timezone:'Europe/Zurich',time_rule:metric.key==='points'?'legacy_inclusive_zurich_dates':'next_zurich_midnight_full_days',training_type_id:metric.key==='training_count'?type.id:metric.training_type_id??null,training_type_name:metric.key==='training_count'?type.name:metric.training_type_name??null};
   if(!validRule(rule))throw Error('Die Duellregel ist unvollständig. Bitte aktualisieren.');
   return {rpc:'duel_v3_invite',args:{p_challenger:challenger,p_opponent:opponent,p_duration_days:days,p_metric:metric.key,p_training_type_id:metric.key==='training_count'?type.id:null,p_visibility:visibility,p_expected_rule:{metric_revision:metric.revision,training_type_revision:metric.key==='training_count'?type.revision:null}},lines:ruleLines(rule,days),rule};
  }
  async function act(name,args,token,epoch){
   if(mutating||!current(token,epoch))return;mutating=true;
   try{if(!await verifyActor()||!current(token,epoch))return;await rpc(name,args);if(!current(token,epoch))return;if(onMutation)await onMutation();else await load()}
   catch(error){if(current(token,epoch))say(error?.message||'Die Änderung konnte nicht gespeichert werden.',true)}finally{mutating=false}
  }
  function render(items,token,epoch,requestedScope){
   list.replaceChildren();if(!items.length){list.append(node('p','Keine Duelle für diese Auswahl.'));return}
   const labels={pending:'Einladung offen',active:'Aktiv',awaiting_reviews:'Trainerprüfung offen',settled:'Abgeschlossen',declined:'Abgelehnt',expired:'Abgelaufen',cancelled:'Zurückgezogen'};
   for(const item of items){
    const d=JSON.parse(JSON.stringify(item)),card=node('article','');card.className='tl-duel-card';card.dataset.metricDuel=d.id;card.dataset.status=d.status;if(requestedScope==='mine'||requestedScope==='staff')card.dataset.duelId=d.id;
    if(targetDuel===d.id){card.classList.add('is-linked-duel');card.tabIndex=-1}
    card.append(node('h3',(d.challenger_name||'Boxer')+' vs. '+(d.opponent_name||'Boxer')),node('p',labels[d.status]));for(const line of ruleLines(d.rule,d.duration_days,d.starts_at,d.ends_at))card.append(node('p',line));
    if(d.scores){card.append(node('p',d.scores.valid?(d.scores.provisional?'Vorläufiger Zwischenstand: ':'Offizieller Endstand: ')+format(d.scores.challenger_score)+' : '+format(d.scores.opponent_score)+' '+d.rule.unit:'Zwischenstand nicht verlässlich berechenbar. Trainerprüfung erforderlich.'));if(d.scores.pending)card.append(node('p',d.scores.pending+' offene Trainings können das Ergebnis verändern.'))}
    const expired=d.status==='pending'&&date(d.expires_at)&&Date.parse(d.expires_at)<=Date.now();
    if(d.status==='pending'&&!expired&&getActor().role==='boxer'&&d.opponent_id===getActor().id){
     const review=node('section','');review.hidden=true;review.append(node('h4','Vereinbarung vor Annahme prüfen'));for(const line of ruleLines(d.rule,d.duration_days))review.append(node('p',line));
     const accept=node('button','Nach Prüfung ausdrücklich annehmen');accept.type='button';accept.onclick=()=>act('duel_v2_respond',{p_duel_id:d.id,p_accept:true},token,epoch);review.append(accept);
     const open=node('button','Einladung prüfen'),decline=node('button','Einladung ablehnen');open.type=decline.type='button';open.onclick=()=>{review.hidden=false;accept.focus()};decline.onclick=()=>{if(global.confirm('Diese Einladung ablehnen?'))act('duel_v2_respond',{p_duel_id:d.id,p_accept:false},token,epoch)};card.append(open,decline,review);
    }
    if(d.status==='pending'&&!expired&&(staff()||d.challenger_id===getActor().id)){const withdraw=node('button','Einladung zurückziehen');withdraw.type='button';withdraw.onclick=()=>{if(global.confirm('Diese Einladung zurückziehen?'))act('duel_v2_withdraw_invite',{p_duel_id:d.id},token,epoch)};card.append(withdraw)}
    if(staff()&&['active','awaiting_reviews','settled'].includes(d.status)&&Date.parse(d.ends_at)<=Date.now()){const close=node('button',d.status==='settled'?'Abschluss ansehen':'Ergebnis prüfen');close.type='button';close.onclick=()=>openClosure(d);card.append(close)}
    list.append(card);
   }
  }
  async function load(){
   if(!options||view.value!=='all'||!getActor())return;const token=++request,epoch=getEpoch();loading=true;prev.disabled=next.disabled=true;list.replaceChildren();say('Lade vereinbarte Duelle …');
   const requestedScope=scope.value;if(requestedScope==='staff'&&!staff()){say('Traineransicht nicht verfügbar.',true);return}
   try{
    const value=await rpc('duel_v3_list',{p_scope:requestedScope,p_state:targetDuel?'all':state.value,p_limit:20,p_before:cursor?.before||null,p_before_id:cursor?.before_id||null,p_search:targetDuel?null:search.value.trim(),p_duel_id:targetDuel||null});
    if(!current(token,epoch))return;
    if(!value||!Array.isArray(value.items)||value.items.length>20||value.items.some(d=>!validItem(d))||value.next_cursor!==null&&(!date(value.next_cursor?.before)||typeof value.next_cursor?.before_id!=='string'))throw Error('Die Duellübersicht ist unvollständig. Bitte erneut laden.');
    if(targetDuel&&(value.items.length>1||value.next_cursor!==null||value.items.some(d=>d.id!==targetDuel)))throw Error('Der verlinkte Duellstand konnte nicht eindeutig geladen werden.');
    if(value.items.some(d=>requestedScope==='mine'&&![d.challenger_id,d.opponent_id].includes(getActor().id)||requestedScope==='club'&&(d.rule.version!==3||d.rule.visibility!=='club'||!['active','awaiting_reviews','settled'].includes(d.status))))throw Error('Die Antwort passt nicht zum gewählten Sichtbarkeitsbereich.');
    nextCursor=value.next_cursor;render(value.items,token,epoch,requestedScope);say('Seite '+(history.length+1)+' · '+value.items.length+' Duelle'+(targetDuel?' · Verlinktes Duell':'')+(requestedScope==='club'?' · Nur ausdrücklich freigegebene Gesamtstände.':''));prev.hidden=!history.length;next.hidden=!nextCursor;
   }catch(error){if(current(token,epoch)){nextCursor=null;prev.hidden=!history.length;next.hidden=true;say(['PGRST202','42883'].includes(error?.code)?'Die Übersicht für alle Duellarten ist noch nicht verfügbar. Bestehende Punkte-Duelle bleiben separat erreichbar.':String(error?.message||error),true)}}
   finally{if(current(token,epoch)){loading=false;prev.disabled=next.disabled=false}}
  }
  async function changeView(){request++;cursor=null;history=[];nextCursor=null;root.hidden=view.value!=='all';legacy.hidden=view.value==='all';doc.dispatchEvent(new Event('takeover:duels-view'));if(!root.hidden)await load();else await onMutation?.()}
  function invalidate(){request++;options=null;cursor=null;history=[];nextCursor=null;list.replaceChildren();say('');root.hidden=true;view.hidden=true;view.value='legacy';legacy.hidden=false;onChange?.()}
  view.addEventListener('change',changeView);scope.addEventListener('change',()=>{cursor=null;history=[];load()});state.addEventListener('change',()=>{cursor=null;history=[];load()});$('metricDuelFilter').onsubmit=e=>{e.preventDefault();cursor=null;history=[];load()};
  prev.onclick=()=>{if(loading||!history.length)return;cursor=history.pop();load()};next.onclick=()=>{if(loading||!nextCursor)return;history.push(cursor);cursor=nextCursor;load()};
  form.elements.metric.addEventListener('change',choice);form.elements.training_type.addEventListener('change',onChange);form.elements.visibility.addEventListener('change',onChange);
  return {loadOptions:init,prepare,load,invalidate,available:()=>!!options};
 }
 global.TLDuelMetrics={create,validRule,validOptions,validItem,ruleLines};
})(window);
