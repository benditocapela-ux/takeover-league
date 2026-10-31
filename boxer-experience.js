/* Takeover League 3.0 · Boxer Experience: die einzige Boxer-Oberfläche (Heute, Training, Kämpfe, Liga, Mein Boxer).
 * Vereinstraining per Ein-Klick-RPC (submit_scheduled_club_training_today), eigenes Training im integrierten
 * Formular (takeover-training-form.js, gleiche Regeln wie das bisherige Formular), Studio-Funktionen in
 * boxer-experience-studio.js. Keine Punkte-, EXP- oder Coin-Buchungen im Browser; kein iframe.
 * Unteransichten per Hash: #training/eigenes, #training/verein, #training/historie, #heute/mitteilungen, #boxer/profil.
 */
(function () {
  'use strict';
  const $ = id => document.getElementById(id);
  const state = { db:null, profile:null, current:'heute', leaderboard:[], types:[], cfg:null, checkinOnly:false, form:false, formApi:null, pendingSub:'', quickBusy:false };
  const navTabs = ['heute','training','kaempfe','liga','boxer'];
  const fmt = n => Number(n).toLocaleString('de-CH',{maximumFractionDigits:0});
  const empty = (selector,message) => { const node=$(selector); if(node)node.textContent=message; };
  const setText = (id,value) => {const node=$(id);if(node)node.textContent=String(value);};
  const asNumber = value => Number.isFinite(Number(value)) ? Number(value) : null;
  const dateZurich = date => new Intl.DateTimeFormat('en-CA',{timeZone:'Europe/Zurich',year:'numeric',month:'2-digit',day:'2-digit'}).format(date);
  const dayLabel = value => {try{return new Intl.DateTimeFormat('de-CH',{day:'2-digit',month:'short',year:'numeric'}).format(new Date(value+'T12:00:00'))}catch(_){return value||'–'}};
  function showGate(title,message,link,href){
    $('ex-app').hidden=true;$('ex-gate').hidden=false;
    setText('ex-gate-title',title);setText('ex-gate-message',message);
    const a=$('ex-gate-link');a.hidden=!link;
    if(link){a.textContent=link;a.href=href||'./login.html?next=boxer-experience.html';}
  }
  const SUB_TARGET={historie:'ex-history-card',mitteilungen:'ex-notify-card',profil:'ex-profile'};
  function selectTab(name,sub){
    if(!navTabs.includes(name))return;
    const changed=state.current!==name;
    state.current=name;
    for(const section of document.querySelectorAll('[data-view]')){
      const current=section.dataset.view===name;
      section.classList.toggle('active',current);
      section.hidden=!current;
    }
    for(const button of document.querySelectorAll('[data-tab]')){
      const current=button.dataset.tab===name;
      button.setAttribute('aria-current',current?'page':'false');
    }
    $('ex-home-stage').hidden=name!=='heute';
    $('ex-card-stage').hidden=name!=='boxer';
    if(changed||!sub)$('ex-scroll').scrollTop=0;
    if(sub==='eigenes'||sub==='verein')openForm(sub==='verein'?'club':'individual');
    else if(name==='training'&&state.form&&!sub)closeForm(false);
    const target=SUB_TARGET[sub]&&$(SUB_TARGET[sub]);
    if(target)requestAnimationFrame(()=>target.scrollIntoView({block:'start'}));
  }
  function parseHash(){const [tab,sub]=decodeURIComponent(location.hash.replace(/^#/,'')).split('/');return {tab:navTabs.includes(tab)?tab:'heute',sub:sub||''}}
  function go(tab,sub,push){
    const hash='#'+tab+(sub?'/'+sub:'');
    try{if(location.hash!==hash){if(push)history.pushState(null,'',hash);else history.replaceState(null,'',hash)}}catch(_){}
    selectTab(tab,sub);
  }
  function bindNavigation(){
    document.querySelectorAll('[data-tab],[data-open-tab]').forEach(node=>node.addEventListener('click',()=>go(node.dataset.tab||node.dataset.openTab,'',true)));
    window.addEventListener('popstate',()=>{const h=parseHash();selectTab(h.tab,h.sub)});
    window.addEventListener('hashchange',()=>{const h=parseHash();selectTab(h.tab,h.sub)});
    const h=parseHash();state.pendingSub=h.sub;selectTab(h.tab,'');
  }
  async function safeRpc(name,args){
    try{const r=await state.db.rpc(name,args||{});return r.error?null:r.data}catch(_){return null}
  }
  function safeHolo(config,opts){
    if(!config || !window.TLHolo || typeof window.TLHolo.svg!=='function')return null;
    try{return window.TLHolo.svg(window.TLHolo.normalize(config),opts||{pose:'guard',scene:'none',holo:false})}
    catch(err){console.warn('[boxer-experience] Holo could not render',err);return null}
  }
  function showMyHolo(look){
    const host=$('ex-home-holo');
    const svg=safeHolo(look,{pose:look?.pose_profile||'guard',scene:'none',holo:false,label:'Dein Boxer-Holo'});
    if(svg)host.innerHTML=svg;
    else host.innerHTML='<span class="ex-note">Dein Holo ist noch nicht verfügbar.</span>';
  }
  async function loadMyPerformance(){
    const [result,cardLooks,holoLooks]=await Promise.all([
      safeRpc('get_my_performance'),
      safeRpc('get_card_looks',{p_display_names:[state.profile.display_name]}),
      safeRpc('get_holo_looks',{p_display_names:[state.profile.display_name]})
    ]);
    const name=state.profile.display_name,lower=name.toLocaleLowerCase('de-CH');
    const getLook=(obj)=>obj&&typeof obj==='object'?
      Object.entries(obj).find(([k])=>k.toLocaleLowerCase('de-CH')===lower)?.[1]||null:null;
    const holoConfig=getLook(holoLooks);
    const cardLook=getLook(cardLooks)||{};
    const look={...cardLook,holo:holoConfig};
    showMyHolo(holoConfig);
    const P=window.TLPerf;
    const rating=result?.rating?.current?.summary;
    const style=result?.style?.current?.scores;
    const type=style&&P&&P.styleType?P.styleType(style):null;
    const pos=type?.pos||'BOX';
    setText('ex-pos',type?.title||'BOX');
    if(rating&&P&&P.card){
      const current=rating.public&&rating.public.overall!=null?rating.public:rating;
      if(Number.isFinite(Number(current.overall))&&current.categories){
        $('ex-fut-card').innerHTML=P.card({
          name,overall:Number(current.overall),categories:current.categories,pos,
          width:185,look:look
        });
        setText('ex-overall',Number(current.overall));
      }else{
        empty('ex-fut-card','Deine FUT-Card wird nach der ersten Coach-Bewertung angezeigt.');
      }
    }else{
      $('ex-fut-card').innerHTML='<div class="ex-card-absence">Noch keine Coach-Bewertung vorhanden. Hier wird später deine FUT-Card angezeigt.</div>';
      setText('ex-overall','–');
    }
    if(style&&P&&P.radarSVG){
      $('ex-radar').innerHTML=P.radarSVG(style,null,330);
      setText('ex-style-title',type?.title||'Dein Boxstil');
      setText('ex-style-text',type?.text||'Dein Boxstil wurde ausgewertet.');
    }else{
      empty('ex-radar','Noch kein Boxstil-Test vorhanden.');
      setText('ex-style-title','Dein Boxstil ist noch offen');
      setText('ex-style-text','Mache den Boxstil-Test, um hier dein persönliches Diagramm zu sehen.');
    }
  }
  function renderPodium(rows,looks){
    const host=$('ex-podium');host.replaceChildren();
    if(!rows.length){const p=document.createElement('p');p.className='ex-muted';p.textContent='Die Rangliste enthält noch keine Boxer.';host.append(p);return;}
    const sorted=rows.slice().filter(r=>r?.boxer_name&&asNumber(r.monthly_points)!==null)
      .sort((a,b)=>(Number(a.rank_position)||9999)-(Number(b.rank_position)||9999));
    const podium=[sorted[1]||null,sorted[0]||null,sorted[2]||null];
    for(const [i,boxer] of podium.entries()){
      const order=[2,1,3][i];
      const step=document.createElement(boxer?'a':'div');
      step.className='ex-step '+(order===1?'first':order===3?'third':'second');
      if(boxer){step.href='./boxer-profile.html?name='+encodeURIComponent(boxer.boxer_name);step.setAttribute('aria-label','Platz '+order+': '+boxer.boxer_name);}
      const figure=document.createElement('div');figure.className='ex-podium-holo';
      const config=boxer&&looks&&Object.entries(looks).find(([n])=>n.toLocaleLowerCase('de-CH')===String(boxer.boxer_name).toLocaleLowerCase('de-CH'))?.[1];
      const svg=safeHolo(config,{pose:config?.pose_profile||'guard',scene:'none',holo:false,label:'Holo von '+(boxer?.boxer_name||'')});
      if(svg)figure.innerHTML=svg;
      else{const marker=document.createElement('span');marker.textContent='🥊';marker.style.fontSize='48px';marker.setAttribute('aria-label','Kein Holo verfügbar');figure.append(marker)}
      const name=document.createElement('div');name.className='ex-step-name';name.textContent=boxer?boxer.boxer_name:'Noch offen';
      const points=document.createElement('div');points.className='ex-step-points';points.textContent=boxer?fmt(boxer.monthly_points)+' P':'–';
      const base=document.createElement('div');base.className='ex-step-base';base.textContent=String(order);
      step.append(figure,name,points,base);host.append(step);
    }
  }
  async function loadLeaderboard(){
    const rows=await safeRpc('get_public_leaderboard');
    if(!Array.isArray(rows)){
      empty('ex-podium','Rangliste derzeit nicht verfügbar. Nutze die bestehende Liga-Seite.');
      return;
    }
    state.leaderboard=rows;
    const mine=rows.find(r=>String(r.boxer_name||'').toLocaleLowerCase('de-CH')===state.profile.display_name.toLocaleLowerCase('de-CH'));
    const rank=mine&&Number(mine.monthly_points)>0&&Number(mine.rank_position)>0?'#'+mine.rank_position:'–';
    setText('ex-home-rank',rank);setText('ex-league-rank',rank);
    setText('ex-league-points',mine?fmt(mine.monthly_points):'–');
    const top=rows.filter(r=>r.boxer_name).slice().sort((a,b)=>(Number(a.rank_position)||9999)-(Number(b.rank_position)||9999)).slice(0,3);
    const looks=top.length?await safeRpc('get_holo_looks',{p_display_names:top.map(r=>r.boxer_name)}):null;
    renderPodium(rows,looks);
  }
  /* Training 2.0: Die Konfiguration kommt aus public.get_training_v2_config (keine lokale Kopie der Regeln).
   * «Ja, im Verein» → submit_scheduled_club_training_today (Server entscheidet: Check-in oder Antrag).
   * «Nein, eigenes Training» → integriertes Formular (takeover-training-form.js). Keine Vorschau ist eine Gutschrift. */
  function trainingOption(title,detail,href,subtitle){
    const a=document.createElement('a');
    a.className='ex-link-card';a.href=href;
    const h=document.createElement('b');h.textContent=title;
    const sub=document.createElement('small');sub.textContent=detail;
    a.append(h,sub);
    if(subtitle){const more=document.createElement('small');more.textContent=subtitle;more.style.color='#f2c14e';a.append(more)}
    return a;
  }
  function choiceButton(title,detail,primary,onClick){
    const b=document.createElement('button');b.type='button';b.className='ex-choice'+(primary?' primary':'');
    const h=document.createElement('b');h.textContent=title;const sub=document.createElement('small');sub.textContent=detail;
    b.append(h,sub);b.addEventListener('click',onClick);return b;
  }
  function trainingReward(value){
    const points=Number(value?.points),exp=Number(value?.exp),coins=Number(value?.coins);
    return [Number.isFinite(points)?fmt(points)+' Punkte':null,
            Number.isFinite(exp)?fmt(exp)+' EXP':null,
            Number.isFinite(coins)?fmt(coins)+' Coins':null].filter(Boolean).join(' · ');
  }
  function openForm(mode){
    if(!state.formApi){state.pendingSub=mode==='club'?'verein':'eigenes';return}
    $('ex-training-form').hidden=false;state.form=true;
    state.formApi.open(mode);
  }
  function closeForm(navigate){
    const host=$('ex-training-form');if(host)host.hidden=true;state.form=false;
    if(navigate)go('training','',false);
    const head=document.querySelector('[data-view="training"] .ex-card h3');if(navigate&&head){head.tabIndex=-1;head.focus({preventScroll:true})}
  }
  function mountForm(){
    if(!window.TLTrainingForm||state.formApi)return;
    state.formApi=window.TLTrainingForm.mount($('ex-training-form'),{db:state.db,profile:state.profile,cfg:state.cfg,types:state.types,
      checkinOnly:state.checkinOnly,onSubmitted:()=>{void loadTraining();if(window.TLStudio)void window.TLStudio.refresh()},onClose:()=>closeForm(true)});
    if(state.pendingSub==='eigenes'||state.pendingSub==='verein'){const sub=state.pendingSub;state.pendingSub='';go('training',sub,false)}
    else if(state.pendingSub){const sub=state.pendingSub;state.pendingSub='';selectTab(state.current,sub)}
  }
  function trainingFallback(host){
    host.replaceChildren();
    const p=document.createElement('p');p.className='ex-muted';
    p.textContent='Trage dein Training ein. Dein Trainer bestätigt es und legt die Gutschrift fest.';
    const actions=document.createElement('div');actions.className='ex-choice-actions';
    actions.append(choiceButton('＋ Training eintragen','Trainingsart, Datum, Dauer und Bemerkung',true,()=>go('training','eigenes',true)));
    host.append(p,actions);
  }
  function todayDow(){
    const day=new Intl.DateTimeFormat('en-US',{timeZone:'Europe/Zurich',weekday:'long'}).format(new Date()).toLowerCase();
    return {monday:1,tuesday:2,wednesday:3,thursday:4,friday:5,saturday:6,sunday:7}[day]||0;
  }
  function clubResponseMessage(r){
    switch(r?.status){
      case 'submitted':return 'Dein heutiges Vereinstraining «'+r.label+'» wurde automatisch eingetragen und zur Trainerfreigabe eingereicht.';
      case 'already_pending':return 'Dein heutiges Vereinstraining wurde bereits eingereicht und wartet auf Freigabe. Kein Doppeleintrag.';
      case 'already_approved':return 'Dein heutiges Vereinstraining wurde bereits bestätigt. Kein Doppeleintrag.';
      case 'already_checked_in':return 'Du bist für die heutige Vereinseinheit bereits eingecheckt. Dein Trainer bestätigt später deine Anwesenheit. Kein Doppeleintrag.';
      case 'checked_in':return 'Erfolgreich eingecheckt! Das heutige Vereinstraining ist als Anwesenheit registriert und wird vom Trainer bestätigt.';
      case 'gym_not_open':return 'Das heutige Vereinstraining wurde vom Trainer noch nicht zum Check-in geöffnet. Bitte versuche es nach dem Trainingsstart erneut.';
      case 'choose_gym_session':return 'Mehrere Gym-Einheiten sind geöffnet. Bitte wähle die richtige im Gym-Check-in.';
      case 'no_slot':return 'Heute ist kein Pflichttraining hinterlegt. Du kannst ein individuelles Training erfassen.';
      case 'choose_slot':return 'Mehrere Vereinseinheiten sind heute geplant. Bitte wähle die richtige Einheit.';
      case 'disabled':return 'Der Ein-Klick-Antrag ist derzeit nicht aktiviert. Erfasse dein Training im Formular.';
      default:return 'Die Einreichung konnte nicht bestätigt werden. Bitte prüfe deine Trainingshistorie.';
    }
  }
  async function loadTrainingConfiguration(){
    const host=$('ex-training-options');if(!host)return;
    // Supabase-Abfragen sind nur «thenable» (kein .catch): Fehler deshalb mit try/await abfangen.
    const flags=async()=>{try{return await state.db.from('league_feature_flags').select('feature_key,is_enabled').in('feature_key',['gym_training','club_checkin_only'])}catch(_){return {error:true}}};
    const types=async()=>{try{return await state.db.from('training_types').select('*').eq('is_active',true).order('name')}catch(_){return {error:true}}};
    const [cfg,checkin,typeRows]=await Promise.all([safeRpc('get_training_v2_config'),flags(),types()]);
    state.types=typeRows&&!typeRows.error&&Array.isArray(typeRows.data)?typeRows.data:[];
    // Nur betreuter Check-in gilt wie in PR #84 erst, wenn gym_training UND club_checkin_only an sind.
    const checkinOnly=!checkin.error&&Array.isArray(checkin.data)&&['gym_training','club_checkin_only'].every(k=>checkin.data.some(x=>x.feature_key===k&&x.is_enabled===true));
    state.checkinOnly=checkinOnly;
    state.cfg=cfg?.enabled===true&&Array.isArray(cfg.pflicht)&&Array.isArray(cfg.extras)?cfg:null;
    mountForm();
    if(!state.cfg){trainingFallback(host);return}
    host.replaceChildren();
    const title=document.createElement('h3');title.textContent='Warst du heute im Vereinstraining?';
    host.append(title);
    const help=document.createElement('p');help.className='ex-muted';
    help.textContent='Mit Ja wird die heutige Pflichteinheit automatisch erfasst: bei einer geöffneten Gym-Einheit per Check-in, ansonsten bei erlaubter Selbstmeldung als Antrag zur Freigabe.';
    host.append(help);
    const actions=document.createElement('div');actions.className='ex-choice-actions';
    const yes=choiceButton('✓ Ja, im Verein','Heutige Pflichteinheit mit einem Tipp melden',true,()=>submit(null,yes));
    const no=choiceButton('✕ Nein, eigenes Training','Training hier im Formular erfassen',false,()=>go('training','eigenes',true));
    actions.append(yes,no);host.append(actions);
    const status=document.createElement('div');status.className='ex-note';status.setAttribute('role','status');status.setAttribute('aria-live','polite');status.hidden=true;status.style.marginTop='10px';host.append(status);
    const dow=todayDow();
    const slots=state.cfg.pflicht.filter(x=>Number(x.dow)===dow);
    const schedule=document.createElement('p');schedule.className='ex-muted';
    schedule.textContent=slots.length?
      'Heute geplant: '+slots.map(x=>String(x.label||'Vereinstraining')).join(' / '):
      'Heute ist keine Pflichteinheit im Stundenplan eingeplant.';
    host.append(schedule);
    async function submit(slotId,button){
      if(state.quickBusy)return;state.quickBusy=true;
      if(button)button.disabled=true;status.hidden=false;status.textContent='Dein Training wird erfasst …';
      try{
        const r=await state.db.rpc('submit_scheduled_club_training_today',{p_slot_id:slotId==null?null:Number(slotId)});
        if(r.error)throw r.error;
        status.replaceChildren(document.createTextNode(clubResponseMessage(r.data)));
        if(r.data?.status==='choose_slot'){
          const options=document.createElement('div');options.className='ex-grid';options.style.marginTop='9px';
          for(const slot of slots){
            const b=document.createElement('button');b.type='button';b.className='ex-link-card';
            b.textContent=String(slot.label||'Vereinstraining');
            b.addEventListener('click',()=>submit(slot.slot_id,b));options.append(b);
          }
          status.append(options);
        }
        if(['gym_not_open','choose_gym_session'].includes(r.data?.status))
          status.append(trainingOption('ZUM GYM-CHECK-IN','Geöffnete Vereinseinheit auswählen','./checkin.html'));
        if(['no_slot','disabled'].includes(r.data?.status)){const b=document.createElement('button');b.type='button';b.className='ex-btn ex-btn-ghost';b.style.marginTop='9px';b.textContent='Eigenes Training erfassen';b.addEventListener('click',()=>go('training','eigenes',true));status.append(b)}
        if(['submitted','checked_in'].includes(r.data?.status)){await loadTraining();if(window.TLStudio)void window.TLStudio.refresh()}
      }catch(err){
        status.textContent='Antrag nicht gespeichert: '+String(err.message||err)+'. Bitte nicht blind erneut einreichen.';
      }finally{state.quickBusy=false;if(button)button.disabled=false}
    }
    if(checkinOnly){
      const notice=document.createElement('p');notice.className='ex-note';
      notice.textContent='Dein Verein verwendet den betreuten Gym-Check-in. Mit Ja wirst du bei einer vom Trainer geöffneten Pflicht-Einheit angemeldet; ohne geöffnete Einheit ist keine Selbstmeldung möglich.';
      host.append(notice);
    }
    const extra=document.createElement('p');extra.className='ex-muted';
    extra.textContent='Ergänzungstraining im Verein (Sandsack, Athletik, Technik) meldest du mit Trainerfreigabe:';
    host.append(extra);
    if(checkinOnly)host.append(trainingOption('ERGÄNZUNGSTRAINING IM VEREIN','Sandsack, Athletik oder Technik per Gym-Check-in','./checkin.html'));
    else{const g=document.createElement('div');g.className='ex-choice-actions';g.append(choiceButton('Ergänzungstraining im Verein','Sandsack, Athletik oder Technik mit Trainerfreigabe',false,()=>go('training','verein',true)));host.append(g)}
  }
  async function loadTraining(){
    const db=state.db, id=state.profile.id;
    const entries=await db.from('training_submissions').select('training_date,status,training_type_id,created_at').eq('boxer_id',id).order('created_at',{ascending:false}).limit(200);
    if(entries.error)return;
    const rows=Array.isArray(entries.data)?entries.data:[];
    const current=dateZurich(new Date()),start=new Date(current+'T12:00:00Z');start.setUTCDate(start.getUTCDate()-6);const from=dateZurich(start);
    const approved=rows.filter(r=>r.status==='approved'&&r.training_date>=from&&r.training_date<=current).length;
    const pending=rows.filter(r=>r.status==='pending').length;
    setText('ex-week-sessions',approved);setText('ex-pending',pending);
  }
  async function loadLevel(){
    const flag=await state.db.from('league_feature_flags').select('is_enabled').eq('feature_key','performance_dashboard').maybeSingle();
    if(flag.error||flag.data?.is_enabled!==true){setText('ex-level','–');setText('ex-exp','Noch nicht freigeschaltet');return;}
    const x=await safeRpc('get_boxer_exp_level_rank',{p_boxer_id:state.profile.id});
    const data=Array.isArray(x)?x[0]:x;
    if(!data){setText('ex-level','–');return;}
    const xp=Math.max(0,Number(data.lifetime_exp)||0);
    const n=Math.min(98,Math.floor((Math.sqrt(49+0.32*xp)-7)/2));
    const level=n+1,threshold=100*n+25*n*(n-1)/2,needed=100+25*n;
    setText('ex-level','LVL '+String(level).padStart(2,'0'));
    setText('ex-exp',fmt(Math.max(0,xp-threshold))+' / '+fmt(needed)+' EXP');
  }
  async function init(){
    bindNavigation();
    const P=window.TLPerf;
    if(!P||!P.client){showGate('NICHT VERFÜGBAR','Die Datenanbindung konnte nicht geladen werden. Bitte prüfe deine Verbindung.','Zur Anmeldung');return}
    try{
      state.db=await P.client();
      const auth=await state.db.auth.getUser();
      const user=auth.data?.user;
      if(auth.error||!user){showGate('BITTE ANMELDEN','Melde dich mit deinem Boxer-Konto an, um dein Dashboard und deine Daten zu sehen.','ANMELDEN');return}
      const pr=await state.db.from('profiles').select('id,display_name,role,is_active,avatar_key,avatar_url').eq('auth_user_id',user.id).maybeSingle();
      const profile=pr.data;
      if(pr.error||!profile||!profile.is_active){showGate('KEIN AKTIVES PROFIL','Für dieses Konto ist kein aktiver Boxer freigeschaltet.','ZUM LOGIN');return}
      if(profile.role!=='boxer'){const home=profile.role==='admin'?'./admin.html':'./coach.html';showGate('BOXER-BEREICH','Mein Takeover ist der Bereich für Boxer. Dein Konto hat eine eigene Oberfläche.',profile.role==='admin'?'ZUR CLUBVERWALTUNG':'ZUM TRAINER-DASHBOARD',home);return}
      state.profile=profile;
      setText('ex-home-name',profile.display_name||'MEIN BOXER');
      setText('ex-welcome','Willkommen, '+profile.display_name+'. Dein nächster Schritt ist nur einen Klick entfernt.');
      $('ex-gate').hidden=true;$('ex-app').hidden=false;
      const av=$('ex-account-avatar');if(av)av.textContent=String(profile.display_name||'?').trim().split(/\s+/).slice(0,2).map(x=>x[0]||'').join('').toUpperCase()||'👤';
      await Promise.allSettled([loadMyPerformance(),loadLeaderboard(),loadTraining(),loadLevel(),loadTrainingConfiguration()]);
      if(window.TLStudio)await window.TLStudio.mount({db:state.db,profile:state.profile,types:state.types});
      if(state.pendingSub){const sub=state.pendingSub;state.pendingSub='';selectTab(state.current,sub)}
    }catch(error){
      console.error('[boxer-experience] init failed',error);
      showGate('VERBINDUNGSPROBLEM','Deine Daten konnten nicht geladen werden. Bitte lade die Seite neu.','ERNEUT VERSUCHEN','./boxer-experience.html');
    }
  }
  init();
})();