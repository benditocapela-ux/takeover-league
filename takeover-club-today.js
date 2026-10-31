/* Scheduled club training: one-tap request and fixed schedule.
 * Own training still uses boxer.html. Server is authoritative for slot, date and rewards.
 */
const e=(tag,cls,value)=>{const n=document.createElement(tag);if(cls)n.className=cls;if(value!=null)n.textContent=value;return n};
const isoDow=()=>{
 const s=new Intl.DateTimeFormat('en-US',{weekday:'long',timeZone:'Europe/Zurich'}).format(new Date()).toLowerCase();
 return {monday:1,tuesday:2,wednesday:3,thursday:4,friday:5,saturday:6,sunday:7}[s]||0;
};
const label=x=>(x.day_name||'')+' · '+(x.label||'Vereinstraining');
function styles(){
 if(document.getElementById('ct-style'))return;
 const s=e('style');s.id='ct-style';
 s.textContent='.ct-panel{margin:12px 0 18px;padding:16px;background:linear-gradient(145deg,#182841,#101a2c);border:1px solid #be9e5c;border-radius:14px}'
 +'.ct-panel h2{margin:4px 0 10px}.ct-panel p{color:var(--muted,#aac0d8)}'
 +'.ct-kicker{font-size:11px;color:#f2c14e;letter-spacing:1.5px;font-weight:800}'
 +'.ct-actions{display:flex;gap:10px;flex-wrap:wrap;margin:12px 0}.ct-actions button,.ct-actions a,.ct-item button{min-height:44px;padding:10px 14px;border-radius:9px;border:1px solid #a58750;background:#efc560;color:#171522;text-decoration:none;font:700 14px system-ui;cursor:pointer}'
 +'.ct-actions .ct-secondary{background:#182943;color:#f9da93}.ct-actions button:disabled,.ct-item button:disabled{opacity:.5}'
 +'.ct-result{border:1px solid #465575;border-radius:9px;padding:12px;background:#122037;color:#e8eef8}.ct-result[hidden]{display:none!important}.ct-error{color:#ffadad;border-color:#e07070}'
 +'.ct-list{display:grid;gap:8px;margin-top:12px}.ct-item{display:flex;justify-content:space-between;align-items:center;gap:12px;border:1px solid #364a64;background:#101e32;padding:12px;border-radius:10px}'
 +'.ct-item.ct-today{border-color:#dfb45e}.ct-item b{display:block}.ct-item small{display:block;font-size:11px;color:#acbfd5;margin-top:4px}'
 +'@media(max-width:420px){.ct-item{flex-direction:column;align-items:stretch}.ct-item button{width:100%}}';
 document.head.append(s);
}
const messages={
 submitted:r=>'Dein heutiges Vereinstraining «'+r.label+'» wurde automatisch eingetragen und zur Trainerfreigabe eingereicht.',
 already_pending:()=>'Dein heutiges Vereinstraining ist bereits zur Freigabe eingereicht. Kein doppelter Eintrag.',
 already_approved:()=>'Dein heutiges Vereinstraining ist bereits bestätigt. Kein doppelter Eintrag.',
 gym_registered:()=>'Du bist heute bereits im Gym eingecheckt. Es wurde kein zweiter Antrag erstellt.',
 checkin_required:()=>'Dein Verein verwendet den verpflichtenden Gym-Check-in. Melde dich bei der vom Trainer gestarteten Einheit an.',
 no_slot:()=>'Heute ist kein Pflichttraining im Stundenplan hinterlegt. Du kannst dein eigenes Training eintragen.',
 choose_slot:()=>'Heute gibt es mehrere Vereinseinheiten. Bitte wähle die passende Einheit.',
 disabled:()=>'Training 2.0 ist noch nicht freigeschaltet. Verwende das bisherige Formular.'
};
async function submit(db,slot,btn,output,cfg){
 if(btn)btn.disabled=true;
 output.hidden=false;output.classList.remove('ct-error');output.replaceChildren(e('p','','Antrag wird gespeichert …'));
 try{
  const r=await db.rpc('submit_scheduled_club_training_today',{p_slot_id:slot==null?null:Number(slot)});
  if(r.error)throw r.error;
  const result=r.data||{},format=messages[result.status];
  output.replaceChildren(e('p','',format?format(result):'Unbekannte Serverantwort. Bitte überprüfe deinen Verlauf.'));
  if(result.status==='choose_slot'){
   const list=e('div','ct-actions');
   for(const x of (cfg.pflicht||[]).filter(x=>Number(x.dow)===isoDow())){
    const b=e('button','ct-secondary',label(x));b.type='button';b.addEventListener('click',()=>submit(db,x.slot_id,b,output,cfg));list.append(b);
   }
   output.append(list);
  }
  if(result.status==='checkin_required'){
   const link=e('a','','Zum Gym-Check-in');link.href='./checkin.html';output.append(link);
  }
  if(['no_slot','disabled'].includes(result.status))output.classList.add('ct-error');
  if(result.status==='submitted')document.dispatchEvent(new CustomEvent('takeover:club-today-submitted',{detail:result}));
 }catch(error){
  output.replaceChildren(e('p','','Antrag nicht gespeichert: '+String(error.message||error)));
  output.classList.add('ct-error');
 }finally{if(btn)btn.disabled=false}
}
export function mountBoxerPrompt({db,cfg,onIndividual}){
 const form=document.getElementById('form');
 if(!form||!db||cfg?.enabled!==true||document.getElementById('ct-boxer'))return;
 styles();
 const panel=e('section','ct-panel');panel.id='ct-boxer';
 panel.append(e('span','ct-kicker','HEUTIGES TRAINING'),e('h2','','Warst du heute im Vereinstraining?'),
  e('p','','Bei Ja wird das heutige Pflichttraining mit den Vereinsvorgaben zur Trainerfreigabe beantragt.'));
 const choices=e('div','ct-actions');
 const yes=e('button','','Ja, im Verein');const no=e('button','ct-secondary','Nein, eigenes Training');
 yes.type='button';no.type='button';choices.append(yes,no);panel.append(choices);
 const result=e('div','ct-result');result.hidden=true;result.setAttribute('role','status');result.setAttribute('aria-live','polite');panel.append(result);
 form.before(panel);form.hidden=true;
 yes.addEventListener('click',()=>submit(db,null,yes,result,cfg));
 no.addEventListener('click',()=>{
  if(typeof onIndividual==='function')onIndividual();
  form.hidden=false;panel.hidden=true;form.scrollIntoView({block:'start',behavior:'smooth'});
 });
 if(new URLSearchParams(location.search).get('individual')==='1')no.click();
}
export function mountCheckinSchedule({db,cfg,role}){
 if(role!=='boxer'||cfg?.enabled!==true||document.getElementById('ct-checkin'))return;
 const app=document.getElementById('app');if(!app)return;
 styles();
 const panel=e('section','ct-panel');panel.id='ct-checkin';
 panel.append(e('span','ct-kicker','FIXER VEREINSSTUNDENPLAN'),e('h2','','Deine Vereinstrainings'));
 const list=e('div','ct-list'),result=e('div','ct-result');result.hidden=true;result.setAttribute('role','status');result.setAttribute('aria-live','polite');
 const slots=(cfg.pflicht||[]).slice().sort((a,b)=>Number(a.dow)-Number(b.dow));
 if(!slots.length)panel.append(e('p','','Der Verein hat noch keine Pflichttrainings hinterlegt.'));
 for(const x of slots){
  const item=e('div','ct-item'+(Number(x.dow)===isoDow()?' ct-today':''));
  const copy=e('span');copy.append(e('b','',label(x)),e('small','',String(x.duration_minutes||'–')+' Minuten · Trainerfreigabe erforderlich'));
  item.append(copy);
  if(Number(x.dow)===isoDow()){
   const b=e('button','','Heute beantragen');b.type='button';
   b.addEventListener('click',()=>submit(db,x.slot_id,b,result,cfg));item.append(b);
  }
  list.append(item);
 }
 panel.append(list,result);
 const links=e('div','ct-actions'),own=e('a','ct-secondary','Eigenes Training eintragen');
 own.href='./boxer.html?individual=1#trainingFormCard';links.append(own);panel.append(links);
 app.before(panel);
}
