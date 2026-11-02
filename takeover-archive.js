(function(){
 'use strict';
 const API='https://iqarjivcrddcixrvqbfb.supabase.co',KEY='sb_publishable_o--Z21P8Q08lMvIOask_Fw__SRRX7_R';
 const $=id=>document.getElementById(id),node=(tag,text)=>{const e=document.createElement(tag);e.textContent=String(text??'');return e};
 const fmt=n=>Number(n).toLocaleString('de-CH'),uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
 const month=/^[0-9]{4}-(0[1-9]|1[0-2])$/,seasons=new Map();
 const parts=new Intl.DateTimeFormat('en-CA',{timeZone:'Europe/Zurich',year:'numeric',month:'2-digit'}).formatToParts(new Date());
 const currentMonth=parts.find(p=>p.type==='year').value+'-'+parts.find(p=>p.type==='month').value;
 let db,staffClose,epoch=0,loading=false,next=null,seasonOffset=0,seasonLoading=false,selected=null;
 const statuses={official:'Offiziell abgeschlossen',live:'Laufender Zwischenstand',reconstructed:'Rekonstruierter Monatsrückblick',awaiting_close:'Zeitraum beendet – Auswertung läuft'};
 function say(message){$('periodStatus').textContent=message}
 function date(value){return new Date(value+'T12:00:00Z').toLocaleDateString('de-CH',{day:'2-digit',month:'2-digit',year:'numeric',timeZone:'Europe/Zurich'})}
 function clear(){for(const id of ['results','honors','periodPodium'])$(id).replaceChildren();$('periodMine').textContent='';$('periodMine').hidden=true;$('moreResults').hidden=true;next=null}
 function controls(){const isMonth=$('periodKind').value==='month';$('monthLabel').hidden=!isMonth;$('seasonLabel').hidden=isMonth;$('periodMonth').required=isMonth;$('periodSeason').required=!isMonth}
 function rowValid(r){return r&&typeof r.name==='string'&&Number.isSafeInteger(r.rank)&&r.rank>0&&Number.isSafeInteger(r.points)}
 function valid(p,kind,key){return p&&p.version===1&&p.kind===kind&&p.key===key&&statuses[p.status]&&typeof p.title==='string'
  && /^\d{4}-\d{2}-\d{2}$/.test(p.starts_on)&&/^\d{4}-\d{2}-\d{2}$/.test(p.ends_on)
  && Array.isArray(p.rows)&&p.rows.length<=20&&p.rows.every(r=>rowValid(r)&&Number.isSafeInteger(r.exp))
  && Array.isArray(p.top)&&p.top.every(r=>rowValid(r)&&r.rank<=3&&r.points>0)&&Array.isArray(p.honors)
  && Number.isSafeInteger(p.total)&&p.total>=p.rows.length&&(p.next_offset===null||(Number.isSafeInteger(p.next_offset)&&p.next_offset>=0))
  && (p.my_result===null||rowValid(p.my_result))&&p.reward?.additional_payout===false
  && ((p.status==='official'&&p.official===true&&p.source===(kind==='season'?'season_snapshot':'month_snapshot'))||(p.status!=='official'&&p.official===false&&p.source==='current_ledger_reconstruction'))}
 function resultRow(r){const a=node('article','');a.className='item';const strong=node('strong',(r.points>0?'#'+r.rank:'Ohne Podiumsplatz')+' · '+r.name);strong.className='place';a.append(strong,node('p',fmt(r.points)+' Punkte · '+fmt(r.exp)+' EXP im Zeitraum'));return a}
 function render(p,append){
  if(!append){
   $('periodTitle').textContent=p.kind==='month'?new Date(p.key+'-01T12:00:00Z').toLocaleDateString('de-CH',{month:'long',year:'numeric'}):p.title;
   $('periodSummary').textContent=statuses[p.status]+' · '+date(p.starts_on)+' bis '+date(p.ends_on)+' · Europe/Zurich. '+
    (p.official?'Gespeicherter '+(p.kind==='season'?'Saisonendstand':'Monatsendstand')+'. Heute ausgeblendete Profile werden nicht erneut veröffentlicht.':'Aus aktuellem Buchungsstand berechnet. Spätere Buchungen oder Korrekturen können die Werte ändern. Kein offizieller Abschluss.');
   $('periodReward').textContent='EXP im Ergebnis sind vorhandene Buchungen, keine neue Abschlussprämie. Eine zusätzliche Belohnung ist nicht eingerichtet.';
   $('periodPodium').replaceChildren();for(const r of p.top){const a=node('article','');a.className='item';a.append(node('strong','#'+r.rank+' · '+r.name),node('p',fmt(r.points)+' Punkte'));$('periodPodium').append(a)}
   if(!p.top.length)$('periodPodium').append(node('p','Noch keine Topplätze mit positiven Punkten.'));
   $('honors').replaceChildren();for(const h of p.honors){const a=node('article','');a.className='item';a.append(node('strong',h.name+' · '+h.title),node('p',h.description||''));$('honors').append(a)}
   if(!p.honors.length)$('honors').append(node('p',p.official?'Keine veröffentlichten Ehrungen für diese Periode.':'Noch keine offiziellen Ehrungen für diese Periode.'));
   $('results').replaceChildren();$('periodMine').hidden=!p.my_result;
   $('periodMine').textContent=p.my_result?'Dein Ergebnis: '+(p.my_result.points>0?'#'+p.my_result.rank:'ohne Podiumsplatz')+' · '+fmt(p.my_result.points)+' Punkte':'';
  }
  for(const r of p.rows)$('results').append(resultRow(r));
  if(!p.total)$('results').append(node('p','Noch keine veröffentlichten Ergebnisse für diesen Zeitraum.'));
  next=p.next_offset;$('moreResults').hidden=next===null;
  say(statuses[p.status]+' · '+$('results').querySelectorAll('article').length+' von '+p.total+' Ergebnissen');
 }
 async function load(kind,key,append=false,keepClose=false){
  if(append&&loading)return;
  if(!['month','season'].includes(kind)||(kind==='month'?!month.test(key):!uuid.test(key))){epoch++;clear();say('Ungültiger Zeitraum-Link. Bitte Monat oder Saison wählen.');return}
  const request=++epoch,offset=append?next:0;loading=true;$('moreResults').disabled=true;
  if(!append){selected={kind,key};clear();if(!keepClose)staffClose?.clear();$('periodTitle').textContent='Zeitraum wird geladen';$('periodSummary').textContent='';$('periodReward').textContent='';
   $('periodKind').value=kind;if(kind==='month')$('periodMonth').value=key;else $('periodSeason').value=key;controls()}
  say('Lade genau diesen Zeitraum …');
  try{
   if(!db)throw Error('Die Verbindung zum Archiv ist noch nicht verfügbar.');
   const {data,error}=await db.rpc('league_archive_period',{p_kind:kind,p_key:key,p_limit:20,p_offset:offset});
   if(request!==epoch)return;
   if(error)throw Error(error.code==='PGRST202'?'Die neue Archivansicht ist noch nicht freigegeben.':'Der gewählte Zeitraum konnte nicht geladen werden.');
   if(!valid(data,kind,key)||data.next_offset!==null&&data.next_offset<=offset)throw Error('Das Archiv hat keine gültige Antwort für diesen Zeitraum geliefert.');
   if(kind==='season'&&!seasons.has(key)){const opt=node('option',data.title);opt.value=key;$('periodSeason').append(opt);seasons.set(key,data);
    if($('periodKind').value===kind&&!$('periodSeason').value)$('periodSeason').value=key}
   render(data,append);if(!append&&!keepClose)staffClose?.setPeriod(kind,key);const url=new URL(location.href);url.searchParams.delete('month');url.searchParams.delete('season');url.searchParams.set(kind,key);history.replaceState(null,'',url);
  }catch(e){if(request!==epoch)return;if(!append)clear();say(e.message||'Archiv derzeit nicht verfügbar.');$('moreResults').hidden=next===null}
  finally{if(request===epoch){loading=false;$('moreResults').disabled=false}}
 }
 async function loadSeasons(){
  if(seasonLoading)return;seasonLoading=true;$('moreSeasons').disabled=true;
  try{
   const url=new URL(API+'/rest/v1/league_seasons_v21');for(const [k,v] of Object.entries({select:'id,title,starts_on,ends_on,status',status:'in.(active,closed)',order:'starts_on.desc,id.asc',limit:'20',offset:String(seasonOffset)}))url.searchParams.set(k,v);
   const r=await fetch(url,{headers:{apikey:KEY},cache:'no-store'});if(!r.ok)throw Error('Saisonliste derzeit nicht verfügbar.');const rows=await r.json();if(!Array.isArray(rows))throw Error('Ungültige Saisonliste.');
   if(!seasonOffset)$('seasons').replaceChildren();
   for(const s of rows){if(!uuid.test(s.id)||!['active','closed'].includes(s.status))continue;
    if(!seasons.has(s.id)){const opt=node('option',s.title);opt.value=s.id;$('periodSeason').append(opt)}seasons.set(s.id,s);
    const article=node('article','');article.className='item';const button=node('button',s.title);button.type='button';button.onclick=()=>load('season',s.id);article.append(button,node('p',date(s.starts_on)+' bis '+date(s.ends_on)+' · '+(s.status==='closed'?'Abgeschlossen':'Aktiv')));$('seasons').append(article);
   }
   seasonOffset+=rows.length;$('moreSeasons').hidden=rows.length<20;if(!seasonOffset)$('seasons').append(node('p','Noch keine veröffentlichte Saison.'));
  }catch(e){if(!seasonOffset)$('seasons').textContent=e.message;$('moreSeasons').hidden=false}
  finally{seasonLoading=false;$('moreSeasons').disabled=false}
 }
 $('periodMonth').value=currentMonth;$('periodMonth').max=currentMonth;
 $('periodKind').onchange=controls;$('periodForm').onsubmit=e=>{e.preventDefault();load($('periodKind').value,$('periodKind').value==='month'?$('periodMonth').value:$('periodSeason').value)};
 $('moreResults').onclick=()=>{if(selected&&next!==null)load(selected.kind,selected.key,true)};$('moreSeasons').onclick=loadSeasons;
 const params=new URLSearchParams(location.search),both=params.has('month')&&params.has('season');
 const initial={kind:params.has('season')?'season':'month',key:params.get('season')??params.get('month')??currentMonth};
 loadSeasons();controls();
 (async()=>{try{const m=await import('./takeover-client.js');db=m.createClient(API,KEY);
  staffClose=window.TLPeriodClose?.create({host:$('periodClose'),db,onClosed:(kind,key)=>load(kind,key,false,true)});
  db.auth.onAuthStateChange?.(event=>{if(['SIGNED_OUT','SIGNED_IN','USER_UPDATED'].includes(event)){epoch++;staffClose?.clear();$('periodMine').hidden=true;$('periodMine').textContent='';setTimeout(()=>{if(selected)load(selected.kind,selected.key)},0)}});
  if(both){clear();say('Der Link enthält zwei Perioden. Bitte genau einen Monat oder eine Saison wählen.')}else await load(initial.kind,initial.key);
 }catch(_){say('Das Archiv konnte nicht verbunden werden. Bitte erneut laden.')}})();
})();
