/* Takeover League · Training 2.0 – Trainingsmeldung in vier Schritten (Ort → Einheit → Details → Belohnung).
   Aktiv nur, wenn der Server «Training 2.0» freigibt (get_training_v2_config.enabled). Sonst bleibt das bisherige Formular.
   Die Auswahl ist ein Antrag: Stufe, Punkte, EXP und Coins legt ausschliesslich der Server bei der Trainerbestätigung fest.
   Alle angezeigten Werte stammen aus der Server-Konfiguration (gleiche Regel wie die Buchung). */
(function(){
 'use strict';
 if(!document.body||document.body.dataset.tlScreen!=='boxer')return;
 const DAYS=['Montag','Dienstag','Mittwoch','Donnerstag','Freitag','Samstag','Sonntag'];
 const state={cfg:null,ctx:null,loc:null,choice:null,ui:null};
 const el=(tag,cls,text)=>{const n=document.createElement(tag);if(cls)n.className=cls;if(text!=null)n.textContent=text;return n};
 const $=id=>document.getElementById(id);
 const isoDow=d=>{const x=new Date(d+'T12:00:00Z');return ((x.getUTCDay()+6)%7)+1};
 const addDays=(d,n)=>{const x=new Date(d+'T12:00:00Z');x.setUTCDate(x.getUTCDate()+n);return x.toISOString().slice(0,10)};
 function swissToday(){const p=new Intl.DateTimeFormat('en-CA',{timeZone:'Europe/Zurich',year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(new Date());const g=t=>p.find(x=>x.type===t)?.value||'';return g('year')+'-'+g('month')+'-'+g('day')}
 const rewardText=r=>r?`${r.points} Punkte · ${r.exp} EXP · ${r.coins} Coins`:'';
 const slotOf=()=>state.choice&&state.choice.kind==='slot'?state.cfg.pflicht.find(x=>x.slot_id===state.choice.id):null;
 const extraOf=()=>state.choice&&state.choice.kind==='extra'?state.cfg.extras.find(x=>x.key===state.choice.key):null;

 const api={
  active:()=>!!state.cfg,
  payload(){
   if(!state.cfg)return {};
   if(state.loc==='club'){const s=slotOf(),e=extraOf();return {training_location:'club',requested_slot_id:s?s.slot_id:null,requested_extra_key:e?e.key:null}}
   return {training_location:'individual',requested_slot_id:null,requested_extra_key:null};
  },
  validate(){
   if(!state.cfg)return null;
   if(!state.loc){focusStep(1);return 'Bitte zuerst wählen, wo du trainiert hast.'}
   if(state.loc==='club'&&!state.choice){focusStep(2);return 'Bitte die Vereinseinheit wählen (Pflicht- oder Ergänzungstraining).'}
   const s=slotOf(),date=$('date')?.value;
   if(s&&date&&isoDow(date)!==s.dow)return `«${s.label}» findet am ${s.day_name} statt. Bitte das Datum prüfen.`;
   if(date&&date>swissToday())return 'Das Trainingsdatum darf nicht in der Zukunft liegen.';
   return null;
  }
 };
 window.TLTrainingV2=api;

 function css(){
  if($('tlTrainingV2Css'))return;
  const s=el('style');s.id='tlTrainingV2Css';s.textContent=`
.tl-v2{display:grid;gap:var(--sp-4,16px);margin:0 0 var(--sp-4,16px)}
.tl-v2-step{border:1px solid var(--line,#26324a);border-radius:var(--r-lg,16px);padding:var(--sp-4,16px);background:var(--surface-2,rgba(255,255,255,.02))}
.tl-v2-step>header{display:flex;align-items:center;gap:10px;margin:0 0 12px}
.tl-v2-num{display:inline-grid;place-items:center;width:28px;height:28px;border-radius:50%;background:var(--gold,#d4a83a);color:#0b1220;font-weight:800;font-size:14px;flex:none}
.tl-v2-step h3{margin:0;font-size:1.05rem}
.tl-v2-cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,220px),1fr));gap:10px}
.tl-v2-card{display:grid;grid-template-columns:auto 1fr auto;align-items:center;gap:12px;text-align:left;min-height:64px;padding:12px 14px;border:1px solid var(--line-strong,#34425f);border-radius:14px;background:var(--surface,#111a2c);color:var(--text,#fff);cursor:pointer;font:inherit}
.tl-v2-card[aria-checked="true"]{border-color:var(--gold,#d4a83a);box-shadow:0 0 0 2px color-mix(in srgb,var(--gold,#d4a83a) 45%,transparent) inset;background:color-mix(in srgb,var(--gold,#d4a83a) 10%,var(--surface,#111a2c))}
.tl-v2-card:focus-visible{outline:3px solid var(--gold,#d4a83a);outline-offset:2px}
.tl-v2-card .ic{font-size:24px;line-height:1}.tl-v2-card strong{display:block}.tl-v2-card small{display:block;color:var(--muted,#9aa6bf);margin-top:2px}
.tl-v2-card .ck{width:22px;height:22px;border-radius:50%;border:2px solid var(--line-strong,#34425f);display:grid;place-items:center;font-size:13px;color:#0b1220}
.tl-v2-card[aria-checked="true"] .ck{background:var(--gold,#d4a83a);border-color:var(--gold,#d4a83a)}
.tl-v2-group{margin:4px 0 8px;font-size:12px;letter-spacing:.14em;font-weight:800;color:var(--gold,#d4a83a)}
.tl-v2-group+.tl-v2-cards{margin-bottom:12px}
.tl-v2-msg{margin:8px 0 0;font-size:.9rem}.tl-v2-msg.bad{color:var(--bad,#ff6b6b)}
.tl-v2-reward{display:grid;gap:6px;border:1px solid color-mix(in srgb,var(--gold,#d4a83a) 55%,transparent);border-radius:14px;padding:14px;background:color-mix(in srgb,var(--gold,#d4a83a) 8%,transparent);margin:var(--sp-4,16px) 0}
.tl-v2-reward .cat{font-size:12px;letter-spacing:.14em;font-weight:800;color:var(--gold,#d4a83a);text-transform:uppercase}
.tl-v2-reward .val{font-size:1.25rem;font-weight:800}.tl-v2-reward small{color:var(--muted,#9aa6bf)}
#form.tl-v2-club .tl-v2-kind{display:none!important}
.tl-v2-subhead{display:flex;align-items:center;gap:10px;margin:var(--sp-4,16px) 0 6px}.tl-v2-reward .tl-v2-subhead{margin:0 0 4px}
#form.tl-v2-on #points{display:none}`;
  document.head.append(s);
 }
 function card({icon,title,sub,checked,onPick,label}){
  const b=el('button','tl-v2-card');b.type='button';b.setAttribute('role','radio');b.setAttribute('aria-checked',String(!!checked));
  if(label)b.setAttribute('aria-label',label);
  const t=el('span');t.append(el('strong','',title));if(sub)t.append(el('small','',sub));
  b.append(el('span','ic',icon),t,el('span','ck',checked?'✓':''));b.addEventListener('click',onPick);
  b.addEventListener('keydown',e=>{const list=[...b.parentElement.querySelectorAll('.tl-v2-card')];const i=list.indexOf(b);
   if(['ArrowDown','ArrowRight'].includes(e.key)){e.preventDefault();list[(i+1)%list.length].focus()}
   if(['ArrowUp','ArrowLeft'].includes(e.key)){e.preventDefault();list[(i-1+list.length)%list.length].focus()}});
  return b;
 }
 function step(n,title){const s=el('section','tl-v2-step');s.dataset.step=String(n);const h=el('header');h.append(el('span','tl-v2-num',String(n)),el('h3','',title));s.append(h);return s}
 function focusStep(n){const s=state.ui?.root.querySelector(`[data-step="${n}"]`);if(!s)return;s.scrollIntoView({block:'center',behavior:'smooth'});s.querySelector('button')?.focus({preventScroll:true})}
 function remember(){try{localStorage.setItem('takeover_v2_choice_'+state.ctx.profile.id,JSON.stringify({loc:state.loc,choice:state.choice}))}catch{}}

 function setKind(typeId){const k=$('kind');if(!k||!typeId)return;if(String(k.value)!==String(typeId)){k.value=String(typeId);k.dispatchEvent(new Event('change',{bubbles:true}))}}
 function lastDateFor(dow){let d=swissToday();for(let i=0;i<7;i++){if(isoDow(d)===dow)return d;d=addDays(d,-1)}return d}

 function render(){
  const ui=state.ui,cfg=state.cfg,form=$('form');
  form.classList.add('tl-v2-on');form.classList.toggle('tl-v2-club',state.loc==='club');
  // Schritt 1
  ui.loc.replaceChildren();
  ui.loc.append(card({icon:'🏟️',title:'Im Verein / Gym',sub:'Pflicht- oder Ergänzungstraining',checked:state.loc==='club',onPick:()=>{state.loc='club';if(state.choice&&!slotOf()&&!extraOf())state.choice=null;remember();render();focusStep(2)}}),
   card({icon:'🏠',title:'Individuell / ausserhalb des Vereins',sub:'Joggen, Kraft, Heimtraining …',checked:state.loc==='individual',onPick:()=>{state.loc='individual';state.choice=null;remember();render()}}));
  ui.loc.setAttribute('role','radiogroup');ui.loc.setAttribute('aria-label','Wo hast du trainiert?');
  // Schritt 2
  ui.cat.hidden=!state.loc;ui.catBody.replaceChildren();
  const k=$('kind');
  // Individuell: Vereinsarten ausblenden (deaktivierte Optionen zeigen die Auswahlkarten nicht)
  if(k)for(const o of k.options){const t=cfg.types.find(x=>String(x.id)===o.value);o.disabled=!!(state.loc==='individual'&&t&&t.club_only)}
  if(k&&state.loc==='individual'&&k.selectedOptions[0]?.disabled){k.value='';k.dispatchEvent(new Event('change',{bubbles:true}))}
  if(state.loc==='club'){
   ui.cat.querySelector('h3').textContent='Welche Einheit?';
   const mk=(title,list,make)=>{if(!list.length)return;ui.catBody.append(el('div','tl-v2-group',title));const g=el('div','tl-v2-cards');g.setAttribute('role','radiogroup');g.setAttribute('aria-label',title);list.forEach(x=>g.append(make(x)));ui.catBody.append(g)};
   mk('PFLICHTTRAINING',cfg.pflicht,x=>card({icon:'🥊',title:`${x.day_name} – ${x.label}`,sub:rewardText(x.reward),label:`Pflichttraining ${x.day_name} – ${x.label}, ${rewardText(x.reward)}`,
    checked:state.choice?.kind==='slot'&&state.choice.id===x.slot_id,onPick:()=>{state.choice={kind:'slot',id:x.slot_id};setKind(x.training_type_id);
     const d=$('date');if(d&&(!d.value||isoDow(d.value)!==x.dow)){d.value=lastDateFor(x.dow);d.dispatchEvent(new Event('input',{bubbles:true}));d.dispatchEvent(new Event('change',{bubbles:true}))}
     remember();render()}}));
   mk('ERGÄNZUNGSTRAINING',cfg.extras,x=>card({icon:x.key==='athletik'?'💪':x.key==='technik'?'🎯':'🥊',title:x.label,sub:rewardText(x.reward)+' · an jedem Tag',label:`Ergänzungstraining ${x.label}, ${rewardText(x.reward)}`,
    checked:state.choice?.kind==='extra'&&state.choice.key===x.key,onPick:()=>{state.choice={kind:'extra',key:x.key};setKind(x.training_type_id);remember();render()}}));
   const s=slotOf();if(s)setKind(s.training_type_id);const e=extraOf();if(e)setKind(e.training_type_id);
  }else if(state.loc==='individual'){
   ui.cat.querySelector('h3').textContent='Welche Trainingsart?';
   ui.catBody.append(el('p','muted small','Wähle unten die Trainingsart. Es gilt der Wert der Trainingsart.'));
  }
  // Schritt 4: Vorschau aus der Server-Konfiguration
  updatePreview();
 }
 function updatePreview(){
  const ui=state.ui;if(!ui)return;const cfg=state.cfg,s=slotOf(),e=extraOf();
  let cat='',r=null;
  if(state.loc==='club'&&s){cat='Pflichttraining';r=s.reward}
  else if(state.loc==='club'&&e){cat='Ergänzungstraining';r=e.reward}
  else if(state.loc==='individual'){const t=cfg.types.find(x=>String(x.id)===String($('kind')?.value));if(t){cat='Individuelles Training · '+t.name;r=t.reward}}
  ui.reward.hidden=!r;ui.rewardCat.textContent=cat;ui.rewardVal.textContent=rewardText(r);
  // Datum prüfen
  const d=$('date')?.value;ui.dateMsg.textContent='';ui.dateMsg.className='tl-v2-msg';
  if(s&&d&&isoDow(d)!==s.dow){ui.dateMsg.textContent=`Achtung: «${s.label}» ist am ${s.day_name}. Das gewählte Datum ist ein ${DAYS[isoDow(d)-1]}.`;ui.dateMsg.className='tl-v2-msg bad'}
 }

 async function start(ctx){
  if(state.cfg||!ctx||!ctx.db)return;state.ctx=ctx;
  let r;try{r=await ctx.db.rpc('get_training_v2_config')}catch(e){return}
  if(!r||r.error||!r.data||r.data.enabled!==true||!Array.isArray(r.data.pflicht))return;
  state.cfg={pflicht:r.data.pflicht||[],extras:r.data.extras||[],types:r.data.types||[]};
  css();
  const form=$('form');if(!form)return;
  const k=$('kind'),kindLabel=document.querySelector('label[for="kind"]');
  // Trainingsart-Auswahl (Select + Auswahlkarten) als Block markieren, im Verein ausblenden
  if(kindLabel)kindLabel.classList.add('tl-v2-kind');if(k){k.classList.add('tl-v2-kind');const w=k.nextElementSibling;if(w&&w.classList.contains('tl-choice-field'))w.classList.add('tl-v2-kind')}
  new MutationObserver(()=>{const w=k&&k.nextElementSibling;if(w&&w.classList.contains('tl-choice-field'))w.classList.add('tl-v2-kind')}).observe(form,{childList:true,subtree:false});
  const root=el('div','tl-v2');root.id='trainingV2';
  const s1=step(1,'Wo hast du trainiert?'),loc=el('div','tl-v2-cards');s1.append(loc);
  const s2=step(2,'Welche Einheit?'),catBody=el('div');s2.append(catBody);
  root.append(s1,s2);form.prepend(root);
  const dh=el('div','tl-v2-subhead');dh.id='trainingV2Details';dh.append(el('span','tl-v2-num','3'),el('strong','','Details'));
  ($('joggingField')||$('techniqueField'))?.insertAdjacentElement('beforebegin',dh);
  const dateMsg=el('p','tl-v2-msg');dateMsg.setAttribute('role','status');$('date')?.insertAdjacentElement('afterend',dateMsg);
  const reward=el('div','tl-v2-reward');reward.id='trainingV2Reward';reward.setAttribute('aria-live','polite');
  const rewardCat=el('span','cat'),rewardVal=el('span','val');
  const rh=el('header','tl-v2-subhead');rh.append(el('span','tl-v2-num','4'),el('strong','','Voraussichtliche Belohnung'));
  reward.append(rh,rewardCat,rewardVal,el('small','','Die endgültige Gutschrift erfolgt nach Bestätigung durch deinen Trainer.'));
  const submit=$('submit');(submit?.closest('p')||submit)?.insertAdjacentElement('beforebegin',reward);
  state.ui={root,loc,cat:s2,catBody,reward,rewardCat,rewardVal,dateMsg};
  try{const saved=JSON.parse(localStorage.getItem('takeover_v2_choice_'+ctx.profile.id)||'null');if(saved&&['club','individual'].includes(saved.loc)){state.loc=saved.loc;state.choice=saved.choice||null;if(state.loc==='club'&&!slotOf()&&!extraOf())state.choice=null}}catch{}
  for(const id of ['date','kind'])$(id)?.addEventListener('change',updatePreview);
  $('date')?.addEventListener('input',updatePreview);
  document.addEventListener('takeover:training-fields-updated',updatePreview);
  const help=$('trainingHelp');if(help)help.textContent='Wähle zuerst, wo du trainiert hast. Vereinstrainings stuft dein Trainer beim Bestätigen ein – Punkte, EXP und Coins gibt es erst nach seiner Bestätigung.';
  render();
  try{
   const quick=await import('./takeover-club-today.js');
   quick.mountBoxerPrompt({db:ctx.db,cfg:{...state.cfg,enabled:true},onIndividual:()=>{
    state.loc='individual';state.choice=null;remember();render();
   }});
  }catch(err){console.warn('Club-Today-Prompt nicht geladen:',err)}
 }
 if(window.__tlTrainingCtx)start(window.__tlTrainingCtx);
 document.addEventListener('takeover:training-ctx',e=>start(e.detail));
})();
