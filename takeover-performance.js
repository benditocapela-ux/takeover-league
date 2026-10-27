/* Takeover League · Coach-Bewertung (Spielerkarte) und Boxstil-Test.
 * Gemeinsame Bausteine für bewertung.html, stil-test.html, Mein Studio und das Boxerprofil.
 * Alle Daten kommen aus geprüften RPCs (Rollen, Sichtbarkeit und Feature-Flags prüft der Server).
 * Gäste sehen nichts; andere Liga-Mitglieder sehen nur die Karte, nie Einzelnoten oder Kommentare.
 */
(function(){
'use strict';
const SB_URL='https://iqarjivcrddcixrvqbfb.supabase.co',SB_KEY='sb_publishable_o--Z21P8Q08lMvIOask_Fw__SRRX7_R';
let clientPromise=null;
function client(){
 if(!clientPromise)clientPromise=import('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm').then(m=>m.createClient(SB_URL,SB_KEY));
 return clientPromise;
}
const CATS=[
 {k:'OFF',n:'Offense',w:25,s:[['jab','Jab','schnell, gerade und sofort zurück in die Deckung'],['cross','Gerade (hintere Hand)','mit Hüftdrehung, Kinn bleibt geschützt'],['hook','Haken','kurz, mit Drehung, Ellbogen auf Schulterhöhe'],['upper','Uppercut','aus den Beinen, nicht ausholen'],['body','Körperschläge','Knie beugen, nicht nur mit dem Arm'],['combo','Kombinationen','Schläge fliessend verbinden']]},
 {k:'DEF',n:'Defense',w:25,s:[['guard','Deckung','Hände oben, Ellbogen eng am Körper'],['block','Blocken','Schläge mit Handschuhen und Armen abfangen'],['slip','Ausweichen (Slip)','Kopf knapp neben dem Schlag vorbei'],['roll','Abtauchen (Roll)','unter dem Haken durch, Augen beim Gegner'],['parry','Parieren','Schlag mit der Hand zur Seite lenken'],['counter','Konter nach Abwehr','nach dem Abwehren sofort zurückschlagen']]},
 {k:'BEI',n:'Beinarbeit',w:20,s:[['stance','Stellung & Balance','stabil, nie mit gekreuzten Füssen'],['steps','Schritte vor und zurück','kleine Schritte, Abstand halten'],['angles','Winkel & Seitwärts','raus aus der Linie, neue Winkel finden'],['ring','Ringkontrolle','nicht in die Ecke drängen lassen']]},
 {k:'KON',n:'Kondition',w:10,s:[['endur','Ausdauer','bis zur letzten Runde gleich stark'],['pace','Tempo halten','dein Tempo über alle Runden'],['recov','Erholung in der Pause','schnell wieder ruhig atmen']]},
 {k:'TAK',n:'Taktik',w:10,s:[['timing','Timing','im richtigen Moment schlagen'],['dist','Distanzgefühl','wissen, wann du triffst und wann nicht'],['plan','Plan umsetzen','das machen, was ihr besprochen habt']]},
 {k:'MEN',n:'Mentalität',w:10,s:[['focus','Konzentration','auch nach einem Treffer ruhig bleiben'],['heart','Kampfgeist','nie aufgeben'],['coach','Coach-Tipps umsetzen','Hinweise schnell einbauen']]}
];
const SKILL={};CATS.forEach(c=>c.s.forEach(([k,n,h])=>{SKILL[k]={n,h,c:c.k}}));
const SKILL_KEYS=CATS.flatMap(c=>c.s.map(s=>s[0]));
const AX=[
 {k:'o',l:'DISTANZ',n:'Distanz-Boxer',pos:'DIS',p:'hältst gern Abstand und arbeitest mit schnellen Füssen',tip:'Übe Jab und Schritt zurück. Seilspringen macht deine Füsse schnell.'},
 {k:'v',l:'SCHLAGZAHL',n:'Schlag-Maschine',pos:'VOL',p:'wirfst viele Schläge hintereinander',tip:'Trainiere Ausdauer: Rundenarbeit am Sandsack mit 5er-Kombinationen.'},
 {k:'c',l:'KONTER',n:'Konter-Boxer',pos:'KTR',p:'wartest auf Fehler und schlägst sofort zurück',tip:'Übe an der Pratze: blocken und direkt zurückschlagen.'},
 {k:'p',l:'DRUCK',n:'Druck-Boxer',pos:'DRK',p:'gehst nach vorne und machst Druck',tip:'Übe Kopfbewegung beim Vorwärtsgehen, damit du weniger getroffen wirst.'},
 {k:'s',l:'PRÄZISION',n:'Scharfschütze',pos:'PRZ',p:'suchst den einen genauen Treffer',tip:'Übe einzelne harte Schläge auf ein kleines Ziel, zum Beispiel Pratze mit Zahlen.'},
 {k:'a',l:'ANGRIFF',n:'Angreifer',pos:'ANG',p:'willst den ersten Schlag setzen',tip:'Übe einen schnellen Jab als Eröffnung und danach sofort Deckung hoch.'}
];
// Reihenfolge der Antworten muss zu league_private.style_weights() passen (Frage 1–8, Antwort A–C).
const QUESTIONS=[
 {q:'Wie triffst du am liebsten?',tip:'Denk an dein letztes Sparring. Wie hast du getroffen?',o:[['Mit vielen Schlägen schnell hintereinander','Zum Beispiel Jab, Jab, Gerade, Haken.'],['Das kommt auf meinen Gegner an','Gegen einen schnellen Gegner boxe ich anders als gegen einen langsamen.'],['Mit einem einzigen, genauen Schlag','Ein Treffer am richtigen Ort im richtigen Moment.']]},
 {q:'Wo stehst du im Ring meistens?',tip:'Stell dir den Ring von oben vor, wie auf einer Landkarte.',o:[['In der Mitte','Ich bleibe vorne und lasse mich nicht zurückdrängen.'],['Mal hier, mal dort','Ich bin im ganzen Ring unterwegs.'],['Aussen, nahe am Seil','Ich kreise um meinen Gegner herum.']]},
 {q:'Wer schlägt bei euch zuerst?',tip:'Es gibt keine falsche Antwort. Antworte so, wie es wirklich ist.',o:[['Ich','Ich will den ersten Schlag setzen.'],['Mal ich, mal mein Gegner','Das ist bei mir verschieden.'],['Mein Gegner','Ich warte, bis er angreift, und schlage dann zurück.']]},
 {q:'Dein Gegner kommt mit vielen Schlägen auf dich zu. Was machst du?',tip:'Stell dir vor, du stehst gerade im Ring.',o:[['Ich bleibe stehen und schlage auch','Ich halte dagegen.'],['Ich gehe zur Seite weg','Mit einem Schritt raus, damit er ins Leere schlägt.'],['Ich blocke und schlage sofort zurück','Erst Deckung, dann Konter.']]},
 {q:'Wie weit weg vom Gegner fühlst du dich am wohlsten?',tip:'Abstand heisst: wie weit ihr auseinander steht.',o:[['Nah dran','So nah, dass ich Haken schlagen kann.'],['Ich wechsle gern','Mal nah, mal weit weg.'],['Eher weit weg','So weit, dass ich gerade noch mit dem Jab treffe.']]},
 {q:'Gegen wen boxt du lieber?',tip:'Welcher Gegner macht dir mehr Spass?',o:[['Gegen einen, der nur blockt','Er schlägt nach dem Blocken nicht zurück. Dann kann ich viel angreifen.'],['Das ist mir egal','Ich komme mit beiden klar.'],['Gegen einen, der beim Angreifen die Deckung vergisst','Dann finde ich Lücken für meine Konter.']]},
 {q:'Wie viele Schläge wirfst du meistens auf einmal?',tip:'Eine Kombination sind mehrere Schläge direkt hintereinander.',o:[['1 bis 2','Kurz und genau.'],['3 bis 4','Eine normale Kombination.'],['5 oder mehr','Ich höre nicht so schnell auf.']]},
 {q:'Was ist dir im Kampf am wichtigsten?',tip:'Wähle das, was dir am meisten bedeutet.',o:[['Selbst nicht getroffen werden','Gute Verteidigung zuerst.'],['Den Gegner müde machen','Immer weiter Druck und Schläge.'],['Sauber und hart treffen','Lieber wenige, aber gute Treffer.']]}
];
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
// Spiegel von league_private.rating_summary (nur für die Live-Vorschau im Bewertungsformular).
function summary(scores){
 const categories={};
 for(const c of CATS){const avg=c.s.reduce((t,s)=>t+Number(scores[s[0]]),0)/c.s.length;categories[c.k]=Math.min(99,Math.round(avg*10))}
 const overall=Math.min(99,Math.round(CATS.reduce((t,c)=>t+categories[c.k]*c.w,0)/100));
 return {categories,overall};
}
const tier=o=>o>=85?['elite','Elite']:o>=75?['gold','Gold']:o>=65?['silber','Silber']:['bronze','Bronze'];
function styleType(v){
 const s=AX.slice().sort((a,b)=>v[b.k]-v[a.k]),top=s[0],sec=s[1],spread=v[top.k]-v[s[5].k];
 if(spread<25)return {title:'Allrounder',kind:'Du kannst von allem etwas.',text:'Du passt dich deinem Gegner an und hast keine grosse Schwäche.',tip:'Such dir eine Stärke aus und trainiere sie gezielt, dann wirst du gefährlicher.',pos:'ALL'};
 if(v[top.k]-v[sec.k]>=15)return {title:top.n,kind:'Du hast einen klaren Stil!',text:'Du '+top.p+'. Ein bisschen '+sec.n+' steckt auch in dir.',tip:top.tip,pos:top.pos};
 return {title:top.n+' + '+sec.n,kind:'Du bist ein Mischtyp.',text:'Du '+top.p+' und '+sec.p+'.',tip:top.tip,pos:top.pos};
}
function radarSVG(v,prev,size){
 const R=92,pt=(i,val)=>{const a=-Math.PI/2+i*Math.PI/3,r=R*val/100;return [(Math.cos(a)*r).toFixed(1),(Math.sin(a)*r).toFixed(1)]};
 const ring=f=>AX.map((_,i)=>pt(i,f).join(',')).join(' ');
 const poly=vals=>AX.map((a,i)=>pt(i,Number(vals[a.k])||0).join(',')).join(' ');
 const labels=AX.map((a,i)=>{const [x,y]=pt(i,128);return `<text x="${x}" y="${(+y+4).toFixed(1)}" text-anchor="middle" class="tlp-rl">${a.l}</text><text x="${x}" y="${(+y+19).toFixed(1)}" text-anchor="middle" class="tlp-rv">${Number(v[a.k])||0}</text>`}).join('');
 return `<svg class="tlp-radar" viewBox="-160 -150 320 300" width="${size||320}" role="img" aria-label="Stil-Diagramm: ${AX.map(a=>a.l+' '+(Number(v[a.k])||0)).join(', ')}">
  ${[20,40,60,80,100].map(f=>`<polygon points="${ring(f)}" class="tlp-grid${f===100?' outer':''}"/>`).join('')}
  ${AX.map((_,i)=>{const [x,y]=pt(i,100);return `<line x1="0" y1="0" x2="${x}" y2="${y}" class="tlp-grid"/>`}).join('')}
  ${prev?`<polygon points="${poly(prev)}" class="tlp-prev"/>`:''}
  <polygon points="${poly(v)}" class="tlp-shape"/>
  ${labels}</svg>`;
}
function deltaTag(d,big){
 if(d===null||d===undefined)return '';
 d=Number(d);
 return d>0?`<span class="tlp-dl up${big?' big':''}">▲ +${d}</span>`:d<0?`<span class="tlp-dl down${big?' big':''}">▼ ${d}</span>`:`<span class="tlp-dl same${big?' big':''}">±0</span>`;
}
function fmtDate(iso){
 if(!iso)return '–';
 try{return new Intl.DateTimeFormat('de-CH',{day:'2-digit',month:'2-digit',year:'numeric',timeZone:'Europe/Zurich'}).format(new Date(iso))}catch(_){return String(iso).slice(0,10)}
}
function initials(name){return String(name||'?').trim().split(/\s+/).map(x=>x[0]||'').join('').slice(0,2).toUpperCase()||'?'}
// Spielerkarte: name, overall, categories, pos, delta (optional)
function card(o){
 const [tc,tl]=tier(o.overall);
 return `<div class="tlp-card t-${tc}" style="--fw:${o.width||170}px" role="img" aria-label="Spielerkarte ${esc(o.name)}: Gesamt ${o.overall}, ${CATS.map(c=>c.n+' '+o.categories[c.k]).join(', ')}">
  <div class="tlp-top"><div><div class="tlp-ov">${o.overall}</div><div class="tlp-pos">${esc(o.pos||'BOX')}</div>${o.delta?`<div class="tlp-d ${o.delta>0?'up':'down'}">${o.delta>0?'▲':'▼'}${Math.abs(o.delta)}</div>`:''}</div><div class="tlp-face">${esc(initials(o.name))}</div></div>
  <div class="tlp-name">${esc(String(o.name||'').toUpperCase())}</div>
  <div class="tlp-stats">${CATS.map(c=>`<span><b>${o.categories[c.k]}</b> ${c.k}</span>`).join('')}</div>
  <div class="tlp-foot">TKL · ${tl}</div></div>`;
}

/* ---- automatische Bausteine im Boxerprofil und in Mein Studio ---- */
async function mountProfile(){
 const name=(new URLSearchParams(location.search).get('name')||'').trim();
 const anchor=document.getElementById('sportProfile');
 if(!name||!anchor)return;
 const db=await client();
 const s=await db.auth.getSession();if(!s.data||!s.data.session)return;
 const {data,error}=await db.rpc('get_performance_card',{p_display_name:name});
 if(error||!data||(!data.rating&&!data.style))return;
 const box=document.createElement('section');box.className='tlp-profile';box.setAttribute('aria-label','Coach-Bewertung und Boxstil');
 let html='';
 if(data.rating){
  const r=data.rating,pos=data.style&&data.style.scores?styleType(data.style.scores).pos:'BOX';
  html+=`<div class="tlp-block"><h2>Coach-Bewertung</h2><div class="tlp-row">${card({name:data.display_name,overall:r.overall,categories:r.categories,pos,delta:r.delta,width:150})}
   <div class="tlp-side"><div class="tlp-eyebrow">Gesamt</div><div class="tlp-big">${r.overall} ${deltaTag(r.delta,true)}</div><div class="tlp-note">aktualisiert am ${fmtDate(r.rated_at)}</div>
   <div class="tlp-eyebrow ok">Stärken</div>${(r.top||[]).map(x=>`<div class="tlp-note">${esc(SKILL[x.k]?SKILL[x.k].n:x.k)} <b class="ok">${x.v}</b></div>`).join('')}
   <div class="tlp-eyebrow bad">Daran arbeiten</div>${(r.low||[]).map(x=>`<div class="tlp-note">${esc(SKILL[x.k]?SKILL[x.k].n:x.k)} <b class="bad">${x.v}</b></div>`).join('')}</div></div></div>`;
 }
 if(data.style&&data.style.scores){
  const t=styleType(data.style.scores);
  html+=`<div class="tlp-block"><h2>Boxstil</h2><div class="tlp-center">${radarSVG(data.style.scores,null,280)}<strong class="tlp-type">${esc(t.title)}</strong><p class="tlp-note">${esc(t.text)} · Test vom ${fmtDate(data.style.created_at)}</p></div></div>`;
 }
 box.innerHTML=html;anchor.after(box);
}
async function mountStudio(){
 const host=document.getElementById('studioPanelOverview');if(!host)return;
 const db=await client();
 const s=await db.auth.getSession();if(!s.data||!s.data.session)return;
 const {data,error}=await db.rpc('get_my_performance');
 if(error||!data||(!data.ratings_enabled&&!data.style_enabled))return;
 const tiles=[];
 if(data.ratings_enabled){
  const r=data.rating;
  if(r&&r.current){const o=r.current.summary.overall,d=r.previous?o-r.previous.summary.overall:null;
   tiles.push(`<a class="tlp-tile" href="./bewertung.html"><span class="tlp-chip t-${tier(o)[0]}">${o}</span><span><span class="tlp-eyebrow">Coach-Bewertung</span><strong>Gesamt ${o} ${deltaTag(d)}</strong><span class="tlp-note">aktualisiert am ${fmtDate(r.current.created_at)}</span></span></a>`);
  }else tiles.push(`<a class="tlp-tile" href="./bewertung.html"><span class="tlp-chip t-bronze">–</span><span><span class="tlp-eyebrow">Coach-Bewertung</span><strong>Noch keine Bewertung</strong><span class="tlp-note">Dein Coach bewertet dich bald.</span></span></a>`);
 }
 if(data.style_enabled){
  const st=data.style||{},cur=st.current,state=st.state||{};
  tiles.push(`<a class="tlp-tile" href="./stil-test.html"><span class="tlp-chip t-gold">${cur?esc(styleType(cur.scores).pos):'?'}</span><span><span class="tlp-eyebrow">Boxstil-Test</span><strong>${cur?esc(styleType(cur.scores).title):'Welcher Boxer-Typ bist du?'}</strong><span class="tlp-note">${state.can_take?'Test diesen Monat offen':'nächster Test ab '+fmtDate(state.next_allowed_on)}</span></span></a>`);
 }
 const box=document.createElement('div');box.className='tlp-tiles';box.innerHTML=tiles.join('');
 host.prepend(box);
}
function boot(){
 const screen=document.body&&document.body.dataset.tlScreen;
 const run=fn=>fn().catch(e=>console.warn('Bewertung/Boxstil nicht verfügbar:',e));
 if(screen==='boxer-profile')run(mountProfile);
 if(screen==='boxer')run(mountStudio);
}
window.TLPerf={client,CATS,SKILL,SKILL_KEYS,AX,QUESTIONS,esc,summary,tier,styleType,radarSVG,deltaTag,fmtDate,card,initials};
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',boot);else boot();
})();
