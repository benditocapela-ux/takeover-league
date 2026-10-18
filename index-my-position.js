/* Takeover League 2.0 - own ranking shortcut; no private data is exposed. */
(async function(){
'use strict';
const root=document.getElementById('ranking');
if(!root)return;
const info=document.createElement('p');info.className='status';info.setAttribute('role','status');
const button=document.createElement('button');button.type='button';button.textContent='📍 Zu meiner Position';button.hidden=true;button.style.cssText='min-height:44px;padding:10px 14px;margin:8px 0';
const compare=document.createElement('a');compare.href='./boxer-compare.html';compare.textContent='⚖️ Boxer vergleichen';compare.style.marginLeft='12px';
const container=document.createElement('div');container.append(button,compare,info);root.insertBefore(container,root.querySelector('#ranking-content'));
let myName='';
try{
 const {createClient}=await import('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm');
 const db=createClient('https://iqarjivcrddcixrvqbfb.supabase.co','sb_publishable_o--Z21P8Q08lMvIOask_Fw__SRRX7_R');
 const {data:{user},error}=await db.auth.getUser();if(error||!user)return;
 const {data:p,error:pe}=await db.from('profiles').select('display_name,role,is_active').eq('auth_user_id',user.id).maybeSingle();
 if(pe||!p||!p.is_active||p.role!=='boxer')return;
 myName=String(p.display_name||'').trim();
 button.hidden=!myName;
}catch(e){console.warn('Eigene Rankingposition nicht verfügbar:',e);return}
button.addEventListener('click',()=>{
 if(typeof switchTab==='function')switchTab('ranking');
 const matches=[...root.querySelectorAll('#ranking-content a.league-boxer-link')].filter(a=>{
  try{return new URL(a.href).searchParams.get('name')?.toLocaleLowerCase('de-CH')===myName.toLocaleLowerCase('de-CH')}catch{return false}
 });
 if(matches.length===1){
  const row=matches[0];row.scrollIntoView({behavior:'smooth',block:'center'});
  row.style.outline='3px solid #dfbd77';row.style.outlineOffset='4px';info.textContent='Deine Position ist markiert.';
 }else info.textContent=matches.length?'Name ist nicht eindeutig. Wähle dein Profil manuell.':'Deine Position ist im geladenen Ranking noch nicht vorhanden.';
});
})();