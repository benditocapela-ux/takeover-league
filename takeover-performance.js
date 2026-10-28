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
// Etappe 7a: Texte zum Bewertungsregler (1–20) in fünf Stufen: 1–4, 5–8, 9–12, 13–16, 17–20.
const BAND_NAMES=['Anfang','Grundlagen','Solide','Stark','Elite'];
const BANDS={
 jab:['Kommt selten, langsam oder mit offener Deckung','Sitzt im Training, ist aber oft angedeutet oder zu kurz','Gerade, schnell und kommt zuverlässig zurück','Steuert Distanz und Tempo, auch doppelt und zum Körper','Echte Waffe: trifft, öffnet Kombinationen, bleibt unter Druck sauber'],
 cross:['Ohne Hüfte, Kinn offen, verliert die Balance','Hüfte dreht mit, der Weg zurück in die Deckung ist noch langsam','Kraftvoll und gerade, Kinn bleibt geschützt','Präzise aus der Kombination und als Konter','Schlagkräftig und getimt, ohne Lücke – auch wenn er müde ist'],
 hook:['Holt weit aus, Ellbogen hängt','Kurz, aber Drehung und Füsse fehlen noch','Kompakt mit Drehung, Deckung bleibt oben','Zum Kopf und Körper, aus Kombination und als Konter','Gefährlicher Haken, auch im Rückwärtsgehen'],
 upper:['Ausgeholt, kommt nur aus dem Arm','Richtige Richtung, die Beine helfen noch kaum','Aus den Beinen, kurz und kontrolliert','Gezielt in der Halbdistanz eingesetzt','Treffsichere Waffe im Nahkampf'],
 body:['Schlägt nur mit dem Arm nach unten','Beugt die Knie, verliert dabei aber die Deckung','Knie gebeugt, Deckung oben, sauber zurück nach oben','Wechselt Kopf und Körper bewusst ab','Macht den Gegner gezielt mit Körpertreffern müde'],
 combo:['Einzelne Schläge mit langen Pausen','2er- und 3er-Kombis im Training, im Sparring stockend','Flüssige 3er- und 4er-Kombis, endet mit Deckung','Variiert Kombis, wechselt Höhe und Rhythmus','Kreative Kombis auch unter Druck, mit Bewegung zum Schluss'],
 guard:['Hände fallen oft, Kinn ist offen','Deckung steht, fällt aber beim Schlagen','Hände oben, Ellbogen eng, auch beim Schlagen','Deckung hält auch müde und in Bewegung','Kaum Lücken, über alle Runden'],
 block:['Blockt selten, dreht den Kopf weg','Blockt Gerade, Haken kommen noch durch','Blockt Kopf und Körper sicher','Blockt und bleibt dabei in Schlagposition','Blockt aktiv und kontert sofort'],
 slip:['Bewegt den Kopf kaum','Weicht aus, aber zu gross oder zu spät','Knappes Ausweichen gegen den Jab','Weicht auch Geraden und Kombinationen aus','Liest den Schlag und landet direkt in der Konterposition'],
 roll:['Duckt sich nach vorne, Augen zu','Taucht unter langsamen Haken durch','Taucht mit gebeugten Knien ab, Augen beim Gegner','Taucht ab und kommt mit Winkel heraus','Taucht flüssig ab und kontert direkt'],
 parry:['Pariert nicht','Pariert im Partnertraining, im Sparring selten','Lenkt den Jab sicher ab','Pariert Jab und Gerade, bleibt kompakt','Pariert und kontert in einer Bewegung'],
 counter:['Nach der Abwehr kommt nichts zurück','Konter kommt, aber zu spät','Kontert nach Block oder Ausweichen mit 1–2 Schlägen','Konter sitzen, auch mit Haken und zum Körper','Lockt Fehler heraus und bestraft sie sofort'],
 stance:['Steht schief, Füsse kreuzen sich','Stellung stimmt im Stand, aber nicht in Bewegung','Stabile Stellung, auch beim Schlagen','Balance hält auch bei Druck und in Kombinationen','Immer im Gleichgewicht, nie überdreht'],
 steps:['Springt oder schleift die Füsse','Kleine Schritte, Abstand noch ungenau','Sauber vor und zurück, Abstand passt','Wechselt Tempo und Rhythmus der Schritte','Kontrolliert die Distanz jederzeit'],
 angles:['Bleibt auf einer Linie','Geht seitwärts, aber ohne Plan','Verlässt die Linie nach Kombinationen','Schafft sich Winkel zum Angreifen','Drehungen und Winkel wie selbstverständlich'],
 ring:['Landet oft in der Ecke oder am Seil','Kommt aus der Ecke heraus, aber spät','Bleibt meistens in der Ringmitte','Drängt den Gegner dorthin, wo er ihn haben will','Kontrolliert den Ring über alle Runden'],
 endur:['Nach einer Runde ausser Atem','Hält 2 Runden, dann deutlich schwächer','Hält 3 Runden mit leichtem Einbruch','Das ganze Sparring auf gleichem Niveau','Legt in der letzten Runde sogar noch zu'],
 pace:['Tempo schwankt stark','Startet schnell und baut dann ab','Hält ein solides Tempo','Bestimmt das Tempo selbst','Kann das Tempo gezielt erhöhen und brechen'],
 recov:['Braucht die ganze Pause und mehr','Atmung beruhigt sich nur langsam','Nach 30–40 Sekunden wieder bereit','Schnell erholt und hört in der Pause gut zu','Sofort wieder frisch, nutzt die Pause für den Plan'],
 timing:['Schlägt, wenn der Gegner bereit ist','Trifft ab und zu im richtigen Moment','Erkennt offensichtliche Lücken','Trifft, wenn der Gegner einsteigt','Perfektes Timing, auch gegen schnelle Gegner'],
 dist:['Schlägt oft ins Leere oder steht zu nah','Distanz stimmt nur im Stand','Kennt die eigene Reichweite','Spielt mit der Distanz: rein und wieder raus','Bleibt ausser Reichweite und trifft trotzdem'],
 plan:['Kein Plan erkennbar','Plan in der ersten Runde, danach vergessen','Hält sich meistens an die Vorgabe','Setzt den Plan um und passt ihn an','Ändert den Plan selbstständig und klug'],
 focus:['Nach einem Treffer aus dem Konzept','Fängt sich nach einigen Sekunden wieder','Bleibt meistens ruhig und konzentriert','Ruhig auch bei Rückstand oder Druck','Eiskalt in jeder Situation'],
 heart:['Gibt bei Druck schnell auf','Kämpft, solange es gut läuft','Zieht bis zum Ende durch','Kommt nach schweren Runden zurück','Unbeugsam und reisst andere mit'],
 coach:['Hört Tipps, setzt sie aber nicht um','Setzt Tipps erst nach mehrmaligem Erklären um','Setzt Tipps in der nächsten Runde um','Setzt Tipps sofort um und fragt nach','Denkt mit und bringt eigene Lösungen']
};
const bandIdx=v=>Math.max(0,Math.min(4,Math.floor((Number(v)-1)/4)));
function band(k,v){const i=bandIdx(v);return {i,name:BAND_NAMES[i],text:(BANDS[k]||[])[i]||''}}
// Einzelnote auf die 20er-Skala bringen (bisherige Bewertungen sind auf 1–10 gespeichert).
const to20=(v,scale)=>Number(v)*(Number(scale)===20?1:2);
// Spiegel von league_private.rating_summary (nur für die Live-Vorschau im Bewertungsformular).
function summary(scores,scale){
 const sc=Number(scale)===20?20:10,categories={};
 for(const c of CATS){const avg=c.s.reduce((t,s)=>t+Number(scores[s[0]]),0)/c.s.length;categories[c.k]=Math.min(99,Math.round(avg*100/sc))}
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
// Etappe 7a: zwei Stile übereinander (gold = eigener bzw. linker Boxer, blau = Vergleich) mit gemeinsamer Fläche.
// Die gemeinsame Fläche (Minimum je Achse) liegt immer innerhalb beider Formen.
function similarity(a,b){
 let lo=0,hi=0;for(const x of AX){const u=Number(a[x.k])||0,v=Number(b[x.k])||0;lo+=Math.min(u,v);hi+=Math.max(u,v)}
 return hi?Math.round(lo*100/hi):100;
}
function radarCompare(gold,blue,o){
 o=o||{};
 const R=92,pt=(i,val)=>{const a=-Math.PI/2+i*Math.PI/3,r=R*val/100;return [(Math.cos(a)*r).toFixed(1),(Math.sin(a)*r).toFixed(1)]};
 const ring=f=>AX.map((_,i)=>pt(i,f).join(',')).join(' ');
 const poly=vals=>AX.map((a,i)=>pt(i,Number(vals[a.k])||0).join(',')).join(' ');
 const both={};AX.forEach(a=>{both[a.k]=Math.min(Number(gold[a.k])||0,Number(blue[a.k])||0)});
 const labels=AX.map((a,i)=>{const [x,y]=pt(i,128);return `<text x="${x}" y="${(+y+2).toFixed(1)}" text-anchor="middle" class="tlp-rl">${a.l}</text><text x="${x}" y="${(+y+17).toFixed(1)}" text-anchor="middle" class="tlp-rv2"><tspan class="g">${Number(gold[a.k])||0}</tspan> · <tspan class="b">${Number(blue[a.k])||0}</tspan></text>`}).join('');
 return `<svg class="tlp-radar tlp-radar-cmp" viewBox="-160 -150 320 300" width="${o.size||320}" role="img" aria-label="Stil-Vergleich: ${AX.map(a=>a.l+' '+esc(o.goldName||'')+' '+(Number(gold[a.k])||0)+', '+esc(o.blueName||'')+' '+(Number(blue[a.k])||0)).join('; ')}">
  ${[20,40,60,80,100].map(f=>`<polygon points="${ring(f)}" class="tlp-grid${f===100?' outer':''}"/>`).join('')}
  ${AX.map((_,i)=>{const [x,y]=pt(i,100);return `<line x1="0" y1="0" x2="${x}" y2="${y}" class="tlp-grid"/>`}).join('')}
  <polygon points="${poly(blue)}" class="tlp-shape2"/><polygon points="${poly(gold)}" class="tlp-shape"/><polygon points="${poly(both)}" class="tlp-overlap"/>
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
// Spielerkarte: name, overall, categories, pos, delta (optional), look (Etappe 7d: Karten-Design und Auszeichnungen)
const AWARD_LABEL={cotw:'Card of the Week',cotm:'Card of the Month',poty:'Player of the Year'};
const hex=v=>/^#[0-9a-f]{3,8}$/i.test(String(v||''))?v:null;
function card(o){
 const [tc,tl]=tier(o.overall),lk=o.look&&o.look.design&&!o.look.design.tier?o.look:null,d=lk?lk.design:null;
 const vars=d?['a','b','ink','edge'].map(k=>hex(d[k])?`--c${k}:${d[k]};`:'').join(''):'';
 const pat=d&&/^[a-z]{2,12}$/.test(d.pattern||'')?d.pattern:'';
 const awards=o.look&&Array.isArray(o.look.awards)?o.look.awards:[];
 const ho=o.look&&o.look.holo&&window.TLHolo?o.look.holo:null;
 const count=k=>awards.filter(a=>a.kind===k).length;
 const stars=['poty','cotm','cotw'].filter(k=>count(k)).map(k=>`<span title="${AWARD_LABEL[k]}">${k==='poty'?'👑':k==='cotm'?'🏆':'⭐'}${count(k)>1?count(k):''}</span>`).join('');
 return `<div class="tlp-card t-${tc}${d?' d-design':''}${d&&d.glow?' d-glow':''}"${pat?` data-pattern="${pat}"`:''} style="--fw:${o.width||170}px;${vars}" role="img" aria-label="Spielerkarte ${esc(o.name)}: Gesamt ${o.overall}, ${CATS.map(c=>c.n+' '+o.categories[c.k]).join(', ')}${lk?', Design '+esc(lk.name):''}${awards.length?', '+awards.length+' Auszeichnung'+(awards.length>1?'en':''):''}">
  ${d&&/^[A-Z]{3,5}$/.test(d.badge||'')?`<span class="tlp-badge">${d.badge}</span>`:''}
  <div class="tlp-top"><div><div class="tlp-ov">${o.overall}</div><div class="tlp-pos">${esc(o.pos||'BOX')}</div>${o.delta?`<div class="tlp-d ${o.delta>0?'up':'down'}">${o.delta>0?'▲':'▼'}${Math.abs(o.delta)}</div>`:''}</div>${ho?`<div class="tlp-holo">${window.TLHolo.svg(ho,{pose:ho.pose_card,scene:'none',holo:false})}</div>`:`<div class="tlp-face">${esc(initials(o.name))}</div>`}</div>
  <div class="tlp-name">${esc(String(o.name||'').toUpperCase())}</div>
  <div class="tlp-stats">${CATS.map(c=>`<span><b>${o.categories[c.k]}</b> ${c.k}</span>`).join('')}</div>
  <div class="tlp-foot">${stars?`<span class="tlp-stars">${stars}</span> `:''}TKL · ${lk?esc(lk.name):tl}</div></div>`;
}
// Karten-Looks (Design, Auszeichnungen) für mehrere Namen; leer, solange Karten-Designs nicht freigeschaltet sind.
async function looks(db,names){
 const list=names.filter(Boolean).slice(0,50);
 const safe=pr=>pr.then(r=>r.error||!r.data?{}:r.data).catch(()=>({}));
 const [c,h]=await Promise.all([safe(db.rpc('get_card_looks',{p_display_names:list})),safe(db.rpc('get_holo_looks',{p_display_names:list}))]);
 const out=Object.assign({},c);
 if(Object.keys(h).length){try{await holoLib()}catch(_){return out}for(const n of Object.keys(h))out[n]=Object.assign({},out[n]||{},{holo:h[n]})}
 return out;
}
// Etappe 9: Boxer-Holo-Zeichnungen erst laden, wenn jemand einen Holo hat.
let holoPromise=null;
function holoLib(){
 if(window.TLHolo)return Promise.resolve(window.TLHolo);
 if(!holoPromise)holoPromise=new Promise((ok,fail)=>{const sc=document.createElement('script');sc.src='./takeover-holo.js';sc.onload=()=>ok(window.TLHolo);sc.onerror=fail;document.head.appendChild(sc)});
 return holoPromise;
}

/* ---- automatische Bausteine im Boxerprofil und in Mein Studio ---- */
// Kampfgeist-Zeichnungen erst laden, wenn der Shop für diese Person sichtbar ist.
let kgPromise=null;
function kampfgeist(){
 if(window.TLKG)return Promise.resolve(window.TLKG);
 if(!kgPromise)kgPromise=new Promise((ok,fail)=>{const sc=document.createElement('script');sc.src='./takeover-kampfgeist.js';sc.onload=()=>ok(window.TLKG);sc.onerror=fail;document.head.appendChild(sc)});
 return kgPromise;
}
async function mountProfileLook(db,name,anchor){
 const {data,error}=await db.rpc('get_kg_look',{p_display_name:name});
 if(error||!data||!data.avatar)return;
 const K=await kampfgeist();
 const box=document.createElement('section');box.className='tlp-profile';box.setAttribute('aria-label','Kampfgeist-Karte');
 box.innerHTML=`<div class="tlp-block">${K.card(data,{name:data.name,size:104})}</div>`;anchor.after(box);
}
async function mountProfile(){
 const name=(new URLSearchParams(location.search).get('name')||'').trim();
 const anchor=document.getElementById('sportProfile');
 if(!name||!anchor)return;
 const db=await client();
 const s=await db.auth.getSession();if(!s.data||!s.data.session)return;
 const {data,error}=await db.rpc('get_performance_card',{p_display_name:name});
 const hl=(await looks(db,[name]).catch(()=>({})));const hk=Object.keys(hl).find(k=>k.toLowerCase()===name.toLowerCase()&&hl[k].holo);
 if(hk){const cfg=hl[hk].holo,hb=document.createElement('section');hb.className='tlp-profile';hb.setAttribute('aria-label','Boxer-Holo');
  hb.innerHTML=`<div class="tlp-block"><div class="tlh-stage">${window.TLHolo.svg(cfg,{pose:cfg.pose_profile,label:'Boxer-Holo von '+hk})}</div></div>`;anchor.after(hb)}
 else await mountProfileLook(db,name,anchor).catch(e=>console.warn('Kampfgeist-Karte nicht verfügbar:',e));
 if(error||!data||(!data.rating&&!data.style))return;
 const box=document.createElement('section');box.className='tlp-profile';box.setAttribute('aria-label','Coach-Bewertung und Boxstil');
 let html='';
 if(data.rating){
  const r=data.rating,pos=data.style&&data.style.scores?styleType(data.style.scores).pos:'BOX',lk=(await looks(db,[data.display_name]))[data.display_name];
  html+=`<div class="tlp-block"><h2>Coach-Bewertung</h2><div class="tlp-row">${card({name:data.display_name,overall:r.overall,categories:r.categories,pos,delta:r.delta,width:150,look:lk})}
   <div class="tlp-side"><div class="tlp-eyebrow">Gesamt</div><div class="tlp-big">${r.overall} ${deltaTag(r.delta,true)}</div><div class="tlp-note">aktualisiert am ${fmtDate(r.rated_at)}</div>
   <div class="tlp-eyebrow ok">Stärken</div>${(r.top||[]).map(x=>`<div class="tlp-note">${esc(SKILL[x.k]?SKILL[x.k].n:x.k)} <b class="ok">${to20(x.v,r.scale)}</b></div>`).join('')}
   <div class="tlp-eyebrow bad">Daran arbeiten</div>${(r.low||[]).map(x=>`<div class="tlp-note">${esc(SKILL[x.k]?SKILL[x.k].n:x.k)} <b class="bad">${to20(x.v,r.scale)}</b></div>`).join('')}</div></div></div>`;
 }
 if(data.style&&data.style.scores){
  const t=styleType(data.style.scores);
  html+=`<div class="tlp-block"><h2>Boxstil</h2><div class="tlp-center">${radarSVG(data.style.scores,null,280)}<strong class="tlp-type">${esc(t.title)}</strong><p class="tlp-note">${esc(t.text)} · Test vom ${fmtDate(data.style.created_at)}</p></div></div>`;
 }
 box.innerHTML=html;(document.querySelector('.tlp-profile[aria-label="Boxer-Holo"]')||anchor).after(box);
}
async function mountStudio(){
 const host=document.getElementById('studioPanelOverview');if(!host)return;
 const db=await client();
 const s=await db.auth.getSession();if(!s.data||!s.data.session)return;
 const [perf,wk,qs,kg,kp]=await Promise.all([db.rpc('get_my_performance'),db.rpc('get_my_week_plan'),db.rpc('get_my_quests'),db.rpc('get_my_kampfgeist',{p_full:false}),db.rpc('get_my_kampfpfad')]);
 const data=perf.data,error=perf.error,gym=!wk.error&&wk.data&&wk.data.enabled?wk.data:null,quest=!qs.error&&qs.data&&qs.data.enabled?qs.data:null;
 const myName=data&&data.profile&&data.profile.display_name;
 const holo=myName?(await looks(db,[myName]).catch(()=>({})))[myName]:null;
 const holoOn=!!(holo&&holo.holo)||await (async()=>{try{const r=await db.from('league_feature_flags').select('is_enabled').eq('feature_key','boxer_holo').maybeSingle();return !!(r&&r.data&&r.data.is_enabled===true)}catch(_){return false}})();
 const shop=!kg.error&&kg.data&&kg.data.enabled?kg.data:null;
 if(error||!data||(!data.ratings_enabled&&!data.style_enabled&&!gym&&!quest&&!shop&&!holoOn))return;
 const tiles=[];
 if(holoOn)tiles.push(`<a class="tlp-tile" href="./mein-boxer.html">${holo&&holo.holo?`<span class="tlh-mini">${window.TLHolo.svg(holo.holo,{pose:holo.holo.pose_profile,scene:'none',holo:false})}</span>`:'<span class="tlp-chip t-gold">🥊</span>'}<span><span class="tlp-eyebrow">Mein Boxer</span><strong>${holo&&holo.holo?'Outfit und Pose ändern':'Gestalte deinen Boxer'}</strong><span class="tlp-note">Haare, Kleidung, Mäntel, Auren und Posen</span></span></a>`);
 if(shop){
  const K=await kampfgeist(),rk=K.RANKS[shop.level.rank_idx];
  const pass=!kp.error&&kp.data&&kp.data.enabled?kp.data:null;
  if(pass){const open=pass.tiers.filter(t=>t.reached&&!t.claimed).length+(pass.previous_open||0);
   tiles.push(`<a class="tlp-tile" href="./kampfpfad.html"><span class="tlp-chip t-gold">${pass.points.tier}</span><span><span class="tlp-eyebrow">Kampfpfad</span><strong>${open?open+' Belohnung'+(open>1?'en':'')+' bereit':'Stufe '+pass.points.tier+' von 30'}</strong><span class="tlp-note">${K.fmt(pass.points.total)} Punkte · noch ${pass.days_left} Tage in diesem Monat</span></span></a>`)}
  tiles.push(`<a class="tlp-tile" href="./shop.html">${K.avatarBox(shop.look,52)}<span><span class="tlp-eyebrow">Kampfgeist-Shop</span><strong><span class="kg-price">${K.COIN}${K.fmt(shop.wallet.balance)}</span> Coins</strong><span class="tlp-note">Rang ${rk.r} · ${esc(rk.n)} · Level ${shop.level.level} · <span style="color:var(--gold)">Roadmap</span></span></span></a>`);
 }
 if(quest){
  const weekly=(quest.weekly||[]).filter(q=>q.available),done=weekly.filter(q=>q.done).length;
  const ready=[...weekly,...(quest.chest?[quest.chest]:[]),...(quest.daily||[]).filter(q=>q.key)].filter(q=>quest.can_claim&&q.done&&!q.claimed&&q.available&&q.period_start>=quest.claim_from).length;
  const today=(quest.daily||[]).find(q=>q.period_start===quest.today&&q.key);
  tiles.push(`<a class="tlp-tile" href="./quests.html"><span class="tlp-chip t-gold">${done}/${weekly.length}</span><span><span class="tlp-eyebrow">Wochen-Quests</span><strong>${ready?ready+' Belohnung'+(ready>1?'en':'')+' bereit':today?esc(today.title):'Quests dieser Woche'}</strong><span class="tlp-note">${today?(today.claimed?'Tagesquest abgeholt':today.done?'Tagesquest erfüllt':'Tagesquest offen'):'Wochenquests'} · +${quest.exp_week} EXP diese Woche</span></span></a>`);
 }
 if(gym){
  const target=gym.group?gym.group.weekly_target:2;
  tiles.push(`<a class="tlp-tile" href="./wochenplan.html"><span class="tlp-chip t-gold">${gym.trainings}/${target}</span><span><span class="tlp-eyebrow">Wochenplan${gym.group?' · '+esc(gym.group.name):''}</span><strong>${gym.plan&&gym.plan.focus?esc(gym.plan.focus):gym.plan?'Plan dieser Woche':'Noch kein Plan diese Woche'}</strong><span class="tlp-note">${gym.trainings>=target?'Wochenziel erreicht!':'noch '+(target-gym.trainings)+' Training'+(target-gym.trainings===1?'':'s')+' bis zum Wochenziel'}</span></span></a>`);
  tiles.push(`<a class="tlp-tile" href="./praesenz.html"><span class="tlp-chip t-silber">✓</span><span><span class="tlp-eyebrow">Präsenz</span><strong>Anwesenheit und Serie</strong><span class="tlp-note">Gym-Check-in und die letzten 4 Wochen</span></span></a>`);
 }
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
/* ---- Etappe 5: Emotes und Einlauf im Duell; Podium-Emote (Etappe 8) ---- */
let duelState=null,duelTimer=null;
async function mountDuels(){
 const list=document.getElementById('duelList');if(!list)return;
 const db=await client();
 const decorate=async()=>{
  const s=await db.auth.getSession();if(!s.data||!s.data.session)return;
  const cards=[...list.querySelectorAll('article.tl-duel-card[data-duel-id]')];if(!cards.length)return;
  const ids=[...new Set(cards.map(c=>c.dataset.duelId))].slice(0,60);
  const {data,error}=await db.rpc('get_duel_kampfgeist',{p_duel_ids:ids});
  if(error||!data||!data.enabled)return;
  duelState=data;const K=await kampfgeist();
  for(const card of cards){
   const d=data.duels.find(x=>x.id===card.dataset.duelId);card.querySelector('.kg-social')?.remove();if(!d)continue;
   const box=document.createElement('div');box.className='kg-social';
   const fighter=f=>`<span class="kg-fighter">${K.avatarBox(f,52)}<span><b>${esc(f.name||'')}</b>${K.titleTag(f.titel)}</span></span>`;
   const ev=d.events.map(e=>`<span class="kg-ev${e.hidden?' hidden':''}">${K.emoteHTML(e.emote&&e.emote.design,52)}<span>${esc(e.sender||'')}</span>${data.can_moderate&&!e.hidden?`<button type="button" class="kg-mini-btn" data-kg-hide="${e.id}" aria-label="Emote ausblenden">Ausblenden</button>`:''}</span>`).join('');
   box.innerHTML=`<div class="kg-vsrow">${fighter(d.challenger)}<button type="button" class="kg-mini-btn" data-kg-intro="${esc(d.id)}">Einlauf ansehen</button>${fighter(d.opponent)}</div>
    <div class="kg-feed" aria-label="Emotes in diesem Duell">${ev||'<span class="tlp-note">Noch keine Emotes.</span>'}</div>
    ${d.can_send?`<div class="kg-picker" role="group" aria-label="Emote senden">${data.my_emotes.map(m=>`<button type="button" data-kg-send="${esc(d.id)}" data-kg-emote="${esc(m.key)}" aria-label="${esc(m.name)} senden">${K.emoteHTML(m.design,48)}</button>`).join('')}</div>`
     :data.muted?'<span class="tlp-note">Deine Emotes sind gerade pausiert.</span>':''}`;
   card.append(box);
  }
 };
 const schedule=()=>{clearTimeout(duelTimer);duelTimer=setTimeout(()=>decorate().catch(e=>console.warn('Duell-Emotes nicht verfügbar:',e)),150)};
 new MutationObserver(m=>{if(m.some(x=>[...x.addedNodes].some(n=>n.nodeType===1&&!n.classList.contains('kg-social'))))schedule()}).observe(list,{childList:true});
 list.addEventListener('click',async ev=>{
  const b=ev.target.closest('[data-kg-send],[data-kg-hide],[data-kg-intro]');if(!b||!duelState)return;
  if(b.dataset.kgIntro){const d=duelState.duels.find(x=>x.id===b.dataset.kgIntro),K=await kampfgeist();K.playEinlauf([{look:d.challenger,name:d.challenger.name},{look:d.opponent,name:d.opponent.name}]);return}
  b.disabled=true;
  const r=b.dataset.kgSend?await db.rpc('send_duel_emote',{p_duel_id:b.dataset.kgSend,p_emote_key:b.dataset.kgEmote}):await db.rpc('hide_kg_emote',{p_event_id:Number(b.dataset.kgHide)});
  const st=document.getElementById('status');
  if(r.error){if(st)st.textContent=r.error.message;b.disabled=false;return}
  if(st)st.textContent=b.dataset.kgSend?'Emote gesendet.':'Emote ausgeblendet.';
  decorate().catch(()=>{});
 });
 schedule();
}
/* Etappe 8: kein eigenes Kampfgeist-Podium. Wer auf dem normalen Podium steht, entscheidet selbst, ob dort ein Emote erscheint. */
async function mountPodium(){
 const anchor=document.getElementById('podium-content');if(!anchor)return;
 const db=await client();
 const s=await db.auth.getSession();if(!s.data||!s.data.session)return;
 let data=null,K=null,busy=false,pickOpen=false;
 const load=async()=>{const r=await db.rpc('get_podium_kampfgeist');const d=r.error||!r.data||!r.data.enabled?null:r.data;if(d)K=K||await kampfgeist();data=d};
 const norm=v=>String(v||'').trim().toLowerCase();
 const decorate=()=>{
  const pod=anchor.querySelector('.tl-podium');if(!pod||!data)return;
  pod.dataset.kgEmotes='1';
  pod.querySelectorAll('.tl-podium-emote').forEach(n=>n.remove());
  const old=anchor.querySelector('.tl-podium-emote-pick');if(old)old.remove();
  for(const step of pod.querySelectorAll('.tl-podium-step')){
   const name=norm(step.querySelector('.tl-podium-name')&&step.querySelector('.tl-podium-name').textContent);
   const pl=data.places.find(x=>norm(x.name)===name);
   if(!pl||!pl.show_emote||!pl.emote)continue;
   const b=document.createElement('span');b.className='tl-podium-emote';b.setAttribute('aria-label','Emote von '+pl.name+': '+(pl.emote.name||''));
   b.innerHTML=K.emoteHTML(pl.emote.design,i(step)?56:44);step.prepend(b);
  }
  const me=data.places.find(x=>x.is_me);if(!me)return;
  const cur=data.my_emote&&data.my_emote.key,on=data.my_show&&data.my_emote;
  const pick=document.createElement('details');pick.className='tl-podium-emote-pick';pick.open=pickOpen;
  pick.addEventListener('toggle',()=>{pickOpen=pick.open});
  pick.innerHTML=`<summary><b>Dein Emote im Podium</b><span class="tl-podium-emote-state">${on?K.emoteHTML(data.my_emote.design,28):'Aus'}</span></summary>
   <div class="tl-podium-emote-body" role="group" aria-label="Emote auswählen">${data.preview?'<span class="tlp-note">Vorschau – nur für dich sichtbar, solange der Shop aus ist.</span>':''}
   <div class="tl-podium-emote-opts"><button type="button" data-podium-emote="" aria-pressed="${!data.my_show}">Kein Emote</button>${(data.my_emotes||[]).map(m=>`<button type="button" data-podium-emote="${esc(m.key)}" aria-pressed="${data.my_show&&m.key===cur}" aria-label="${esc(m.name)}">${K.emoteHTML(m.design,36)}</button>`).join('')}</div>
   <span class="tlp-note">Nur du entscheidest, ob neben deinem Platz ein Emote erscheint. Weitere Emotes gibt es im <a href="./shop.html">Shop</a>.</span></div>`;
  pod.after(pick);
 };
 const i=step=>step.classList.contains('tl-podium-1');
 anchor.addEventListener('click',async ev=>{
  const b=ev.target.closest('[data-podium-emote]');if(!b||busy)return;
  busy=true;b.disabled=true;
  const key=b.dataset.podiumEmote;
  const r=await db.rpc('set_podium_emote',key?{p_show:true,p_emote_key:key}:{p_show:false});
  busy=false;b.disabled=false;
  if(r.error){const pick=anchor.querySelector('.tl-podium-emote-pick');if(pick)alertBox(pick,r.error.message);return}
  await load();decorate();
 });
 new MutationObserver(()=>{const pod=anchor.querySelector('.tl-podium');if(pod&&!pod.dataset.kgEmotes)decorate()}).observe(anchor,{childList:true});
 await load();decorate();
}
/* ---- Etappe 7a: Spielerkarte und Boxstil im Boxervergleich ---- */
async function mountCompare(){
 const results=document.getElementById('results'),left=document.getElementById('left'),right=document.getElementById('right');
 if(!results||!left||!right)return;
 const box=document.createElement('section');box.className='panel tlp-compare';box.hidden=true;box.setAttribute('aria-label','Spielerkarte und Boxstil im Vergleich');
 results.after(box);
 const db=await client();
 const s=await db.auth.getSession(),signedIn=!!(s.data&&s.data.session);
 let seq=0,timer=null;
 const render=async()=>{
  const a=left.value,b=right.value;
  if(!a||!b||a===b){box.hidden=true;return}
  if(!signedIn){box.hidden=false;box.innerHTML='<h2>Spielerkarte und Boxstil</h2><p class="tlp-note">Die Spielerkarten und den Boxstil-Vergleich siehst du, wenn du <a href="./login.html">angemeldet</a> bist.</p>';return}
  const my=++seq;
  const [ra,rb]=await Promise.all([db.rpc('get_performance_card',{p_display_name:a}),db.rpc('get_performance_card',{p_display_name:b})]);
  if(my!==seq)return;
  const A=ra.error?null:ra.data,B=rb.error?null:rb.data,lks=await looks(db,[a,b]);
  if(my!==seq)return;
  if(!A&&!B||!(A&&(A.rating||A.style))&&!(B&&(B.rating||B.style))){box.hidden=true;return}
  // Reihenfolge wie in der Auswahl; Farbe: der eigene Boxer ist gold, sonst der linke.
  const meRight=!!(B&&B.is_me&&!(A&&A.is_me));
  const sides=[{d:A,n:a,c:meRight?'b':'g'},{d:B,n:b,c:meRight?'g':'b'}];
  const G=sides.find(x=>x.c==='g'),L=sides.find(x=>x.c==='b');
  const posOf=d=>d&&d.style&&d.style.scores?styleType(d.style.scores).pos:'BOX';
  const cardOf=x=>x.d&&x.d.rating?card({name:x.n,overall:x.d.rating.overall,categories:x.d.rating.categories,pos:posOf(x.d),width:150,look:lks[x.n]})
   :`<div class="tlp-card-empty"><b>${esc(x.n)}</b><span class="tlp-note">noch keine Coach-Bewertung</span></div>`;
  const legend=`<div class="tlp-legend">${sides.map(x=>`<span><i class="sw ${x.c}"></i>${esc(x.n)}${x.d&&x.d.is_me?' (du)':''}</span>`).join('')}</div>`;
  let html=`<h2>Spielerkarte und Boxstil</h2>${legend}<div class="tlp-vs">${sides.map(x=>`<div class="tlp-vs-side ${x.c}">${cardOf(x)}</div>`).join('')}</div>`;
  const [lr,rr]=sides.map(x=>x.d&&x.d.rating);
  if(lr&&rr){
   const [lc,rc]=sides.map(x=>x.c);
   const rows=[['Gesamt',lr.overall,rr.overall],...CATS.map(c=>[c.n,lr.categories[c.k],rr.categories[c.k]])];
   html+=`<div class="tlp-cmp">${rows.map(([n,u,v])=>`<div class="tlp-cmprow${n==='Gesamt'?' total':''}"><b class="l ${lc}${u>v?' lead':''}">${u}</b><span class="tlp-cmpbar"><i class="l ${lc}" style="width:${Math.max(0,Math.min(99,u))/2}%"></i><i class="r ${rc}" style="width:${Math.max(0,Math.min(99,v))/2}%"></i></span><b class="r ${rc}${v>u?' lead':''}">${v}</b><span class="tlp-cmpname">${esc(n)}</span></div>`).join('')}</div>`;
  }
  const gs=G.d&&G.d.style&&G.d.style.scores,ls=L.d&&L.d.style&&L.d.style.scores;
  if(gs&&ls){
   const sim=similarity(gs,ls);
   html+=`<div class="tlp-center">${radarCompare(gs,ls,{goldName:G.n,blueName:L.n,size:300})}
    <p class="tlp-note"><b>${sim}% gleicher Stil.</b> Die helle Fläche zeigt, wo sich eure Stile überlappen. ${esc(G.n)}: ${esc(styleType(gs).title)} · ${esc(L.n)}: ${esc(styleType(ls).title)}</p></div>`;
  }else{
   const miss=[!gs?G.n:null,!ls?L.n:null].filter(Boolean);
   html+=`<p class="tlp-note">Boxstil-Vergleich: ${miss.map(esc).join(' und ')} ${miss.length>1?'haben':'hat'} den Boxstil-Test noch nicht gemacht.</p>`;
  }
  box.innerHTML=html;box.hidden=false;
 };
 const schedule=()=>{clearTimeout(timer);timer=setTimeout(()=>render().catch(e=>console.warn('Vergleich nicht verfügbar:',e)),120)};
 new MutationObserver(schedule).observe(results,{childList:true});
 left.addEventListener('change',schedule);right.addEventListener('change',schedule);
 schedule();
}
/* ---- Etappe 7d: Card of the Week / Month / Player of the Year auf dem Podium ---- */
async function mountAwards(){
 const anchor=document.getElementById('podium-content');if(!anchor)return;
 const db=await client();
 const s=await db.auth.getSession();if(!s.data||!s.data.session)return;
 const {data,error}=await db.rpc('get_card_awards');
 if(error||!data||!data.enabled)return;
 const items=['cotw','cotm','poty'].map(k=>data.latest&&data.latest[k]).filter(Boolean);
 if(!items.length)return;
 const cards=await Promise.all(items.map(a=>db.rpc('get_performance_card',{p_display_name:a.display_name}).then(r=>r.error?null:r.data).catch(()=>null)));
 const fmtP=a=>a.kind==='cotw'?fmtDate(a.period_start)+' – '+fmtDate(a.period_end):a.kind==='cotm'?new Intl.DateTimeFormat('de-CH',{month:'long',year:'numeric',timeZone:'UTC'}).format(new Date(a.period_start+'T12:00:00Z')):String(a.period_start).slice(0,4);
 const box=document.createElement('section');box.className='tlp-profile';box.setAttribute('aria-label','Ausgezeichnete Karten');
 box.innerHTML=`<div class="tlp-block"><h2>Ausgezeichnet</h2>${data.preview?'<p class="tlp-note">Vorschau – für die Boxer sichtbar, sobald Karten-Designs freigeschaltet sind.</p>':''}
  <div class="tlp-awards">${items.map((a,i)=>{const c=cards[i],r=c&&c.rating;
   return `<a class="tlp-award" href="./boxer-profile.html?name=${encodeURIComponent(a.display_name)}"><span class="tlp-eyebrow">${esc(AWARD_LABEL[a.kind])}</span>
    ${r?card({name:a.display_name,overall:r.overall,categories:r.categories,pos:c.style&&c.style.scores?styleType(c.style.scores).pos:'BOX',width:130,look:a.look})
     :`<span class="tlp-award-plate d-design" style="${['a','b','ink','edge'].map(k=>a.look&&a.look.design&&hex(a.look.design[k])?`--c${k}:${a.look.design[k]};`:'').join('')}"><b>${esc(a.display_name)}</b></span>`}
    <span class="tlp-note">${esc(fmtP(a))}${a.note?' · '+esc(a.note):''}</span></a>`}).join('')}</div>
  <p class="tlp-note"><a href="./karten.html">Alle Auszeichnungen und Karten-Designs</a></p></div>`;
 anchor.after(box);
}
function alertBox(box,msg){let n=box.querySelector('.tlp-status');if(!n){n=document.createElement('p');n.className='tlp-status error';n.setAttribute('role','status');box.prepend(n)}n.textContent=msg}
function boot(){
 const screen=document.body&&document.body.dataset.tlScreen;
 const run=fn=>fn().catch(e=>console.warn('Bewertung/Boxstil nicht verfügbar:',e));
 if(screen==='boxer-profile')run(mountProfile);
 if(screen==='boxer')run(mountStudio);
 if(screen==='duels')run(mountDuels);
 if(screen==='index'){run(mountPodium);run(mountAwards)}
 if(screen==='boxer-compare')run(mountCompare);
}
window.TLPerf={client,looks,holoLib,AWARD_LABEL,CATS,SKILL,SKILL_KEYS,AX,QUESTIONS,BANDS,BAND_NAMES,band,to20,esc,summary,tier,styleType,radarSVG,radarCompare,similarity,deltaTag,fmtDate,card,initials};
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',boot);else boot();
})();
