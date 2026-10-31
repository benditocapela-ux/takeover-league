/* Boxer Experience V1: isolated, read-only view backed by the existing RPCs.
 * No training mutation or duplicate points logic is implemented here.
 * The canonical training flow remains boxer.html until the parallel training work lands.
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
    const intro=document.createElement('p');intro.className='ex-muted';
    intro.textContent='Training 2.0 ist noch nicht freigeschaltet. Du kannst weiterhin das bisherige Trainingsformular verwenden.';
    host.append(intro,trainingOption('🥊 TRAINING EINREICHEN','Das bewährte Formular öffnen','./boxer.html#trainingFormCard'));
  }
  async function loadTrainingConfiguration(){
    const host=$('ex-training-options');if(!host)return;
    // No SQL migration or disabled flag? Remain usable with the old form.
    const [cfg,checkin]=await Promise.all([
      safeRpc('get_training_v2_config'),
      state.db.from('league_feature_flags').select('is_enabled').eq('feature_key','club_checkin_only').maybeSingle().catch(()=>({error:true}))
    ]);
    if(cfg?.enabled!==true||!Array.isArray(cfg.pflicht)||!Array.isArray(cfg.extras)){
      trainingFallback(host);return;
    }
    const checkinOnly=!checkin.error&&checkin.data?.is_enabled===true;
    host.replaceChildren();
    const headline=document.createElement('p');headline.className='ex-eyebrow';
    headline.textContent='TRAINING 2.0 · AKTIV';
    host.append(headline);
    const grid=document.createElement('div');grid.className='ex-grid';
    const clubHref=checkinOnly?'./checkin.html':'./boxer.html#trainingFormCard';
    if(cfg.pflicht.length){
      const info=cfg.pflicht.map(x=>String(x.day_name||'')+' · '+String(x.label||'')).join(' / ');
      // Rewards may differ per schedule slot; never hardcode 60/40.
      const reward=cfg.pflicht.map(x=>trainingReward(x.reward)).filter(Boolean);
      grid.append(trainingOption('📅 PFLICHTTRAINING',info,clubHref,
        checkinOnly?'Nur via Gym-Check-in':reward.length&&reward.every(x=>x===reward[0])?'Voraussichtlich: '+reward[0]:'Wert wird im Formular angezeigt'));
    }
    if(cfg.extras.length){
      const info=cfg.extras.map(x=>String(x.label||'')).join(' / ');
      const reward=cfg.extras.map(x=>trainingReward(x.reward)).filter(Boolean);
      grid.append(trainingOption('💪 ERGÄNZUNGSTRAINING',info,clubHref,
        checkinOnly?'Nur via Gym-Check-in':reward.length&&reward.every(x=>x===reward[0])?'Voraussichtlich: '+reward[0]:'Wert wird im Formular angezeigt'));
    }
    const individual=(Array.isArray(cfg.types)?cfg.types:[]).filter(x=>x.club_only!==true);
    if(individual.length)grid.append(trainingOption('🏃 INDIVIDUELLES TRAINING',
      'Joggen, Kraft, Heimtraining und weitere Trainingsarten','./boxer.html#trainingFormCard',
      'Wert abhängig von der gewählten Trainingsart'));
    if(grid.childElementCount)host.append(grid);
    else trainingFallback(host);
    if(checkinOnly){
      const warning=document.createElement('p');warning.className='ex-note';
      warning.textContent='Dein Verein verlangt für Vereinstrainings derzeit den Gym-Check-in. Das direkte Formular wird dafür nicht angeboten.';
      host.append(warning);
    }
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