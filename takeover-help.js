/* Takeover League · Etappe 7c: Hilfe-Register pro Seite, Tour beim nächsten Login.
 * Inhalte in einfacher Sprache. Register erscheinen nur, wenn die Funktion freigeschaltet ist (Feature-Flag)
 * und – bei Trainer-Seiten – nur für Trainer und Admins. Die Tour zeigt der Server einmal pro Person und Version.
 */
(function(){
'use strict';
const SB_URL='https://iqarjivcrddcixrvqbfb.supabase.co',SB_KEY='sb_publishable_o--Z21P8Q08lMvIOask_Fw__SRRX7_R';
const TOUR_VERSION=1;
let clientPromise=null;
function client(){
 if(!clientPromise)clientPromise=import('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm').then(m=>m.createClient(SB_URL,SB_KEY));
 return clientPromise;
}
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
// Gruppen wie im Menü
const GROUPS=[['start','👋','Erste Schritte'],['mein','👤','Mein Bereich'],['kampf','🥊','Kämpfe & Challenges'],['liga','🏆','Liga & Erfolge'],['hilfe','💬','Hilfe & Neuigkeiten'],['staff','🧑‍🏫','Für Trainer']];
// key, Seite, Gruppe, Symbol, Titel, Kurzbeschreibung, Punkte, Flag (optional), nur Trainer (optional)
const REGISTERS=[
 {key:'start',page:'boxer.html',group:'start',icon:'🚀',title:'So funktioniert die Liga',summary:'Trainieren, eintragen, bestätigen lassen, aufsteigen.',points:[
  'Du trainierst und trägst dein Training in «Mein Studio» ein.','Dein Coach bestätigt es. Erst dann bekommst du Punkte und EXP.',
  'Punkte zählen für das Monatsranking und starten jeden Monat neu.','EXP bleiben für immer: damit steigst du im Level (1–99) und Rang (F bis S) auf.',
  'Unten in der Leiste findest du Podium, Ranking, das Menü mit allen Bereichen und dein Studio.']},
 {key:'studio',page:'boxer.html',group:'mein',icon:'🥊',title:'Mein Studio',summary:'Dein Startpunkt: Training eintragen und Fortschritt sehen.',points:[
  '«Training einreichen»: Art, Datum und Dauer wählen und absenden.','«Letzte Trainings» zeigt, was offen, bestätigt oder abgelehnt ist.',
  'Wochenfortschritt, Kalender und «Performance · letzte 30 Tage» zeigen, wie regelmässig du trainierst.',
  'Unter «Mitteilungen & Aufgaben» kommen Bestätigungen, Feedback und Neuigkeiten an.','«Feedback vom Coach» ist 7 Tage oben sichtbar, danach im Archiv.']},
 {key:'ziele',page:'goals.html',group:'mein',icon:'🎯',title:'Meine Ziele',summary:'Eigene Trainingsziele setzen und verfolgen.',points:[
  'Automatische Ziele zählen nur bestätigte Trainings.','Freie Ziele aktualisierst du selbst.','Erreichte Ziele kannst du abschliessen oder archivieren.']},
 {key:'bewertung',page:'bewertung.html',group:'mein',icon:'🃏',title:'Bewertung & Spielerkarte',flag:'coach_ratings',summary:'Deine Spielerkarte mit den Noten deines Coaches.',points:[
  'Dein Coach bewertet 25 Punkte in 6 Bereichen von 1 bis 20.','Die Karte zeigt deine Gesamtwertung und die 6 Bereiche – mit Pfeil, was rauf- oder runterging.',
  'Einzelnoten und Kommentar siehst nur du. Andere sehen nur die Karte, wenn dein Profil sichtbar ist.',
  'Sobald freigeschaltet, schätzt du dich alle 14 Tage selbst ein – dein Coach gibt frei oder passt an.']},
 {key:'stil',page:'stil-test.html',group:'mein',icon:'🧭',title:'Boxstil-Test',flag:'style_test',summary:'8 Fragen: Welcher Boxer-Typ bist du?',points:[
  'Beantworte 8 kurze Fragen ehrlich – es gibt keine falschen Antworten.','Du bekommst dein Stil-Netz mit 6 Achsen und einen Trainingstipp.',
  'Einmal pro Monat möglich; dein Coach kann ihn früher freigeben.']},
 {key:'karten',page:'karten.html',group:'mein',icon:'🎴',title:'Karten & Auszeichnungen',flag:'card_designs',summary:'Kartendesign wählen, Card of the Week & Co.',points:[
  'Wähle ein Design für deine Spielerkarte – andere sehen deine Karte so.','Neue Designs gibt es mit dem Rang, im Shop (Coins) oder nur als Auszeichnung.',
  'Card of the Week, Card of the Month und Player of the Year: wer die meisten EXP sammelt, wird vorgeschlagen, ein Trainer bestätigt.',
  'Das Spezial-Design einer Auszeichnung gilt im Zeitraum danach (eine Woche, ein Monat bzw. ein Jahr). Die Symbole ⭐ 🏆 👑 auf deiner Karte bleiben.',
  'Eigenes Design: Schaltet der Admin es für dich frei, gestaltest du Farben, Muster und Abzeichen deiner Karte selbst.']},
 {key:'wochenplan',page:'wochenplan.html',group:'mein',icon:'🗓️',title:'Wochenplan',flag:'gym_training',summary:'Welche Trainings diese Woche anstehen.',points:[
  'Montag, Mittwoch und Samstag sind Pflichttrainings, Dienstag und Donnerstag Ergänzung.','«Erledigt» erscheint, sobald dein Training an dem Tag bestätigt ist.',
  'Im Register «Stundenplan» siehst du alle Vereinseinheiten.']},
 {key:'quests',page:'quests.html',group:'mein',icon:'🎯',title:'Wochen-Quests',flag:'weekly_quests',summary:'Aufgaben der Woche mit Belohnungen.',points:[
  'Quests füllen sich automatisch mit deinen bestätigten Trainings.','Erfüllte Quests holst du selbst ab – erst dann gibt es die Belohnung.',
  'Jeden Montag starten neue Wochen-Quests, dazu gibt es Tagesquests und eine Wochentruhe.']},
 {key:'praesenz',page:'praesenz.html',group:'mein',icon:'✅',title:'Präsenz',flag:'gym_training',summary:'Deine Anwesenheit der letzten Wochen.',points:[
  'Die Punkte zeigen die letzten 4 Wochen, links ist diese Woche.','Wettkämpfer sehen zusätzlich ihre Pflichtquote.']},
 {key:'checkin',page:'checkin.html',group:'mein',icon:'⚡',title:'Gym-Check-in',flag:'gym_training',summary:'Im Gym einchecken statt selbst eintragen.',points:[
  'Startet dein Coach das Training, tippst du hier auf «Einchecken».','Nach dem Training bestätigt der Coach alle Anwesenden – du musst nichts mehr eintragen.',
  'Vereinstrainings (z. B. Technik, Sparring) laufen nur noch über den Check-in.']},
 {key:'meinboxer',page:'mein-boxer.html',group:'mein',icon:'🥊',title:'Mein Boxer',flag:'boxer_holo',summary:'Deinen eigenen Boxer-Holo gestalten.',points:[
  'Wähle Hautfarbe, Frisur, Haar- und Augenfarbe. Alles ist gratis und jederzeit änderbar.','Ziehe deinen Boxer an: Kappe, Hoodie mit Kapuze auf oder ab, Trainingsanzug, Hosen, Bandagen oder Handschuhe, Mantel an oder aus.',
  'Mäntel, Auren, Spezial-Augen, Hintergründe und Posen gibt es im Shop, in Bundles oder als Belohnung. Gesperrtes kannst du vorher anprobieren.','Wähle eine Pose für dein Profil und eine für deine FUT-Karte und tippe auf «Speichern».']},
 {key:'shop',page:'shop.html',group:'mein',icon:'🛍️',title:'Kampfgeist-Shop',flag:'kampfgeist_shop',summary:'Coins sammeln und deinen Look gestalten.',points:[
  'Für bestätigte Trainings und abgeholte Quests bekommst du Kampfgeist-Coins.','Damit kaufst du Avatare, Auren, Banner, Rahmen, Titel und Handschuhe.',
  'Manche Items gibt es erst ab einem bestimmten Rang.',
  'Dein Rahmen und dein Titel erscheinen überall bei deinem Profilbild. Ohne Auswahl trägst du das Emblem deines Rangs.']},
 {key:'kampfpfad',page:'kampfpfad.html',group:'mein',icon:'🛤️',title:'Kampfpfad',flag:'kampfgeist_shop',summary:'Jeden Monat neue Stufen und Belohnungen.',points:[
  'Trainings, Quests und Duelle bringen Kampfpfad-Punkte.','Erreichte Stufen holst du ab. Jeden Monat startet der Pfad wieder bei 0.']},
 {key:'roadmap',page:'roadmap.html',group:'mein',icon:'📈',title:'Level-Roadmap',flag:'kampfgeist_shop',summary:'Was dich bei welchem Level erwartet.',points:[
  '99 Levels und 7 Ränge (F bis S). Jedes Level braucht etwas mehr EXP.','Hier siehst du, welche Belohnungen bei welchem Rang frei werden.']},
 {key:'duelle',page:'duels.html',group:'kampf',icon:'🥊',title:'Duelle',summary:'Fordere einen anderen Boxer heraus.',points:[
  'Wähle einen Gegner und einen Zeitraum und sende die Einladung.','Nimmt er an, zählt, wer im Zeitraum mehr bestätigte Trainingspunkte sammelt.',
  'Offene Einladungen kannst du zurückziehen. Unter «Meine Duelle» siehst du den Stand.']},
 {key:'arena',page:'arena.html',group:'kampf',icon:'🏟️',title:'Mehrgegner-Arena',summary:'3 bis 8 Boxer in einem Wettkampf.',points:[
  'Der Trainer lädt mehrere Boxer ein.','Vorläufige Punkte kommen nur aus bestätigten Trainings; das Endergebnis prüft der Trainer.']},
 {key:'challenges',page:'league-challenges.html',group:'kampf',icon:'⚡',title:'Live- und persönliche Challenges',summary:'Gemeinsame und eigene Trainingsziele.',points:[
  'Live-Challenges sind Vereinsziele, bei denen du dich freiwillig anmeldest.','Persönliche Challenges bekommst du vom Coach oder legst sie selbst an.',
  'Es zählen nur bestätigte Trainings.']},
 {key:'ranking',page:'index.html',group:'liga',icon:'📊',title:'Podium & Ranking',summary:'Wer liegt diesen Monat vorne?',points:[
  'Das Monatsranking zählt die Punkte des Monats und startet jeden Monat neu.','Die Level-Rangliste zeigt die EXP über alle Zeit.',
  'Im Punkteverlauf siehst du, woher die Punkte kommen.',
  'Stehst du auf dem Podium, kannst du direkt darunter ein eigenes Emote neben deinem Platz einschalten – oder «Kein Emote» wählen.']},
 {key:'vergleich',page:'boxer-compare.html',group:'liga',icon:'⚖️',title:'Boxervergleich',summary:'Zwei Boxer direkt nebeneinander.',points:[
  'Wähle zwei Boxer und vergleiche Punkte, EXP und Level.','Angemeldet siehst du auch die Spielerkarten und eure Boxstile übereinander – dein Stil in Gold.',
  'Mit «Merken» speicherst du Favoriten auf diesem Gerät.']},
 {key:'awards',page:'awards.html',group:'liga',icon:'🏅',title:'Auszeichnungen & Saisons',summary:'Monatsauszeichnungen, Saisons und Hall of Fame.',points:[
  'Monatsauszeichnungen beruhen nur auf bestätigten Trainings.','Unter «Saisons & Hall of Fame» stehen die offiziellen Ergebnisse.']},
 {key:'profil',page:'boxer-profile.html',group:'liga',icon:'👤',title:'Boxerprofile',summary:'Öffentliche Leistungen eines Boxers.',points:[
  'Tippe im Ranking auf einen Namen, um das Profil zu öffnen.','Sichtbar sind nur öffentliche Werte: Rang, Rekorde, Auszeichnungen und – angemeldet – die Spielerkarte.']},
 {key:'news',page:'news.html',group:'hilfe',icon:'📰',title:'Neuigkeiten',summary:'Was mit jedem Update neu ist.',points:[
  'Nach jedem Update steht hier kurz, was neu, besser oder behoben ist.','Ein Punkt am «Menü» zeigt dir, dass es etwas Neues gibt.']},
 {key:'feedback',page:'feedback.html',group:'hilfe',icon:'💬',title:'Feedback & Fehler melden',flag:'app_feedback',summary:'Fehler oder Ideen direkt melden.',points:[
  'Wähle die Art, schreibe kurz, was passiert ist, und hänge bis zu 3 Screenshots an.','Unter «Meine Meldungen» siehst du den Status und die Antwort.',
  'Du bekommst eine Benachrichtigung, sobald es eine Antwort gibt.']},
 {key:'coach',page:'coach.html',group:'staff',icon:'🧑‍🏫',title:'Trainer-Dashboard',staff:true,summary:'Trainings prüfen und Boxer begleiten.',points:[
  'Oben stehen offene Trainings und «Gym heute». Die anderen Bereiche klappst du bei Bedarf auf.',
  'Mehrere Trainings auf einmal bestätigen oder ablehnen; eintragen für Boxer unter «Training eintragen».',
  'Feedback mit «sichtbar bis» senden, später archivieren oder zurückziehen.','«Trainings bearbeiten» und «Änderungshistorie» zeigen die letzten 5 Einträge.']},
 {key:'gymstaff',page:'checkin.html',group:'staff',icon:'⚡',title:'Gym-Check-in leiten',staff:true,flag:'gym_training',summary:'Einheit starten, Anwesende bestätigen.',points:[
  'Tippe beim heutigen Stundenplan-Training auf «Starten».','Boxer checken sich ein; du kannst Anwesende auch selbst markieren.',
  '«Alle bestätigen» trägt das Training für alle ein. Später lässt sich die Einheit noch umstellen.']},
 {key:'vergeben',page:'karten.html',group:'staff',icon:'🏆',title:'Auszeichnungen vergeben',staff:true,flag:'card_designs',summary:'Card of the Week, Month und Player of the Year.',points:[
  'Unter «Karten & Auszeichnungen» → «Vergeben» stehen die Vorschläge (meiste EXP aus bestätigten Trainings).',
  'Nach Ende der Woche, des Monats oder Jahres bestätigst du den Vorschlag oder wählst jemand anderen.','Zurücknehmen geht mit kurzer Begründung; sich selbst auszeichnen geht nicht.']},
 {key:'bewerten',page:'bewertung.html',group:'staff',icon:'🃏',title:'Boxer bewerten',staff:true,summary:'Spielerkarte mit Reglern 1–20 pflegen.',points:[
  'Boxer antippen, Regler einstellen – der Text darunter beschreibt die Stufe.','«war …» zeigt die bisherige Note. Die eigene Bewertung macht ein anderer Trainer.',
  'Selbsteinschätzungen der Boxer stehen oben: so freigeben, Regler anpassen und freigeben oder ablehnen.']},
 {key:'manager',page:'league-manager.html',group:'staff',icon:'🛡️',title:'League Manager & Verwaltung',staff:true,summary:'Saisons, Ziele, Liga-Challenges, Konten.',points:[
  'Trainer verwalten hier die Boxerziele; Saisons und Liga-Challenges pflegt der Admin.','Konten, Rollen und Sichtbarkeit stehen in der Clubverwaltung (nur Admin).']}
];
// Seite → Register für den «?»-Knopf
const PAGE_KEY={'boxer.html':'studio','goals.html':'ziele','bewertung.html':'bewertung','stil-test.html':'stil','wochenplan.html':'wochenplan','quests.html':'quests',
 'praesenz.html':'praesenz','checkin.html':'checkin','shop.html':'shop','mein-boxer.html':'meinboxer','kampfpfad.html':'kampfpfad','roadmap.html':'roadmap','duels.html':'duelle','arena.html':'arena',
 'league-challenges.html':'challenges','challenges.html':'challenges','index.html':'ranking','boxer-compare.html':'vergleich','awards.html':'awards',
 'league-history.html':'awards','boxer-profile.html':'profil','news.html':'news','feedback.html':'feedback','karten.html':'karten','coach.html':'coach','league-manager.html':'manager','admin.html':'manager'};
const TOUR=[
 {icon:'👋',title:'Willkommen in der Takeover League',text:'In einer Minute zeigen wir dir, wo du was findest. Du kannst die Tour jederzeit überspringen und später unter «Hilfe & Tutorial» nochmal ansehen.'},
 {icon:'🥊',title:'Training eintragen',text:'Hier in «Mein Studio» trägst du dein Training ein. Sobald dein Coach es bestätigt, bekommst du Punkte und EXP.',focus:'.tl-screen-ribbon .tl-screen-primary'},
 {icon:'📊',title:'Ranking und Podium',text:'Unten in der Leiste siehst du jederzeit, wer diesen Monat vorne liegt. Punkte starten jeden Monat neu, EXP bleiben für immer.',focus:'.tl-global-bottom [data-tl-tab="ranking"]'},
 {icon:'🧭',title:'Alle Bereiche im Menü',text:'Im Menü findest du Duelle, Challenges, Quests, Shop, Bewertung und mehr – sortiert nach Rubriken.',focus:'#takeover-menu-open'},
 {icon:'🧑‍🏫',title:'Für Trainer',text:'Im Trainer-Dashboard bestätigst du Trainings, gibst Feedback und startest den Gym-Check-in.',staff:true},
 {icon:'❓',title:'Hilfe auf jeder Seite',text:'Das «?» oben auf jeder Seite erklärt dir genau diese Seite. Fehler oder Ideen meldest du im Menü unter «Feedback & Fehler melden».',focus:'.tl-help-link'}
];
function tourSteps(role){return TOUR.filter(s=>!s.staff||role==='admin'||role==='coach')}
let tourEl=null;
function runTour(opts){
 opts=opts||{};
 if(tourEl)return;
 const steps=tourSteps(opts.role);let i=0,focused=null;
 tourEl=document.createElement('div');tourEl.className='tl-tour';
 const prevFocus=document.activeElement;
 const unfocus=()=>{if(focused){focused.classList.remove('tl-tour-focus');focused=null}};
 const finish=async(done)=>{
  unfocus();tourEl.remove();tourEl=null;document.removeEventListener('keydown',onKey);
  if(prevFocus&&prevFocus.focus)try{prevFocus.focus()}catch(_){}
  if(opts.onDone)opts.onDone(done);
 };
 const onKey=e=>{if(e.key==='Escape'){e.preventDefault();finish(false)}};
 const draw=()=>{
  const s=steps[i],last=i===steps.length-1;unfocus();
  if(s.focus){const el=document.querySelector(s.focus);if(el&&el.getClientRects().length){focused=el;el.classList.add('tl-tour-focus');const r=el.getBoundingClientRect();if(r.bottom<0||r.top>window.innerHeight)try{el.scrollIntoView({block:'nearest'})}catch(_){}}}
  tourEl.classList.toggle('dim',!focused);
  tourEl.classList.toggle('low',!!(focused&&focused.getBoundingClientRect().top+focused.getBoundingClientRect().height/2>window.innerHeight/2));
  tourEl.innerHTML=`<div class="tl-tour-card" role="dialog" aria-label="Kurze Einführung"><div class="tl-tour-top"><span class="tl-tour-icon" aria-hidden="true">${s.icon}</span><span class="tl-tour-count">${i+1} / ${steps.length}</span></div>
   <h2>${esc(s.title)}</h2><p>${esc(s.text)}</p>
   <div class="tl-tour-dots" aria-hidden="true">${steps.map((_,k)=>`<i class="${k===i?'on':''}"></i>`).join('')}</div>
   <div class="tl-tour-actions"><button type="button" class="tl-tour-skip" data-tour="skip">${last?'Schliessen':'Überspringen'}</button>
   <span>${i>0?'<button type="button" class="tl-tour-back" data-tour="back">Zurück</button>':''}<button type="button" class="tl-tour-next" data-tour="next">${last?'Los geht’s':'Weiter'}</button></span></div>
   ${last?'<a class="tl-tour-more" href="./hilfe.html">Alle Funktionen erklärt: Hilfe & Tutorial</a>':''}</div>`;
  const nx=tourEl.querySelector('[data-tour="next"]');if(nx)nx.focus();
 };
 tourEl.addEventListener('click',e=>{const b=e.target.closest('[data-tour]');if(!b)return;
  if(b.dataset.tour==='skip')finish(false);else if(b.dataset.tour==='back'){i=Math.max(0,i-1);draw()}else if(i<steps.length-1){i++;draw()}else finish(true)});
 document.addEventListener('keydown',onKey);
 document.body.appendChild(tourEl);draw();
}
// Mein Studio: Tour beim nächsten Login, einmal pro Person und Version.
async function maybeTour(){
 const db=await client();
 const s=await db.auth.getSession();if(!s.data||!s.data.session)return;
 const {data,error}=await db.rpc('get_my_onboarding');
 if(error||!data||!data.enabled||Number(data.tour_version)>=TOUR_VERSION)return;
 runTour({role:data.role,onDone:()=>{db.rpc('mark_tour_seen',{p_version:TOUR_VERSION}).then(r=>{if(r.error)console.warn('Tour-Stand nicht gespeichert:',r.error.message)})}});
}
window.TLHelp={GROUPS,REGISTERS,PAGE_KEY,TOUR,TOUR_VERSION,tourSteps,runTour,maybeTour,client,esc};
if(document.body&&document.body.dataset.tlScreen==='boxer'){
 const go=()=>setTimeout(()=>maybeTour().catch(e=>console.warn('Tour nicht verfügbar:',e)),600);
 if(document.readyState==='complete')go();else window.addEventListener('load',go,{once:true});
}
})();
