/* Takeover League 3.0 · Studio-Funktionen direkt in der Boxer Experience (ersetzt die alte boxer.html-Ansicht für Boxer).
 * Übernommen aus boxer.html (gleiche Tabellen, RPCs und Rechteprüfung, nur neue Darstellung):
 *  Trainingshistorie mit Filter, Trainingskalender, Änderungshistorie, Mitteilungen, Profilbild, Trainingsstatistik,
 *  EXP/Level/Rang, 30-Tage-Performance, Coach-Feedback sowie Wochen-Quests/Achievements (takeover-gamification.js).
 * Schreibende Aktionen: nur update_my_boxer_avatar (Profilbild) und mark_my_notification_read – wie bisher.
 */
(function(){
 'use strict';
 if(window.TLStudio)return;
 const $=id=>document.getElementById(id);
 const el=(tag,cls,text)=>{const n=document.createElement(tag);if(cls)n.className=cls;if(text!=null)n.textContent=text;return n};
 const fmt=(v,d=0)=>Number(v??0).toLocaleString('de-CH',{maximumFractionDigits:d});
 const STATUS={pending:'In Prüfung',approved:'Bestätigt',rejected:'Abgelehnt'};
 const TIER={pflicht:'Pflichttraining',ergaenzung:'Ergänzungstraining'};
 const PRESETS=Object.fromEntries(Array.from({length:14},(_,i)=>{const n=String(i+1).padStart(2,'0');return ['avatar-'+n,'./avatars/avatar-'+n+'.webp']}));
 const NOTE_PAGES=new Set(['boxer.html','duels.html','challenges.html','index.html','awards.html','boxer-profile.html','league-challenges.html','league-history.html','goals.html','arena.html','bewertung.html','karten.html','feedback.html']);
 const S={db:null,profile:null,types:[],rows:[],visible:8,mounted:false,gamify:null};
 const calendarDay=d=>d.toLocaleDateString('sv-SE',{timeZone:'Europe/Zurich'});
 const stepDay=(key,delta)=>{const d=new Date(key+'T12:00:00Z');d.setUTCDate(d.getUTCDate()+delta);return d.toISOString().slice(0,10)};
 const typeName=id=>S.types.find(t=>String(t.id)===String(id))?.name||'Training';
 const dayLabel=v=>{try{return new Date(v+'T12:00:00').toLocaleDateString('de-CH',{weekday:'short',day:'2-digit',month:'2-digit',year:'numeric'})}catch{return v}};

 // ---------------- Trainingshistorie ----------------
 async function loadHistory(){
  const host=$('ex-history');if(!host)return;
  const r=await S.db.from('training_submissions').select('*').eq('boxer_id',S.profile.id).order('created_at',{ascending:false}).limit(1000);
  if(r.error){$('ex-history-status').textContent='Trainingshistorie konnte nicht geladen werden: '+r.error.message;return}
  S.rows=Array.isArray(r.data)?r.data:[];S.visible=8;
  $('ex-history-status').textContent=S.rows.length?S.rows.length+(S.rows.length===1?' Training':' Trainings')+' eingereicht · '+S.rows.filter(x=>x.status==='approved').length+' bestätigt · '+S.rows.filter(x=>x.status==='pending').length+' in Prüfung':'';
  renderHistory();renderInsights();
  document.dispatchEvent(new Event('takeover:history-loaded'));
 }
 function renderHistory(){
  const host=$('ex-history'),filter=$('ex-history-filter')?.value||'all',more=$('ex-history-more');
  const rows=S.rows.filter(s=>filter==='all'||s.status===filter);host.replaceChildren();
  if(!rows.length){host.append(el('p','ex-muted',filter==='all'?'Noch keine Trainings eingereicht.':'Keine Trainings mit diesem Status.'));more.hidden=true;return}
  for(const s of rows.slice(0,S.visible)){
   const line=el('div','ex-list-line ex-history-line');
   const copy=el('span','ex-history-copy');
   const title=el('b','',typeName(s.training_type_id)+(s.club_tier&&TIER[s.club_tier]?' · '+TIER[s.club_tier]:''));
   const meta=[dayLabel(s.training_date),s.jogging_km!=null?fmt(s.jogging_km,2)+' km':null,
    s.duration_minutes!=null?s.duration_minutes+' Min.':s.technique_minutes!=null?s.technique_minutes+' Min.':null,
    s.training_location==='club'?'Verein':s.training_location==='individual'?'Individuell':null,s.recorded_by?'vom Trainer eingetragen':null].filter(Boolean).join(' · ');
   copy.append(title,el('small','',meta));
   if(s.notes)copy.append(el('small','ex-history-note',s.notes));
   const pill=el('span','ex-pill ex-pill-'+s.status,STATUS[s.status]||s.status||'Offen');
   line.append(copy,pill);host.append(line);
  }
  more.hidden=S.visible>=rows.length;more.textContent='Mehr anzeigen ('+Math.min(10,rows.length-S.visible)+' weitere)';
 }
 function renderInsights(){
  const approved=S.rows.filter(r=>r.status==='approved'&&/^\d{4}-\d{2}-\d{2}$/.test(r.training_date||''));
  const now=calendarDay(new Date()),days=new Map();for(const t of approved)days.set(t.training_date,(days.get(t.training_date)||0)+1);
  let cursor=days.has(now)?now:stepDay(now,-1),streak=0;while(days.has(cursor)&&streak<10000){streak++;cursor=stepDay(cursor,-1)}
  const count=n=>approved.filter(r=>r.training_date<=now&&r.training_date>=stepDay(now,-(n-1))).length;
  const set=(id,v)=>{const n=$(id);if(n)n.textContent=String(v)};
  set('ex-streak',streak);set('ex-last7',count(7));set('ex-last30',count(30));
  const chart=$('ex-week-chart');
  if(chart){chart.replaceChildren();for(let w=5;w>=0;w--){let c=0;for(let d=0;d<7;d++)c+=days.get(stepDay(now,-w*7-d))||0;
   const col=el('div','ex-bar');const fill=el('i');fill.style.height=Math.max(4,Math.round(Math.min(100,c/7*100)))+'%';
   col.title=c+' bestätigte Trainings';col.append(el('b','',String(c)),fill,el('small','',w===0?'Diese':'W-'+w));chart.append(col)}}
  const cal=$('ex-calendar');
  if(cal){cal.replaceChildren();for(let d=29;d>=0;d--){const date=stepDay(now,-d),c=days.get(date)||0;const cell=el('span','ex-cal'+(c?' done':''),date.slice(-2));
   cell.title=date+': '+c+' bestätigte Trainings';cell.setAttribute('aria-label',cell.title);cal.append(cell)}}
 }

 // ---------------- Änderungshistorie ----------------
 async function loadAudit(){
  const host=$('ex-audit');if(!host)return;host.replaceChildren(el('p','ex-muted','Lade Änderungshistorie …'));
  const r=await S.db.rpc('league_training_audit_recent',{p_boxer_id:S.profile.id});host.replaceChildren();
  if(r.error){host.append(el('p','ex-muted','Änderungshistorie ist derzeit nicht verfügbar.'));return}
  const rows=Array.isArray(r.data)?r.data:[];
  if(!rows.length){host.append(el('p','ex-muted','Keine Änderungen protokolliert.'));return}
  for(const a of rows){host.append(el('div','ex-list-line',new Date(a.changed_at).toLocaleString('de-CH')+' · '+(STATUS[a.old_status]||a.old_status||'Neu')+' → '+(STATUS[a.new_status]||a.new_status||'Gelöscht')))}
 }

 // ---------------- Mitteilungen ----------------
 function noteLink(path){
  const clean=String(path||'').trim().replace(/^\.\//,'');const p=clean.startsWith('/')&&!clean.startsWith('//')?clean.slice(1):clean;
  const [file,query]=p.split('?',2);if(!NOTE_PAGES.has(file)||file.includes('/')||(query&&/[#\\]/.test(query)))return null;
  const base=new URL('./',location.href),dest=new URL('./'+file+(query?'?'+query:''),base);
  if(dest.origin!==location.origin||!dest.pathname.startsWith(base.pathname))return null;
  const legacy=window.TLShell&&window.TLShell.legacyTarget(dest.href,'boxer');
  return legacy?new URL(legacy,location.href).href:dest.href;
 }
 async function loadNotifications(){
  const host=$('ex-notifications'),label=$('ex-notifications-status');if(!host)return;
  label.textContent='Prüfe Mitteilungen …';
  const flag=await S.db.from('league_feature_flags').select('is_enabled').eq('feature_key','notifications').maybeSingle();
  host.replaceChildren();
  if(flag.error||flag.data?.is_enabled!==true){label.textContent='Mitteilungen sind derzeit noch nicht freigeschaltet.';setBadge(0);return}
  const r=await S.db.from('boxer_notifications').select('id,notification_type,title,message,target_path,created_at,read_at')
   .eq('recipient_id',S.profile.id).order('created_at',{ascending:false}).limit(20);
  if(r.error){label.textContent='Mitteilungen konnten nicht geladen werden: '+r.error.message;return}
  const rows=r.data||[];const unread=()=>rows.filter(x=>!x.read_at).length;
  const summary=()=>{label.textContent=rows.length?unread()+' ungelesen von '+rows.length+' Mitteilungen':'Du hast aktuell keine Mitteilungen.';setBadge(unread())};summary();
  for(const note of rows){
   const item=el('article','ex-notice'+(note.read_at?' read':''));
   item.append(el('strong','',note.title||'Mitteilung'),el('p','',note.message||''),el('small','',new Date(note.created_at).toLocaleDateString('de-CH')));
   const actions=el('div','ex-notice-actions');
   const href=noteLink(note.target_path);if(href){const a=el('a','ex-btn ex-btn-ghost','Ansehen');a.href=href;actions.append(a)}
   if(!note.read_at){
    const mark=el('button','ex-btn ex-btn-ghost','Als gelesen markieren');mark.type='button';
    mark.setAttribute('aria-label','Mitteilung als gelesen markieren: '+(note.title||'Mitteilung'));
    mark.addEventListener('click',async()=>{
     mark.disabled=true;mark.textContent='Speichere …';
     const res=await S.db.rpc('mark_my_notification_read',{p_notification_id:note.id});
     if(res.error){mark.disabled=false;mark.textContent='Als gelesen markieren';label.textContent='Mitteilung konnte nicht gespeichert werden. Bitte erneut versuchen.';return}
     if(res.data!==true){const chk=await S.db.from('boxer_notifications').select('read_at').eq('id',note.id).eq('recipient_id',S.profile.id).maybeSingle();
      if(chk.error||!chk.data?.read_at){mark.disabled=false;mark.textContent='Als gelesen markieren';label.textContent='Mitteilung konnte nicht bestätigt werden. Bitte aktualisieren.';return}}
     note.read_at=new Date().toISOString();item.classList.add('read');mark.remove();summary();
    });
    actions.append(mark);
   }
   if(actions.childNodes.length)item.append(actions);
   host.append(item);
  }
 }
 function setBadge(n){const b=$('ex-notify-badge');if(!b)return;b.hidden=!n;b.textContent=n>99?'99+':String(n)}

 // ---------------- Profil, Statistik, Level, Performance, Feedback ----------------
 function drawAvatar(key,url){
  const box=$('ex-avatar');if(!box)return;box.replaceChildren();
  const src=url||PRESETS[key]||PRESETS['avatar-01'];const img=el('img');img.alt='Dein Profilbild';img.src=src;img.addEventListener('error',()=>{box.textContent='🥊'});box.append(img);
  document.querySelectorAll('#ex-avatar-options button').forEach(b=>b.setAttribute('aria-pressed',String(!url&&b.dataset.key===key)));
 }
 function mountProfile(){
  const opts=$('ex-avatar-options');if(!opts)return;
  $('ex-profile-name').textContent=S.profile.display_name;
  let selected=S.profile.avatar_key||'avatar-01',photo=S.profile.avatar_url||null,file=null;
  opts.replaceChildren();
  for(const [key,url] of Object.entries(PRESETS)){
   const b=el('button','ex-avatar-option');b.type='button';b.dataset.key=key;b.setAttribute('aria-label','Avatar '+key.slice(-2)+' wählen');
   const img=el('img');img.src=url;img.alt='';img.loading='lazy';b.append(img);
   b.addEventListener('click',()=>{selected=key;photo=null;file=null;$('ex-photo').value='';drawAvatar(selected,null)});opts.append(b);
  }
  drawAvatar(selected,photo);
  $('ex-photo').addEventListener('change',()=>{
   const f=$('ex-photo').files[0];if(!f)return;
   if(!['image/jpeg','image/png','image/webp'].includes(f.type)||f.size>3*1024*1024){$('ex-profile-msg').textContent='Nur JPG, PNG oder WebP bis 3 MB erlaubt.';$('ex-photo').value='';return}
   file=f;if(photo&&photo.startsWith('blob:'))URL.revokeObjectURL(photo);photo=URL.createObjectURL(f);drawAvatar(selected,photo);
  });
  $('ex-avatar-save').addEventListener('click',async()=>{
   const btn=$('ex-avatar-save'),msg=$('ex-profile-msg');btn.disabled=true;msg.textContent='Wird gespeichert …';
   try{
    let url=null,key=selected;
    if(file){const u=await S.db.auth.getUser();const user=u.data&&u.data.user;if(!user)throw Error('Bitte erneut anmelden.');
     const ext={'image/jpeg':'jpg','image/png':'png','image/webp':'webp'}[file.type];
     const path=user.id+'/avatar-'+(crypto.randomUUID?crypto.randomUUID():Date.now())+'.'+ext;
     const up=await S.db.storage.from('boxer-avatars').upload(path,file,{contentType:file.type,upsert:false});if(up.error)throw up.error;
     url=S.db.storage.from('boxer-avatars').getPublicUrl(path).data.publicUrl;key=null}
    else if(!PRESETS[key])throw Error('Avatar nicht gefunden.');
    const r=await S.db.rpc('update_my_boxer_avatar',{p_avatar_key:key,p_avatar_url:url});if(r.error)throw r.error;
    S.profile.avatar_key=key;S.profile.avatar_url=url;photo=url;file=null;$('ex-photo').value='';drawAvatar(key||'avatar-01',url);msg.textContent='Profilbild gespeichert.';
   }catch(e){msg.textContent='Speichern fehlgeschlagen: '+(e.message||e)}finally{btn.disabled=false}
  });
 }
 async function loadStats(){
  const host=$('ex-type-breakdown');if(!host)return;
  const sum={};for(const t of S.types)sum[String(t.id)]={name:t.name,count:0,km:0,minutes:0};
  let km=0,sprints=0,tech=0,offset=0;
  try{
   for(;;){const r=await S.db.from('training_submissions').select('training_type_id,jogging_km,technique_minutes').eq('boxer_id',S.profile.id).eq('status','approved').range(offset,offset+499);
    if(r.error)throw r.error;
    for(const e of r.data||[]){const it=sum[String(e.training_type_id)];if(!it)continue;it.count++;const k=Number(e.jogging_km)||0,m=Number(e.technique_minutes)||0;it.km+=k;it.minutes+=m;
     if(/jogg|lauf|running/i.test(it.name))km+=k;if(/sprint/i.test(it.name))sprints++;if(/technik/i.test(it.name))tech+=m}
    if(!r.data||r.data.length<500)break;offset+=500}
   $('ex-total-km').textContent=fmt(km,2)+' km';$('ex-total-sprints').textContent=fmt(sprints)+' Einheiten';$('ex-total-technique').textContent=fmt(tech)+' Min.';
   host.replaceChildren();
   const list=Object.values(sum).filter(x=>x.count).sort((a,b)=>b.count-a.count||a.name.localeCompare(b.name));
   if(!list.length)host.append(el('p','ex-muted','Noch keine bestätigten Trainings.'));
   for(const it of list){const row=el('div','ex-list-line');const l=el('span');l.append(el('b','',it.name));
    if(it.km||it.minutes)l.append(el('small','',[it.km?fmt(it.km,2)+' km':'',it.minutes?fmt(it.minutes)+' Min.':''].filter(Boolean).join(' · ')));
    row.append(l,el('span','ex-pill',fmt(it.count)+' ×'));host.append(row)}
  }catch(err){host.textContent='Statistik konnte nicht geladen werden: '+(err.message||err)}
 }
 async function loadLevel(){
  const box=$('expRankSection');if(!box)return;const status=$('ex-rank-status');
  const flag=await S.db.from('league_feature_flags').select('is_enabled').eq('feature_key','performance_dashboard').maybeSingle();
  if(flag.error||flag.data?.is_enabled!==true){status.textContent='Bald verfügbar: EXP, Level und Rang sind noch nicht freigeschaltet.';return}
  const r=await S.db.rpc('get_boxer_exp_level_rank',{p_boxer_id:S.profile.id});const a=Array.isArray(r.data)?r.data[0]:r.data;
  if(r.error||!a){status.textContent='EXP und Level konnten nicht geladen werden.';return}
  const xp=Math.max(0,Number(a.lifetime_exp)||0),n=Math.min(98,Math.floor((Math.sqrt(49+0.32*xp)-7)/2));
  const level=n+1,start=100*n+25*n*(n-1)/2,needed=100+25*n,into=xp-start,pct=Math.min(100,Math.max(0,100*into/needed));
  const ranks=['F','E','D','C','B','A','S'];
  $('ex-rank-letter').textContent=ranks[Math.min(Math.floor((level-1)/10),ranks.length-1)];$('ex-rank-level').textContent=fmt(level);$('ex-rank-exp').textContent=fmt(xp);
  const bar=$('ex-rank-bar');bar.setAttribute('aria-valuenow',String(Math.round(pct)));bar.firstElementChild.style.width=pct+'%';
  status.textContent=fmt(into)+' / '+fmt(needed)+' EXP im aktuellen Level · noch '+fmt(needed-into)+' EXP · Gesamtpunkte '+fmt(a.lifetime_points);
 }
 async function loadPerformance(){
  const status=$('ex-perf-status');if(!status)return;
  const flag=await S.db.from('league_feature_flags').select('is_enabled').eq('feature_key','performance_dashboard').maybeSingle();
  if(flag.error||flag.data?.is_enabled!==true){status.textContent='Bald verfügbar: 30-Tage-Performance ist noch nicht freigeschaltet.';return}
  const r=await S.db.rpc('get_boxer_performance_30d',{p_boxer_id:S.profile.id});const a=r.data&&r.data[0];
  if(r.error||!a){status.textContent='Keine Performance-Daten verfügbar.';return}
  status.textContent='Gesamtscore '+fmt(a.total_score,2)+' / 100 · '+fmt(a.active_days)+' aktive Tage · '+fmt(a.training_equivalents,2)+' Trainingseinheiten · Konsistenz '+fmt(a.consistency_score,2)+'/40 · Volumen '+fmt(a.volume_score,2)+'/40 · Vielfalt '+fmt(a.variety_score,2)+'/20 ('+a.period_start+' bis '+a.period_end+')';
 }
 async function loadFeedback(){
  const host=$('ex-feedback');if(!host)return;
  const r=await S.db.rpc('get_my_feedback');host.replaceChildren();
  if(r.error||!r.data||r.data.enabled!==true){host.append(el('p','ex-muted',r.error?'Feedback konnte nicht geladen werden.':'Bald verfügbar: Coach-Feedback ist noch nicht freigeschaltet.'));return}
  const active=r.data.active||[],archived=r.data.archived||[];
  const d=v=>new Date(v+(String(v).length===10?'T12:00:00Z':'')).toLocaleDateString('de-CH');
  const card=(it,arch)=>{const c=el('article','ex-notice'+(arch?' read':''));c.append(el('strong','',it.title),el('small','',(it.coach?it.coach+' · ':'')+d(it.created_at)+(arch?'':' · sichtbar bis '+d(it.visible_until))),el('p','',it.message));return c};
  if(!active.length&&!archived.length)host.append(el('p','ex-muted','Du hast noch keine Rückmeldungen erhalten.'));
  for(const it of active)host.append(card(it,false));
  if(archived.length){const det=el('details','ex-details');det.append(el('summary','','Archivierte Feedbacks ('+archived.length+')'));for(const it of archived)det.append(card(it,true));host.append(det)}
 }
 async function mountGamification(){
  if(S.gamify)return;
  try{const mod=await import('./takeover-gamification.js');S.gamify=await mod.mountGamification({db:S.db,profile:S.profile,types:S.types,getHistory:()=>S.rows})}
  catch(err){console.warn('[boxer-experience] Quests/Achievements nicht verfügbar',err)}
 }

 async function mount({db,profile,types}){
  S.db=db;S.profile=profile;S.types=types||[];if(S.mounted)return;S.mounted=true;
  $('ex-history-filter')?.addEventListener('change',()=>{S.visible=8;renderHistory()});
  $('ex-history-more')?.addEventListener('click',()=>{S.visible+=10;renderHistory()});
  $('ex-history-refresh')?.addEventListener('click',()=>{loadHistory();loadAudit()});
  $('ex-notifications-refresh')?.addEventListener('click',loadNotifications);
  document.addEventListener('visibilitychange',()=>{if(!document.hidden)loadNotifications().catch(()=>{})});
  mountProfile();
  const p=await db.from('profiles').select('avatar_key,avatar_url').eq('id',profile.id).maybeSingle();
  if(!p.error&&p.data){S.profile.avatar_key=p.data.avatar_key;S.profile.avatar_url=p.data.avatar_url;drawAvatar(p.data.avatar_key||'avatar-01',p.data.avatar_url)}
  await Promise.allSettled([loadHistory(),loadNotifications(),loadAudit(),loadStats(),loadLevel(),loadPerformance(),loadFeedback()]);
  mountGamification();
 }
 window.TLStudio={mount,refresh:()=>Promise.allSettled([loadHistory(),loadAudit(),loadStats()]),loadNotifications,_noteLink:noteLink};
})();
