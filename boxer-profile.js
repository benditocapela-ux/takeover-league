/* Public boxer profile: only data from already public league RPCs.
 * Trainer action is also validated by authenticated Supabase RPCs.
 */
(function(){
'use strict';
const $=id=>document.getElementById(id);
const PUBLIC_URL='https://iqarjivcrddcixrvqbfb.supabase.co';
const PUBLIC_KEY='sb_publishable_o--Z21P8Q08lMvIOask_Fw__SRRX7_R';
const requested=(new URLSearchParams(window.location.search).get('name')||'').trim();
const status=$('status');
function fail(message){status.textContent=message;status.classList.add('error');$('profileCard').hidden=true}
function equalName(a,b){return String(a||'').trim().toLocaleLowerCase('de-CH')===String(b||'').trim().toLocaleLowerCase('de-CH')}
const fmt=n=>Number(n||0).toLocaleString('de-CH',{maximumFractionDigits:0});
async function publicRpc(fn){
 const response=await fetch(PUBLIC_URL+'/rest/v1/rpc/'+fn,{method:'POST',headers:{apikey:PUBLIC_KEY,'Content-Type':'application/json'},body:'{}',cache:'no-store'});
 if(!response.ok)throw new Error('Liga-Daten derzeit nicht erreichbar (HTTP '+response.status+').');
 const rows=await response.json();
 if(!Array.isArray(rows))throw new Error('Ungültige Antwort der Liga.');
 return rows;
}
function progress(xp){
 // Maximum Level 99 (Owner-Entscheid 28.10.2026); EXP zählen danach weiter.
 const n=Math.min(98,Math.max(0,Math.floor((Math.sqrt(49+0.32*xp)-7)/2)));
 const used=100*n+25*n*(n-1)/2;
 const needed=100+25*n;
 const ranks=['F','E','D','C','B','A','S'];
 if(n>=98)return {level:99,rank:'S',pct:100,remaining:0};
 return {level:n+1,rank:ranks[Math.min(Math.floor(n/10),ranks.length-1)],pct:Math.max(0,Math.min(100,(xp-used)/needed*100)),remaining:Math.max(0,needed-(xp-used))};
}
function renderPublicRadar(boxer,leader,levels,leaders){
 const defs=[
  ['EXP',Math.max(0,Number(boxer.lifetime_exp)||0),Math.max(1,...levels.map(x=>Number(x.lifetime_exp)||0))],
  ['Monat',Math.max(0,Number(leader.monthly_points)||0),Math.max(1,...leaders.map(x=>Number(x.monthly_points)||0))],
  ['Trainings',Math.max(0,Number(leader.approved_sessions)||0),Math.max(1,...leaders.map(x=>Number(x.approved_sessions)||0))],
  ['Trainingspunkte',Math.max(0,Number(leader.points_training)||0),Math.max(1,...leaders.map(x=>Number(x.points_training)||0))],
  ['Bonuspunkte',Math.max(0,Number(leader.points_bonus)||0),Math.max(1,...leaders.map(x=>Number(x.points_bonus)||0))]
 ];
 const center=130,r=87,polar=(i,percent)=>{
  const angle=-Math.PI/2+2*Math.PI*i/defs.length;
  return [center+Math.cos(angle)*r*percent,center+Math.sin(angle)*r*percent];
 };
 const polygon=ratio=>defs.map((_,i)=>polar(i,ratio).map(v=>v.toFixed(1)).join(',')).join(' ');
 const values=defs.map((d,i)=>polar(i,Math.max(0,Math.min(1,d[1]/d[2]))).map(v=>v.toFixed(1)).join(',')).join(' ');
 const svg=document.createElementNS('http://www.w3.org/2000/svg','svg');
 svg.setAttribute('viewBox','0 0 260 260');svg.setAttribute('aria-hidden','true');
 for(const ratio of [.25,.5,.75,1]){
  const ring=document.createElementNS(svg.namespaceURI,'polygon');ring.setAttribute('points',polygon(ratio));
  ring.setAttribute('fill','none');ring.setAttribute('stroke','#465977');ring.setAttribute('stroke-width','1');svg.append(ring);
 }
 const shape=document.createElementNS(svg.namespaceURI,'polygon');shape.setAttribute('points',values);
 shape.setAttribute('fill','#dfbd7750');shape.setAttribute('stroke','#dfbd77');shape.setAttribute('stroke-width','2.8');svg.append(shape);
 const root=$('sportRadar');root.replaceChildren(svg);
 root.setAttribute('aria-label',defs.map(d=>d[0]+': '+fmt(d[1])+' von '+fmt(d[2])+' Liga-Maximum').join('; '));
 const metrics=$('sportMetrics');metrics.replaceChildren();
 for(const [title,value,max] of defs){const line=document.createElement('div');line.className='radar-metric';
  const label=document.createElement('strong');label.textContent=title;line.append(label,document.createTextNode(fmt(value)+' · '+Math.round(100*value/max)+'% vom Liga-Maximum'));metrics.append(line)}
}


async function renderPublicRecords(name){
 const status=$('recordStatus'),root=$('recordGrid');if(!status||!root)return;
 root.replaceChildren();
 try{
  const query=new URL(PUBLIC_URL+'/rest/v1/league_public_records_v21');
  query.searchParams.set('select','approved_sessions,active_days,max_jogging_km,max_technique_minutes,refreshed_at');
  query.searchParams.set('boxer_name','eq.'+name);
  query.searchParams.set('limit','2');
  const response=await fetch(query.href,{headers:{apikey:PUBLIC_KEY},cache:'no-store'});
  if(!response.ok)throw new Error('HTTP '+response.status);
  const rows=await response.json();if(!Array.isArray(rows)||rows.length>1)throw Error('Ambiguous boxer');
  if(!rows.length){status.textContent='Für diesen Boxer wurden noch keine öffentlichen Rekorde berechnet.';return}
  const r=rows[0];
  const values=[
   ['Bestätigte Trainings',fmt(r.approved_sessions)],
   ['Trainingstage',fmt(r.active_days)],
   ['Längster Jogging-Eintrag',Number(r.max_jogging_km||0).toLocaleString('de-CH')+' km'],
   ['Längste Technik-Einheit',fmt(r.max_technique_minutes)+' Min.']
  ];
  for(const [title,value] of values){const card=document.createElement('div');card.className='badge-tile';
   const h=document.createElement('strong');h.textContent=title;
   const p=document.createElement('small');p.textContent=value;card.append(h,p);root.append(card)}
  status.textContent='Nur bestätigte Trainings · zuletzt berechnet '+new Date(r.refreshed_at).toLocaleDateString('de-CH');
 }catch(e){status.textContent='Öffentliche Rekorde derzeit nicht verfügbar.'}
}
async function renderPublicBadges(name){
 const status=$('publicBadgeStatus'),grid=$('publicBadgeGrid');if(!status||!grid)return;
 grid.replaceChildren();
 try{
  const query=new URL(PUBLIC_URL+'/rest/v1/league_public_badges_v21');
  query.searchParams.set('select','title,icon_key,earned_at');
  query.searchParams.set('boxer_name','eq.'+name);
  query.searchParams.set('order','earned_at.desc');
  query.searchParams.set('limit','60');
  const response=await fetch(query.href,{headers:{apikey:PUBLIC_KEY},cache:'no-store'});
  if(!response.ok)throw new Error('HTTP '+response.status);
  const badges=await response.json();if(!Array.isArray(badges))throw Error('Badgedaten ungültig');
  status.textContent=badges.length?badges.length+' verdiente Abzeichen':'Noch keine Auszeichnungen erhalten.';
  for(const badge of badges){
   const card=document.createElement('article');card.className='badge-tile';
   const title=document.createElement('strong');title.textContent=String(badge.title||'Achievement');
   const earned=document.createElement('small');earned.textContent=badge.earned_at?'Verliehen '+new Date(badge.earned_at).toLocaleDateString('de-CH'):'';
   card.append(title,earned);grid.append(card);
  }
 }catch(e){status.textContent='Öffentliche Auszeichnungen sind noch nicht verfügbar.'}
}
// Palmarès: nur belegte, öffentliche Erfolge aus bestehenden Projektionen (keine erfundenen Titel).
// Quellen: Hall of Fame und Saisonplatzierungen abgeschlossener Saisons, abgeschlossene Liga-Challenges,
// öffentliche Duell-Historie. Nicht öffentliche Boxer erscheinen dort nicht (bzw. als «Privates Profil»).
async function publicTable(table,params){
 const query=new URL(PUBLIC_URL+'/rest/v1/'+table);
 for(const [k,v] of Object.entries(params))query.searchParams.set(k,v);
 const response=await fetch(query.href,{headers:{apikey:PUBLIC_KEY},cache:'no-store'});
 if(!response.ok)throw new Error('HTTP '+response.status);
 const rows=await response.json();if(!Array.isArray(rows))throw Error('Ungültige Antwort');return rows;
}
async function renderPalmares(name){
 const anchor=$('publicBadges');if(!anchor)return;
 const section=document.createElement('section');section.className='public-badges palmares';
 const h=document.createElement('h2');h.textContent='🥇 Palmarès';
 const status=document.createElement('p');status.className='role';status.textContent='Erfolge werden geladen …';
 const list=document.createElement('ul');list.className='palmares-list';
 section.append(h,status,list);anchor.after(section);
 try{
  const [hof,seasons,seasonMeta,globals,duels]=await Promise.all([
   publicTable('league_hall_of_fame_v21',{select:'title,description,awarded_at,season_id',boxer_name:'eq.'+name,order:'awarded_at.desc',limit:'50'}),
   publicTable('league_season_results_v21',{select:'season_id,rank_position,points',boxer_name:'eq.'+name,limit:'50'}),
   publicTable('league_seasons_v21',{select:'id,title,ends_on',status:'eq.closed',limit:'100'}),
   publicTable('league_global_results_v21',{select:'challenge_id,rank_position,completed,closed_at',boxer_name:'eq.'+name,order:'closed_at.desc',limit:'50'}),
   publicTable('league_public_duel_history_v21',{select:'challenger_id,opponent_id,challenger_name,opponent_name,winner_id',or:'(challenger_name.eq.'+JSON.stringify(name)+',opponent_name.eq.'+JSON.stringify(name)+')',limit:'200'})
  ]);
  const challengeIds=[...new Set(globals.map(g=>g.challenge_id))];
  const challenges=challengeIds.length?await publicTable('league_global_challenges_v21',{select:'id,title',id:'in.('+challengeIds.join(',')+')'}):[];
  const seasonTitle=new Map(seasonMeta.map(x=>[x.id,x.title])),challengeTitle=new Map(challenges.map(x=>[x.id,x.title]));
  const items=[];
  for(const x of hof)items.push(['🏆',x.title,seasonTitle.get(x.season_id)||x.description||'Saison']);
  for(const x of seasons)if(!hof.some(hx=>hx.season_id===x.season_id))
   items.push(['📅','Saison '+(seasonTitle.get(x.season_id)||''),'Platz '+fmt(x.rank_position)+' · '+fmt(x.points)+' Punkte']);
  for(const x of globals)if(x.completed||x.rank_position===1)
   items.push([x.rank_position===1?'⚡':'✅','Liga-Challenge «'+(challengeTitle.get(x.challenge_id)||'Challenge')+'»',(x.rank_position===1?'Platz 1':'Platz '+fmt(x.rank_position))+(x.completed?' · Ziel erreicht':'')]);
  const mine=duels.filter(d=>d.challenger_name===name||d.opponent_name===name);
  if(mine.length){
   const wins=mine.filter(d=>d.winner_id&&((d.challenger_name===name&&d.winner_id===d.challenger_id)||(d.opponent_name===name&&d.winner_id===d.opponent_id))).length;
   const draws=mine.filter(d=>!d.winner_id).length;
   items.push(['🥊','Duellbilanz',fmt(wins)+(wins===1?' Sieg':' Siege')+' · '+fmt(mine.length-wins-draws)+(mine.length-wins-draws===1?' Niederlage':' Niederlagen')+(draws?' · '+fmt(draws)+' Unentschieden':'')]);
  }
  for(const [icon,title,detail] of items){
   const li=document.createElement('li');const strong=document.createElement('strong');strong.textContent=icon+' '+title;
   const small=document.createElement('small');small.textContent=detail;li.append(strong,small);list.append(li);
  }
  status.textContent=items.length?'Belegte Erfolge aus Saisons, Liga-Challenges und Duellen.':'Noch keine Titel. Abgeschlossene Saisons, Liga-Challenges und Duelle füllen das Palmarès.';
 }catch(e){status.textContent='Palmarès derzeit nicht verfügbar.'}
}
function photoUrl(a){
 if(a?.avatar_url){
  try{const u=new URL(a.avatar_url);if(u.protocol==='https:'&&u.hostname==='iqarjivcrddcixrvqbfb.supabase.co'&&u.pathname.startsWith('/storage/v1/object/public/boxer-avatars/'))return u.href}catch(_){}
 }
 if(/^avatar-(0[1-9]|1[0-4])$/.test(a?.avatar_key||''))return './avatars/'+a.avatar_key+'.webp';
 return null;
}
async function showCoachAction(name){
 try{
   const {createClient}=await import('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm');
   const db=createClient(PUBLIC_URL,PUBLIC_KEY);
   const {data:{user},error}=await db.auth.getUser();
   if(error||!user)return;
   const {data:p,error:pe}=await db.from('profiles').select('role,is_active').eq('auth_user_id',user.id).maybeSingle();
   if(pe||!p?.is_active||!['coach','admin'].includes(p.role))return;
   const action=$('challengeAction');
   action.href='./challenges.html?target='+encodeURIComponent(name);
   action.hidden=false;
 }catch(e){console.warn('Traineraktion nicht verfügbar:',e)}
}
async function init(){
 if(!requested||requested.length>120||/[\x00-\x1f]/.test(requested)){fail('Kein gültiges Boxerprofil ausgewählt.');return}
 try{
  const [levels,leaders,avatars]=await Promise.all([
   publicRpc('get_public_levels'),publicRpc('get_public_leaderboard'),publicRpc('get_public_boxer_avatars')
  ]);
  const rows=levels.filter(r=>equalName(r.boxer_name,requested));
  // Without a stable public ID, duplicate display names must never resolve
  // to an arbitrary (possibly wrong) opponent or reward recipient.
  if(rows.length!==1){fail(rows.length?'Dieser Name ist mehrfach vorhanden. Bitte einen eindeutigen Boxer-Namen verwenden.':'Boxerprofil nicht gefunden.');return}
  const boxer=rows[0],name=boxer.boxer_name;
  const leader=leaders.filter(r=>equalName(r.boxer_name,name));
  const avatar=avatars.filter(r=>equalName(r.boxer_name,name));
  if(leader.length>1||avatar.length>1){fail('Dieser Boxername ist nicht eindeutig. Aktionen sind gesperrt.');return}
  const xp=Math.max(0,Number(boxer.lifetime_exp)||0);
  const level=progress(xp);
  $('profileName').textContent=name;
  $('profileRank').textContent=leader[0]?.rank_position?'Platz '+fmt(leader[0].rank_position)+' im aktuellen Monatsranking':'Aktiver Liga-Boxer';
  $('monthlyPoints').textContent=fmt(leader[0]?.monthly_points||0);
  $('totalXp').textContent=fmt(xp);
  $('level').textContent=level.rank+' · '+level.level;
  $('levelFill').style.width=level.pct+'%';
  renderPublicRadar(boxer,leader[0]||{},levels,leaders);
  renderPublicBadges(name);
  renderPublicRecords(name);
  renderPalmares(name);
  $('levelStatus').textContent='Rang '+level.rank+' · Level '+level.level;
  $('nextLevel').textContent='Noch '+fmt(level.remaining)+' EXP bis zum nächsten Level';
  const img=photoUrl(avatar[0]);
  if(img){const picture=document.createElement('img');picture.src=img;picture.alt='';picture.addEventListener('error',()=>picture.remove());$('profilePhoto').replaceChildren(picture)}
  $('duelAction').href='./duels.html?opponent='+encodeURIComponent(name);const cmp=$('compareAction');if(cmp)cmp.href='./boxer-compare.html?left='+encodeURIComponent(name);
  status.hidden=true;$('profileCard').hidden=false;
  showCoachAction(name);
 }catch(e){fail('Boxerprofil konnte nicht geladen werden: '+String(e.message||e))}
}
init();
})();