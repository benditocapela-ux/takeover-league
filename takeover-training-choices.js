/* Training-page quick choices. Native date/number inputs remain authoritative. */
(function(){
 'use strict';
 const body=document.body;
 if(!body||body.dataset.tlScreen!=='boxer')return;
 const dateInput=document.getElementById('date');
 const techniqueInput=document.getElementById('techniqueMinutes');
 const create=(tag,className,text)=>{const node=document.createElement(tag);if(className)node.className=className;if(text)node.textContent=text;return node};
 function localSwissDate(offset=0){
  const parts=new Intl.DateTimeFormat('en-CA',{timeZone:'Europe/Zurich',year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(new Date());
  const part=type=>parts.find(x=>x.type===type)?.value||'';
  const date=new Date(Date.UTC(Number(part('year')),Number(part('month'))-1,Number(part('day'))+offset,12));
  return [date.getUTCFullYear(),String(date.getUTCMonth()+1).padStart(2,'0'),String(date.getUTCDate()).padStart(2,'0')].join('-');
 }
 function buildGroup(input,{title,hint,ariaLabel,choices}){
  if(!input)return null;
  const field=create('div','tl-choice-field tl-choice-presets');
  const heading=create('div','tl-choice-heading');
  heading.append(create('span','',title),create('small','',hint));
  const track=create('div','tl-choice-track');track.setAttribute('role','group');track.setAttribute('aria-label',ariaLabel);
  const buttons=choices.map(choice=>{
   const button=create('button','tl-choice-card');button.type='button';button.dataset.preset=choice.value;
   button.setAttribute('aria-pressed','false');
   const mark=create('span','tl-choice-mark');mark.setAttribute('aria-hidden','true');mark.textContent=choice.icon;
   const copy=create('span','tl-choice-copy',choice.label);
   const check=create('span','tl-choice-check','');check.setAttribute('aria-hidden','true');
   button.append(mark,copy,check);track.append(button);return button;
  });
  field.append(heading,track);input.insertAdjacentElement('afterend',field);
  return {field,buttons,track};
 }
 if(dateInput){
  const group=buildGroup(dateInput,{
   title:'Datum-Schnellwahl',hint:'Heute oder gestern übernehmen – für ein anderes Datum den Kalender nutzen.',
   ariaLabel:'Schnellauswahl für Trainingsdatum',
   choices:[{value:'today',label:'Heute',icon:'📅'},{value:'yesterday',label:'Gestern',icon:'🗓️'},{value:'custom',label:'Anderes Datum',icon:'✍️'}]
  });
  const sync=()=>{
   const value=dateInput.value,today=localSwissDate(),yesterday=localSwissDate(-1);
   const selected=value===today?'today':value===yesterday?'yesterday':'custom';
   group.buttons.forEach(button=>{
    const active=button.dataset.preset===selected;
    button.classList.toggle('is-selected',active);button.setAttribute('aria-pressed',String(active));
    const mark=button.querySelector('.tl-choice-check');mark.textContent=active?'✓':'';
   });
  };
  group.buttons.forEach(button=>button.addEventListener('click',()=>{
   if(button.dataset.preset==='custom'){
    dateInput.focus();
    try{if(typeof dateInput.showPicker==='function')dateInput.showPicker()}catch{}
    sync();return;
   }
   dateInput.value=localSwissDate(button.dataset.preset==='today'?0:-1);
   dateInput.dispatchEvent(new Event('input',{bubbles:true}));
   dateInput.dispatchEvent(new Event('change',{bubbles:true}));
   sync();
  }));
  dateInput.addEventListener('input',sync);dateInput.addEventListener('change',sync);
  document.addEventListener('takeover:training-fields-updated',sync);
  const form=dateInput.form;if(form)form.addEventListener('reset',()=>Promise.resolve().then(sync));
  sync();
 }
 if(techniqueInput){
  const group=buildGroup(techniqueInput,{
   title:'Technikdauer – Schnellwahl',hint:'Optional eine häufige Dauer antippen oder die Minuten frei eingeben.',
   ariaLabel:'Schnellauswahl für Technikminuten',
   choices:[30,45,60,90].map(value=>({value:String(value),label:value+' Min.',icon:'⏱️'}))
  });
  const sync=()=>group.buttons.forEach(button=>{
   const active=techniqueInput.value===button.dataset.preset;
   button.classList.toggle('is-selected',active);button.setAttribute('aria-pressed',String(active));
   button.querySelector('.tl-choice-check').textContent=active?'✓':'';
  });
  group.buttons.forEach(button=>button.addEventListener('click',()=>{
   techniqueInput.value=button.dataset.preset;
   techniqueInput.dispatchEvent(new Event('input',{bubbles:true}));
   techniqueInput.dispatchEvent(new Event('change',{bubbles:true}));
   sync();
  }));
  techniqueInput.addEventListener('input',sync);techniqueInput.addEventListener('change',sync);
  document.addEventListener('takeover:training-fields-updated',sync);
  const kind=document.getElementById('kind');if(kind)kind.addEventListener('change',sync);
  const form=techniqueInput.form;if(form)form.addEventListener('reset',()=>Promise.resolve().then(sync));
  sync();
 }
})();
