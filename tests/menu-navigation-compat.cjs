const fs=require('node:fs');
const assert=require('node:assert/strict');
const {JSDOM}=require('jsdom');
const pages=['index.html','login.html','boxer.html','coach.html','challenges.html','duels.html','awards.html','features.html','coming-soon.html','boxer-profile.html','arena.html','goals.html','boxer-compare.html','league-manager.html'];
const navScript=fs.readFileSync('takeover-navigation.js','utf8');
const navCss=fs.readFileSync('takeover-navigation.css','utf8');
const deploy=fs.readFileSync('.github/workflows/takeover-pages-deploy.yml','utf8');

assert.match(deploy,/name '.*\.js'/,'Pages deployment must copy shared JavaScript');
assert.match(deploy,/name '.*\.css'/,'Pages deployment must copy shared CSS');
for(const fragment of ['.tl-menu-panel','.tl-menu-backdrop','.tl-global-bottom','--tl-nav-gold:var(--gold)']) {
 assert.ok(navCss.includes(fragment),'Shared original-color styling missing: '+fragment);
}

let inspected=0;
for(const page of pages){
 const html=fs.readFileSync(page,'utf8');
 assert.match(html,/<link rel="stylesheet" href="\.\/takeover-navigation\.css">/,'Shared CSS missing from '+page);
 assert.match(html,/<script src="\.\/takeover-navigation\.js" defer><\/script>/,'Shared menu JS missing from '+page);
 assert.ok(!html.includes('id="takeover-menu-panel"'),'Duplicate drawer embedded in '+page);
 const dom=new JSDOM(html,{
   url:'https://benditocapela-ux.github.io/takeover-league/'+page,
   runScripts:'outside-only'
 });
 const win=dom.window,doc=win.document;
 let selectedTab=null;
 win.switchTab=tab=>{selectedTab=tab;};
 win.eval(navScript);
 doc.dispatchEvent(new win.Event('DOMContentLoaded',{bubbles:true}));
 const trigger=doc.getElementById('takeover-menu-open');
 const panel=doc.getElementById('tl-menu-panel');
 const backdrop=doc.getElementById('tl-menu-backdrop');
 const close=doc.getElementById('tl-menu-close');
 assert.ok(trigger&&panel&&backdrop&&close,'Menu button/drawer/close missing from '+page);
 assert.ok(trigger.querySelector('.tl-emoji'),'Menu button needs a clear emoji wayfinder on '+page);
 assert.ok(panel.querySelector('.tl-menu-icon .tl-emoji'),'Drawer links need emoji wayfinders on '+page);
 if(page==='index.html')assert.ok(doc.querySelector('[data-tl-wayfinder] .tl-section-emoji'),'League sections need emoji wayfinders');
 assert.equal(doc.querySelectorAll('#takeover-menu-open').length,1,'Multiple drawer buttons on '+page);
 assert.equal(doc.querySelectorAll('#tl-menu-panel').length,1,'Multiple drawers on '+page);
 assert.equal(trigger.getAttribute('aria-expanded'),'false',page+' drawer initial state');
 assert.equal(panel.getAttribute('aria-hidden'),'true');
 assert.equal(backdrop.hidden,true);

 const menuLink=href=>panel.querySelector('a.tl-menu-link[href="'+href+'"]');
 for(const href of [
  './index.html#podium','./index.html#ranking','./index.html#levels','./index.html#history',
  './awards.html','./challenges.html','./duels.html','./login.html','./boxer.html','./coach.html'
 ])assert.ok(menuLink(href),'Drawer missing '+href+' on '+page);

 const accordionButtons=Array.from(panel.querySelectorAll('.tl-menu-group-toggle'));
 assert.equal(accordionButtons.length,3,'Drawer should have three clear accordion categories on '+page);
 const combatToggle=accordionButtons.find(button=>/Kämpfe & Challenges/.test(button.textContent));
 const leagueToggle=accordionButtons.find(button=>/Liga & Erfolge/.test(button.textContent));
 assert.ok(combatToggle&&leagueToggle,'Wettkampf and Liga categories missing on '+page);
 trigger.click();
 if(combatToggle.getAttribute('aria-expanded')!=='true')combatToggle.click();
 assert.equal(combatToggle.getAttribute('aria-expanded'),'true','Combat category should expand on '+page);
 assert.equal(menuLink('./duels.html').closest('.tl-menu-group-links').hidden,false,'Duel link should be visible when category is expanded on '+page);
 if(leagueToggle.getAttribute('aria-expanded')!=='true')leagueToggle.click();
 assert.equal(leagueToggle.getAttribute('aria-expanded'),'true','League category should expand on '+page);
 assert.equal(combatToggle.getAttribute('aria-expanded'),'false','Accordion should collapse the previous category on '+page);
 assert.equal(menuLink('./duels.html').closest('.tl-menu-group-links').hidden,true,'Duel links should collapse with their category on '+page);
 close.click();
 assert.equal(trigger.getAttribute('aria-expanded'),'false','Accordion test should leave menu closed on '+page);

 if(page==='boxer.html'){
   const select=doc.querySelector('select[data-tl-choice="training-kind"]');
   const rail=doc.querySelector('.tl-choice-rail[data-choice-for="training-kind"]');
   assert.ok(select&&rail,'Training choice-card markup missing');
   const option=doc.createElement('option');option.value='browser-fixture';option.textContent='Sparring';
   select.append(option);select.dispatchEvent(new win.Event('change',{bubbles:true}));
   const card=rail.querySelector('button[data-value="browser-fixture"]');
   assert.ok(card,'Training type card should refresh when options arrive');
   card.click();assert.equal(select.value,'browser-fixture','Training card must synchronize with the existing select');
 }
 if(page==='goals.html'){
   const select=doc.querySelector('select[data-tl-choice="goal-metric"]');
   const rail=doc.querySelector('.tl-choice-rail[data-choice-for="goal-metric"]');
   assert.ok(select&&rail&&rail.querySelectorAll('.tl-choice-card').length===4,'Goal metrics should render as choice cards');
   rail.querySelector('button[data-value="jogging_km"]').click();
   assert.equal(select.value,'jogging_km','Goal metric card must update the existing select');
 }
 if(page==='challenges.html'){
   const select=doc.querySelector('select[data-tl-choice="challenge-kind"]');
   const rail=doc.querySelector('.tl-choice-rail[data-choice-for="challenge-kind"]');
   assert.ok(select&&rail&&rail.querySelectorAll('.tl-choice-card').length===3,'Challenge types should render as choice cards');
   rail.querySelector('button[data-value="competition"]').click();
   assert.equal(select.value,'competition','Challenge type card must update the existing select');
 }
 if(page==='boxer-compare.html'){
   const select=doc.querySelector('select[data-tl-choice="compare-left"]');
   const rail=doc.querySelector('.tl-choice-rail[data-choice-for="compare-left"]');
   assert.ok(select&&rail,'Boxer comparison choice-card markup missing');
   for(const [value,label] of [['alpha','Boxer Alpha'],['beta','Boxer Beta']]){
     const option=doc.createElement('option');option.value=value;option.textContent=label;select.append(option);
   }
   select.dispatchEvent(new win.Event('change',{bubbles:true}));
   rail.querySelector('button[data-value="beta"]').click();
   assert.equal(select.value,'beta','Boxer comparison card must update the original select');
 }
 if(page==='league-manager.html'){
   const select=doc.querySelector('select[data-tl-choice="manager-goal-metric"]');
   const rail=doc.querySelector('.tl-choice-rail[data-choice-for="manager-goal-metric"]');
   assert.ok(select&&rail&&rail.querySelectorAll('.tl-choice-card').length===4,'Manager goal metrics should render as cards');
   rail.querySelector('button[data-value="jogging_km"]').click();
   assert.equal(select.value,'jogging_km','Manager goal metric card must update the original select');
 }
 if(page==='arena.html'){
   const select=doc.querySelector('select[data-tl-choice="arena-boxers"]');
   const rail=doc.querySelector('.tl-choice-rail[data-choice-for="arena-boxers"]');
   assert.ok(select&&rail,'Arena boxer choice-card markup missing');
   for(const [value,label] of [['alpha','Boxer Alpha'],['beta','Boxer Beta'],['gamma','Boxer Gamma']]){
     const option=doc.createElement('option');option.value=value;option.textContent=label;select.append(option);
   }
   select.dispatchEvent(new win.Event('change',{bubbles:true}));
   const cards=rail.querySelectorAll('.tl-choice-card');
   assert.equal(cards.length,3,'Arena options should render as multi-select cards');
   cards[0].click();cards[1].click();
   assert.equal(select.selectedOptions.length,2,'Arena cards should preserve multi-select behavior');
 }
 const footer=page==='index.html'
   ?doc.querySelector('.bottom')
   :doc.querySelector('.tl-global-bottom');
 assert.ok(footer,'Persistent bottom navigation missing on '+page);
 assert.equal(footer.querySelectorAll('.nav,.tl-nav-item').length,4,'Bottom bar must have four items on '+page);
 assert.ok(footer.querySelector('a[href="./login.html"]'),'Dashboard absent from bottom on '+page);
 assert.ok(!footer.querySelector('[data-tab="levels"],[data-tab="history"],[data-tl-tab="levels"],[data-tl-tab="history"]'),
 'Levels/History must be drawer-only on '+page);
 if(page==='index.html'){
   assert.ok(html.includes('href="./takeover-theme.css"'),'Central design foundation missing from index');
   const theme=fs.readFileSync('takeover-theme.css','utf8');
   for(const token of ['--bg:#070d1a','--surface:#0e1c32','--gold:#c9a86b','--ok:#558f6a'])assert.ok(theme.includes(token),'Central token missing: '+token);
   for(const id of ['podium','ranking','levels','history','podium-content','ranking-content','levels-content','history-content'])
     assert.ok(doc.getElementById(id),'Original league section missing: '+id);
   assert.equal(doc.querySelectorAll('.tl-global-bottom').length,0,'Home must not have duplicate footer');
 }else{
   assert.equal(footer.querySelector('[data-tl-tab="podium"]').getAttribute('href'),'./index.html#podium');
   assert.equal(footer.querySelector('[data-tl-tab="ranking"]').getAttribute('href'),'./index.html#ranking');
 }
 // Try to reopen the same menu repeatedly on every page.
 for(let attempt=0;attempt<3;attempt++){
   trigger.click();
   assert.equal(trigger.getAttribute('aria-expanded'),'true','Cannot reopen menu on '+page);
   assert.equal(panel.getAttribute('aria-hidden'),'false');
   assert.equal(backdrop.hidden,false);
   assert.ok(doc.body.classList.contains('tl-menu-visible'));
   if(attempt===0){
     close.click();
   }else if(attempt===1){
     doc.dispatchEvent(new win.KeyboardEvent('keydown',{key:'Escape',bubbles:true}));
   }else{
     backdrop.click();
   }
   assert.equal(trigger.getAttribute('aria-expanded'),'false','Cannot close menu on '+page);
   assert.equal(backdrop.hidden,true);
   assert.equal(panel.getAttribute('aria-hidden'),'true');
 }
 if(page==='index.html'){
   trigger.click();
   menuLink('./index.html#levels').click();
   assert.equal(selectedTab,'levels','Levels should open immediately on existing index');
   assert.equal(win.location.hash,'#levels');
   assert.equal(trigger.getAttribute('aria-expanded'),'false');
   assert.ok(trigger.classList.contains('active'),'Drawer tab should highlight when Levels is selected');
   trigger.click();
   menuLink('./index.html#history').click();
   assert.equal(selectedTab,'history');
   assert.equal(win.location.hash,'#history');
 }else{
   assert.ok(menuLink('./index.html#levels'),'Levels must deep-link from '+page);
   assert.ok(menuLink('./index.html#history'),'History must deep-link from '+page);
 }
 dom.window.close();
 inspected++;
}

// The same links used on external pages must restore the original live tab view.
for(const tab of ['levels','history','ranking']){
 const src=fs.readFileSync('index.html','utf8');
 const dom=new JSDOM(src,{url:'https://benditocapela-ux.github.io/takeover-league/index.html#'+tab,runScripts:'outside-only'});
 let selected=null;
 dom.window.switchTab=x=>{selected=x;};
 dom.window.eval(navScript);
 dom.window.document.dispatchEvent(new dom.window.Event('DOMContentLoaded',{bubbles:true}));
 assert.equal(selected,tab,'Cross-page deep link failed to restore '+tab);
 dom.window.close();
}
console.log('PASS: Shared drawer reopens on all '+inspected+' public HTML pages; index deep links, original layout, four footer items and focus controls verified.');
