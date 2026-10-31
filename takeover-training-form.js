/* Takeover League 3.0 · Trainingsmeldung direkt in der Boxer Experience (ersetzt das eingebettete boxer.html-Formular).
 *
 * Gleiche Regeln wie das bewährte Formular in boxer.html (bitte bei Änderungen beide prüfen):
 *  - Schreibt ausschliesslich einen Antrag in training_submissions (status 'pending'). Punkte, EXP, Coins und die
 *    Einstufung Pflicht/Ergänzung legt allein der Server bei der Trainerbestätigung fest
 *    (league_private.training_insert_guard prüft Ort, Einheit, Wochentag und Datum erneut).
 *  - Doppeltes Antippen: Sperre während des Sendens + client_request_id (eindeutiger Index) → keine Doppelmeldung.
 *  - Entwürfe: Sitzungsentwurf (takeover_draft_<id>) und, falls freigeschaltet, privater Cloud-Entwurf (training_drafts_v2).
 *  - «Letztes Training übernehmen» (takeover_last_training_<id>), Training-2.0-Auswahl (takeover_v2_choice_<id>).
 *  Alle Schlüssel sind mit boxer.html kompatibel.
 */
(function(){
 'use strict';
 if(window.TLTrainingForm)return;
 const DAYS=['Montag','Dienstag','Mittwoch','Donnerstag','Freitag','Samstag','Sonntag'];
 const CATEGORY_ORDER=['Wettkampf','Boxen','Athletik','Ausdauer','Erholung & Team'];
 const el=(tag,cls,text)=>{const n=document.createElement(tag);if(cls)n.className=cls;if(text!=null)n.textContent=text;return n};
 const isoDow=d=>{const x=new Date(d+'T12:00:00Z');return ((x.getUTCDay()+6)%7)+1};
 const addDays=(d,n)=>{const x=new Date(d+'T12:00:00Z');x.setUTCDate(x.getUTCDate()+n);return x.toISOString().slice(0,10)};
 function swissToday(){const p=new Intl.DateTimeFormat('en-CA',{timeZone:'Europe/Zurich',year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(new Date());const g=t=>p.find(x=>x.type===t)?.value||'';return g('year')+'-'+g('month')+'-'+g('day')}
 const rewardText=r=>r?[r.points!=null?r.points+' Punkte':null,r.exp!=null?r.exp+' EXP':null,r.coins!=null?r.coins+' Coins':null].filter(Boolean).join(' · '):'';
 const isJogging=t=>!!t&&/^joggen$/i.test(String(t.name).trim());
 const isTechnique=t=>!!t&&/^techniktraining$/i.test(String(t.name).trim());
 function sortTypes(list){const rank=c=>{const i=CATEGORY_ORDER.indexOf(c||'');return i<0?99:i};
  return [...list].sort((a,b)=>rank(a.category)-rank(b.category)||(a.sort_order??9999)-(b.sort_order??9999)||String(a.name).localeCompare(String(b.name),'de'))}
 function uuid(){if(crypto.randomUUID)return crypto.randomUUID();const b=crypto.getRandomValues(new Uint8Array(16));b[6]=b[6]&15|64;b[8]=b[8]&63|128;
  const h=[...b].map(x=>x.toString(16).padStart(2,'0')).join('');return h.slice(0,8)+'-'+h.slice(8,12)+'-'+h.slice(12,16)+'-'+h.slice(16,20)+'-'+h.slice(20)}
 const store={get(k,s){try{return (s||localStorage).getItem(k)}catch{return null}},set(k,v,s){try{(s||localStorage).setItem(k,v);return true}catch{return false}},del(k,s){try{(s||localStorage).removeItem(k)}catch{}}};

 /** Baut die Logik (ohne DOM) – auch für Tests nutzbar. */
 function buildPayload({profile,type,values,v2,loc,slot,extra,requestId}){
  const minutes=Number(values.minutes);
  const payload={boxer_id:profile.id,training_type_id:type.id,training_date:values.date,notes:String(values.notes||'').trim(),
   jogging_km:isJogging(type)?Number(values.km):null,duration_minutes:minutes,
   technique_minutes:isTechnique(type)?minutes:null,status:'pending'};
  if(v2){
   if(loc==='club')Object.assign(payload,{training_location:'club',requested_slot_id:slot?slot.slot_id:null,requested_extra_key:extra?extra.key:null});
   else Object.assign(payload,{training_location:'individual',requested_slot_id:null,requested_extra_key:null});
  }
  if(requestId)payload.client_request_id=requestId;
  return payload;
 }
 function validate({type,values,v2,loc,slot,extra,today}){
  if(v2&&!loc)return {field:'loc',message:'Bitte zuerst wählen, wo du trainiert hast.'};
  if(v2&&loc==='club'&&!slot&&!extra)return {field:'unit',message:'Bitte die Vereinseinheit wählen (Pflicht- oder Ergänzungstraining).'};
  if(!type)return {field:'kind',message:'Bitte die Trainingsart wählen.'};
  if(!/^\d{4}-\d{2}-\d{2}$/.test(values.date||''))return {field:'date',message:'Bitte das Trainingsdatum angeben.'};
  if(values.date>today)return {field:'date',message:'Das Trainingsdatum darf nicht in der Zukunft liegen.'};
  if(slot&&isoDow(values.date)!==Number(slot.dow))return {field:'date',message:'«'+slot.label+'» findet am '+(slot.day_name||DAYS[slot.dow-1])+' statt. Bitte das Datum prüfen.'};
  const minutes=Number(values.minutes);
  if(!Number.isInteger(minutes)||minutes<1||minutes>1440)return {field:'minutes',message:'Bitte die Trainingsdauer in Minuten angeben (1–1440).'};
  if(isJogging(type)){const km=Number(values.km);if(!Number.isFinite(km)||km<0.01||km>1000)return {field:'km',message:'Bitte die Joggingdistanz in km angeben (0.01–1000).'}}
  const notes=String(values.notes||'').trim();
  if(notes.length<3)return {field:'notes',message:'Bitte eine Bemerkung zum Training eingeben (mindestens 3 Zeichen).'};
  if(notes.length>500)return {field:'notes',message:'Die Bemerkung darf höchstens 500 Zeichen haben.'};
  return null;
 }

 function mount(host,opts){
  const db=opts.db,profile=opts.profile;
  const cfg=opts.cfg&&opts.cfg.enabled===true&&Array.isArray(opts.cfg.pflicht)?opts.cfg:null;
  const keys={draft:'takeover_draft_'+profile.id,request:'takeover_submission_request_'+profile.id,last:'takeover_last_training_'+profile.id,
   lastType:'takeover_last_type_'+profile.id,choice:'takeover_v2_choice_'+profile.id};
  let types=sortTypes((opts.types||[]).filter(t=>t&&t.is_active!==false));
  if(opts.checkinOnly)types=types.filter(t=>!t.club_only); // Server lehnt Vereinsarten bei «nur per Gym-Check-in» ab
  const st={loc:null,choice:null,busy:false,requestIdSupported:true,probe:Promise.resolve(),cloud:false,cloudTimer:null,cloudSeq:0,cloudFlight:Promise.resolve()};
  const slotOf=()=>cfg&&st.choice&&st.choice.kind==='slot'?cfg.pflicht.find(x=>String(x.slot_id)===String(st.choice.id))||null:null;
  const extraOf=()=>cfg&&st.choice&&st.choice.kind==='extra'?cfg.extras.find(x=>x.key===st.choice.key)||null:null;

  host.replaceChildren();host.classList.add('tf');
  const form=el('form','tf-form');form.noValidate=true;form.setAttribute('aria-label','Training melden');
  const top=el('div','tf-top');
  const title=el('h3','tf-title','Training melden');title.tabIndex=-1;
  const close=el('button','tf-close','Schliessen');close.type='button';close.setAttribute('aria-label','Trainingsformular schliessen');
  top.append(title,close);
  const help=el('p','tf-help',cfg?'Wähle zuerst, wo du trainiert hast. Vereinstrainings stuft dein Trainer beim Bestätigen ein – Punkte, EXP und Coins gibt es erst nach seiner Bestätigung.':'Punkte und EXP werden erst nach Bestätigung durch deinen Trainer gutgeschrieben.');
  const tools=el('div','tf-tools');
  const repeat=el('button','tf-chip','↻ Letztes Training');repeat.type='button';
  const clear=el('button','tf-chip','Entwurf verwerfen');clear.type='button';
  const cloudSave=el('button','tf-chip','Entwurf online sichern');cloudSave.type='button';cloudSave.hidden=true;
  const draftStatus=el('span','tf-draft','Eingaben werden während dieser Sitzung zwischengespeichert.');draftStatus.setAttribute('role','status');
  tools.append(repeat,clear,cloudSave,draftStatus);
  const step=(n,label)=>{const s=el('fieldset','tf-step');s.dataset.step=String(n);const lg=el('legend','tf-legend');lg.append(el('span','tf-num',String(n)),el('span','',label));s.append(lg);return s};
  const s1=step(1,'Wo hast du trainiert?'),locBox=el('div','tf-cards');locBox.setAttribute('role','radiogroup');locBox.setAttribute('aria-label','Wo hast du trainiert?');s1.append(locBox);
  const s2=step(2,'Welche Einheit?'),unitBox=el('div');s2.append(unitBox);
  const s3=step(cfg?3:1,'Details');
  const kindLabel=el('label','tf-label','Trainingsart');const kind=el('select','tf-input');kind.id='tf-kind';kindLabel.htmlFor='tf-kind';
  const kindHint=el('p','tf-hint');
  const dateLabel=el('label','tf-label','Trainingsdatum');const date=el('input','tf-input');date.type='date';date.id='tf-date';dateLabel.htmlFor='tf-date';date.max=swissToday();
  const dateMsg=el('p','tf-hint');dateMsg.setAttribute('role','status');
  const minLabel=el('label','tf-label','Trainingsdauer (Minuten)');const minutes=el('input','tf-input');minutes.type='number';minutes.id='tf-minutes';minutes.min='1';minutes.max='1440';minutes.step='1';minutes.inputMode='numeric';minutes.placeholder='z. B. 60';minLabel.htmlFor='tf-minutes';
  const kmWrap=el('div','tf-km');const kmLabel=el('label','tf-label','Joggingdistanz (km)');const km=el('input','tf-input');km.type='number';km.id='tf-km';km.min='0.01';km.max='1000';km.step='0.01';km.inputMode='decimal';km.placeholder='z. B. 5.5';kmLabel.htmlFor='tf-km';kmWrap.append(kmLabel,km);kmWrap.hidden=true;
  const notesLabel=el('label','tf-label','Bemerkung');const notes=el('textarea','tf-input');notes.id='tf-notes';notes.rows=3;notes.maxLength=500;notes.placeholder='Was hast du trainiert? z. B. Pratzen, Kombinationen, Runden';notesLabel.htmlFor='tf-notes';
  const kindWrap=el('div','tf-kind-wrap');kindWrap.append(kindLabel,kind,kindHint);
  const grid=el('div','tf-grid');const dWrap=el('div');dWrap.append(dateLabel,date);const mWrap=el('div');mWrap.append(minLabel,minutes);grid.append(dWrap,mWrap);
  s3.append(kindWrap,grid,dateMsg,kmWrap,notesLabel,notes);
  const reward=el('div','tf-reward');reward.setAttribute('aria-live','polite');const rewardCat=el('span','tf-reward-cat'),rewardVal=el('strong','tf-reward-val');
  reward.append(el('span','tf-eyebrow','VORAUSSICHTLICHE BELOHNUNG'),rewardCat,rewardVal,el('small','','Die endgültige Gutschrift erfolgt erst nach Bestätigung durch deinen Trainer.'));
  const error=el('p','tf-error');error.setAttribute('role','alert');error.hidden=true;
  const submit=el('button','tf-submit','Training einreichen');submit.type='submit';
  const status=el('p','tf-status');status.setAttribute('role','status');status.setAttribute('aria-live','polite');
  if(cfg)form.append(s1,s2);form.append(s3,reward,error,submit,status);
  const done=el('div','tf-done');done.hidden=true;done.setAttribute('role','status');
  host.append(top,help,tools,form,done);

  // Trainingsarten
  function fillKinds(){
   const cur=kind.value;kind.replaceChildren(new Option('Bitte wählen',''));let group=null,curCat;
   const list=types.filter(t=>!(cfg&&st.loc==='individual'&&t.club_only));
   for(const t of list){const o=new Option(t.name,String(t.id));if(t.category){if(t.category!==curCat){curCat=t.category;group=el('optgroup');group.label=t.category;kind.append(group)}group.append(o)}else kind.append(o)}
   if([...kind.options].some(o=>o.value===cur))kind.value=cur;
  }
  const typeOf=()=>types.find(t=>String(t.id)===kind.value)||null;
  function setKind(id){if(id!=null&&String(kind.value)!==String(id)){kind.value=String(id);if(String(kind.value)!==String(id)){const t=types.find(x=>String(x.id)===String(id));if(t){kind.append(new Option(t.name,String(t.id)));kind.value=String(id)}}}}
  function lastDateFor(dow){let d=swissToday();for(let i=0;i<7;i++){if(isoDow(d)===Number(dow))return d;d=addDays(d,-1)}return d}
  function card({icon,title,sub,checked,label,onPick}){
   const b=el('button','tf-card');b.type='button';b.setAttribute('role','radio');b.setAttribute('aria-checked',String(!!checked));if(label)b.setAttribute('aria-label',label);
   const t=el('span','tf-card-copy');t.append(el('strong','',title));if(sub)t.append(el('small','',sub));
   const ic=el('span','tf-card-ic',icon);ic.setAttribute('aria-hidden','true');const ck=el('span','tf-card-ck',checked?'✓':'');ck.setAttribute('aria-hidden','true');
   b.append(ic,t,ck);b.addEventListener('click',onPick);
   b.addEventListener('keydown',e=>{const list=[...b.parentElement.querySelectorAll('.tf-card')];const i=list.indexOf(b);
    if(['ArrowDown','ArrowRight'].includes(e.key)){e.preventDefault();list[(i+1)%list.length].focus()}
    if(['ArrowUp','ArrowLeft'].includes(e.key)){e.preventDefault();list[(i-1+list.length)%list.length].focus()}});
   return b;
  }
  function rememberChoice(){store.set(keys.choice,JSON.stringify({loc:st.loc,choice:st.choice}))}
  function render(){
   if(cfg){
    locBox.replaceChildren(
     card({icon:'🏟️',title:'Im Verein / Gym',sub:opts.checkinOnly?'Per Gym-Check-in beim Trainer':'Pflicht- oder Ergänzungstraining',checked:st.loc==='club',onPick:()=>{st.loc='club';if(!slotOf()&&!extraOf())st.choice=null;rememberChoice();render();remember();focusStep(2)}}),
     card({icon:'🏠',title:'Individuell',sub:'Ausserhalb des Vereins: Joggen, Kraft, Heimtraining …',checked:st.loc==='individual',onPick:()=>{st.loc='individual';st.choice=null;rememberChoice();render();remember();kind.focus()}}));
    s2.hidden=st.loc!=='club';unitBox.replaceChildren();
    if(st.loc==='club'&&opts.checkinOnly){
     unitBox.append(el('p','tf-hint','Dein Verein erfasst Vereinstrainings ausschliesslich per Gym-Check-in. Eine Selbstmeldung ist dafür nicht möglich.'));
     const a=el('a','tf-submit tf-secondary tf-link','Zum Gym-Check-in');a.href='./checkin.html';unitBox.append(a);
    }else if(st.loc==='club'){
     const mk=(label,list,make)=>{if(!list.length)return;unitBox.append(el('div','tf-group',label));const g=el('div','tf-cards');g.setAttribute('role','radiogroup');g.setAttribute('aria-label',label);list.forEach(x=>g.append(make(x)));unitBox.append(g)};
     mk('PFLICHTTRAINING · FESTER WOCHENTAG',cfg.pflicht,x=>card({icon:'🥊',title:(x.day_name||DAYS[x.dow-1])+' – '+x.label,sub:rewardText(x.reward),
      label:'Pflichttraining '+(x.day_name||DAYS[x.dow-1])+' – '+x.label+', '+rewardText(x.reward),checked:st.choice?.kind==='slot'&&String(st.choice.id)===String(x.slot_id),
      onPick:()=>{st.choice={kind:'slot',id:x.slot_id};setKind(x.training_type_id);if(!date.value||isoDow(date.value)!==Number(x.dow))date.value=lastDateFor(x.dow);
       if(!minutes.value&&x.duration_minutes)minutes.value=String(x.duration_minutes);rememberChoice();render();remember()}}));
     mk('ERGÄNZUNGSTRAINING · AN JEDEM TAG',cfg.extras,x=>card({icon:x.key==='athletik'?'💪':x.key==='technik'?'🎯':'🥊',title:x.label,sub:rewardText(x.reward),
      label:'Ergänzungstraining '+x.label+', '+rewardText(x.reward),checked:st.choice?.kind==='extra'&&st.choice.key===x.key,
      onPick:()=>{st.choice={kind:'extra',key:x.key};setKind(x.training_type_id);rememberChoice();render();remember()}}));
    }
    s3.hidden=!st.loc||(st.loc==='club'&&!!opts.checkinOnly);submit.hidden=s3.hidden&&!!cfg;reward.hidden=reward.hidden||s3.hidden;
    const s=slotOf(),e=extraOf();if(s)setKind(s.training_type_id);if(e)setKind(e.training_type_id);
    kindWrap.hidden=st.loc==='club';
   }
   fillKinds();updateFields();
  }
  function focusStep(n){const s=form.querySelector('[data-step="'+n+'"]');if(!s)return;s.scrollIntoView({block:'nearest',behavior:'smooth'});s.querySelector('button')?.focus({preventScroll:true})}
  function updateFields(){
   const t=typeOf();kmWrap.hidden=!isJogging(t);if(!isJogging(t))km.value='';
   kindHint.textContent=!cfg&&t?'Vorgesehene Punkte nach Bestätigung: '+t.points:'';
   const s=slotOf(),e=extraOf();let cat='',r=null;
   if(cfg){
    if(st.loc==='club'&&s){cat='Pflichttraining';r=s.reward}
    else if(st.loc==='club'&&e){cat='Ergänzungstraining';r=e.reward}
    else if(st.loc==='individual'&&t){const ct=cfg.types&&cfg.types.find(x=>String(x.id)===String(t.id));cat='Individuelles Training · '+t.name;r=ct?ct.reward:{points:t.points,exp:t.points}}
   }else if(t){cat=t.name;r={points:t.points}}
   reward.hidden=!r;rewardCat.textContent=cat;rewardVal.textContent=rewardText(r);
   dateMsg.textContent='';dateMsg.classList.remove('tf-bad');
   if(s&&date.value&&isoDow(date.value)!==Number(s.dow)){dateMsg.textContent='Achtung: «'+s.label+'» ist am '+(s.day_name||DAYS[s.dow-1])+'. Das gewählte Datum ist ein '+DAYS[isoDow(date.value)-1]+'.';dateMsg.classList.add('tf-bad')}
  }
  // Entwürfe
  const values=()=>({kind:kind.value,date:date.value,notes:notes.value,joggingKm:km.value,techniqueMinutes:minutes.value});
  function applyDraft(d){
   if(!d||typeof d!=='object')return;
   if(d.kind&&types.some(t=>String(t.id)===String(d.kind))){setKind(d.kind)}
   if(/^\d{4}-\d{2}-\d{2}$/.test(d.date||''))date.value=d.date;
   if(d.notes!=null)notes.value=String(d.notes);if(d.joggingKm!=null)km.value=String(d.joggingKm);if(d.techniqueMinutes!=null)minutes.value=String(d.techniqueMinutes);
   updateFields();if(d.joggingKm!=null&&!kmWrap.hidden)km.value=String(d.joggingKm);
  }
  function remember(){
   if(st.busy)return;
   store.del(keys.request,sessionStorage);scheduleCloud();
   if(store.set(keys.draft,JSON.stringify(values()),sessionStorage))draftStatus.textContent='Entwurf auf diesem Gerät für diese Sitzung gesichert.';
  }
  function cloudRow(){const t=typeOf();return {boxer_id:profile.id,training_type_id:t?t.id:null,training_date:date.value||null,notes:notes.value.slice(0,500),
   jogging_km:km.value?Number(km.value):null,technique_minutes:null,duration_minutes:minutes.value?Number(minutes.value):null,updated_at:new Date().toISOString()}}
  function scheduleCloud(){
   if(!st.cloud)return;if(st.cloudTimer)clearTimeout(st.cloudTimer);const seq=++st.cloudSeq;
   st.cloudTimer=setTimeout(()=>{st.cloudTimer=null;st.cloudFlight=st.cloudFlight.then(async()=>{
    try{const r=await db.from('training_drafts_v2').upsert(cloudRow(),{onConflict:'boxer_id'});if(r.error)throw r.error;
     if(seq===st.cloudSeq)draftStatus.textContent='Privater Entwurf online gesichert – noch nicht eingereicht.'}
    catch{if(seq===st.cloudSeq)draftStatus.textContent='Online-Speichern fehlgeschlagen; der Entwurf auf diesem Gerät bleibt gesichert.'}
   })},1300);
  }
  form.addEventListener('input',remember);
  kind.addEventListener('change',()=>{updateFields();remember()});
  date.addEventListener('change',updateFields);
  repeat.addEventListener('click',()=>{
   let last=null;try{last=JSON.parse(store.get(keys.last)||'null')}catch{}
   if(!last){status.textContent='Noch kein vorheriges Training gespeichert.';return}
   if(cfg&&!st.loc){st.loc='individual';render()}
   applyDraft({...last,date:date.value||swissToday()});remember();status.textContent='Letztes Training übernommen. Bitte Datum und Angaben prüfen.';
  });
  clear.addEventListener('click',async()=>{
   if(!confirm('Diesen nicht eingereichten Trainingsentwurf verwerfen?'))return;
   if(st.cloudTimer){clearTimeout(st.cloudTimer);st.cloudTimer=null}st.cloudSeq++;await st.cloudFlight;
   store.del(keys.draft,sessionStorage);store.del(keys.request,sessionStorage);
   if(st.cloud){const r=await db.from('training_drafts_v2').delete().eq('boxer_id',profile.id);if(r.error){status.textContent='Online-Entwurf konnte nicht gelöscht werden: '+r.error.message;return}}
   notes.value='';km.value='';minutes.value='';date.value=swissToday();kind.value='';updateFields();draftStatus.textContent='Entwurf verworfen.';
  });
  cloudSave.addEventListener('click',async()=>{
   if(!st.cloud)return;cloudSave.disabled=true;draftStatus.textContent='Privater Entwurf wird gespeichert …';
   try{const r=await db.from('training_drafts_v2').upsert(cloudRow(),{onConflict:'boxer_id'});if(r.error)throw r.error;draftStatus.textContent='Privater Entwurf online gespeichert. Noch nicht eingereicht.'}
   catch(e){draftStatus.textContent='Online-Speichern fehlgeschlagen: '+String(e.message||e)}finally{cloudSave.disabled=false}
  });
  function showError(v){
   error.hidden=false;error.textContent=v.message;
   const target={loc:locBox.querySelector('button'),unit:unitBox.querySelector('button'),kind,date,minutes,km,notes}[v.field];
   if(target){target.setAttribute('aria-invalid','true');target.focus({preventScroll:false});setTimeout(()=>target.removeAttribute('aria-invalid'),2500)}
  }
  form.addEventListener('submit',async e=>{
   e.preventDefault();if(st.busy)return;error.hidden=true;
   const t=typeOf();const v={date:date.value,minutes:minutes.value,km:km.value,notes:notes.value};
   const problem=validate({type:t,values:v,v2:!!cfg,loc:st.loc,slot:slotOf(),extra:extraOf(),today:swissToday()});
   if(problem){showError(problem);return}
   st.busy=true;submit.disabled=true;form.querySelectorAll('input,select,textarea,button').forEach(n=>{if(n!==submit){n.dataset.tfWas=n.disabled?'1':'';n.disabled=true}});submit.textContent='Wird eingereicht …';status.textContent='Training wird eingereicht …';
   if(st.cloudTimer){clearTimeout(st.cloudTimer);st.cloudTimer=null}st.cloudSeq++;
   let requestId=null;
   await st.probe;
   if(st.requestIdSupported){requestId=store.get(keys.request,sessionStorage);if(!requestId){requestId=uuid();store.set(keys.request,requestId,sessionStorage)}}
   let duplicate=false;
   try{
    const payload=buildPayload({profile,type:t,values:v,v2:!!cfg,loc:st.loc,slot:slotOf(),extra:extraOf(),requestId});
    const r=await db.from('training_submissions').insert(payload);
    if(r.error){
     if(!(requestId&&r.error.code==='23505'))throw r.error;
     const old=await db.from('training_submissions').select('id,status').eq('boxer_id',profile.id).eq('client_request_id',requestId).maybeSingle();
     if(old.error||!old.data)throw r.error;duplicate=true;
    }
    store.set(keys.lastType,String(t.id));store.set(keys.last,JSON.stringify({kind:String(t.id),joggingKm:km.value,techniqueMinutes:minutes.value}));
    store.del(keys.draft,sessionStorage);store.del(keys.request,sessionStorage);
    if(st.cloud){await st.cloudFlight;const c=await db.from('training_drafts_v2').delete().eq('boxer_id',profile.id);if(c.error)console.warn('Entwurf nach Einreichung nicht gelöscht:',c.error.message)}
    const label=(slotOf()?'Pflichttraining · ':extraOf()?'Ergänzungstraining · ':'')+t.name;
    notes.value='';km.value='';minutes.value='';
    showDone(duplicate?'Dieses Training wurde bereits eingereicht – es gibt keine doppelten Punkte.':'Dein Training «'+label+'» vom '+new Date(v.date+'T12:00:00').toLocaleDateString('de-CH')+' wurde eingereicht und wartet auf die Bestätigung deines Trainers.');
    if(typeof opts.onSubmitted==='function')opts.onSubmitted({duplicate});
   }catch(err){
    status.textContent='';error.hidden=false;error.textContent='Einreichen fehlgeschlagen: '+String(err&&err.message||err)+'. Bitte prüfe deine Trainingshistorie, bevor du erneut sendest.';
   }finally{st.busy=false;submit.disabled=false;submit.textContent='Training einreichen';form.querySelectorAll('[data-tf-was]').forEach(n=>{n.disabled=n.dataset.tfWas==='1';delete n.dataset.tfWas})}
  });
  function showDone(text){
   form.hidden=true;tools.hidden=true;help.hidden=true;done.hidden=false;done.replaceChildren();
   const icon=el('div','tf-done-icon','✓');icon.setAttribute('aria-hidden','true');
   const h=el('h4','','Eingereicht');h.tabIndex=-1;
   const again=el('button','tf-chip','＋ Weiteres Training');again.type='button';again.addEventListener('click',()=>{reset();title.focus()});
   const back=el('button','tf-submit tf-secondary','Zur Trainingsübersicht');back.type='button';back.addEventListener('click',()=>{if(typeof opts.onClose==='function')opts.onClose()});
   done.append(icon,h,el('p','',text),el('p','tf-hint','Den Status siehst du in deiner Trainingshistorie.'),back,again);h.focus();
   status.textContent='';
  }
  function reset(){form.hidden=false;tools.hidden=false;help.hidden=false;done.hidden=true;date.value=swissToday();updateFields()}
  close.addEventListener('click',()=>{if(typeof opts.onClose==='function')opts.onClose()});

  // Start
  date.value=swissToday();
  if(cfg){try{const c=JSON.parse(store.get(keys.choice)||'null');if(c&&['club','individual'].includes(c.loc)){st.loc=c.loc;st.choice=c.choice||null;if(st.loc==='club'&&!slotOf()&&!extraOf())st.choice=null}}catch{}}
  render();
  let saved=null;try{saved=JSON.parse(store.get(keys.draft,sessionStorage)||'null')}catch{}
  if(saved){applyDraft(saved);draftStatus.textContent='Letzten Sitzungsentwurf wiederhergestellt.'}
  else{const k=store.get(keys.lastType);if(k&&types.some(t=>String(t.id)===k)&&!(cfg&&st.loc==='club'))setKind(k);updateFields()}
  if(!types.length){submit.disabled=true;status.textContent='Es sind noch keine Trainingsarten hinterlegt. Bitte den Trainer informieren.'}
  st.probe=(async()=>{try{const probe=await db.from('training_submissions').select('client_request_id').eq('boxer_id',profile.id).limit(1);st.requestIdSupported=!probe.error}catch{st.requestIdSupported=true}})();
  (async()=>{
   try{const r=await db.from('training_drafts_v2').select('training_type_id,training_date,notes,jogging_km,technique_minutes,duration_minutes').eq('boxer_id',profile.id).maybeSingle();
    if(!r.error){st.cloud=true;cloudSave.hidden=false;
     if(r.data&&!saved){applyDraft({kind:String(r.data.training_type_id||''),date:r.data.training_date,notes:r.data.notes,joggingKm:r.data.jogging_km,techniqueMinutes:r.data.duration_minutes??r.data.technique_minutes});draftStatus.textContent='Privater Entwurf wiederhergestellt.'}}}catch{}
  })();

  return {
   open(mode){
    reset();
    if(cfg&&mode==='club'){st.loc='club';if(!slotOf()&&!extraOf())st.choice=null;rememberChoice();render();}
    else if(cfg&&mode==='individual'){st.loc='individual';st.choice=null;rememberChoice();render();}
    host.hidden=false;title.focus({preventScroll:true});host.scrollIntoView({block:'start',behavior:'smooth'});
   },
   get busy(){return st.busy}
  };
 }
 window.TLTrainingForm={mount,validate,buildPayload,swissToday,sortTypes};
})();
