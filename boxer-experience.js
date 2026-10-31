/* Boxer Experience V1: isolated, authenticated views plus a single server-controlled
 * pending club-training request RPC (only when Training 2.0 is enabled).
 * No direct training table writes, rating mutations or point/EXP transactions.
 * Individual and supplementary submissions use the canonical boxer.html form.
 */
(function () {
  'use strict';
  const $ = id => document.getElementById(id);
  const state = { db:null, profile:null, current:'heute', leaderboard:[] };
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
  function selectTab(name){
    if(!navTabs.includes(name))return;
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
    $('ex-scroll').scrollTop=0;
    try{history.replaceState(null,'','#'+name)}catch(_){}
  }
  function bindNavigation(){
    document.querySelectorAll('[data-tab],[data-open-tab]').forEach(node=>node.addEventListener('click',()=>selectTab(node.dataset.tab||node.dataset.openTab)));
    $('ex-settings').addEventListener('click',()=>{ $('ex-drawer').hidden=false;$('ex-settings').setAttribute('aria-expanded','true');$('ex-close').focus(); });
    const closeDrawer=()=>{$('ex-drawer').hidden=true;$('ex-settings').setAttribute('aria-expanded','false');$('ex-settings').focus()};
    $('ex-close').addEventListener('click',closeDrawer);
    $('ex-drawer').addEventListener('click',e=>{if(e.target===$('ex-drawer'))closeDrawer()});
    document.addEventListener('keydown',e=>{if(e.key==='Escape'&&!$('ex-drawer').hidden)closeDrawer()});
    const initial=location.hash.replace('#','');
    selectTab(navTabs.includes(initial)?initial:'heute');
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
  /* PR #84 integration contract:
   * Config is read from public.get_training_v2_config, not duplicated locally.
   * Render only server-advertised options while enabled. The existing
   * boxer.html form (with takeover-training-v2.js) owns the actual selection,
   * payload, validation and rewards. No preview implies a confirmed credit.
   */
  function trainingOption(title,detail,href,subtitle){
    const a=document.createElement('a');
    a.className='ex-link-card';a.href=href;
    const h=document.createElement('b');h.textContent=title;
    const sub=document.createElement('small');sub.textContent=detail;
    a.append(h,sub);
    if(subtitle){const more=document.createElement('small');more.textContent=subtitle;more.style.color='#f2c14e';a.append(more)}
    return a;
  }
  function trainingReward(value){
    const points=Number(value?.points),exp=Number(value?.exp),coins=Number(value?.coins);
    return [Number.isFinite(points)?fmt(points)+' Punkte':null,
            Number.isFinite(exp)?fmt(exp)+' EXP':null,
            Number.isFinite(coins)?fmt(coins)+' Coins':null].filter(Boolean).join(' · ');
  }
  function trainingFallback(host){
    host.replaceChildren();
    const p=document.createElement('p');p.className='ex-muted';
    p.textContent='Training 2.0 ist noch nicht freigeschaltet. Verwende das bewährte Formular.';
    host.append(p,trainingOption('🥊 TRAINING EINREICHEN','Zum bisherigen Formular','./boxer.html#trainingFormCard'));
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
      case 'gym_registered':return 'Du bist heute bereits in einer Gym-Einheit eingecheckt. Kein Doppeleintrag.';
      case 'checkin_required':return 'Dein Verein verlangt den Gym-Check-in. Bitte melde dich dort zur laufenden Einheit an.';
      case 'no_slot':return 'Heute ist kein Pflichttraining hinterlegt. Du kannst ein individuelles Training erfassen.';
      case 'choose_slot':return 'Mehrere Vereinseinheiten sind heute geplant. Bitte wähle die richtige Einheit.';
      case 'disabled':return 'Der Ein-Klick-Antrag ist derzeit nicht aktiviert. Das bisherige Formular bleibt verfügbar.';
      default:return 'Die Einreichung konnte nicht bestätigt werden. Bitte prüfe deine Trainingshistorie.';
    }
  }
  async function loadTrainingConfiguration(){
    const host=$('ex-training-options');if(!host)return;
    const [cfg,checkin]=await Promise.all([
      safeRpc('get_training_v2_config'),
      state.db.from('league_feature_flags').select('is_enabled').eq('feature_key','club_checkin_only').maybeSingle().catch(()=>({error:true}))
    ]);
    if(cfg?.enabled!==true||!Array.isArray(cfg.pflicht)||!Array.isArray(cfg.extras)){
      trainingFallback(host);return;
    }
    const checkinOnly=!checkin.error&&checkin.data?.is_enabled===true;
    host.replaceChildren();
    const title=document.createElement('h3');title.textContent='Warst du heute im Vereinstraining?';
    host.append(title);
    const help=document.createElement('p');help.className='ex-muted';
    help.textContent='Mit Ja wird die heutige Pflichteinheit aus dem Vereinsstundenplan automatisch zur Trainerfreigabe beantragt.';
    host.append(help);
    const actions=document.createElement('div');actions.className='ex-grid';
    const yes=document.createElement('button');yes.type='button';yes.className='ex-link-card';
    yes.textContent='✓ JA, IM VEREIN';
    const no=trainingOption('✕ NEIN, EIGENES TRAINING','Zum individuellen Trainingsformular','./boxer.html?individual=1#trainingFormCard');
    actions.append(yes,no);host.append(actions);
    const status=document.createElement('div');status.className='ex-note';status.setAttribute('role','status');status.setAttribute('aria-live','polite');status.hidden=true;status.style.marginTop='10px';host.append(status);
    const dow=todayDow();
    const slots=cfg.pflicht.filter(x=>Number(x.dow)===dow);
    const schedule=document.createElement('p');schedule.className='ex-muted';
    schedule.textContent=slots.length?
      'Heute geplant: '+slots.map(x=>String(x.label||'Vereinstraining')).join(' / '):
      'Heute ist keine Pflichteinheit im Stundenplan eingeplant.';
    host.append(schedule);
    async function submit(slotId,button){
      if(button)button.disabled=true;status.hidden=false;status.textContent='Dein Antrag wird gespeichert …';
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
        if(r.data?.status==='checkin_required')status.append(trainingOption('ZUM GYM-CHECK-IN','Vereinstraining vor Ort einchecken','./checkin.html'));
        if(r.data?.status==='submitted')await loadTraining();
      }catch(err){
        status.textContent='Antrag nicht gespeichert: '+String(err.message||err)+'. Bitte nicht blind erneut einreichen.';
      }finally{if(button)button.disabled=false}
    }
    yes.addEventListener('click',()=>submit(null,yes));
    if(checkinOnly){
      const notice=document.createElement('p');notice.className='ex-note';
      notice.textContent='Der Verein verlangt einen Gym-Check-in. Eine separate Selbstmeldung ist in diesem Modus gesperrt.';
      host.append(notice);
    }
    const extra=document.createElement('p');extra.className='ex-muted';
    extra.textContent='Ergänzungstrainings kannst du weiterhin im regulären Formular nach Trainingsart auswählen.';
    host.append(extra);
    host.append(trainingOption('ERGAENZUNGSTRAINING IM VEREIN',
      'Sandsack, Athletik oder Technik mit Trainerfreigabe',
      checkinOnly?'./checkin.html':'./boxer.html?club=1#trainingFormCard'));
  }
  async function loadTraining(){
    const db=state.db, id=state.profile.id;
    const [entries,types]=await Promise.all([
      db.from('training_submissions').select('training_date,status,training_type_id,created_at').eq('boxer_id',id).order('created_at',{ascending:false}).limit(50),
      db.from('training_types').select('id,name').eq('is_active',true)
    ]);
    const host=$('ex-training-history');host.replaceChildren();
    if(entries.error){const p=document.createElement('p');p.className='ex-muted';p.textContent='Trainingshistorie konnte nicht geladen werden.';host.append(p);return;}
    const rows=Array.isArray(entries.data)?entries.data:[];
    const names=new Map((types.data||[]).map(t=>[String(t.id),t.name]));
    const current=dateZurich(new Date()),start=new Date(current+'T12:00:00Z');start.setUTCDate(start.getUTCDate()-6);const from=dateZurich(start);
    const approved=rows.filter(r=>r.status==='approved'&&r.training_date>=from&&r.training_date<=current).length;
    const pending=rows.filter(r=>r.status==='pending').length;
    setText('ex-week-sessions',approved);setText('ex-pending',pending);
    for(const item of rows.slice(0,5)){
      const line=document.createElement('div');line.className='ex-list-line';
      const copy=document.createElement('span'),title=document.createElement('b'),sub=document.createElement('small');
      title.textContent=names.get(String(item.training_type_id))||'Training';
      sub.textContent=dayLabel(item.training_date);
      copy.append(title,sub);
      const status=document.createElement('span');status.className='ex-pill';
      status.textContent={approved:'Bestätigt',pending:'In Prüfung',rejected:'Abgelehnt'}[item.status]||item.status||'Offen';
      line.append(copy,status);host.append(line);
    }
    if(!rows.length){const p=document.createElement('p');p.className='ex-muted';p.textContent='Noch keine Trainingseinträge vorhanden.';host.append(p)}
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
      const pr=await state.db.from('profiles').select('id,display_name,role,is_active').eq('auth_user_id',user.id).maybeSingle();
      const profile=pr.data;
      if(pr.error||!profile||!profile.is_active){showGate('KEIN AKTIVES PROFIL','Für dieses Konto ist kein aktiver Boxer freigeschaltet.','ZUM LOGIN');return}
      if(profile.role!=='boxer'){showGate('BOXER-BEREICH','Diese neue Oberfläche ist für Boxer reserviert. Für Trainer und Admins bleibt das bisherige Dashboard erhalten.','TRAINER-DASHBOARD','./coach.html');return}
      state.profile=profile;
      setText('ex-home-name',profile.display_name||'MEIN BOXER');
      setText('ex-welcome','Willkommen, '+profile.display_name+'. Dein nächster Schritt ist nur einen Klick entfernt.');
      $('ex-gate').hidden=true;$('ex-app').hidden=false;
      await Promise.allSettled([loadMyPerformance(),loadLeaderboard(),loadTraining(),loadLevel(),loadTrainingConfiguration()]);
    }catch(error){
      console.error('[boxer-experience] init failed',error);
      showGate('VERBINDUNGSPROBLEM','Deine Daten konnten nicht geladen werden. Bitte lade die Seite neu.','ERNEUT VERSUCHEN','./boxer-experience.html');
    }
  }
  init();
})();