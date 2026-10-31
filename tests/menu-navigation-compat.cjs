const fs=require('node:fs');
const assert=require('node:assert/strict');
const {JSDOM}=require('jsdom');
const pages=['index.html','login.html','boxer.html','coach.html','challenges.html','duels.html','awards.html','features.html','coming-soon.html','boxer-profile.html'];
const navScript=fs.readFileSync('takeover-navigation.js','utf8');
const navCss=fs.readFileSync('takeover-navigation.css','utf8');
const deploy=fs.readFileSync('.github/workflows/takeover-pages-deploy.yml','utf8');

assert.ok(deploy.includes('node tools/assemble-pages-site.cjs _site'),'Pages must use the tested assembler');
const os=require('node:os'),path=require('node:path');
const staging=fs.mkdtempSync(path.join(os.tmpdir(),'navigation-pages-'));
try{
 require('../tools/assemble-pages-site.cjs').assemble(process.cwd(),staging);
 for(const name of ['takeover-navigation.js','takeover-navigation.css'])
  assert.deepEqual(fs.readFileSync(path.join(staging,name)),fs.readFileSync(name),'Pages navigation '+name);
}finally{fs.rmSync(staging,{recursive:true,force:true})}
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
   for(const token of ['--bg:#070b16','--surface:#0f1830','--gold:#f2c14e','--ok:#5fb27f'])assert.ok(theme.includes(token),'Central token missing: '+token);
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
