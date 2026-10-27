// Takeover League: Mein Studio gamification layer (read-only, no EXP is awarded here).
// Weekly quests and week streak, rival hint from the public leaderboard, "Fast geschafft"
// achievement progress and a one-time level-up celebration. Server data stays authoritative:
// achievements, levels and EXP are still decided by the database.

const ACH_FAMILIES={
 training:{label:'Trainings',unit:n=>n===1?'Training':'Trainings',thresholds:[10,25,50,100]},
 consistent:{label:'Trainingstage',unit:n=>n===1?'Trainingstag':'Trainingstage',thresholds:[10,25,60,120]},
 road:{label:'Lauf-Kilometer',unit:()=>'km',thresholds:[25,75,150,300]},
 flash:{label:'Sprint-Intervalle',unit:n=>n===1?'Sprint-Einheit':'Sprint-Einheiten',thresholds:[5,15,30,60]},
 technician:{label:'Technik-Minuten',unit:()=>'Technik-Minuten',thresholds:[300,900,1800,3600]},
 fighter:{label:'Sparring',unit:n=>n===1?'Sparring':'Sparrings',thresholds:[5,15,30,60]},
 engine:{label:'Krafttraining',unit:n=>n===1?'Krafttraining':'Krafttrainings',thresholds:[10,25,50,100]},
 complete:{label:'Komplette Runden',unit:n=>n===1?'komplette Runde':'komplette Runden',thresholds:[1,3,7,15]}
};
const TIER_NAMES=['Bronze','Silber','Gold','Platin'];
const TIER_REWARD=[25,60,125,250];
// Same six training types the database uses for achievements and "Complete Boxer".
const TYPE_KEYS={'reguläres boxtraining':'boxing','sparring':'sparring','techniktraining':'technique',
 'krafttraining':'strength','sprint-intervalle':'sprint','joggen':'jogging'};
const LEVEL_RANKS=[['F','Rookie'],['E','Prospect'],['D','Contender'],['C','Challenger'],['B','Elite Fighter'],['A','Champion'],['S','Legend']];
const WEEK_GOAL=2;

const el=(tag,cls,text)=>{const n=document.createElement(tag);if(cls)n.className=cls;if(text!==undefined)n.textContent=String(text);return n};
const fmt=v=>Number(v||0).toLocaleString('de-CH',{maximumFractionDigits:1});
const store={
 get(k){try{return localStorage.getItem(k)}catch{return null}},
 set(k,v){try{localStorage.setItem(k,v)}catch{}}
};

export function levelFromExp(total){
 const xp=Math.max(0,Number(total)||0);
 const n=Math.max(0,Math.floor((Math.sqrt(49+0.32*xp)-7)/2));
 const level=n+1;
 const [letter,name]=LEVEL_RANKS[Math.min(Math.floor((level-1)/10),LEVEL_RANKS.length-1)];
 return {level,letter,name};
}

function dayKey(d){return d.getFullYear()+'-'+String(d.getMonth()+1).padStart(2,'0')+'-'+String(d.getDate()).padStart(2,'0')}
function parseDay(s){const [y,m,d]=String(s).split('-').map(Number);return new Date(y,m-1,d)}
// Monday-based calendar week, local time (Europe/Zurich for the league).
export function weekStart(date){const d=new Date(date.getFullYear(),date.getMonth(),date.getDate());const wd=(d.getDay()+6)%7;d.setDate(d.getDate()-wd);return dayKey(d)}
function shiftWeek(key,weeks){const d=parseDay(key);d.setDate(d.getDate()+7*weeks);return dayKey(d)}

function typeKeyFor(row,typeNames){
 const name=String(typeNames.get(String(row.training_type_id))||'').trim().toLowerCase();
 return TYPE_KEYS[name]||'other';
}

export function weeklyState(rows,typeNames,today=new Date()){
 const current=weekStart(today);
 const valid=rows.filter(r=>/^\d{4}-\d{2}-\d{2}$/.test(r.training_date||''));
 const inWeek=valid.filter(r=>weekStart(parseDay(r.training_date))===current);
 const approved=inWeek.filter(r=>r.status==='approved'),pending=inWeek.filter(r=>r.status==='pending');
 const count=(list,keys)=>list.filter(r=>keys.includes(typeKeyFor(r,typeNames))).length;
 const quests=[
  {key:'sessions',title:'Zwei Trainings',hint:'Zwei bestätigte Trainings in dieser Woche.',goal:WEEK_GOAL,
   done:approved.length,waiting:pending.length},
  {key:'boxing',title:'Am Sack und im Ring',hint:'Ein Boxtraining, Techniktraining oder Sparring.',goal:1,
   done:count(approved,['boxing','technique','sparring']),waiting:count(pending,['boxing','technique','sparring'])},
  {key:'engine',title:'Motor aufbauen',hint:'Einmal Joggen, Sprint-Intervalle oder Krafttraining.',goal:1,
   done:count(approved,['jogging','sprint','strength']),waiting:count(pending,['jogging','sprint','strength'])}
 ];
 // Week streak: consecutive weeks with at least WEEK_GOAL approved trainings. The running week
 // only counts once it is complete, so an unfinished week never breaks the streak.
 const perWeek=new Map();
 for(const r of valid)if(r.status==='approved'){const w=weekStart(parseDay(r.training_date));perWeek.set(w,(perWeek.get(w)||0)+1)}
 const currentMet=(perWeek.get(current)||0)>=WEEK_GOAL;
 let cursor=currentMet?current:shiftWeek(current,-1),streak=0;
 while((perWeek.get(cursor)||0)>=WEEK_GOAL&&streak<520){streak++;cursor=shiftWeek(cursor,-1)}
 return {quests,streak,currentMet,missing:Math.max(0,WEEK_GOAL-approved.length),pending:pending.length};
}

export function achievementProgress(rows,typeNames){
 const approved=rows.filter(r=>r.status==='approved');
 const per={boxing:0,sparring:0,technique:0,strength:0,sprint:0,jogging:0};
 let km=0,minutes=0;
 for(const r of approved){
  const key=typeKeyFor(r,typeNames);if(key in per)per[key]++;
  if(key==='jogging')km+=Number(r.jogging_km)||0;
  if(key==='technique')minutes+=Number(r.technique_minutes)||0;
 }
 return {training:approved.length,consistent:new Set(approved.map(r=>r.training_date)).size,road:km,
  flash:per.sprint,technician:minutes,fighter:per.sparring,engine:per.strength,
  complete:Math.min(...Object.values(per))};
}

export function nextAchievements(progress,owned,definitions,limit=3){
 const out=[];
 for(const d of definitions){
  const [family,value]=String(d.code||'').split('_');const meta=ACH_FAMILIES[family];if(!meta)continue;
  const threshold=Number(value),tier=meta.thresholds.indexOf(threshold);if(tier<0||owned.has(d.id))continue;
  const have=progress[family]||0;if(have<=0)continue;
  out.push({title:d.title,family,threshold,tier,have,missing:Math.max(0,threshold-have),ratio:Math.min(1,have/threshold),reward:TIER_REWARD[tier],unit:meta.unit});
 }
 // Only the next tier per family, closest first.
 const best=new Map();
 for(const item of out.sort((a,b)=>a.threshold-b.threshold))if(!best.has(item.family))best.set(item.family,item);
 return [...best.values()].sort((a,b)=>b.ratio-a.ratio||a.missing-b.missing).slice(0,limit);
}

export function rivalHint(rows,myName){
 const list=(Array.isArray(rows)?rows:[]).filter(r=>r&&r.boxer_name);
 const mine=list.filter(r=>String(r.boxer_name).trim()===String(myName||'').trim());
 if(mine.length!==1)return null;
 const me=mine[0],pos=list.indexOf(me);
 const myPoints=Number(me.monthly_points)||0;
 if(pos===0){
  const next=list[1];
  return {rank:1,leader:true,name:next?next.boxer_name:null,gap:next?myPoints-(Number(next.monthly_points)||0):null};
 }
 const above=list[pos-1];
 return {rank:Number(me.rank_position)||pos+1,leader:false,name:above.boxer_name,
  targetRank:Number(above.rank_position)||pos,gap:Math.max(0,(Number(above.monthly_points)||0)-myPoints)};
}

function questCard(root,state){
 root.replaceChildren();
 const head=el('div','tl-quest-head');
 const streak=el('p','tl-quest-streak');
 const flame=el('strong','',state.streak);streak.append(flame,document.createTextNode(state.streak===1?' Woche in Folge':' Wochen in Folge'));
 head.append(streak);
 const note=el('p','tl-quest-note');
 if(state.currentMet)note.textContent='Wochenziel erreicht. Deine Serie läuft weiter.';
 else if(state.streak>0)note.textContent='Fast geschafft: noch '+state.missing+(state.missing===1?' bestätigtes Training':' bestätigte Trainings')+' diese Woche, dann wächst deine Serie auf '+(state.streak+1)+'.';
 else note.textContent='Starte deine Serie: '+WEEK_GOAL+' bestätigte Trainings pro Woche.';
 head.append(note);root.append(head);
 const list=el('ul','tl-quest-list');
 for(const q of state.quests){
  const item=el('li','tl-quest');const done=q.done>=q.goal;item.dataset.done=String(done);
  const mark=el('span','tl-quest-mark',done?'✓':String(Math.min(q.done,q.goal))+'/'+q.goal);mark.setAttribute('aria-hidden','true');
  const body=el('div','tl-quest-body');
  body.append(el('strong','',q.title),el('small','',q.hint));
  if(!done&&q.waiting)body.append(el('small','tl-quest-wait',q.waiting===1?'1 Training wartet auf Bestätigung':q.waiting+' Trainings warten auf Bestätigung'));
  const sr=el('span','tl-sr',done?'Erledigt':'Fortschritt '+Math.min(q.done,q.goal)+' von '+q.goal);
  item.append(mark,body,sr);list.append(item);
 }
 root.append(list);
}

function rivalCard(root,hint){
 root.replaceChildren();
 if(!hint){root.append(el('p','tl-quest-note','Sammle diesen Monat Punkte, dann siehst du hier, wen du als Nächstes überholen kannst.'));return}
 if(hint.leader){
  root.append(el('p','tl-rival-main','Du führst die Monatsrangliste an.'));
  if(hint.name)root.append(el('p','tl-quest-note',fmt(hint.gap)+' Punkte Vorsprung auf '+hint.name+'. Bleib dran.'));
  return;
 }
 const main=el('p','tl-rival-main');
 main.append(document.createTextNode('Platz '+hint.rank+' · Dein Rivale: '),el('strong','',hint.name));
 root.append(main);
 root.append(el('p','tl-quest-note',hint.gap===0
  ?'Punktgleich mit Platz '+hint.targetRank+'. Ein Training entscheidet.'
  :'Noch '+fmt(hint.gap)+' Punkte bis Platz '+hint.targetRank+'.'));
}

function nextGoalsList(root,items){
 root.replaceChildren();
 if(!items.length){root.append(el('p','tl-quest-note','Trage Trainings ein, dann zeigen wir dir hier deine nächsten Achievements.'));return}
 const list=el('ul','tl-goal-list');
 for(const it of items){
  const li=el('li','tl-goal');
  li.append(el('strong','',it.title));
  const bar=el('div','tl-goal-bar');bar.setAttribute('role','progressbar');bar.setAttribute('aria-valuemin','0');
  bar.setAttribute('aria-valuemax',String(it.threshold));bar.setAttribute('aria-valuenow',String(Math.min(it.have,it.threshold)));
  bar.setAttribute('aria-label',it.title+': '+fmt(it.have)+' von '+fmt(it.threshold));
  const fill=el('span');fill.style.width=Math.round(100*it.ratio)+'%';bar.append(fill);li.append(bar);
  li.append(el('small','',(it.ratio>=0.75?'Fast geschafft: noch ':'Noch ')+fmt(it.missing)+' '+it.unit(it.missing)+' · +'+it.reward+' EXP'));
  list.append(li);
 }
 root.append(list);
}

// One tile per family (8 instead of 32): earned tiers as pips plus progress to the next tier.
function achievementGrid(root,progress,owned,definitions){
 root.replaceChildren();
 const byFamily=new Map();
 for(const d of definitions){
  const [family,value]=String(d.code||'').split('_');const meta=ACH_FAMILIES[family];if(!meta)continue;
  const tier=meta.thresholds.indexOf(Number(value));if(tier<0)continue;
  if(!byFamily.has(family))byFamily.set(family,[]);
  byFamily.get(family).push({...d,tier,threshold:Number(value),earned:owned.has(d.id)});
 }
 for(const [family,list] of byFamily){
  list.sort((a,b)=>a.tier-b.tier);
  const meta=ACH_FAMILIES[family],earned=list.filter(x=>x.earned),next=list.find(x=>!x.earned);
  const tile=el('div','achievement-tile '+(earned.length?'earned':'achievement-locked'));
  const name=String((next||list[list.length-1]).title).split(' – ')[0];
  tile.append(el('div','achievement-title',name));
  const pips=el('div','achievement-pips');
  for(const x of list){const pip=el('span','achievement-pip'+(x.earned?' on':''),TIER_NAMES[x.tier]);pip.title=x.title+(x.earned?' · freigeschaltet':'');pips.append(pip)}
  tile.append(pips);
  const have=progress[family]||0;
  if(next){
   const bar=el('div','tl-goal-bar');bar.setAttribute('role','progressbar');bar.setAttribute('aria-valuemin','0');
   bar.setAttribute('aria-valuemax',String(next.threshold));bar.setAttribute('aria-valuenow',String(Math.min(have,next.threshold)));
   bar.setAttribute('aria-label',next.title+': '+fmt(have)+' von '+fmt(next.threshold));
   const fill=el('span');fill.style.width=Math.round(100*Math.min(1,have/next.threshold))+'%';bar.append(fill);tile.append(bar);
   tile.append(el('div','achievement-meta','Nächstes Ziel '+TIER_NAMES[next.tier]+': '+fmt(Math.min(have,next.threshold))+' / '+fmt(next.threshold)+' '+meta.unit(next.threshold)+' · +'+TIER_REWARD[next.tier]+' EXP'));
  }else tile.append(el('div','achievement-meta','Alle Stufen freigeschaltet. Legende!'));
  root.append(tile);
 }
}

function celebrate(level,previous){
 const backdrop=el('div','tl-levelup-backdrop');const box=el('div','tl-levelup');box.setAttribute('role','dialog');box.setAttribute('aria-modal','true');box.setAttribute('aria-labelledby','tlLevelUpTitle');
 const rankChanged=previous&&previous.letter!==level.letter;
 const badge=el('div','tl-levelup-badge',level.letter);badge.setAttribute('aria-hidden','true');
 const title=el('h2','',rankChanged?'Neuer Rang: '+level.letter+' · '+level.name:'Level '+level.level+' erreicht!');title.id='tlLevelUpTitle';
 const text=el('p','',rankChanged?'Du bist jetzt Level '+level.level+'. Willkommen in der nächsten Liga.':'Rang '+level.letter+' · '+level.name+'. Jede bestätigte Einheit bringt dich weiter.');
 const close=el('button','tl-primary','Weiter');close.type='button';
 const done=()=>{backdrop.remove();document.removeEventListener('keydown',onKey)};
 const onKey=e=>{if(e.key==='Escape')done()};
 close.onclick=done;document.addEventListener('keydown',onKey);
 backdrop.addEventListener('click',e=>{if(e.target===backdrop)done()});
 box.append(badge,title,text,close);backdrop.append(box);document.body.append(backdrop);
 setTimeout(()=>close.focus(),50);
}

function section(id,heading,intro){
 const s=el('section','card tl-gamify');s.id=id;s.setAttribute('aria-labelledby',id+'Heading');
 const h=el('h2','',heading);h.id=id+'Heading';s.append(h);
 if(intro)s.append(el('p','tl-quest-note',intro));
 const body=el('div','tl-gamify-body');s.append(body);
 return {section:s,body};
}

export async function mountGamification({db,profile,types,getHistory}){
 if(!db||!profile||document.getElementById('weeklyQuestsSection'))return null;
 const typeNames=new Map((types||[]).map(t=>[String(t.id),t.name]));
 const pulse=document.getElementById('studioPulseSection');
 const quests=section('weeklyQuestsSection','Wochen-Quests');
 const rival=section('rivalSection','Dein nächster Platz');
 const goals=section('nextGoalsSection','Fast geschafft');
 if(pulse){pulse.after(quests.section);quests.section.after(rival.section);rival.section.after(goals.section)}
 else return null;
 const goalsLink=el('a','tl-quest-link','Alle Achievements ansehen');goalsLink.href='#achievementsV2';
 goals.section.append(goalsLink);

 // Full achievement grid in the details tab, below EXP · Level · Rang (as before the redesign).
 let grid=null;
 const anchor=document.getElementById('expRankSection');
 if(anchor){
  const ach=section('achievementsV2','Achievements');ach.section.classList.remove('tl-gamify');
  const status=el('p','muted','Wird geladen …');status.id='achievementStatus';ach.section.insertBefore(status,ach.body);
  ach.body.className='achievement-grid';ach.body.id='achievementGrid';
  anchor.after(ach.section);grid={root:ach.body,status};
 }

 let definitions=[],owned=new Set(),achievementsOn=false;
 try{
  const [flag,defs,earned]=await Promise.all([
   db.from('league_feature_flags').select('is_enabled').eq('feature_key','achievements').maybeSingle(),
   db.from('achievement_definitions').select('id,code,title,description,is_active').eq('is_active',true).order('title'),
   db.from('boxer_achievements').select('achievement_id').eq('boxer_id',profile.id)
  ]);
  achievementsOn=!flag.error&&flag.data?.is_enabled===true;
  if(achievementsOn&&!defs.error&&!earned.error){
   definitions=(defs.data||[]).filter(d=>/^(training|consistent|road|flash|technician|fighter|engine|complete)_\d+$/.test(d.code));
   owned=new Set((earned.data||[]).map(x=>x.achievement_id));
  }else if(achievementsOn)throw (defs.error||earned.error);
 }catch(e){if(grid)grid.status.textContent='Achievements konnten nicht geladen werden.';}

 function renderAll(){
  const rows=(typeof getHistory==='function'?getHistory():[])||[];
  questCard(quests.body,weeklyState(rows,typeNames));
  const progress=achievementProgress(rows,typeNames);
  if(achievementsOn&&definitions.length){
   nextGoalsList(goals.body,nextAchievements(progress,owned,definitions));
   if(grid){achievementGrid(grid.root,progress,owned,definitions);grid.status.textContent=owned.size+' / '+definitions.length+' Achievements freigeschaltet'}
  }else{
   goals.section.hidden=true;
   if(grid&&!grid.status.textContent.includes('nicht'))grid.status.textContent='Bald verfügbar: Achievements werden demnächst freigeschaltet.';
  }
 }
 renderAll();
 document.addEventListener('takeover:history-loaded',renderAll);

 try{
  const board=await db.rpc('get_public_leaderboard');
  if(board.error)throw board.error;
  rivalCard(rival.body,rivalHint(board.data,profile.display_name));
 }catch{rival.section.hidden=true}

 // Level-up moment: remembered per device; the notification list keeps the permanent record.
 try{
  const r=await db.rpc('get_boxer_exp_level_rank',{p_boxer_id:profile.id});
  const row=Array.isArray(r.data)?r.data[0]:r.data;
  if(!r.error&&row){
   const level=levelFromExp(row.lifetime_exp),key='tl-last-level-'+profile.id,seen=Number(store.get(key));
   if(Number.isFinite(seen)&&seen>0&&level.level>seen){
    const [letter,name]=LEVEL_RANKS[Math.min(Math.floor((seen-1)/10),LEVEL_RANKS.length-1)];
    celebrate(level,{level:seen,letter,name});
   }
   store.set(key,String(level.level));
  }
 }catch{}

 if(location.hash==='#achievementsV2'){const t=document.getElementById('achievementsV2');if(t){window.dispatchEvent(new HashChangeEvent('hashchange'));t.scrollIntoView({block:'start'})}}
 return {refresh:renderAll};
}
