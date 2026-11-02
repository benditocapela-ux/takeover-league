// Shared notification reader. Existing RLS, feature flag and mark-read RPC remain authoritative.
export function createInbox({getContext,host,label,noteLink,markRead,onUnread=()=>{},classes={}}){
 const doc=host.ownerDocument,pageSize=20;
 const node=(tag,text,cls)=>{const el=doc.createElement(tag);el.textContent=String(text??'');if(cls)el.className=cls;return el};
 let epoch=0,unreadEpoch=0,offset=0,owner=null,rows=[],total=null,unread=null,enabled=false,subscription=null,client=null;
 const pager=node('div','',classes.actions||'actions'),previous=node('button','Vorherige 20',classes.button),next=node('button','Weitere 20',classes.button),page=node('p','','muted');
 pager.id=host.id+'-pager';previous.id=host.id+'-prev';next.id=host.id+'-next';page.id=host.id+'-page';
 pager.setAttribute('role','navigation');pager.setAttribute('aria-label','Mitteilungsseiten');page.setAttribute('role','status');label.setAttribute('role','status');
 previous.type=next.type='button';previous.style.minHeight=next.style.minHeight='44px';previous.dataset.inboxPage='previous';next.dataset.inboxPage='next';
 pager.append(previous,next,page);host.after(pager);pager.hidden=true;
 const count=value=>Number.isSafeInteger(value)&&value>=0;
 const current=(token,context)=>token===epoch&&getContext()?.profile?.id===context.profileId&&getContext()?.db===context.db;
 function clear(){epoch++;offset=0;owner=null;rows=[];total=null;unread=null;enabled=false;host.replaceChildren();label.textContent='Bitte anmelden, um Mitteilungen zu sehen.';pager.hidden=true;onUnread(0)}
 function bind(db){if(client===db)return;subscription?.unsubscribe?.();client=db;const result=db.auth.onAuthStateChange?.((event)=>{if(['SIGNED_OUT','SIGNED_IN','USER_UPDATED'].includes(event))clear()});subscription=result?.data?.subscription||null}
 async function identity(context,token,expectedActor=null){
  const auth=await context.db.auth.getUser();
  if(!current(token,context))return null;
  const user=auth.data?.user;
  if(auth.error||!user||expectedActor&&user.id!==expectedActor)return null;
  const result=await context.db.from('profiles').select('id,is_active,role,archived_at').eq('auth_user_id',user.id).maybeSingle();
  if(!current(token,context)||result.error||result.data?.id!==context.profileId||!result.data.is_active||result.data.archived_at||!['boxer','coach'].includes(result.data.role))return null;
  return user.id;
 }
 function summary(){
  if(!enabled)return;
  label.textContent=count(total)&&count(unread)?unread.toLocaleString('de-CH')+' ungelesen von '+total.toLocaleString('de-CH')+' Mitteilungen insgesamt.':'Die genaue Anzahl der Mitteilungen ist derzeit nicht verfügbar.';
  onUnread(count(unread)?unread:null);
  pager.hidden=!count(total)||!total;
  previous.hidden=offset===0;next.hidden=!count(total)||offset+rows.length>=total;
  page.textContent=total?(offset+1)+'–'+(offset+rows.length)+' von '+total+' · höchstens 20 pro Seite':'';
 }
 async function readUnread(context){return context.db.from('boxer_notifications').select('id',{count:'exact',head:true}).eq('recipient_id',context.profileId).is('read_at',null)}
 function render(context,token){
  host.replaceChildren();
  if(!rows.length)host.append(node('p','Du hast aktuell keine Mitteilungen.',classes.muted||'muted'));
  for(const note of rows){
   const item=node('article','',classes.item||'ux-notice');item.dataset.notificationId=note.id;item.classList.toggle(classes.read||'ux-notice-read',!!note.read_at);
   item.append(node('strong',note.title||'Mitteilung'),node('p',note.message||''),node('small',new Date(note.created_at).toLocaleDateString('de-CH')));
   const actions=node('div','',classes.actions||'actions'),href=noteLink(note.target_path);
   if(href){const link=node('a','Ansehen',classes.button);link.href=href;actions.append(link)}
   if(!note.read_at){
    const mark=node('button','Als gelesen markieren',classes.button);mark.type='button';mark.style.minHeight='44px';mark.setAttribute('aria-label','Mitteilung als gelesen markieren: '+(note.title||'Mitteilung'));
    mark.onclick=async()=>{
     if(mark.disabled||!current(token,context))return;mark.disabled=true;mark.textContent='Speichere …';
     try{
      const actor=await identity(context,token,context.actor);
      if(!current(token,context))return;
      if(!actor){clear();return}
      const response=await markRead(context.db,note.id);
      if(!current(token,context))return;
      if(response.error)throw Error('Mitteilung konnte nicht gespeichert werden. Bitte erneut versuchen.');
      let readAt=null;
      if(response.data!==true){
       const check=await context.db.from('boxer_notifications').select('read_at').eq('id',note.id).eq('recipient_id',context.profileId).maybeSingle();
       if(!current(token,context))return;
       if(check.error||!check.data?.read_at)throw Error('Mitteilung konnte nicht bestätigt werden. Bitte aktualisieren.');
       readAt=check.data.read_at;
      }
      note.read_at=readAt||new Date().toISOString();item.classList.add(classes.read||'ux-notice-read');mark.remove();
      const unreadToken=++unreadEpoch,fresh=await readUnread(context);
      if(!current(token,context)||unreadToken!==unreadEpoch)return;
      if(fresh.error||!count(fresh.count)){unread=null;summary();label.textContent='Als gelesen gespeichert. Der genaue Gesamtzähler ist derzeit nicht verfügbar.';return}
      unread=fresh.count;summary();
     }catch(error){if(current(token,context)){mark.disabled=false;mark.textContent='Als gelesen markieren';label.textContent=String(error?.message||error)}}
    };
    actions.append(mark);
   }
   item.append(actions);host.append(item);
  }
 }
 async function load({reset=true}={}){
  const supplied=getContext();if(!supplied?.db||!supplied.profile?.id){clear();return}
  bind(supplied.db);const context={db:supplied.db,profileId:supplied.profile.id,actor:null};
  if(reset||owner!==context.profileId)offset=0;owner=context.profileId;
  const token=++epoch;rows=[];enabled=false;host.replaceChildren();pager.hidden=true;previous.disabled=next.disabled=true;onUnread(null);label.textContent='Prüfe Mitteilungen …';
  try{
   context.actor=await identity(context,token);
   if(!current(token,context))return;
   if(!context.actor){clear();label.textContent='Deine Sitzung hat sich geändert. Bitte die Seite neu laden.';return}
   const flag=await context.db.from('league_feature_flags').select('is_enabled').eq('feature_key','notifications').maybeSingle();
   if(!current(token,context))return;
   if(flag.error)throw Error('Mitteilungen konnten nicht geprüft werden. Bitte erneut versuchen.');
   if(flag.data?.is_enabled!==true){label.textContent='Mitteilungen sind derzeit noch nicht freigeschaltet.';onUnread(0);return}
   enabled=true;
   const [response,unreadResult]=await Promise.all([
    context.db.from('boxer_notifications').select('id,notification_type,title,message,target_path,created_at,read_at',{count:'exact'})
     .eq('recipient_id',context.profileId).order('created_at',{ascending:false}).order('id',{ascending:false}).range(offset,offset+pageSize-1),
    readUnread(context)
   ]);
   if(!current(token,context))return;
   if(response.error||!Array.isArray(response.data)||response.data.length>pageSize||!count(response.count))throw Error('Mitteilungen konnten nicht vollständig geladen werden. Bitte erneut versuchen.');
   rows=response.data;total=response.count;unread=!unreadResult.error&&count(unreadResult.count)?unreadResult.count:null;
   if(offset>=total&&offset>0){offset=Math.max(0,Math.floor(Math.max(0,total-1)/pageSize)*pageSize);return load({reset:false})}
   render(context,token);summary();
  }catch(error){if(current(token,context)){total=null;unread=null;pager.hidden=true;onUnread(null);label.textContent=String(error?.message||error)}}
  finally{if(current(token,context))previous.disabled=next.disabled=false}
 }
 previous.onclick=()=>{if(previous.disabled||offset===0)return;offset=Math.max(0,offset-pageSize);load({reset:false})};
 next.onclick=()=>{if(next.disabled||!count(total)||offset+rows.length>=total)return;offset+=pageSize;load({reset:false})};
 return {load,clear,destroy(){clear();subscription?.unsubscribe?.();pager.remove()}};
}
