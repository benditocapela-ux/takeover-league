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
// Etappe 15: öffentliche Kartenwerte – die beste Karte der Liga ist 92, alle anderen im gleichen Verhältnis (gerundet, höchstens 99).
// Spiegel von league_private.rating_public (für die Live-Vorschau im Bewertungsformular).
const CARD_TARGET=92;
function publicSummary(s,best){
 if(!s)return null;const b=Number(best);if(!(b>0))return {overall:s.overall,categories:{...s.categories}};
 const f=v=>Math.min(99,Math.round(Number(v)*CARD_TARGET/b));
 return {overall:f(s.overall),categories:Object.fromEntries(Object.entries(s.categories||{}).map(([k,v])=>[k,f(v)]))};
}
const pubOf=s=>s&&s.public&&s.public.overall!=null?s.public:null;
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
// Etappe 11: Boxerprofil übersichtlich – eine Spielerkarte-Box: FUT-Karte (mit Holo), daneben die Figur (Holo-Pose oder
// Kampfgeist-Avatar mit Aura und Rahmen), Gesamt/Stärken/Schwächen kurz, Boxstil aufklappbar, Vergleichen-Knopf.
async function mountProfile(){
 const name=(new URLSearchParams(location.search).get('name')||'').trim();
 const anchor=document.getElementById('sportProfile');
 if(!name||!anchor)return;
 const db=await client();
 const s=await db.auth.getSession();if(!s.data||!s.data.session)return;
 const [pc,mine,hl]=await Promise.all([db.rpc('get_performance_card',{p_display_name:name}),db.rpc('get_my_performance').catch(()=>({error:true})),looks(db,[name]).catch(()=>({}))]);
 const data=pc.error?null:pc.data;
 const myName=!mine||mine.error||!mine.data||!mine.data.profile?null:mine.data.profile.display_name;
 const shown=data&&data.display_name?data.display_name:name;
 const lkKey=Object.keys(hl).find(k=>k.toLowerCase()===name.toLowerCase()),look=lkKey?hl[lkKey]:null;
 const isMe=!!(data&&data.is_me)||(!!myName&&lowerName(myName)===lowerName(name));
 const enc=encodeURIComponent;
 const cmpHref=myName?(isMe?'./boxer-compare.html?left='+enc(myName):'./boxer-compare.html?left='+enc(myName)+'&right='+enc(shown)):'./boxer-compare.html?left='+enc(shown);
 const ca=document.getElementById('compareAction');if(ca&&myName){ca.dataset.tlMine='1';ca.href=cmpHref}
 let figure='';
 if(look&&look.holo&&window.TLHolo)figure=`<div class="tlh-stage tlp-figure">${window.TLHolo.svg(look.holo,{pose:look.holo.pose_profile,label:'Boxer-Holo von '+shown})}</div>`;
 else if(!(await publicCards()).has(lowerName(name))){ // Etappe 19: Avatar steht schon im Profilkopf
  const kg=await db.rpc('get_kg_look',{p_display_name:name}).catch(()=>({error:true}));
  if(kg&&!kg.error&&kg.data&&kg.data.avatar){const K=await kampfgeist();figure=`<div class="tlp-figure">${K.avatarBox(kg.data,132)}</div>`}
 }
 if(!data&&!figure)return;
 const r=data&&data.rating,st=data&&data.style&&data.style.scores?styleType(data.style.scores):null;
 const skills=(list,c)=>(list||[]).map(x=>`<span>${esc(SKILL[x.k]?SKILL[x.k].n:x.k)} <b class="${c}">${to20(x.v,r.scale)}</b></span>`).join('');
 const box=document.createElement('section');box.className='tlp-profile';box.setAttribute('aria-label','Spielerkarte und Boxstil');
 box.innerHTML=`<div class="tlp-block tlp-player"><h2>Spielerkarte</h2>
  <div class="tlp-player-row">${r?card({name:shown,overall:r.overall,categories:r.categories,pos:st?st.pos:'BOX',delta:r.delta,width:150,look})
   :`<div class="tlp-card-empty"><b>${esc(shown)}</b><span class="tlp-note">${isMe?'Noch keine Spielerkarte – starte mit deiner <a href="./bewertung.html">Selbsteinschätzung</a>.':'Noch keine Spielerkarte.'}</span></div>`}${figure}</div>
  ${r?`<div class="tlp-player-facts"><div><span class="tlp-eyebrow">Gesamt</span><span class="tlp-big">${r.overall} ${deltaTag(r.delta,true)}</span><span class="tlp-note">aktualisiert am ${fmtDate(r.rated_at)}</span></div>
   <div><span class="tlp-eyebrow ok">Stärken</span><span class="tlp-skills">${skills(r.top,'ok')}</span></div>
   <div><span class="tlp-eyebrow bad">Daran arbeiten</span><span class="tlp-skills">${skills(r.low,'bad')}</span></div></div>`:''}
  ${st?`<details class="tlp-style-det"><summary><span class="tlp-chip t-gold">${esc(st.pos)}</span><span><b>${esc(st.title)}</b><span class="tlp-note">Boxstil · Test vom ${fmtDate(data.style.created_at)}</span></span></summary>
   <div class="tlp-center">${radarSVG(data.style.scores,null,240)}<p class="tlp-note">${esc(st.text)}</p></div></details>`:''}
  <a class="tlp-btn tlp-compare-btn" href="${esc(cmpHref)}">${isMe?'Meine Karte & Boxstil vergleichen':'Karten & Boxstil vergleichen'}</a></div>`;
 anchor.after(box);
 // Der grosse Vergleichen-Knopf ersetzt den kleinen in der Aktionsleiste (übersichtlicher).
 if(ca){ca.hidden=true;const duel=document.getElementById('duelAction');if(duel)duel.style.gridColumn='1 / -1'}
}
async function mountStudio(){
 const host=document.getElementById('studioPanelOverview');if(!host)return;
 const db=await client();
 const s=await db.auth.getSession();if(!s.data||!s.data.session)return;
 const [perf,wk,qs,kg,kp]=await Promise.all([db.rpc('get_my_performance'),db.rpc('get_my_week_plan'),db.rpc('get_my_quests'),db.rpc('get_my_kampfgeist',{p_full:false}),db.rpc('get_my_kampfpfad')]);
 const data=perf.data,error=perf.error,gym=!wk.error&&wk.data&&wk.data.enabled?wk.data:null,quest=!qs.error&&qs.data&&qs.data.enabled?qs.data:null;
 const myName=data&&data.profile&&data.profile.display_name;
 // Etappe 11: eigenes Profilbild im Studio mit Rahmen, Titel beim Namen
 { const av=document.getElementById('avatarPreview'),pn=document.getElementById('profileName');
  if(av&&myName){if(pn)pn.setAttribute('data-tl-name','');av.dataset.tlBoxer=myName} }
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
  // Etappe 17b: ausserhalb der eigenen Bewertungsseite überall der öffentliche Wert (beste Karte = 92)
  if(r&&r.current){const cs=pubOf(r.current.summary)||r.current.summary,ps=r.previous?(pubOf(r.previous.summary)||r.previous.summary):null,o=cs.overall,d=ps?o-ps.overall:null;
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
/* ---- Etappe 16: Kartenarena – alle Karten von der besten zur schlechtesten, zwei antippen, Kampfplakat, Punktzettel ---- */
// Rote Ecke = erste Wahl (links), blaue Ecke = zweite Wahl (rechts). Kartenwerte sind die öffentlichen (beste Karte = 92).
const SORTS=[['overall','Gesamt'],...CATS.map(c=>[c.k,c.n])];
const cardVal=(d,k)=>{const r=d&&d.rating;if(!r)return null;return k==='overall'?Number(r.overall):Number(r.categories&&r.categories[k])};
// Punktzettel wie im Boxen: jede Kategorie ist eine Runde, Sieger 10, Verlierer 9, gleich 10:10.
function scorecard(ra,rb){
 const rounds=CATS.map((c,i)=>{const u=Number(ra.categories[c.k])||0,v=Number(rb.categories[c.k])||0;return {i:i+1,k:c.k,n:c.n,u,v,a:u>=v?10:9,b:v>=u?10:9}});
 const ta=rounds.reduce((t,r)=>t+r.a,0),tb=rounds.reduce((t,r)=>t+r.b,0);
 return {rounds,ta,tb,wa:rounds.filter(r=>r.u>r.v).length,wb:rounds.filter(r=>r.v>r.u).length};
}
function cardHex(a,b,na,nb,size){
 const R=92,keys=CATS.map(c=>c.k),pt=(i,val)=>{const t=-Math.PI/2+i*Math.PI/3,r=R*Math.max(0,Math.min(99,val))/99;return [(Math.cos(t)*r).toFixed(1),(Math.sin(t)*r).toFixed(1)]};
 const ring=f=>keys.map((_,i)=>pt(i,f).join(',')).join(' '),poly=v=>keys.map((k,i)=>pt(i,Number(v[k])||0).join(',')).join(' ');
 const labels=keys.map((k,i)=>{const [x,y]=pt(i,128);return `<text x="${x}" y="${(+y+2).toFixed(1)}" text-anchor="middle" class="tlp-rl">${k}</text><text x="${x}" y="${(+y+17).toFixed(1)}" text-anchor="middle" class="tlp-rv2"><tspan class="g">${Number(a[k])||0}</tspan> · <tspan class="b">${Number(b[k])||0}</tspan></text>`}).join('');
 return `<svg class="tlp-radar tla-hex" viewBox="-160 -150 320 300" width="${size||300}" role="img" aria-label="Kartenwerte im Vergleich: ${keys.map(k=>k+' '+esc(na)+' '+(Number(a[k])||0)+', '+esc(nb)+' '+(Number(b[k])||0)).join('; ')}">
  ${[33,66,99].map(f=>`<polygon points="${ring(f)}" class="tlp-grid${f===99?' outer':''}"/>`).join('')}
  ${keys.map((_,i)=>{const [x,y]=pt(i,99);return `<line x1="0" y1="0" x2="${x}" y2="${y}" class="tlp-grid"/>`}).join('')}
  <polygon points="${poly(b)}" class="tlp-shape2"/><polygon points="${poly(a)}" class="tlp-shape"/>${labels}</svg>`;
}
async function mountCompare(){
 const left=document.getElementById('left'),right=document.getElementById('right'),status=document.getElementById('status');
 if(!left||!right||!status)return;
 const q0=new URLSearchParams(location.search),want=[q0.get('left'),q0.get('right')].filter(Boolean); // vor allen Ladevorgängen merken
 const gal=document.createElement('section');gal.className='tla-gallery';gal.hidden=true;gal.setAttribute('aria-labelledby','tlaGalleryTitle');
 const arena=document.createElement('section');arena.className='tlp-compare tla-arena';arena.hidden=true;arena.setAttribute('aria-label','Kartenvergleich');
 const bar=document.createElement('div');bar.className='tla-bar';bar.hidden=true;
 status.after(gal);gal.after(arena);document.body.append(bar);
 const db=await client();
 const s=await db.auth.getSession(),signedIn=!!(s.data&&s.data.session);
 let items=[],lks={},sortKey='overall',sel=[],gallery=false,seq=0,lastPair='',muted=false;
 const lc=n=>String(n||'').toLocaleLowerCase('de-CH');
 const find=n=>items.find(x=>lc(x.display_name)===lc(n));
 if(signedIn){
  try{const r=await db.rpc('get_card_gallery');if(!r.error&&Array.isArray(r.data)&&r.data.length){items=r.data;gallery=true}}catch(_){}
  if(gallery){try{lks=await looks(db,items.map(x=>x.display_name))}catch(_){lks={}}}
 }
 const posOf=d=>d&&d.style&&d.style.scores?styleType(d.style.scores).pos:'BOX';
 const ranked=()=>{const k=sortKey;return items.slice().sort((x,y)=>{const u=cardVal(x,k),v=cardVal(y,k);if(u===null&&v===null)return lc(x.display_name)<lc(y.display_name)?-1:1;if(u===null)return 1;if(v===null)return -1;return v-u||(lc(x.display_name)<lc(y.display_name)?-1:1)})};
 const placeOf=n=>{const r=ranked().filter(x=>cardVal(x,sortKey)!==null);const i=r.findIndex(x=>lc(x.display_name)===lc(n));return i<0?null:{i:i+1,of:r.length}};
 const cornerOf=n=>{const i=sel.findIndex(x=>lc(x)===lc(n));return i===0?'a':i===1?'b':''};
 const cardHtml=(d,n,w)=>d&&d.rating?card({name:n,overall:d.rating.overall,categories:d.rating.categories,pos:posOf(d),delta:d.rating.delta,width:w,look:lks[n]||lks[Object.keys(lks).find(k=>lc(k)===lc(n))]})
  :`<div class="tlp-card-empty tla-blank" style="--fw:${w}px"><b>${esc(n)}</b><span class="tlp-note">noch keine Karte</span></div>`;
 function renderGallery(){
  if(!gallery){gal.hidden=true;return}
  const list=ranked();let place=0;
  gal.innerHTML=`<div class="tla-head"><h2 id="tlaGalleryTitle">Kartenrangliste</h2><p class="tlp-note">Von der besten zur schwächsten Karte. Tippe zwei Karten an und schick sie in den Ring.</p></div>
   <div class="tla-sort" role="group" aria-label="Sortieren nach">${SORTS.map(([k,l])=>`<button type="button" class="tla-chip" data-sort="${k}" aria-pressed="${k===sortKey}">${esc(l)}</button>`).join('')}</div>
   <ol class="tla-grid">${list.map(d=>{const n=d.display_name,c=cornerOf(n),v=cardVal(d,sortKey),p=v===null?null:++place;
    return `<li><button type="button" class="tla-item${c?' sel '+c:''}${d.is_me?' me':''}${p===1?' first':''}" data-pick="${esc(n)}" aria-pressed="${!!c}" aria-label="${esc(n)}${p?', Platz '+p:''}${v!==null?', '+esc(SORTS.find(x=>x[0]===sortKey)[1])+' '+v:', noch keine Karte'}${c?', '+(c==='a'?'rote':'blaue')+' Ecke':''}">
     <span class="tla-place" aria-hidden="true">${p??'–'}</span>${cardHtml(d,n,112)}
     <span class="tla-pick" aria-hidden="true">${c==='a'?'Rote Ecke':c==='b'?'Blaue Ecke':d.is_me?'Du':''}</span>${sortKey!=='overall'&&v!==null?`<span class="tla-sv">${esc(sortKey)} ${v}</span>`:''}</button></li>`}).join('')}</ol>`;
  gal.hidden=false;
 }
 function renderBar(){
  if(!gallery||!sel.length){bar.hidden=true;return}
  bar.innerHTML=`<span class="tla-barnames"><b class="a">${esc(sel[0])}</b><span class="tla-barvs">vs</span>${sel[1]?`<b class="b">${esc(sel[1])}</b>`:'<span class="tlp-note">zweite Karte wählen</span>'}</span>${sel.length===2?'<button type="button" class="tlp-btn" data-act="ring">Zum Ring</button>':`<button type="button" class="tlp-btn ghost" data-act="clear">Leeren</button>`}`;
  bar.hidden=arenaVisible&&sel.length===2;
 }
 let arenaVisible=false;
 if(typeof IntersectionObserver==='function')new IntersectionObserver(es=>{arenaVisible=es.some(e=>e.isIntersecting);renderBar()}).observe(arena);
 const syncSelects=()=>{
  muted=true;
  for(const [el,n] of [[left,sel[0]],[right,sel[1]]]){const ok=n&&[...el.options].some(o=>o.value===n);el.value=ok?n:'';el.dispatchEvent(new Event('change',{bubbles:true}))}
  muted=false;
  const p=new URLSearchParams();if(sel[0])p.set('left',sel[0]);if(sel[1])p.set('right',sel[1]);
  history.replaceState(null,'',location.pathname+(p.size?'?'+p.toString():''));
 };
 async function dataFor(n){
  const d=find(n);if(d||gallery)return d||null;
  const r=await db.rpc('get_performance_card',{p_display_name:n}).catch(()=>({error:true}));return r.error?null:r.data;
 }
 async function renderArena(){
  const [a,b]=sel;
  if(!a||!b||lc(a)===lc(b)){arena.hidden=true;lastPair='';return}
  if(!signedIn){arena.hidden=false;arena.innerHTML='<div class="panel"><h2>Spielerkarten im Ring</h2><p class="tlp-note">Die Karten, den Punktzettel und den Boxstil-Vergleich siehst du, wenn du <a href="./login.html">angemeldet</a> bist.</p></div>';return}
  const my=++seq;
  const [A,B]=await Promise.all([dataFor(a),dataFor(b)]);
  if(!gallery){const l=await looks(db,[a,b]).catch(()=>({}));Object.assign(lks,l)}
  if(my!==seq)return;
  if(!A&&!B){arena.hidden=true;return}
  const pair=lc(a)+'|'+lc(b),fresh=pair!==lastPair;lastPair=pair;
  const ra=A&&A.rating,rb=B&&B.rating,pa=gallery?placeOf(a):null,pb=gallery?placeOf(b):null;
  const side=(d,n,c,pl)=>`<div class="tla-corner ${c}"><span class="tla-cornername">${c==='a'?'Rote Ecke':'Blaue Ecke'}</span>${cardHtml(d,n,150)}
   <b class="tla-name">${esc(n)}${d&&d.is_me?' <span class="tlp-note">(du)</span>':''}</b>${pl?`<span class="tla-rank">Platz ${pl.i} von ${pl.of}</span>`:''}</div>`;
  let html=`<div class="tla-poster${fresh?' go':''}"><div class="tla-ropes" aria-hidden="true"><i></i><i></i><i></i></div>${side(A,a,'a',pa)}<div class="tla-vs" aria-hidden="true">VS</div>${side(B,b,'b',pb)}</div>`;
  if(ra&&rb){
   const sc=scorecard(ra,rb),win=sc.ta>sc.tb?a:sc.tb>sc.ta?b:null,wc=sc.ta>sc.tb?'a':'b';
   html+=`<p class="tla-verdict">${win?`Nach Karten gewinnt <b class="${wc}">${esc(win)}</b> ${Math.max(sc.ta,sc.tb)}:${Math.min(sc.ta,sc.tb)} – ${Math.max(sc.wa,sc.wb)} von 6 Runden.`:`Nach Karten unentschieden, ${sc.ta}:${sc.tb}.`}</p>
    <p class="tlp-note tla-fine">Ein Kartenvergleich, kein echtes Duell: jede Kategorie zählt als Runde, 10 für den besseren Wert, 9 für den anderen.</p>
    <div class="tla-block"><h3>Punktzettel</h3><table class="tla-score"><thead><tr><th scope="col" class="a">${esc(a)}</th><th scope="col">Runde</th><th scope="col" class="b">${esc(b)}</th></tr></thead>
     <tbody>${sc.rounds.map(r=>`<tr><td class="a${r.a>r.b?' won':''}">${r.a}</td><th scope="row"><span class="tla-rnd">${r.i}</span> ${esc(r.n)}</th><td class="b${r.b>r.a?' won':''}">${r.b}</td></tr>`).join('')}</tbody>
     <tfoot><tr><td class="a${sc.ta>sc.tb?' won':''}">${sc.ta}</td><th scope="row">Total</th><td class="b${sc.tb>sc.ta?' won':''}">${sc.tb}</td></tr></tfoot></table></div>`;
   const rows=[['Gesamt',ra.overall,rb.overall],...CATS.map(c=>[c.n,ra.categories[c.k],rb.categories[c.k]])];
   html+=`<div class="tla-block"><h3>Tale of the Tape</h3><div class="tlp-cmp">${rows.map(([n,u,v])=>`<div class="tlp-cmprow${n==='Gesamt'?' total':''}"><b class="l g${u>v?' lead':''}">${u}</b><span class="tlp-cmpbar"><i class="l g" style="width:${Math.max(0,Math.min(99,u))/2}%"></i><i class="r b" style="width:${Math.max(0,Math.min(99,v))/2}%"></i></span><b class="r b${v>u?' lead':''}">${v}</b><span class="tlp-cmpname">${esc(n)}${u!==v?` <span class="tla-diff ${u>v?'a':'b'}">+${Math.abs(u-v)}</span>`:''}</span></div>`).join('')}</div></div>`;
   const edge=(x,y)=>CATS.map(c=>({c,d:(Number(x.categories[c.k])||0)-(Number(y.categories[c.k])||0)})).sort((p,q)=>q.d-p.d)[0];
   const ea=edge(ra,rb),eb=edge(rb,ra);
   const line=(n,e,c,o)=>e.d>0?`<li class="${c}"><b>${esc(n)}</b> hat den grössten Vorsprung in <b>${esc(e.c.n)}</b> (+${e.d}).</li>`:`<li class="${c}"><b>${esc(n)}</b> liegt in keiner Kategorie vorne – am knappsten in <b>${esc(e.c.n)}</b>${e.d<0?' ('+e.d+')':''}.</li>`;
   html+=`<div class="tla-block tla-two"><div><h3>Kartenprofil</h3><div class="tlp-center">${cardHex(ra.categories,rb.categories,a,b,300)}</div></div>
    <div><h3>Wo es entschieden wird</h3><ul class="tla-edges">${line(a,ea,'a')}${line(b,eb,'b')}</ul></div></div>`;
  }else{
   const miss=[!ra?a:null,!rb?b:null].filter(Boolean);
   html+=`<p class="tlp-note">${miss.map(esc).join(' und ')} ${miss.length>1?'haben':'hat'} noch keine Karte – Punktzettel und Kartenprofil gibt es mit zwei Karten.</p>`;
  }
  const sa=A&&A.style&&A.style.scores,sb=B&&B.style&&B.style.scores;
  if(sa&&sb){
   html+=`<div class="tla-block"><h3>Boxstil</h3><div class="tlp-center">${radarCompare(sa,sb,{goldName:a,blueName:b,size:300})}
    <p class="tlp-note"><b>${similarity(sa,sb)}% gleicher Stil.</b> Die helle Fläche zeigt, wo sich die Stile überlappen. ${esc(a)}: ${esc(styleType(sa).title)} · ${esc(b)}: ${esc(styleType(sb).title)}</p></div></div>`;
  }else{
   const miss=[!sa?a:null,!sb?b:null].filter(Boolean);
   html+=`<p class="tlp-note">Boxstil-Vergleich: ${miss.map(esc).join(' und ')} ${miss.length>1?'haben':'hat'} den Boxstil-Test noch nicht gemacht.</p>`;
  }
  const enc=encodeURIComponent;
  html+=`<div class="tla-actions"><button type="button" class="tlp-btn ghost" data-act="swap">Ecken tauschen</button>${gallery&&items.length>2?'<button type="button" class="tlp-btn ghost" data-act="random">Zufälliges Duell</button>':''}${gallery?'<button type="button" class="tlp-btn ghost" data-act="clear">Neue Auswahl</button>':''}<button type="button" class="tlp-btn ghost" data-act="link">Link kopieren</button>
   <a class="tlp-btn ghost" href="./boxer-profile.html?name=${enc(a)}">Profil ${esc(a)}</a><a class="tlp-btn ghost" href="./boxer-profile.html?name=${enc(b)}">Profil ${esc(b)}</a></div>`;
  arena.innerHTML=html;arena.hidden=false;
 }
 const update=(scroll)=>{renderGallery();renderBar();renderArena().then(()=>{renderBar();if(scroll&&!arena.hidden)arena.scrollIntoView({behavior:matchMedia('(prefers-reduced-motion: reduce)').matches?'auto':'smooth',block:'start'})}).catch(e=>console.warn('Vergleich nicht verfügbar:',e))};
 const pick=n=>{const i=sel.findIndex(x=>lc(x)===lc(n));if(i>=0)sel.splice(i,1);else if(sel.length<2)sel.push(n);else sel[1]=n;syncSelects();update(sel.length===2)};
 const onAct=async(t)=>{
  const act=t.dataset.act;
  if(act==='swap'){sel=[sel[1],sel[0]].filter(Boolean);syncSelects();update(false)}
  else if(act==='clear'){sel=[];syncSelects();update(false);gal.scrollIntoView({block:'start'})}
  else if(act==='ring')arena.scrollIntoView({behavior:'smooth',block:'start'});
  else if(act==='random'){const pool=items.filter(x=>x.rating).map(x=>x.display_name);if(pool.length<2)return;const i=Math.floor(Math.random()*pool.length);let j=Math.floor(Math.random()*(pool.length-1));if(j>=i)j++;sel=[pool[i],pool[j]];syncSelects();update(true)}
  else if(act==='link'){try{await navigator.clipboard.writeText(location.href);status.textContent='Link kopiert – damit öffnet sich genau dieses Duell.'}catch(_){status.textContent='Link: '+location.href}}
 };
 gal.addEventListener('click',e=>{const s=e.target.closest('[data-sort]');if(s){sortKey=s.dataset.sort;renderGallery();if(!arena.hidden)renderArena();return}const b=e.target.closest('[data-pick]');if(b)pick(b.dataset.pick)});
 arena.addEventListener('click',e=>{const t=e.target.closest('[data-act]');if(t)onAct(t)});
 bar.addEventListener('click',e=>{const t=e.target.closest('[data-act]');if(t)onAct(t)});
 // Auswahl über die Listen (Gäste, ohne Galerie) oder aus Links (?left=…&right=…)
 const fromSelects=()=>{if(muted||gallery)return;const v=[left.value,right.value].filter(Boolean);if(gallery&&!v.length&&sel.length)return;sel=v;update(false)};
 left.addEventListener('change',fromSelects);right.addEventListener('change',fromSelects);
 if(gallery){
  document.body.classList.add('tla-mode');
  sel=want.map(n=>find(n)).filter(Boolean).map(d=>d.display_name).slice(0,2);
  if(sel.length===2&&lc(sel[0])===lc(sel[1]))sel.pop();
  update(false);
  // Die Seite füllt die Listen erst nach dem Laden der Liga-Daten: dann Auswahl übernehmen, ohne sie zu überschreiben.
  const mo=new MutationObserver(()=>{if(left.options.length>1){mo.disconnect();syncSelects()}});mo.observe(left,{childList:true});
  if(left.options.length>1)syncSelects();
 }else{sel=[left.value,right.value].filter(Boolean);update(false)}
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
/* ---- Etappe 11: Rahmen und Titel überall, wo ein Boxer mit Profilbild erscheint ---- */
// Ziel: jedes runde Profilbild mit data-tl-boxer="Name". Der Rahmen legt sich um das Bild; der Titel kommt direkt hinter
// das Namenselement im selben Block ([data-tl-name], .rank-name, .champion, .tl-podium-name). Daten: get_public_boxer_looks
// (auch für Gäste, nur sichtbare Profile, nur Design-Daten).
let pubLooksPromise=null;
const lowerName=v=>String(v||'').trim().toLowerCase();
function publicLooks(){
 if(!pubLooksPromise)pubLooksPromise=client().then(db=>db.rpc('get_public_boxer_looks')).then(r=>{
  const m=new Map();if(r&&!r.error&&Array.isArray(r.data))for(const x of r.data)if(x&&x.name)m.set(lowerName(x.name),x);return m}).catch(()=>new Map());
 return pubLooksPromise;
}
// Rang-Emblem: kleines Abzeichen am Rand; kommt zurück, falls die Seite das Bild später austauscht.
function rankBadge(el){if(el.dataset.tlRk&&!el.querySelector(':scope>.kg-rkbadge')){const b=document.createElement('span');b.className='kg-rkbadge';b.textContent=el.dataset.tlRk;el.append(b)}}
function applyLook(el,lk,K){
 el.dataset.tlLook='1';
 if(!lk)return;
 const fr=lk.rahmen&&lk.rahmen.design;
 if(fr&&/^[a-z]{2,12}$/.test(fr.fr||'')&&fr.fr!=='none'){
  el.classList.add('tl-framed','kg-fr-'+fr.fr);
  if(fr.fr==='rank'){
   const rk=K.RANKS.find(x=>x.r===fr.rk);
   if(rk){el.style.setProperty('--rk',rk.c);el.dataset.tlRk=rk.r;rankBadge(el)}
  }
 }
 if(lk.titel&&lk.titel.name){
  const host=el.closest('[data-tl-look-scope]')||el.parentElement;
  const nameEl=host&&host.querySelector('[data-tl-name],.rank-name,.champion,.tl-podium-name');
  if(nameEl&&!(nameEl.nextElementSibling&&nameEl.nextElementSibling.classList.contains('tl-look-title'))){
   const t=document.createElement('span');t.className='tl-look-title';t.innerHTML=K.titleTag(lk.titel);nameEl.after(t);
  }
 }
}
async function mountLooks(){
 if(typeof MutationObserver!=='function'||!document.querySelectorAll)return;
 const pending=()=>[...document.querySelectorAll('[data-tl-boxer]:not([data-tl-look])')];
 let busy=false,again=false;
 const run=async()=>{
  if(busy){again=true;return}
  busy=true;
  try{
   if(pending().length){
    const map=await publicLooks();
    const K=map.size?await kampfgeist():null;
    for(const el of pending()){const lk=map.get(lowerName(el.dataset.tlBoxer));if(K)applyLook(el,lk,K);else el.dataset.tlLook='1'}
   }
  }catch(e){console.warn('Rahmen nicht verfügbar:',e)}
  finally{busy=false;if(again){again=false;run()}}
 };
 new MutationObserver(()=>{document.querySelectorAll('[data-tl-rk]').forEach(rankBadge);if(document.querySelector('[data-tl-boxer]:not([data-tl-look])'))run()})
  .observe(document.body,{childList:true,subtree:true,attributes:true,attributeFilter:['data-tl-boxer']});
 await run();
}
/* ---- Etappe 19: Kampfgeist-Anzeige (Banner, Avatar mit Aura/Rahmen, Rang, Level) in Ranking, Podium, Profil und Studio ---- */
// Daten: get_public_boxer_cards (auch für Gäste, nur sichtbare Profile, nur Design-Daten). Wer selbst keinen Avatar gewählt hat,
// behält sein Profilbild – mit Aura und Rahmen. Ohne Daten (Shop aus, Funktion fehlt) bleibt alles wie bisher.
let pubCardsPromise=null;
function publicCards(){
 if(!pubCardsPromise)pubCardsPromise=client().then(db=>db.rpc('get_public_boxer_cards')).then(r=>{
  const m=new Map();if(r&&!r.error&&Array.isArray(r.data))for(const x of r.data)if(x&&x.name)m.set(lowerName(x.name),x);return m}).catch(()=>new Map());
 return pubCardsPromise;
}
const kgPhoto=(el,lk)=>{if(lk.own_avatar)return null;const im=el&&el.querySelector('img');const u=im&&im.getAttribute('src');return u||null};
function kgMeta(lk,K,short){const rk=K.RANKS.find(x=>x.r===lk.rank)||K.RANKS[0];
 return `<span class="tl-kg-meta">${K.rankBadge(rk.r,18)}<span>Rang ${esc(rk.r)}${short?'':' · '+esc(rk.n)} · Level ${Number(lk.level)||1}</span></span>`}
function kgBanner(host,lk,K){
 if(host.querySelector(':scope>.tl-kg-bg'))return;
 host.classList.add('tl-kg-banner');host.insertAdjacentHTML('afterbegin',`<span class="tl-kg-bg" aria-hidden="true">${K.bannerHTML(lk.banner&&lk.banner.design)}</span>`);
}
// Ersetzt ein rundes Profilbild (data-tl-boxer) durch Avatar bzw. Profilbild mit Aura und Rahmen. Das Original bleibt versteckt
// im DOM (Etappe 11 hängt daran den Titel an).
function kgFace(el,lk,K,size){
 if(el.nextElementSibling&&el.nextElementSibling.classList.contains('tl-kg-face'))return;
 const box=document.createElement('span');box.className='tl-kg-face';box.setAttribute('aria-hidden','true');
 box.innerHTML=K.avatarBox(lk,size,{photo:kgPhoto(el,lk)});
 const im=box.querySelector('.kg-photo img');if(im)im.addEventListener('error',()=>{im.closest('.kg-disc').innerHTML=K.avatarSVG(lk.avatar&&lk.avatar.design,lk.handschuhe&&lk.handschuhe.design)});
 el.classList.add('tl-kg-src');el.after(box);
}
async function mountKgCards(){
 if(typeof MutationObserver!=='function'||!document.querySelectorAll)return;
 const screen=document.body.dataset.tlScreen;
 if(!['index','boxer-profile','boxer'].includes(screen))return;
 let busy=false,again=false,K=null,map=null;
 const small=()=>window.matchMedia&&matchMedia('(max-width:420px)').matches;
 const apply=()=>{
  if(screen==='index'){
   // Ranking: jede Zeile mit Banner, Avatar und Rang/Level
   for(const row of document.querySelectorAll('#ranking-content .rank-row:not([data-tl-kg])')){
    row.dataset.tlKg='1';const av=row.querySelector('[data-tl-boxer]');const lk=av&&map.get(lowerName(av.dataset.tlBoxer));if(!lk)continue;
    kgBanner(row,lk,K);kgFace(av,lk,K,small()?54:60);
    const sub=row.querySelector('.sub');(sub||row.querySelector('.rank-name')).insertAdjacentHTML('afterend',kgMeta(lk,K,true));
   }
   // Podium: Champion-Karte mit Banner und grossem Avatar, Treppchen mit Avatar und Banner im Sockel
   for(const ch of document.querySelectorAll('#podium-content .tl-champion:not([data-tl-kg])')){
    ch.dataset.tlKg='1';const av=ch.querySelector('.league-champion [data-tl-boxer]');const lk=av&&map.get(lowerName(av.dataset.tlBoxer));if(!lk)continue;
    kgBanner(ch,lk,K);kgFace(av,lk,K,small()?96:112);ch.querySelector('.league-champion').insertAdjacentHTML('beforeend',kgMeta(lk,K));
   }
   for(const st of document.querySelectorAll('#podium-content .tl-podium-step:not([data-tl-kg])')){
    st.dataset.tlKg='1';const av=st.querySelector('[data-tl-boxer]');const lk=av&&map.get(lowerName(av.dataset.tlBoxer));if(!lk)continue;
    kgFace(av,lk,K,st.classList.contains('tl-podium-1')?(small()?72:84):(small()?56:64));
    const bl=st.querySelector('.tl-podium-block');if(bl)kgBanner(bl,lk,K);
   }
  }
  if(screen==='boxer-profile'){
   const ph=document.getElementById('profilePhoto'),hero=ph&&ph.closest('.hero');
   if(hero&&ph.dataset.tlBoxer&&!hero.dataset.tlKg){
    hero.dataset.tlKg='1';const lk=map.get(lowerName(ph.dataset.tlBoxer));
    if(lk){kgBanner(hero,lk,K);kgFace(ph,lk,K,small()?92:108);const rk=document.getElementById('profileRank');if(rk)rk.insertAdjacentHTML('afterend',kgMeta(lk,K))}
   }
  }
  if(screen==='boxer'){
   const nm=document.getElementById('studioBoxerName'),av=document.getElementById('avatarPreview'),id=nm&&nm.closest('.studio-identity');
   const who=av&&av.dataset.tlBoxer;
   if(id&&who&&!id.dataset.tlKg){
    const lk=map.get(lowerName(who));
    if(lk){id.dataset.tlKg='1';const box=document.createElement('div');box.className='tl-kg-studio';
     box.innerHTML=K.card(lk,{name:lk.name,size:small()?92:108,photo:kgPhoto(av,lk)});
     id.classList.add('tl-kg-has-card');id.prepend(box)}
   }
  }
 };
 const pending=()=>screen==='index'?!!document.querySelector('#ranking-content .rank-row:not([data-tl-kg]),#podium-content .tl-champion:not([data-tl-kg]),#podium-content .tl-podium-step:not([data-tl-kg])')
  :screen==='boxer-profile'?!!document.querySelector('.hero:not([data-tl-kg]) #profilePhoto[data-tl-boxer]')
  :!!document.querySelector('.studio-identity:not([data-tl-kg])')&&!!document.querySelector('#avatarPreview[data-tl-boxer]');
 const run=async()=>{
  if(busy){again=true;return}
  busy=true;
  try{
   if(pending()){
    if(!map)map=await publicCards();
    if(map.size){if(!K)K=await kampfgeist();apply()}
   }
  }catch(e){console.warn('Kampfgeist-Anzeige nicht verfügbar:',e)}
  finally{busy=false;if(again){again=false;run()}}
 };
 new MutationObserver(()=>{if(pending())run()}).observe(document.body,{childList:true,subtree:true,attributes:true,attributeFilter:['data-tl-boxer']});
 await run();
}
/* Boxer-Holo auf dem bestehenden Podium: nur authentifizierte, vom Server freigegebene Looks; keine neuen Rechte. */
async function mountPodiumHolos(){
 const anchor=document.getElementById('podium-content');if(!anchor)return;
 const db=await client();
 const session=await db.auth.getSession();
 if(!session.data||!session.data.session)return;
 let cacheKey='',looksByName=new Map(),H=null,busy=false,again=false;
 const namesIn=pod=>[...pod.querySelectorAll('.tl-podium-step .tl-podium-name')]
  .map(n=>n.textContent.trim()).filter(n=>n&&n!=='–').slice(0,3);
 const addFigure=(host,name,cfg,large)=>{
  if(!host||host.dataset.tlHoloChecked)return;
  host.dataset.tlHoloChecked='1';
  if(!cfg||typeof cfg!=='object'||Array.isArray(cfg)||!H)return;
  const fig=document.createElement('span');
  fig.className=large?'tl-champion-holo':'tl-podium-holo';
  fig.setAttribute('role','img');
  fig.setAttribute('aria-label','Boxer-Holo von '+name+' in seiner gewählten Profil-Pose');
  fig.innerHTML=H.svg(cfg,{pose:cfg.pose_profile,scene:'none',holo:false});
  const before=host.querySelector(large?'.champion':'.tl-podium-name');
  if(before)before.before(fig);else host.prepend(fig);
  host.classList.add(large?'tl-champion-holo-on':'tl-podium-holo-on');
 };
 const apply=async()=>{
  const pod=anchor.querySelector('.tl-podium');
  if(!pod||!pod.querySelector('.tl-podium-step:not([data-tl-holo-checked])'))return;
  if(busy){again=true;return}
  busy=true;
  try{
   const names=namesIn(pod),key=names.map(lowerName).join('\u0001');
   if(key!==cacheKey){
    cacheKey=key;looksByName=new Map();
    if(names.length){
     const r=await db.rpc('get_holo_looks',{p_display_names:names});
     if(!r.error&&r.data&&typeof r.data==='object'&&!Array.isArray(r.data)){
      for(const [name,cfg] of Object.entries(r.data))looksByName.set(lowerName(name),cfg);
     }
    }
   }
   if(looksByName.size&&!H)H=await holoLib();
   if(!anchor.contains(pod))return;
   for(const step of pod.querySelectorAll('.tl-podium-step')){
    const el=step.querySelector('.tl-podium-name'),name=el&&el.textContent.trim();
    addFigure(step,name||'',looksByName.get(lowerName(name)),false);
   }
   const champ=anchor.querySelector('.tl-champion'),champBox=champ&&champ.querySelector('.league-champion');
   const name=champBox&&champBox.querySelector('.champion')?.textContent.trim();
   if(champBox)addFigure(champBox,name||'',looksByName.get(lowerName(name)),true);
  }catch(e){console.warn('Podium-Holo nicht verfügbar:',e)}
  finally{busy=false;if(again){again=false;apply()}}
 };
 new MutationObserver(()=>{
  const pod=anchor.querySelector('.tl-podium');
  if(pod&&pod.querySelector('.tl-podium-step:not([data-tl-holo-checked])'))apply();
 }).observe(anchor,{childList:true,subtree:true});
 await apply();
}
/* ---- Etappe 11: Die Top 3 als FUT-Karten auf dem Podium (für angemeldete Boxer) ---- */
async function mountPodiumCards(){
 const anchor=document.getElementById('podium-content');if(!anchor)return;
 const db=await client();
 const s=await db.auth.getSession();if(!s.data||!s.data.session)return;
 const cache=new Map();let seq=0;
 const cardFor=async n=>{const k=lowerName(n);if(!cache.has(k))cache.set(k,db.rpc('get_performance_card',{p_display_name:n}).then(r=>r.error?null:r.data).catch(()=>null));return cache.get(k)};
 const render=async()=>{
  const pod=anchor.querySelector('.tl-podium');if(!pod||pod.dataset.tlpCards)return;
  pod.dataset.tlpCards='1';const my=++seq;
  const names=[...pod.querySelectorAll('.tl-podium-step')].map(st=>{const n=st.querySelector('.tl-podium-name');return n?n.textContent.trim():''}).filter(n=>n&&n!=='–').slice(0,3);
  if(!names.length)return;
  const data=await Promise.all(names.map(cardFor));
  const rated=names.map((n,i)=>({n,d:data[i],place:i+1})).filter(x=>x.d&&x.d.rating);
  if(my!==seq||!rated.length||!anchor.contains(pod))return;
  const lks=await looks(db,rated.map(x=>x.d.display_name)).catch(()=>({}));
  if(my!==seq||!anchor.contains(pod))return;
  anchor.querySelectorAll('.tlp-podium-cards').forEach(x=>x.remove());
  const box=document.createElement('div');box.className='tlp-podium-cards';box.setAttribute('role','list');box.setAttribute('aria-label','Spielerkarten der Top 3');
  box.innerHTML=rated.map(x=>{const r=x.d.rating,pos=x.d.style&&x.d.style.scores?styleType(x.d.style.scores).pos:'BOX';
   return `<a role="listitem" class="tlp-podium-card p${x.place}" href="./boxer-profile.html?name=${encodeURIComponent(x.d.display_name)}"><span class="tlp-eyebrow">Platz ${x.place}</span>${card({name:x.d.display_name,overall:r.overall,categories:r.categories,pos,delta:r.delta,width:104,look:lks[x.d.display_name]})}</a>`}).join('');
  const pick=anchor.querySelector('.tl-podium-emote-pick');(pick&&pick.previousElementSibling===pod?pick:pod).after(box);
 };
 new MutationObserver(()=>{const pod=anchor.querySelector('.tl-podium');if(pod&&!pod.dataset.tlpCards)render().catch(e=>console.warn('Podium-Karten nicht verfügbar:',e))}).observe(anchor,{childList:true});
 await render();
}
function alertBox(box,msg){let n=box.querySelector('.tlp-status');if(!n){n=document.createElement('p');n.className='tlp-status error';n.setAttribute('role','status');box.prepend(n)}n.textContent=msg}
function boot(){
 const screen=document.body&&document.body.dataset.tlScreen;
 const run=fn=>fn().catch(e=>console.warn('Bewertung/Boxstil nicht verfügbar:',e));
 if(screen==='boxer-profile')run(mountProfile);
 if(screen==='boxer')run(mountStudio);
 if(screen==='duels')run(mountDuels);
 if(screen==='index'){run(mountPodium);run(mountAwards);run(mountPodiumCards);run(mountPodiumHolos)}
 run(mountLooks);
 run(mountKgCards);
 if(screen==='boxer-compare')run(mountCompare);
}
window.TLPerf={scorecard,cardHex,CARD_TARGET,publicSummary,pubOf,client,looks,holoLib,AWARD_LABEL,CATS,SKILL,SKILL_KEYS,AX,QUESTIONS,BANDS,BAND_NAMES,band,to20,esc,summary,tier,styleType,radarSVG,radarCompare,similarity,deltaTag,fmtDate,card,initials};
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',boot);else boot();
})();
