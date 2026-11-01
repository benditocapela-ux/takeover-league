/* Takeover League 3.0 · Mein Account (wiederverwendbare Konto-Komponente für Boxer, Trainer und Admin).
 *
 * Mehrere eigene Konten auf demselben Gerät, Wechsel ohne erneute Passworteingabe.
 * Sicherheitsmodell (siehe docs/TAKEOVER_3_APP_SHELL.md):
 *  - Kein Eingriff in Storage.prototype und kein direktes Schreiben des Supabase-Sitzungsschlüssels.
 *    Gewechselt wird ausschliesslich über die offizielle API auth.setSession(); supabase-js erneuert
 *    abgelaufene Zugriffstoken selbst und lehnt widerrufene Refresh-Tokens ab.
 *  - Gespeichert werden je Konto nur Kennung, E-Mail, Anzeigename, Rolle und das Token-Paar
 *    (dieselbe Vertrauensstufe wie die Sitzung, die supabase-js selbst im localStorage hält).
 *    Keine Passwörter, keine vollständigen Benutzerobjekte, höchstens fünf Konten.
 *  - Nach jedem Wechsel prüft der Server Profil, Rolle und Aktivstatus erneut; die Seite wird neu geladen,
 *    damit keine Daten des vorherigen Kontos im Speicher bleiben.
 *  - Abgelaufene oder widerrufene Sitzungen werden markiert und führen zur erneuten Anmeldung.
 *  - Abmelden widerruft die Sitzung serverseitig und entfernt das Konto aus dem Umschalter.
 */
(function(){
 'use strict';
 if(window.TLAccount)return;
 const KEY='takeover_accounts_v2',LEGACY='takeover_accounts_v1',MAX=5;
 const ROLE_LABEL={admin:'Admin',coach:'Trainer',boxer:'Boxer'};
 const HOME={boxer:'./boxer-experience.html',coach:'./coach.html',admin:'./admin.html'};
 const SAFE_NEXT=/^(?:\.\/)?([a-z0-9-]+\.html)(?:[?#][\w\-=&%.#/]*)?$/i;
 let tracked=null,lastUserId=null,switching=false;

 const now=()=>Date.now();
 function parse(raw){try{const v=JSON.parse(raw||'null');return v}catch{return null}}
 function clean(a){
  if(!a||typeof a!=='object'||typeof a.id!=='string'||!a.id)return null;
  return {id:a.id,email:String(a.email||''),name:String(a.name||a.email||'Konto').slice(0,80),
   role:ROLE_LABEL[a.role]?a.role:'',at:typeof a.at==='string'?a.at:'',rt:typeof a.rt==='string'?a.rt:'',
   exp:Number(a.exp)||0,expired:a.expired===true||!a.rt,savedAt:Number(a.savedAt)||0};
 }
 function migrateLegacy(){
  let legacy;try{legacy=parse(localStorage.getItem(LEGACY))}catch{return []}
  if(!Array.isArray(legacy))return [];
  const out=legacy.map(a=>{const s=a&&parse(a.session);return clean({id:a&&a.id,email:a&&a.email,name:a&&a.name,role:a&&a.role,
   at:s&&s.access_token,rt:s&&s.refresh_token,exp:s&&s.expires_at,savedAt:a&&a.savedAt})}).filter(Boolean);
  try{localStorage.removeItem(LEGACY)}catch{}
  return out;
 }
 function read(){
  let list=null;try{list=parse(localStorage.getItem(KEY))}catch{}
  if(!Array.isArray(list)){list=migrateLegacy();if(list.length)write(list)}
  return list.map(clean).filter(Boolean);
 }
 function write(list){
  const seen=new Set(),out=[];
  for(const a of list.map(clean).filter(Boolean)){if(seen.has(a.id))continue;seen.add(a.id);out.push(a)}
  try{localStorage.setItem(KEY,JSON.stringify(out.slice(0,MAX)))}catch{}
  return out.slice(0,MAX);
 }
 function upsertFromSession(session,profile,front){
  if(!session||!session.user||!session.user.id)return null;
  const list=read(),old=list.find(a=>a.id===session.user.id)||{};
  const entry=clean({id:session.user.id,email:session.user.email||old.email,
   name:(profile&&profile.display_name)||old.name||session.user.email,role:(profile&&profile.role)||old.role,
   at:session.access_token,rt:session.refresh_token,exp:session.expires_at,savedAt:now()});
  const rest=list.filter(a=>a.id!==entry.id);
  write(front===false&&old.id?list.map(a=>a.id===entry.id?entry:a):[entry,...rest]);
  return entry;
 }
 function homeFor(role){return HOME[role]||'./index.html'}
 function safeNext(raw){
  if(!raw)return null;const m=SAFE_NEXT.exec(String(raw));if(!m)return null;
  if(['login.html','boxer.html'].includes(m[1].toLowerCase()))return null;
  return './'+String(raw).replace(/^\.\//,'');
 }
 async function sessionOf(db){try{const r=await db.auth.getSession();return r&&r.data?r.data.session:null}catch{return null}}
 async function profileOf(db){
  const u=await db.auth.getUser();const user=u&&u.data&&u.data.user;
  if(u.error||!user)return {error:u.error||new Error('Keine gültige Sitzung')};
  const p=await db.from('profiles').select('id,display_name,role,is_active').eq('auth_user_id',user.id).maybeSingle();
  if(p.error)return {error:p.error,user};
  return {user,profile:p.data||null};
 }

 /** Hält die gespeicherten Token des aktiven Kontos aktuell (Refresh-Token-Rotation) und
  *  entfernt das Konto, wenn es abgemeldet wird. */
 function track(db,profile){
  if(!db||!db.auth)return;
  if(tracked!==db){
   tracked=db;
   try{db.auth.onAuthStateChange((event,session)=>{
    if(session&&session.user)lastUserId=session.user.id;
    if((event==='TOKEN_REFRESHED'||event==='SIGNED_IN'||event==='USER_UPDATED')&&session&&read().some(a=>a.id===session.user.id))
     upsertFromSession(session,null,false);
    if(event==='SIGNED_OUT'&&lastUserId&&!window.__tlAddingAccount&&!switching){
     // Nur entfernen, wenn wirklich abgemeldet (ein misslungener Wechsel in einem anderen Tab stellt die Sitzung sofort wieder her).
     const gone=lastUserId;setTimeout(()=>{sessionOf(db).then(s=>{if(!s)write(read().filter(a=>a.id!==gone))})},1200);lastUserId=null}
   })}catch{}
  }
  return sessionOf(db).then(s=>{if(!s)return null;lastUserId=s.user.id;return upsertFromSession(s,profile,true)});
 }
 /** Speichert das aktuelle Konto vor dem Hinzufügen eines weiteren Kontos. */
 async function prepareAdd(db){
  const s=await sessionOf(db);if(s)upsertFromSession(s,null,true);
  window.__tlAddingAccount=true;
 }
 function finishAdd(){window.__tlAddingAccount=false}

 /** Wechsel zu einem gespeicherten Konto. Liefert {ok,home} oder {error,needsLogin}. */
 // Netzwerk- oder Zeitüberschreitung: Anmeldung behalten (kein erneutes Passwort nötig), nur endgültige Fehler gelten als abgelaufen.
 function retryable(err){
  if(!err)return false;const m=String(err.message||err);
  return err.name==='AuthRetryableFetchError'||err.status===0||err.status>=500||/fetch|network|netzwerk|timeout|offline|load failed/i.test(m);
 }
 /** Wechsel zu einem gespeicherten Konto. Liefert {ok,home} oder {error,needsLogin}. */
 async function switchTo(db,id,opts){
  const list=read(),target=list.find(a=>a.id===id);
  if(!target)return {error:new Error('Dieses Konto ist nicht mehr gespeichert.')};
  const current=await sessionOf(db);
  const navigate=!opts||opts.navigate!==false;
  if(current&&current.user.id===id){const home=homeFor(target.role);if(navigate)location.replace(home);return {ok:true,home,same:true}}
  if(current)upsertFromSession(current,null,true);
  const restore=async()=>{if(current)try{await db.auth.setSession({access_token:current.access_token,refresh_token:current.refresh_token})}catch{}};
  const relogin=()=>{const l=read().map(a=>a.id===id?{...a,expired:true,at:'',rt:''}:a);write(l);
   return {error:new Error('Die gespeicherte Anmeldung von '+target.name+' ist abgelaufen. Bitte melde dich erneut an.'),needsLogin:true,email:target.email}};
  if(target.expired||!target.rt)return relogin();
  switching=true;
  try{
   let set;try{set=await db.auth.setSession({access_token:target.at||'',refresh_token:target.rt})}catch(err){set={error:err}}
   if(set.error||!set.data||!set.data.session){
    // Zurück zum vorherigen Konto, damit niemand unbemerkt im falschen Konto bleibt.
    await restore();
    if(retryable(set.error))return {error:new Error('Keine Verbindung. Der Wechsel zu '+target.name+' hat nicht geklappt – bitte gleich nochmals versuchen.')};
    return relogin();
   }
   const checked=await profileOf(db);
   if(checked.error||!checked.profile){
    await restore();
    return {error:new Error(checked.error&&retryable(checked.error)?'Keine Verbindung. Bitte gleich nochmals versuchen.':'Für '+target.name+' ist kein aktives Profil verknüpft. Du bleibst im bisherigen Konto.')};
   }
   upsertFromSession(set.data.session,checked.profile,true);
   lastUserId=checked.user.id;
   try{for(const k of Object.keys(sessionStorage))if(/^takeover_(?:draft|submission_request|flow)_/.test(k))sessionStorage.removeItem(k)}catch{}
   const p=checked.profile;
   const home=p.is_active?homeFor(p.role):'./login.html';
   if(navigate)location.replace(home);
   return {ok:true,home,profile:p};
  }finally{switching=false}
 }
 function forget(id){return write(read().filter(a=>a.id!==id))}
 async function signOut(db){
  const s=await sessionOf(db);
  if(s)write(read().filter(a=>a.id!==s.user.id));
  let r;try{r=await db.auth.signOut({scope:'local'})}catch(err){r={error:err}}
  return r||{};
 }

 // ---------------------------------------------------------------------------
 // Darstellung (gleiches Markup für Boxer-, Trainer- und Admin-Oberfläche)
 const el=(tag,cls,text)=>{const n=document.createElement(tag);if(cls)n.className=cls;if(text!=null)n.textContent=text;return n};
 function initials(name){return String(name||'?').trim().split(/\s+/).slice(0,2).map(x=>x[0]||'').join('').toUpperCase()||'?'}
 /** Rendert «Mein Account» in host. ctx = {db, profile, user, onError}. */
 function render(host,ctx){
  if(!host)return;
  const db=ctx&&ctx.db,profile=ctx&&ctx.profile,user=ctx&&ctx.user;
  host.replaceChildren();host.classList.add('tla-account');
  const status=el('p','tla-status');status.setAttribute('role','status');status.setAttribute('aria-live','polite');
  const say=(t,bad)=>{status.textContent=t||'';status.classList.toggle('tla-bad',!!bad)};
  const head=el('div','tla-head');head.append(el('span','tla-eyebrow','MEIN ACCOUNT'));host.append(head);
  const list=read();
  if(user){
   const me=el('div','tla-current');me.setAttribute('aria-label','Aktuell angemeldet');
   const av=el('span','tla-avatar',initials(profile&&profile.display_name||user.email));av.setAttribute('aria-hidden','true');
   const copy=el('div','tla-copy');
   copy.append(el('strong','tla-name',(profile&&profile.display_name)||user.email||'Konto'));
   copy.append(el('span','tla-role',(profile&&ROLE_LABEL[profile.role]||'Ohne Profil')+(user.email?' · '+user.email:'')));
   me.append(av,copy,el('span','tla-badge','Aktiv'));head.append(me);
  }else{
   head.append(el('p','tla-muted','Du bist nicht angemeldet.'));
  }
  const others=list.filter(a=>!user||a.id!==user.id);
  if(others.length){
   host.append(el('span','tla-eyebrow tla-sub','KONTO WECHSELN'));
   const ul=el('ul','tla-list');
   for(const acc of others){
    const li=el('li','tla-row');
    const go=el('button','tla-switch');go.type='button';
    go.setAttribute('aria-label','Zu '+acc.name+' ('+(ROLE_LABEL[acc.role]||'Konto')+') wechseln');
    const av=el('span','tla-avatar',initials(acc.name));av.setAttribute('aria-hidden','true');
    const copy=el('span','tla-copy');copy.append(el('strong','tla-name',acc.name),el('span','tla-role',(ROLE_LABEL[acc.role]||'Konto')+(acc.expired?' · Anmeldung abgelaufen':'')));
    go.append(av,copy,el('span','tla-go',acc.expired?'Anmelden':'Wechseln'));
    go.addEventListener('click',async()=>{
     if(!db){say('Keine Verbindung.',true);return}
     host.querySelectorAll('button').forEach(b=>b.disabled=true);say('Wechsel zu '+acc.name+' …');
     const r=await switchTo(db,acc.id);
     if(r&&r.ok)return;
     if(r&&r.error){
      host.querySelectorAll('button').forEach(b=>b.disabled=false);say(r.error.message,true);go.focus();
      if(r.needsLogin)location.assign('./login.html?add=1&account='+encodeURIComponent(r.email||''));
     }
    });
    const rm=el('button','tla-remove','Entfernen');rm.type='button';
    rm.setAttribute('aria-label','Konto '+acc.name+' aus dem Umschalter entfernen');
    rm.addEventListener('click',()=>{forget(acc.id);render(host,ctx);host.querySelector('.tla-status').textContent=acc.name+' wurde aus dem Umschalter entfernt.'});
    li.append(go,rm);ul.append(li);
   }
   host.append(ul);
  }
  const actions=el('div','tla-actions');
  const add=el('a','tla-action','＋ Weiteres Konto hinzufügen');
  add.href='./login.html?add=1';
  add.addEventListener('click',async e=>{if(!db)return;e.preventDefault();await prepareAdd(db);finishAdd();location.assign(add.href)});
  actions.append(add);
  if(user){
   const out=el('button','tla-action tla-logout','Abmelden');out.type='button';
   out.addEventListener('click',async()=>{
    out.disabled=true;say('Abmelden …');
    const r=await signOut(db);
    if(r&&r.error){out.disabled=false;say('Abmelden fehlgeschlagen: '+(r.error.message||r.error),true);return}
    location.replace('./login.html');
   });
   actions.append(out);
  }else{
   const login=el('a','tla-action','Anmelden');login.href='./login.html';actions.append(login);
  }
  host.append(actions,status,el('p','tla-note','Nur auf deinem eigenen Gerät verwenden. Gespeichert werden keine Passwörter; «Entfernen» löscht die gespeicherte Anmeldung von diesem Gerät.'));
 }

 window.TLAccount={read,write,track,prepareAdd,finishAdd,switchTo,forget,signOut,render,homeFor,safeNext,profileOf,ROLE_LABEL,
  _upsertFromSession:upsertFromSession};
})();
