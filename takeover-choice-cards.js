/* Takeover League · interactive horizontal select cards
   Enhances existing native selects only. Original values, names, IDs and listeners stay intact.
   Intentionally not loaded on the Coach dashboard. */
(function(){
 'use strict';
 const body=document.body;
 if(!body||!body.hasAttribute('data-tl-screen')||body.dataset.tlScreen==='coach')return;
 const targets=new Set(document.querySelectorAll('form select'));
 document.querySelectorAll('select[data-tl-choice]').forEach(select=>targets.add(select));
 const icons=[
  [/sparring|duell|boxer|boxing/i,'🥊'],[/technik|ziel|challenge|target/i,'🎯'],
  [/kraft|strength/i,'💪'],[/sprint|intervall|tempo/i,'⚡'],[/jogg|lauf|km/i,'🏃'],
  [/wettkampf|arena|liga/i,'🏆'],[/exp|belohnung|punkte/i,'✨'],[/7 tage|woche/i,'⏱️'],
  [/14 tage|2 wochen/i,'🗓️'],[/30 tage|monat/i,'📅'],[/manuell|individuell|custom/i,'✍️'],
  [/training|einheit/i,'🥊'],[/coach/i,'🧑‍🏫']
 ];
 function symbol(label){
  for(const [pattern,emoji] of icons)if(pattern.test(label))return emoji;
  const parts=label.trim().split(/\s+/).filter(Boolean);
  return parts.length>1?(parts[0][0]+parts[1][0]).toLocaleUpperCase('de-CH'):(parts[0]||'•').slice(0,2).toLocaleUpperCase('de-CH');
 }
 function directLabel(select){
  if(select.getAttribute('aria-label'))return select.getAttribute('aria-label');
  const label=select.closest('label');
  if(label){
   const direct=Array.from(label.childNodes).filter(node=>node.nodeType===3).map(node=>node.textContent).join(' ').replace(/\s+/g,' ').trim();
   if(direct)return direct.replace(/[(:–-].*$/,'').trim()||direct;
  }
  const external=select.id&&document.querySelector('label[for="'+CSS.escape(select.id)+'"]');
  if(external)return external.textContent.trim();
  return select.name||select.id||'Auswahl';
 }
 function fireChange(select){
  select.dispatchEvent(new Event('input',{bubbles:true}));
  select.dispatchEvent(new Event('change',{bubbles:true}));
 }
 function enhance(select){
  if(select.dataset.tlChoiceEnhanced==='true')return;
  select.dataset.tlChoiceEnhanced='true';
  select.classList.add('tl-choice-native');
  const wrapper=document.createElement('div');wrapper.className='tl-choice-field';
  const track=document.createElement('div');track.className='tl-choice-track';
  track.setAttribute('role','group');track.setAttribute('aria-label',directLabel(select));
  const note=document.createElement('p');note.className='tl-choice-note';note.setAttribute('aria-live','polite');
  select.insertAdjacentElement('afterend',wrapper);wrapper.append(track);
  if(select.multiple)wrapper.append(note);
  const label=directLabel(select);
  function sync(){
   const selected=new Set(Array.from(select.selectedOptions).map(option=>option.value));
   track.querySelectorAll('button[data-value]').forEach(button=>{
    const active=selected.has(button.dataset.value);
    button.classList.toggle('is-selected',active);
    button.setAttribute('aria-pressed',String(active));
    const mark=button.querySelector('.tl-choice-check');
    if(mark)mark.textContent=active?'✓':(select.multiple?'+':'');
   });
   if(select.multiple){
    const count=selected.size;
    const valid=count>=3&&count<=8;
    note.textContent=valid?count+' Boxer ausgewählt.':count+' ausgewählt · Wähle 3–8 Boxer.';
    note.classList.toggle('is-valid',valid);
   }
   wrapper.classList.toggle('is-disabled',select.disabled);
  }
  function render(){
   const options=Array.from(select.options).filter(option=>!(option.value===''&&select.required)&&!option.disabled);
   track.replaceChildren();
   if(!options.length){
    const empty=document.createElement('span');empty.className='tl-choice-empty';
    empty.textContent='Auswahl wird geladen …';track.append(empty);
   }
   for(const option of options){
    const button=document.createElement('button');button.type='button';button.className='tl-choice-card';
    button.dataset.value=option.value;button.disabled=select.disabled;
    button.setAttribute('aria-label',option.textContent.trim());
    button.setAttribute('aria-pressed',String(option.selected));
    const mark=document.createElement('span');mark.className='tl-choice-mark';mark.setAttribute('aria-hidden','true');mark.textContent=symbol(option.textContent);
    const copy=document.createElement('span');copy.className='tl-choice-copy';copy.textContent=option.textContent.trim();
    const check=document.createElement('span');check.className='tl-choice-check';check.setAttribute('aria-hidden','true');check.textContent=option.selected?'✓':(select.multiple?'+':'');
    button.append(mark,copy,check);
    button.addEventListener('click',()=>{
     if(select.disabled||option.disabled)return;
     if(select.multiple)option.selected=!option.selected;
     else select.value=option.value;
     fireChange(select);sync();
    });
    track.append(button);
   }
   sync();
  }
  select.addEventListener('change',sync);
  select.addEventListener('reset',sync);
  const form=select.form;
  if(form)form.addEventListener('reset',()=>Promise.resolve().then(sync));
  const observer=new MutationObserver(render);
  observer.observe(select,{childList:true,subtree:true,attributes:true,attributeFilter:['disabled','label','value']});
  render();
 }
 targets.forEach(enhance);
})();