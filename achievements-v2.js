// Takeover League 2.0: boxer achievement display. Read-only UI.
export async function mountAchievements(db, boxerId) {
  const anchor=document.getElementById('expRankSection');
  if(!anchor || document.getElementById('achievementsV2')) return;
  const section=document.createElement('section');
  section.className='card';
  section.id='achievementsV2';
  section.innerHTML='<h2>Achievements</h2><p class="muted" id="achievementStatus">Wird geladen …</p><div id="achievementGrid" class="achievement-grid"></div>';
  anchor.insertAdjacentElement('afterend',section);
  const css=document.createElement('style');
  css.textContent='.achievement-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(210px,1fr));gap:12px}.achievement-tile{background:#101d30;border:1px solid #34465f;border-radius:12px;padding:15px}.achievement-tile.earned{border-color:#dfbd77}.achievement-title{font-weight:750}.achievement-meta{color:#b6c2d0;font-size:13px;margin-top:6px}.achievement-tier{font-size:12px;color:#dfbd77;margin-bottom:6px}.achievement-locked{opacity:.65}';
  document.head.append(css);
  const status=document.getElementById('achievementStatus'),grid=document.getElementById('achievementGrid');
  try {
    const [flag,definitions,earned]=await Promise.all([
      db.from('league_feature_flags').select('is_enabled').eq('feature_key','achievements').maybeSingle(),
      db.from('achievement_definitions').select('id,code,title,description,is_active').eq('is_active',true).order('title'),
      db.from('boxer_achievements').select('achievement_id').eq('boxer_id',boxerId)
    ]);
    if(flag.error) throw flag.error;
    if(flag.data?.is_enabled!==true){status.textContent='Bald verfügbar: Achievements werden demnächst freigeschaltet.';return;}
    if(definitions.error) throw definitions.error;
    if(earned.error) throw earned.error;
    const owned=new Set((earned.data||[]).map(x=>x.achievement_id));
    const defs=(definitions.data||[]).filter(x=>/^(training|consistent|road|flash|technician|fighter|engine|complete)_\d+$/.test(x.code));
    const rewardByTier=[25,60,125,250], tierNames=['Bronze','Silber','Gold','Platin'];
    const thresholds={training:[10,25,50,100],consistent:[10,25,60,120],road:[25,75,150,300],flash:[5,15,30,60],technician:[300,900,1800,3600],fighter:[5,15,30,60],engine:[10,25,50,100],complete:[1,3,7,15]};
    grid.replaceChildren();
    for(const d of defs){
      const [family,value]=d.code.split('_');
      const tier=thresholds[family]?.indexOf(Number(value))??-1;
      if(tier<0)continue;
      const unlocked=owned.has(d.id),tile=document.createElement('div');
      tile.className='achievement-tile '+(unlocked?'earned':'achievement-locked');
      const t=document.createElement('div');t.className='achievement-tier';t.textContent=(unlocked?'🏅 Freigeschaltet · ':'🔒 Gesperrt · ')+tierNames[tier];
      const name=document.createElement('div');name.className='achievement-title';name.textContent=d.title;
      const desc=document.createElement('div');desc.className='achievement-meta';desc.textContent=d.description||'';
      const xp=document.createElement('div');xp.className='achievement-meta';xp.textContent='+'+rewardByTier[tier]+' EXP bei Freischaltung';
      tile.append(t,name,desc,xp);grid.append(tile);
    }
    status.textContent=owned.size+' / '+defs.length+' Achievements freigeschaltet';
  }catch(e){status.textContent='Achievements konnten nicht geladen werden: '+(e?.message||String(e));}
}
