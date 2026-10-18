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
 const n=Math.max(0,Math.floor((Math.sqrt(49+0.32*xp)-7)/2));
 const used=100*n+25*n*(n-1)/2;
 const needed=100+25*n;
 const ranks=['F','E','D','C','B','A','S'];
 return {level:n+1,rank:ranks[Math.min(n,ranks.length-1)],pct:Math.max(0,Math.min(100,(xp-used)/needed*100)),remaining:Math.max(0,needed-(xp-used))};
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
  $('levelStatus').textContent='Rang '+level.rank+' · Level '+level.level;
  $('nextLevel').textContent='Noch '+fmt(level.remaining)+' EXP bis zum nächsten Level';
  const img=photoUrl(avatar[0]);
  if(img){const picture=document.createElement('img');picture.src=img;picture.alt='';picture.addEventListener('error',()=>picture.remove());$('profilePhoto').replaceChildren(picture)}
  $('duelAction').href='./duels.html?opponent='+encodeURIComponent(name);
  status.hidden=true;$('profileCard').hidden=false;
  showCoachAction(name);
 }catch(e){fail('Boxerprofil konnte nicht geladen werden: '+String(e.message||e))}
}
init();
})();